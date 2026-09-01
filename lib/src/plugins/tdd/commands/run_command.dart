/// `zfa tdd run <feature>` — the resumable driver for the full
/// red-green-refactor loop (spec 049-tdd-run, FR-001..011; 041 Phase 10,
/// T070-T076).
///
/// Given a feature with a behavior test list, the driver walks every
/// behavior through the certified steps delivered by specs 044 (`gen`),
/// 046 (`verify-red`), 047 (`make`), and 048 (`refactor`), spawning each
/// as a sub-process of this CLI and consuming its machine-readable
/// contract (summary line + exit code — never prose). Per-behavior state
/// plus the in-flight behavior/step persist to `tdd/run-state.json` after
/// every completed step, so a run interrupted for minutes or weeks resumes
/// exactly where it stopped.
///
/// Outside-in driving (bug #625): `zfa tdd plan` writes acceptance (A*)
/// behaviors before unit (U*) behaviors — the right reading order — but
/// acceptance prose is unexpressible to the generation planner by design,
/// so one uniform per-behavior cycle deadlocked every feature at its
/// first acceptance `make`, before any unit behavior could run. The
/// driver therefore drives the loop in two passes:
///
/// - **Phase 1** — the uniform cycle in list order, with two deferrals
///   (bugs #625, #635 and #657). ANY behavior whose `make` reports
///   `unexpressible` — the planner's by-design refusal of acceptance
///   prose (bug #625), or of a unit plain-function behavior until `zfa
///   tdd func` scaffolds it (bug #657) — is deferred instead of stopping
///   the feature: `[run] A1 make -> deferred (phase 2)`. And because
///   `refactor` (spec 048 FR-001) demands an absolutely green suite —
///   impossible while a deferred behavior sits honestly RED — ANY
///   behavior whose `refactor` comes due while ANY behavior sits RED
///   defers too: `[run] U1 refactor -> deferred (phase 2)` (bug #635;
///   the deferral concept is applied to both steps, not half-applied to
///   `make` alone). Deferred behaviors stay at their last completed
///   state (RED / GREEN) while the rest of phase 1 proceeds. Any other
///   step failure still stops the run honestly (FR-007), and a behavior
///   whose make IS expressible completes its whole cycle exactly as
///   before — by the time its refactor runs, no behavior is RED.
/// - **Phase 2** — the deferred work finishes on the now-fully-green
///   suite, in two stages. First every deferred behavior re-attempts
///   `make` in list order (bug #625; generalized to unit behaviors by
///   bug #657); a green outcome flips it, and `unexpressible` here is a
///   real, honest stop with everything else done (FR-007). Then a
///   refactor pass runs `refactor` for every behavior still short of
///   DONE — per behavior, in list order — on the fully-green suite and
///   marks each DONE (bug #635), keeping refactor's absolute-green
///   contract met by construction.
///
/// Run-state semantics are unchanged: deferred behaviors sit RED
/// between the phases (their unit siblings sit GREEN with the refactor
/// deferred, bug #635), and a run interrupted anywhere resumes exactly
/// where it stopped.
///
/// Honesty rules:
/// - Evidence beats state, in both directions: a behavior is DONE only when
///   its red AND green entries exist in `tdd/cycle-log.md`; a state-file
///   claim without evidence is demoted to the evidence-backed state, and —
///   when no in-flight marker marks the file as an interrupted run — a
///   pending (or missing) claim with evidence is promoted to it (FR-003;
///   bug #682 — a missing or all-pending `run-state.json` bootstraps from
///   existing brownfield evidence instead of re-driving certified
///   behaviors).
/// - Any step failure stops the run immediately, non-zero: the behavior is
///   left at its last fully-completed state, the failing step and outcome
///   are named, later behaviors never start, and resume instructions are
///   printed (FR-007). Bounded partial progress is the designed outcome of
///   a stop; silently faking progress is the forbidden one.
/// - A corrupted state file stops the driver naming the corruption and the
///   recovery path; a second concurrent run is refused via the in-flight
///   marker (FR-006).
/// - The driver never edits a test or source file, never retries a failed
///   step silently, and never marks DONE without complete evidence
///   (FR-008).
///
/// Machine contract (FR-009/FR-010): every completed step prints
/// `[run] <behavior> <step> -> <outcome>`, and every invocation ends with
/// the final summary line
/// `run: feature=<f> result=<r> pending=<n> red=<n> green=<n> done=<n>`
/// plus ` stopped_at=<behavior>:<step>` when stopped. Exit codes:
/// 0 complete, 1 stopped, 2 runner-error, 3 corrupt-state,
/// 4 concurrent-run — 0 means exactly "all DONE with complete evidence".
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../services/cycle_evidence.dart';
import '../services/run_state_store.dart';
import '../services/step_runner.dart';
import '../services/test_list_reader.dart';
import '../tdd_plugin.dart';

