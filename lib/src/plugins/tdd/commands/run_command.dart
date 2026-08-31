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
/// - **Phase 1** — the uniform cycle in list order, with one addition:
///   an ACCEPTANCE behavior whose `make` reports `unexpressible` — the
///   planner's by-design refusal of acceptance prose — is deferred
///   instead of stopping the feature: `[run] A1 make -> deferred
///   (phase 2)`. Its test sits RED while the unit behaviors complete
///   their full cycles to DONE. Any other step failure still stops the
///   run honestly (FR-007), and an acceptance behavior whose make IS
///   expressible completes its whole cycle exactly as before.
/// - **Phase 2** — the deferred acceptance behaviors re-attempt
///   `make + refactor`, now against a project where the units exist. A
///   green outcome completes the feature; `unexpressible` here is a
///   real, honest stop with the units DONE — bounded, resumable
///   progress instead of the old whole-feature deadlock.
///
/// Run-state semantics are unchanged: acceptance behaviors sit RED
/// between the phases, and a run interrupted anywhere resumes exactly
/// where it stopped.
///
/// Honesty rules:
/// - Evidence beats state: a behavior is DONE only when its red AND green
///   entries exist in `tdd/cycle-log.md`; a state-file claim without
///   evidence is demoted to the evidence-backed state (FR-003).
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
    final feature = rest.first;
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
    // 6. Drive the loop in two phases (FR-001, FR-004..FR-008; bug #625).
    //
    // Phase 1 drives the uniform cycle in list order, EXCEPT that an
    // acceptance behavior whose make reports `unexpressible` (the
    // planner's by-design refusal of acceptance prose) is DEFERRED with
    // `[run] A1 make -> deferred (phase 2)` instead of stopping the
    // feature — the bug #625 deadlock. Unit behaviors therefore run to
    // DONE. Phase 2 re-attempts make + refactor for the deferred
    // acceptance behaviors; `unexpressible` there is a real, honest stop
    // with the units DONE (FR-007). Run-state semantics are unchanged:
    // acceptance behaviors sit RED between the phases, resumable
    // mid-corpus (FR-003..FR-005).
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

    // --- Phase 1: the uniform cycle in list order; acceptance makes
    // that report unexpressible defer to phase 2 (bug #625).
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

    // --- Phase 2: return to the deferred acceptance behaviors and
    // re-attempt their make + refactor (bug #625). Unit behaviors were
    // driven to DONE in phase 1; an acceptance behavior that completed
    // its whole cycle in phase 1 (expressible make) is already DONE and
    // skipped. `unexpressible` here is a real, honest stop (FR-007).
    for (final row in rows) {
      if (row.kind != BehaviorKind.acceptance) continue;
      final state = current.behaviorStates[row.id] ?? BehaviorState.pending;
      if (state == BehaviorState.done) continue;

      final inFlightStep = current.inFlightBehaviorId == row.id
          ? current.inFlightStep
          : null;
      final result = await _driveBehavior(
        row: row,
        steps: _phaseTwoSteps(state, inFlightStep),
        progressSuffix: ' (phase 2)',
        deferralAllowed: false,
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
  /// PENDING, removed rows are retained (dropped), and a DONE claim
  /// without both red and green evidence demotes to the highest
  /// evidence-backed state. In-flight markers survive the merge.
  RunState _reconcile(
    RunState state,
    List<BehaviorRow> rows,
    Set<String> red,
    Set<String> green,
  ) {
    final states = Map<String, BehaviorState>.from(state.behaviorStates);
    for (final row in rows) {
      final claimed = states[row.id] ?? BehaviorState.pending;
      var effective = claimed;
      if (claimed == BehaviorState.done) {
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
  // bug #625).
  // -------------------------------------------------------------------

  /// The steps still to run for a behavior in [state], re-entering at
  /// [inFlightStep] when a crashed run left its marker (U23). Phase 1
  /// uses the full window for every behavior — the uniform cycle — so
  /// acceptance behaviors whose make IS expressible complete exactly as
  /// before the fix; the deferral only engages on the unexpressible
  /// outcome (bug #625).
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

  /// The phase-2 step window for an acceptance behavior (bug #625):
  /// make + refactor only — the behavior was deferred at its phase-1
  /// make and sits RED (or GREEN, when a crash followed a successful
  /// make) here. Re-enters at [inFlightStep] when a crashed run left its
  /// marker (U23).
  List<String> _phaseTwoSteps(BehaviorState state, String? inFlightStep) {
    const tail = ['make', 'refactor'];
    var start = switch (state) {
      // Unreachable: phase 1 certifies every non-DONE acceptance behavior
      // red (or the run stopped). Defensive: treat as red.
      BehaviorState.pending => 0,
      BehaviorState.red => 0,
      BehaviorState.green => 1,
      BehaviorState.done => 2,
    };
    if (inFlightStep != null) {
      final index = tail.indexOf(inFlightStep);
      if (index >= 0) start = index;
    }
    return tail.sublist(start.clamp(0, tail.length));
  }

  /// Drive [row] through [steps] with the mark -> save -> spawn ->
  /// advance -> save contract shared by both phases (FR-004, FR-006..
  /// FR-008, FR-011). Returns the updated state plus, when the run must
  /// stop, the stop report naming the summary result, `stopped_at`, exit
  /// code, and — for the concurrent-run refusal — the refusal message.
  ///
  /// When [deferralAllowed] (phase 1) and the failing step is an
  /// ACCEPTANCE behavior's `make` reporting `unexpressible` — the
  /// planner's by-design refusal of acceptance prose — the behavior is
  /// DEFERRED instead (bug #625): it stays at its last completed state
  /// (RED), the deferral is announced with a phase marker, and the run
  /// continues to the next behavior instead of deadlocking the feature.
  Future<_DriveResult> _driveBehavior({
    required BehaviorRow row,
    required List<String> steps,
    required String progressSuffix,
    required bool deferralAllowed,
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
        // Bug #625 deferral: acceptance prose is unexpressible to the
        // generation planner BY DESIGN. Deferring is honest here — the
        // outcome line above already named it — while stopping the whole
        // feature before its unit behaviors ever ran is the deadlock.
        // The behavior stays RED (its last completed state, FR-007
        // semantics), and phase 2 re-attempts make + refactor.
        if (deferralAllowed &&
            step == 'make' &&
            row.kind == BehaviorKind.acceptance &&
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