class RunCommand extends Command<void> {
  RunCommand(this.plugin) {
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/, test/, and .specify/ (the fixture '
          'or target project). When omitted, the current working directory '
          'is used. The driver never mutates the process-global working '
          'directory.',
    );
    argParser.addOption(
      'zfa-bin',
      help:
          'Path to the zfa CLI entrypoint used to spawn the step commands '
          '(defaults to this package\'s bin/zfa.dart). Point this at a '
          'scripted fake to drive the loop against stubbed steps.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'run';

  @override
  String get description =>
      'Drive every behavior in a feature\'s tdd/test-list.md through '
      'gen -> verify-red -> make -> refactor, resuming from '
      'tdd/run-state.json and stopping honestly on any step failure '
      '(spec 049).';

  @override
  String get invocation =>
      'zfa tdd run <feature> [--project <dir>] [--zfa-bin <path>]';

  static const _exitComplete = 0;
  static const _exitStopped = 1;
  static const _exitRunnerError = 2;
  static const _exitCorruptState = 3;
  static const _exitConcurrentRun = 4;

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      throw UsageException(
        'missing <feature> — name the spec directory whose test list to '
        'drive (e.g. 049-tdd-run)',
        invocation,
      );
    }
    final feature = _stripSpecsPrefix(rest.first);
    _validateFeatureSegment(feature);
    final projectFlag = argResults?['project'] as String?;
    final projectRoot = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : Directory.current.path;
    final zfaBin = argResults?['zfa-bin'] as String?;

    final featureDir = p.join(projectRoot, 'specs', feature);

    // -----------------------------------------------------------------
    // 1. Feature directory (misfire-stop when absent).
    // -----------------------------------------------------------------
    if (!await Directory(featureDir).exists()) {
      print(
        'zfa tdd run: no feature directory at '
        '${p.relative(featureDir, from: projectRoot)} (project root: '
        '$projectRoot)',
      );
      _printSummary(feature, 'runner-error', const [], null);
      exitCode = _exitRunnerError;
      return;
    }

    final store = RunStateStore(featureDir);

    // -----------------------------------------------------------------
    // 2. Load state — corruption stops with the recovery path (FR-006).
    // -----------------------------------------------------------------
    RunState? loaded;
    try {
      loaded = await store.load();
    } on RunStateCorruptException catch (e) {
      print('zfa tdd run: ${e.message}');
      _printSummary(feature, 'corrupt-state', const [], null);
      exitCode = _exitCorruptState;
      return;
    }

    // -----------------------------------------------------------------
    // 3. Concurrent-run refusal via the in-flight marker (FR-006).
    // -----------------------------------------------------------------
    final refusal = store.refusalReason(loaded);
    if (refusal != null) {
      print('zfa tdd run: $refusal');
      _printSummary(feature, 'concurrent-run', const [], null);
      exitCode = _exitConcurrentRun;
      return;
    }

    // -----------------------------------------------------------------
    // 4. Read the test list (misfire-stop on malformed rows, FR-011).
    // -----------------------------------------------------------------
    List<BehaviorRow> rows;
    try {
      rows = await TestListReader(featureDir).read();
    } on TestListReadException catch (e) {
      print('zfa tdd run: ${e.message}');
      _printSummary(feature, 'runner-error', const [], null);
      exitCode = _exitRunnerError;
      return;
    }
    if (rows.isEmpty) {
      print(
        'zfa tdd run: test list at specs/$feature/tdd/test-list.md has no '
        'behaviors',
      );
      _printSummary(feature, 'runner-error', const [], null);
      exitCode = _exitRunnerError;
      return;
    }
    final activeIds = rows.map((r) => r.id).toSet();

    // -----------------------------------------------------------------
    // 5. Reconcile state with evidence: evidence beats state (FR-003).
    // -----------------------------------------------------------------
    final evidence = CycleEvidence(featureDir);
    var current = _reconcile(
      loaded ?? RunState.empty(feature),
      rows,
      await evidence.redEvidence(),
      await evidence.greenEvidence(),
    );

    // Persist the reconciled state only when something actually changed
    // (new rows, a demotion, a dropped-marker difference) so an idempotent
    // re-run changes nothing at all.
    final loadedDropped = await store.readDropped();
    final needsInitialSave =
        loaded == null ||
        loaded.toJson() != current.toJson() ||
        !_listEquals(loadedDropped, store.computeDropped(current, activeIds));
    if (needsInitialSave) {
      await store.save(current, activeBehaviorIds: activeIds);
    }

    final skipped = rows
        .where((r) => current.behaviorStates[r.id] == BehaviorState.done)
        .length;
    print('zfa tdd run: feature $feature — ${rows.length} behavior(s)');
    if (skipped > 0) print('   $skipped already done — skipping');

    // -----------------------------------------------------------------
    // 6. Drive the loop in two phases (FR-001, FR-004..FR-008; bugs
    //    #625, #635 and #657).
    //
    // Phase 1 drives the uniform cycle in list order, EXCEPT that ANY
    // behavior whose make reports `unexpressible` is DEFERRED with
    // `[run] <id> make -> deferred (phase 2)` instead of stopping the
    // feature — the bug #625 acceptance-prose deadlock, generalized to
    // unit behaviors by bug #657 (plain-function behaviors have no
    // expressible surface until `zfa tdd func` scaffolds them; blocking
    // every later behavior on the first one starves the feature) — and
    // ANY behavior's refactor that comes due while any behavior sits
    // RED is deferred with `[run] <id> refactor -> deferred (phase 2)`
    // — the bug #635 deadlock (refactor's absolute-green preflight,
    // spec 048 FR-001, can never pass against a knowingly-red suite).
    // Phase 2 re-attempts the deferred makes, then runs refactor for
    // every behavior on the fully-green suite; `unexpressible` there is
    // a real, honest stop (FR-007) — by then every other behavior has
    // run, and make's own remediation line (bug #657) names the manual
    // path. Run-state semantics are unchanged: deferred behaviors sit
    // RED between the phases, resumable mid-corpus (FR-003..FR-005).
    // -----------------------------------------------------------------
    final runner = StepRunner(zfaBin: zfaBin);

    void applyStop(_Stop stop, RunState state) {
      if (stop.message != null) print('zfa tdd run: ${stop.message}');
      _printSummary(
        feature,
        stop.result,
        rows,
        state,
        stoppedAt: stop.stoppedAt,
      );
      exitCode = stop.exitCode;
    }

    // --- Phase 1: the uniform cycle in list order; a make that reports
    // unexpressible defers to phase 2 (bug #625 for acceptance prose,
    // bug #657 for unit plain-function behaviors), and refactors that
    // come due while ANY behavior sits RED defer too (bug #635, so a
    // deferred unit make leaves the suite knowingly red exactly like a
    // deferred acceptance make).
    for (final row in rows) {
      final state = current.behaviorStates[row.id] ?? BehaviorState.pending;
      if (state == BehaviorState.done) continue;

      final inFlightStep = current.inFlightBehaviorId == row.id
          ? current.inFlightStep
          : null;
      final result = await _driveBehavior(
        row: row,
        steps: _stepsFor(state, inFlightStep),
        progressSuffix: '',
        deferralAllowed: true,
        rows: rows,
        current: current,
        projectRoot: projectRoot,
        activeIds: activeIds,
        store: store,
        evidence: evidence,
        runner: runner,
      );
      if (result.stop != null) {
        applyStop(result.stop!, result.state);
        return;
      }
      current = result.state;
    }

    // --- Phase 2a: return to every behavior deferred at its phase-1
    // make and re-attempt it (bug #625 for acceptance prose; bug #657
    // generalizes the re-attempt to unit plain-function behaviors). A
    // behavior left phase 1 GREEN has only its refactor outstanding
    // (bug #635); one that completed its whole cycle in phase 1
    // (expressible make) is already DONE and skipped. `unexpressible`
    // here is a real, honest stop (FR-007).
    for (final row in rows) {
      final state = current.behaviorStates[row.id] ?? BehaviorState.pending;
      if (state == BehaviorState.done) continue;
      // Only behaviors still sitting RED are here for their make; GREEN
      // behaviors are waiting on the phase-2 refactor pass instead.
      if (state == BehaviorState.green) continue;

      final inFlightStep = current.inFlightBehaviorId == row.id
          ? current.inFlightStep
          : null;
      final result = await _driveBehavior(
        row: row,
        steps: _phaseTwoMakeSteps(state, inFlightStep),
        progressSuffix: ' (phase 2)',
        deferralAllowed: false,
        rows: rows,
        current: current,
        projectRoot: projectRoot,
        activeIds: activeIds,
        store: store,
        evidence: evidence,
        runner: runner,
      );
      if (result.stop != null) {
        applyStop(result.stop!, result.state);
        return;
      }
      current = result.state;
    }

    // --- Phase 2b: the refactor pass (bug #635). Every behavior still
    // short of DONE now sits GREEN — the units whose refactor deferred
    // in phase 1 plus the acceptance behaviors phase 2a just flipped —
    // and every make in the feature is certified green, so the suite
    // is fully green. Run refactor per behavior, in list order, and
    // mark each DONE: refactor's absolute-green contract (spec 048
    // FR-001) is met by construction instead of being relaxed.
    for (final row in rows) {
      final state = current.behaviorStates[row.id] ?? BehaviorState.pending;
      if (state != BehaviorState.green) continue;

      final inFlightStep = current.inFlightBehaviorId == row.id
          ? current.inFlightStep
          : null;
      final result = await _driveBehavior(
        row: row,
        steps: _phaseTwoRefactorSteps(state, inFlightStep),
        progressSuffix: ' (phase 2)',
        deferralAllowed: false,
        rows: rows,
        current: current,
        projectRoot: projectRoot,
        activeIds: activeIds,
        store: store,
        evidence: evidence,
        runner: runner,
      );
      if (result.stop != null) {
        applyStop(result.stop!, result.state);
        return;
      }
      current = result.state;
    }

    // -----------------------------------------------------------------
    // 7. Complete: every behavior DONE with complete evidence (FR-010).
    // -----------------------------------------------------------------
    final allDone = rows.every(
      (r) => current.behaviorStates[r.id] == BehaviorState.done,
    );
    if (!allDone) {
      // Defensive: the loop only exits cleanly when every row reached
      // done; anything else means the driver's own invariant broke.
      print(
        'zfa tdd run: internal error — loop finished with non-DONE '
        'behaviors',
      );
      _printSummary(feature, 'runner-error', rows, current);
      exitCode = _exitRunnerError;
      return;
    }
    _printSummary(feature, 'complete', rows, current);
    exitCode = _exitComplete;
  }

  // -------------------------------------------------------------------
  // Reconciliation (FR-003: evidence beats state).
  // -------------------------------------------------------------------

  /// Merge loaded state with the current test list: new rows enter as
  /// PENDING, removed rows are retained (dropped), DONE claims without
  /// complete evidence demote, and — when the state file carries no
  /// in-flight marker — PENDING claims (including the missing-row default
  /// from `RunState.empty()`) with evidence promote to the evidence-backed
  /// state (red+green -> DONE, green -> GREEN, red -> RED, none ->
  /// PENDING). That promotion is the bug #682 bootstrap: a brownfield
  /// feature with complete `tdd/cycle-log.md` evidence but no (or an
  /// all-pending) `run-state.json` is recognized as certified instead of
  /// being re-driven from gen. A marked file describes an interrupted run
  /// instead — it resumes by its claims (U23), so promotion is gated off
  /// there. RED and GREEN claims keep their resume semantics (re-enter at
  /// make / refactor) either way. In-flight markers survive the merge. A
  /// re-prove of a certified behavior clears its cycle-log evidence (the
  /// certification source), not the state file.
  RunState _reconcile(
    RunState state,
    List<BehaviorRow> rows,
    Set<String> red,
    Set<String> green,
  ) {
    final states = Map<String, BehaviorState>.from(state.behaviorStates);
    final bootstrappable = state.inFlightBehaviorId == null;
    for (final row in rows) {
      final claimed = states[row.id] ?? BehaviorState.pending;
      var effective = claimed;
      if (claimed == BehaviorState.done ||
          (bootstrappable && claimed == BehaviorState.pending)) {
        final hasRed = red.contains(row.id);
        final hasGreen = green.contains(row.id);
        if (hasRed && hasGreen) {
          effective = BehaviorState.done;
        } else if (hasGreen) {
          effective = BehaviorState.green;
        } else if (hasRed) {
          effective = BehaviorState.red;
        } else {
          effective = BehaviorState.pending;
        }
      }
      states[row.id] = effective;
    }
    return RunState(
      feature: state.feature,
      behaviorStates: Map.unmodifiable(states),
      inFlightBehaviorId: state.inFlightBehaviorId,
      inFlightStep: state.inFlightStep,
      inFlightOwnerPid: state.inFlightOwnerPid,
    );
  }

  // -------------------------------------------------------------------
  // Step sequencing (FR-001, FR-005; two-phase outside-in driving,
  // bugs #625 and #635).
  // -------------------------------------------------------------------

  /// The steps still to run for a behavior in [state], re-entering at
  /// [inFlightStep] when a crashed run left its marker (U23). Phase 1
  /// uses the full window for every behavior — the uniform cycle — so
  /// acceptance behaviors whose make IS expressible complete exactly as
  /// before the fixes; the make deferral only engages on the
  /// unexpressible outcome (bug #625) and the refactor deferral only
  /// while an acceptance behavior sits RED (bug #635).
  List<String> _stepsFor(BehaviorState state, String? inFlightStep) {
    const full = ['gen', 'verify-red', 'make', 'refactor'];
    var start = switch (state) {
      BehaviorState.pending => 0,
      BehaviorState.red => 2,
      BehaviorState.green => 3,
      BehaviorState.done => 4,
    };
    if (inFlightStep != null) {
      final index = full.indexOf(inFlightStep);
      if (index >= 0) start = index;
    }
    return full.sublist(start.clamp(0, full.length));
  }

  /// The phase-2 make window for an acceptance behavior (bug #625):
  /// make only — refactor moved to the phase-2 refactor pass (bug #635)
  /// so it runs on the fully-green suite. The behavior was deferred at
  /// its phase-1 make and sits RED here (or GREEN, when a crash followed
  /// a successful make — nothing left to make). Re-enters at
  /// [inFlightStep] when a crashed run left its marker (U23).
  List<String> _phaseTwoMakeSteps(BehaviorState state, String? inFlightStep) {
    const window = ['make'];
    var start = switch (state) {
      // Unreachable: phase 1 certifies every non-DONE acceptance behavior
      // red (or the run stopped). Defensive: treat as red.
      BehaviorState.pending => 0,
      BehaviorState.red => 0,
      BehaviorState.green => 1,
      BehaviorState.done => 1,
    };
    if (inFlightStep != null) {
      final index = window.indexOf(inFlightStep);
      if (index >= 0) start = index;
    }
    return window.sublist(start.clamp(0, window.length));
  }

  /// The phase-2 refactor window for a behavior whose refactor was
  /// deferred (bug #635): refactor only, on the now-fully-green suite.
  /// Re-enters at [inFlightStep] when a crashed run left its marker
  /// (U23).
  List<String> _phaseTwoRefactorSteps(
    BehaviorState state,
    String? inFlightStep,
  ) {
    const window = ['refactor'];
    var start = switch (state) {
      // Unreachable: only GREEN behaviors reach the refactor pass.
      // Defensive: treat as green.
      BehaviorState.pending => 0,
      BehaviorState.red => 0,
      BehaviorState.green => 0,
      BehaviorState.done => 1,
    };
    if (inFlightStep != null) {
      final index = window.indexOf(inFlightStep);
      if (index >= 0) start = index;
    }
    return window.sublist(start.clamp(0, window.length));
  }

  /// Drive [row] through [steps] with the mark -> save -> spawn ->
  /// advance -> save contract shared by both phases (FR-004, FR-006..
  /// FR-008, FR-011). Returns the updated state plus, when the run must
  /// stop, the stop report naming the summary result, `stopped_at`, exit
  /// code, and — for the concurrent-run refusal — the refusal message.
  ///
  /// When [deferralAllowed] (phase 1), two deferrals engage instead of
  /// an honest stop:
  ///
  /// - an ACCEPTANCE behavior's `make` reporting `unexpressible` — the
  ///   planner's by-design refusal of acceptance prose — DEFERS the
  ///   behavior (bug #625): it stays at its last completed state (RED),
  ///   the deferral is announced with a phase marker, and the run
  ///   continues to the next behavior instead of deadlocking the
  ///   feature.
  /// - ANY behavior's `refactor` while an acceptance behavior sits RED
  ///   DEFERS the refactor BEFORE the spawn (bug #635): refactor's
  ///   absolute-green preflight (spec 048 FR-001) can never pass against
  ///   a knowingly-red suite, so the behavior stays at its last completed
  ///   state (GREEN) and the phase-2 refactor pass runs it on the
  ///   fully-green suite instead of deadlocking the feature at
  ///   `<id>:refactor` with `outcome=not-green`.
  Future<_DriveResult> _driveBehavior({
    required BehaviorRow row,
    required List<String> steps,
    required String progressSuffix,
    required bool deferralAllowed,
    required List<BehaviorRow> rows,
    required RunState current,
    required String projectRoot,
    required Set<String> activeIds,
    required RunStateStore store,
    required CycleEvidence evidence,
    required StepRunner runner,
  }) async {
    final feature = current.feature;
    var updated = current;
    var state = updated.behaviorStates[row.id] ?? BehaviorState.pending;
    for (final step in steps) {
      // Bug #635 deferral (decided BEFORE the spawn): refactor's contract
      // (spec 048 FR-001) is an absolutely green suite. While any
      // acceptance behavior sits RED — its make deferred to phase 2 by
      // design — the suite is knowingly red, so refactor is not even
      // attempted (the real preflight's not-green refusal IS the bug
      // #635 deadlock): defer it like make (bug #625) instead. The
      // behavior stays GREEN (its last completed state, FR-007
      // semantics), and the phase-2 refactor pass runs it on the
      // now-fully-green suite.
      if (deferralAllowed &&
          step == 'refactor' &&
          _hasRedBehavior(rows, updated)) {
        updated = updated.advance(row.id, state);
        await store.save(updated, activeBehaviorIds: activeIds);
        print('[run] ${row.id} refactor -> deferred (phase 2)');
        return (state: updated, stop: null);
      }
      // mark -> save -> spawn -> advance -> save: an interruption loses
      // at most the in-flight step (FR-004).
      updated = updated.markInFlight(row.id, step, ownerPid: pid);
      await store.save(updated, activeBehaviorIds: activeIds);

      // Re-check for a concurrent run that claimed the feature after our
      // in-flight marker was written (closes the simultaneous-start race
      // left by the one-shot check at step 3, FR-006). A foreign live pid
      // in the marker means a second run is now in flight, so stop before
      // spawning any step.
      final liveRefusal = store.refusalReason(await store.load());
      if (liveRefusal != null) {
        return (
          state: updated,
          stop: (
            result: 'concurrent-run',
            stoppedAt: null,
            exitCode: _exitConcurrentRun,
            message: liveRefusal,
          ),
        );
      }

      StepResult result;
      try {
        result = await runner.run(
          step: step,
          behaviorId: row.id,
          feature: feature,
          projectRoot: projectRoot,
        );
      } on StateError catch (e) {
        // Entrypoint resolution failed before any spawn: runner-error.
        updated = updated.advance(row.id, state);
        await store.save(updated, activeBehaviorIds: activeIds);
        print(
          'zfa tdd run: step failed — behavior=${row.id} step=$step '
          'outcome=runner-error',
        );
        print('   ${e.message}');
        print('   resume: fix the issue, then re-run `zfa tdd run $feature`');
        return (
          state: updated,
          stop: (
            result: 'runner-error',
            stoppedAt: '${row.id}:$step',
            exitCode: _exitRunnerError,
            message: null,
          ),
        );
      }

      print('[run] ${row.id} $step -> ${result.outcome}$progressSuffix');

      if (!result.success) {
        // Bug #625/#657 deferral: a make reporting `unexpressible` is the
        // planner's by-design refusal for descriptions no generator
        // surface maps — acceptance prose (bug #625) or a unit
        // plain-function behavior until `zfa tdd func` scaffolds it or
        // the capability lands (bug #657). Deferring is honest here —
        // the outcome line above already named it, and make's own
        // remediation message names the manual path — while stopping the
        // whole feature before its later behaviors ever ran is the
        // deadlock. The behavior stays RED (its last completed state,
        // FR-007 semantics), and phase 2 re-attempts the make.
        if (deferralAllowed &&
            step == 'make' &&
            result.outcome == 'unexpressible') {
          updated = updated.advance(row.id, state);
          await store.save(updated, activeBehaviorIds: activeIds);
          print('[run] ${row.id} make -> deferred (phase 2)');
          return (state: updated, stop: null);
        }
        // Honest stop (FR-007): leave the behavior at its last completed
        // state, name what failed, never start later behaviors. A
        // runner-error outcome (spawn/tooling failure) is its own class
        // (FR-011).
        final isRunnerError = result.outcome == 'runner-error';
        updated = updated.advance(row.id, state);
        await store.save(updated, activeBehaviorIds: activeIds);
        print(
          'zfa tdd run: step failed — behavior=${row.id} step=$step '
          'outcome=${result.outcome}',
        );
        _printOutputExcerpt(result.output);
        print(
          '   resume: fix the failing step, then re-run '
          '`zfa tdd run $feature`',
        );
        return (
          state: updated,
          stop: (
            result: isRunnerError ? 'runner-error' : 'stopped',
            stoppedAt: '${row.id}:$step',
            exitCode: isRunnerError ? _exitRunnerError : _exitStopped,
            message: null,
          ),
        );
      }

      // Evidence check before advancing: a certified step that did not
      // write its evidence is a misfire (FR-003, FR-011).
      final misfire = await _evidenceMisfire(evidence, step, row.id);
      if (misfire != null) {
        updated = updated.advance(row.id, state);
        await store.save(updated, activeBehaviorIds: activeIds);
        print(
          'zfa tdd run: step failed — behavior=${row.id} step=$step '
          'outcome=runner-error',
        );
        print('   $misfire');
        print(
          '   resume: fix the failing step, then re-run '
          '`zfa tdd run $feature`',
        );
        return (
          state: updated,
          stop: (
            result: 'runner-error',
            stoppedAt: '${row.id}:$step',
            exitCode: _exitRunnerError,
            message: null,
          ),
        );
      }

      final next = _maxState(state, _targetStateFor(step));
      updated = updated.advance(row.id, next);
      await store.save(updated, activeBehaviorIds: activeIds);
      state = next;
    }
    return (state: updated, stop: null);
  }

  /// The state a successful [step] certifies for a behavior.
  BehaviorState _targetStateFor(String step) => switch (step) {
    'gen' => BehaviorState.pending,
    'verify-red' => BehaviorState.red,
    'make' => BehaviorState.green,
    'refactor' => BehaviorState.done,
    _ => throw ArgumentError.value(step, 'step', 'unknown TDD step'),
  };

  /// Whether any behavior in [rows] currently sits RED — its make
  /// deferred to phase 2 by design (bug #625 acceptance prose, bug #657
  /// unit plain-function behaviors). While one does, the suite is
  /// knowingly red and refactor's absolute-green preflight (spec 048
  /// FR-001) can never pass, so phase 1 defers refactors (bug #635).
  bool _hasRedBehavior(List<BehaviorRow> rows, RunState state) {
    for (final row in rows) {
      if ((state.behaviorStates[row.id] ?? BehaviorState.pending) ==
          BehaviorState.red) {
        return true;
      }
    }
    return false;
  }

  BehaviorState _maxState(BehaviorState a, BehaviorState b) =>
      a.index >= b.index ? a : b;

  /// Non-null when a certified step failed to write the evidence its
  /// contract promises (FR-003): verify-red must leave a red entry, make a
  /// green entry, and refactor requires both to mark DONE.
  Future<String?> _evidenceMisfire(
    CycleEvidence evidence,
    String step,
    String behaviorId,
  ) async {
    switch (step) {
      case 'verify-red':
        if (!await _hasEvidence(evidence.redEvidence, behaviorId)) {
          return 'verify-red certified but no red evidence entry exists for '
              '"$behaviorId" in tdd/cycle-log.md';
        }
      case 'make':
        if (!await _hasEvidence(evidence.greenEvidence, behaviorId)) {
          return 'make reported green but no green evidence entry exists for '
              '"$behaviorId" in tdd/cycle-log.md';
        }
      case 'refactor':
        final hasRed = await _hasEvidence(evidence.redEvidence, behaviorId);
        final hasGreen = await _hasEvidence(evidence.greenEvidence, behaviorId);
        if (!hasRed || !hasGreen) {
          return 'refactor certified but evidence for "$behaviorId" is '
              'incomplete in tdd/cycle-log.md '
              '(red: $hasRed, green: $hasGreen)';
        }
    }
    return null;
  }

  Future<bool> _hasEvidence(
    Future<Set<String>> Function() evidence,
    String behaviorId,
  ) async {
    return (await evidence()).contains(behaviorId);
  }

  // -------------------------------------------------------------------
  // Reporting (FR-009, FR-010).
  // -------------------------------------------------------------------

  void _printSummary(
    String feature,
    String result,
    List<BehaviorRow> rows,
    RunState? state, {
    String? stoppedAt,
  }) {
    var pending = 0;
    var red = 0;
    var green = 0;
    var done = 0;
    for (final row in rows) {
      switch (state?.behaviorStates[row.id] ?? BehaviorState.pending) {
        case BehaviorState.pending:
          pending++;
        case BehaviorState.red:
          red++;
        case BehaviorState.green:
          green++;
        case BehaviorState.done:
          done++;
      }
    }
    print(
      'run: feature=$feature result=$result pending=$pending red=$red '
      'green=$green done=$done'
      '${stoppedAt != null ? ' stopped_at=$stoppedAt' : ''}',
    );
  }

  void _printOutputExcerpt(String output) {
    final lines = output
        .split('\n')
        .map((l) => l.trimRight())
        .where((l) => l.isNotEmpty)
        .take(3);
    for (final line in lines) {
      print('   $line');
    }
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A stop report from `_driveBehavior` (bug #625 two-phase driving): the
/// summary [result] name, the optional [stoppedAt] `behavior:step`, the
/// process [exitCode], and an optional [message] printed before the
/// summary line (the concurrent-run refusal names its reason).
typedef _Stop = ({
  String result,
  String? stoppedAt,
  int exitCode,
  String? message,
});

/// The outcome of driving one behavior through its step window: the
/// updated run state plus, when the run must stop, the [_Stop] report.
typedef _DriveResult = ({RunState state, _Stop? stop});

/// Strip a leading `specs/` prefix from a user-supplied feature
/// reference. Lets users paste the path format shown throughout
/// zuraffa's docs and error messages (`specs/<feature>`) without
/// triggering the segment check below. The traversal guard on
/// `_validateFeatureSegment` still rejects `..` and absolute paths
/// after stripping.
String _stripSpecsPrefix(String feature) {
  if (feature.startsWith('specs/') || feature.startsWith('specs\\')) {
    final stripped = feature.substring('specs/'.length);
    // `specs/` alone is not a feature name.
    if (stripped.isEmpty) return feature;
    return stripped;
  }
  return feature;
}

/// Segment check for the positional feature argument: it lands in a
/// filesystem path, so keep it a single plain directory segment (mirrors
/// verify_red_command.dart).
void _validateFeatureSegment(String feature) {
  if (feature.contains('/') ||
      feature.contains(r'\') ||
      feature == '.' ||
      feature == '..') {
    throw UsageException(
      'invalid feature "$feature": expected a single spec directory name '
          'such as 049-tdd-run, not a path.',
      'zfa tdd run <feature> [--project <dir>] [--zfa-bin <path>]',
    );
  }
}
