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
///   impossible while a deferred behavior sits honestly RED, or while a
///   behavior still PENDING carries generated stubs whose tests throw
///   `UnimplementedError` (bug #734: a run that stopped early leaves
///   U3+ pending, and the full suite refuses every refactor for the
///   already-green behaviors) — ANY behavior whose `refactor` comes due
///   while ANY behavior sits RED or PENDING with gen artifacts (in the
///   registry OR on disk — bug #734 v2: a stub without a registry
///   record reds the suite exactly the same) defers too:
///   `[run] U1 refactor -> deferred (phase 2)` (bugs #635, #734;
///   the deferral concept is applied to both steps, not half-applied to
///   `make` alone). Deferred behaviors stay at their last completed
///   state (RED / GREEN) while the rest of phase 1 proceeds. And when
///   a refactor IS spawned and its preflight still refuses (redness
///   the row model cannot see — a failure outside the feature's rows,
///   a #741-baseline-tolerated failure, a stub at a non-default path;
///   bug #734 v2), the side-effect-free refusal DEFERS the behavior
///   instead of stopping the run. Any other step failure still stops
///   the run honestly (FR-007), and a behavior whose make IS
///   expressible completes its whole cycle exactly as before — by the
///   time its refactor runs, no behavior is RED and no pending stub
///   sits un-driven.
/// - **Phase 2** — the deferred work finishes on the now-fully-green
///   suite, in two stages. First every deferred behavior re-attempts
///   `make` in list order (bug #625; generalized to unit behaviors by
///   bug #657); a green outcome flips it, and `unexpressible` here is a
///   real, honest stop with everything else done (FR-007). Then a
///   refactor pass runs `refactor` for every behavior still short of
///   DONE — per behavior, in list order, gated per behavior on THAT
///   behavior's own test being green (the green evidence make certified,
///   bug #734) rather than on the whole suite — and marks each DONE
///   (bug #635). A behavior whose own test is not certified green is
///   skipped with a recorded reason instead of dying mid-pass at the
///   evidence misfire; so is a behavior whose spawned `refactor`'s real
///   preflight refuses (bug #734 v2: the suite is red from a source the
///   row model cannot see — skip with a recorded reason, stay GREEN,
///   never a fake DONE). The spawned `refactor`'s own full-suite
///   preflight (spec 048 FR-001) remains the absolute authority either
///   way — and, issue #922, it excludes the run baseline's pre-existing
///   failures from that authority: the driver hands its cached baseline
///   (the issue #741 `run-baseline.json`) to every refactor spawn, so
///   pre-existing red in unrelated files (a baseline carrying failures
///   the feature did not cause — 24 of them in the issue's run) cannot
///   refuse every refactor and stop the run at `green=13 done=0`. Only
///   NEW failures (not in the baseline) refuse, keeping the done gate
///   honest: a green behavior behind a red-but-not-worse suite is DONE,
///   and a genuinely regressed suite is still skipped and reported.
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

import '../services/artifact_registry.dart';
import '../services/cycle_evidence.dart';
import '../services/entity_lookup.dart';
import '../services/run_baseline_cache.dart';
import '../services/corpus_baseline_cache.dart';
import '../services/run_state_store.dart';
import '../services/runner.dart';
import '../services/step_runner.dart';
import '../services/suite_guard.dart';
import '../services/test_list_reader.dart';
import '../services/tdd_timeout.dart';
import '../services/tdd_transaction.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

class RunCommand extends Command<void> {
  RunCommand(this.plugin) {
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #964).',
      negatable: false,
    );
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
    argParser.addOption(
      'timeout',
      valueHelp: 'minutes',
      help:
          'Hard deadline in minutes for each spawned step command (bug #742; '
          'default 10). Fractions are allowed. On timeout the child is '
          'killed and the run stops with result=runner-error.',
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
        : ProjectRoot.find(anchorDir: 'specs');
    final zfaBin = argResults?['zfa-bin'] as String?;

    // Bug #742: the --timeout override for each spawned step command.
    final Duration? timeoutOverride;
    try {
      timeoutOverride = parseTddTimeoutMinutes(
        argResults?['timeout'] as String?,
      );
    } on TddTimeoutFormatException catch (e) {
      print('zfa tdd run: ${e.message}');
      _printSummary(feature, 'runner-error', const [], null);
      exitCode = _exitRunnerError;
      return;
    }

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

    // -----------------------------------------------------------------
    // 4b. Bug #828: replay the write-ahead journal BEFORE reconciling.
    // A surviving pending record marks the step the previous run died
    // inside; when its evidence landed, the state advance is applied
    // here (the transaction completes), otherwise the journal is
    // discarded and the in-flight marker re-drives the step. Either way
    // run-state converges with the cycle-log before any claim is
    // reconciled against it.
    // -----------------------------------------------------------------
    final tx = TddTransaction(featureDir);
    final journal = await tx.pending();
    if (journal != null) {
      loaded = await _replayJournal(tx, loaded, evidence, journal);
    }

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
    //    #625, #635, #657 and #734).
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
    // spec 048 FR-001, can never pass against a knowingly-red suite) —
    // and, bug #734, while any behavior sits PENDING with gen artifacts
    // (a run that stopped early leaves later behaviors' generated stubs
    // red on disk; spawning refactor then refuses for the ALREADY-GREEN
    // behaviors and the feature deadlocks at its first refactor).
    // Phase 2 re-attempts the deferred makes, then runs refactor for
    // every behavior, gated per behavior on that behavior's own test
    // being green (its certified green evidence, bug #734);
    // `unexpressible` there is a real, honest stop (FR-007) — by then
    // every other behavior has run, and make's own remediation line
    // (bug #657) names the manual path. Run-state semantics are
    // unchanged: deferred behaviors sit RED between the phases,
    // resumable mid-corpus (FR-003..FR-005).
    // -----------------------------------------------------------------
    // Bug #742: the step spawner carries the deadline — a hanging step
    // child is killed and surfaces as a runner-error step result.
    final runner = StepRunner(zfaBin: zfaBin, timeout: timeoutOverride);

    String? suiteBaselinePath;
    final anyMakeOutstanding = rows.any(
      (r) => current.behaviorStates[r.id] != BehaviorState.done,
    );

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

    // ---------------------------------------------------------------
    // 6a. Phase 0 — spec Key Entities orchestration (bug #829). When
    //     the test list declares entities (plan extracted them from the
    //     spec), the driver creates every entity that does not exist
    //     yet — idempotently: an existing entity file is REUSED, never
    //     regenerated over hand-tuned fields — and runs `zfa build`
    //     ONCE, BEFORE any behavior is driven. A feature without
    //     declared entities runs no phase-0 spawn at all (every pre-829
    //     run is unchanged).
    // ---------------------------------------------------------------
    if (anyMakeOutstanding) {
      final declaredEntities = await TestListReader(featureDir).readEntities();
      if (declaredEntities.isNotEmpty) {
        final stop = await _runEntityPhaseZero(
          projectRoot: projectRoot,
          entities: declaredEntities,
          zfaBin: zfaBin,
          timeout: timeoutOverride,
        );
        if (stop != null) {
          applyStop(stop, current);
          return;
        }
      }
    }

    // ---------------------------------------------------------------
    // 6b. Cache the full-suite baseline ONCE per run (issue #741).
    //     Spec 069 T004: reuse the CORPUS-WIDE baseline when the
    //     dependency fingerprint matches — the corpus lane's per-"
    //     feature suite spawn collapses to one capture per dependency
    //     state. Invalidation (pubspec/lock/suite-template change) is
    //     the safe fallback to the live capture.
    // ---------------------------------------------------------------
    if (anyMakeOutstanding) {
      try {
        final suiteTemplate = await const SingleTestRunner().loadSuiteTemplate(
          workingDirectory: projectRoot,
        );
        final corpusCache = const CorpusBaselineCache();
        final fingerprint = await corpusCache.dependencyFingerprint(
          projectRoot,
        );
        SuiteSnapshot? corpusReused;
        if (fingerprint != null) {
          corpusReused = await corpusCache.read(
            projectRoot: projectRoot,
            fingerprint: fingerprint,
          );
        }
        // Defense in depth (spec 069 T004): the fingerprint keys the
        // suite command only when the profile carries the
        // machine-readable Keys block — a legacy frontmatter profile
        // silently degrades the fingerprint to pubspec+lock, so a
        // changed suite command would still read-hit. The stored
        // live-capture command must equal the freshly loaded template;
        // on mismatch the reuse is dropped and the live suite re-runs.
        if (corpusReused != null &&
            corpusReused.parseable &&
            corpusReused.command != suiteTemplate) {
          print(
            '   suite baseline: corpus cache command drift — the stored '
            'snapshot was captured under a different suite command; the '
            'live suite re-runs (spec 069 T004)',
          );
          corpusReused = null;
        }
        if (corpusReused != null && corpusReused.parseable) {
          // Corpus-wide reuse (spec 069 T004): the make steps' guard is
          // still the scoped single-test run (#741's contract) — the
          // reuse only removes the redundant live capture.
          suiteBaselinePath = await const RunBaselineCache().write(
            featureDir: featureDir,
            snapshot: corpusReused,
          );
          print(
            '   suite baseline: corpus-wide reuse '
            '(fingerprint match; spec 069 T004) — '
            '${corpusReused.failedTests.length} pre-existing failure(s) '
            'captured ${corpusReused.capturedAt}; the suite is not '
            're-run for this feature',
          );
        } else {
          print(
            '   suite baseline: $suiteTemplate (once per run — issue #741)',
          );
          final baselineRecord = await const SingleTestRunner().runSuite(
            suiteTemplate: suiteTemplate,
            workingDirectory: projectRoot,
          );
          final snapshot = const SuiteGuard().fromRunRecord(
            record: baselineRecord,
            capturedAt: DateTime.now().toUtc().toIso8601String(),
          );
          if (snapshot.parseable) {
            suiteBaselinePath = await const RunBaselineCache().write(
              featureDir: featureDir,
              snapshot: snapshot,
            );
            // Spec 069 T004: publish the snapshot corpus-wide so the
            // NEXT feature's driver reuses it (fingerprint-keyed).
            if (fingerprint != null) {
              await corpusCache.write(
                projectRoot: projectRoot,
                snapshot: snapshot,
                fingerprint: fingerprint,
              );
            }
            print(
              '   baseline cached for this run: '
              '${p.relative(suiteBaselinePath, from: projectRoot)} '
              '(${snapshot.failedTests.length} pre-existing failure(s)); '
              'make steps reuse it instead of re-running the suite',
            );
          }
        }
      } on StateError {
        // No profile / no suite template
      }
    }

    // --- Phase 1: the uniform cycle in list order; a make that reports
    // unexpressible defers to phase 2 (bug #625 for acceptance prose,
    // bug #657 for unit plain-function behaviors), and refactors that
    // come due while ANY behavior sits RED defer too (bug #635, so a
    // deferred unit make leaves the suite knowingly red exactly like a
    // deferred acceptance make) — as does a refactor that comes due
    // while any behavior sits PENDING with gen artifacts, in the
    // registry OR on disk (bug #734: a run that stopped early leaves
    // later behaviors' generated stubs red on disk; the spawned
    // refactor's full-suite preflight would refuse for the
    // already-green behaviors and deadlock the feature). A spawned
    // refactor whose preflight STILL refuses (redness the row model
    // cannot see — bug #734 v2) defers post-spawn instead of stopping
    // the run: the refusal is side-effect-free and the pending rows are
    // driven next.
    final registry = ArtifactRegistry(featureDir: featureDir);
    for (final row in rows) {
      final state = current.behaviorStates[row.id] ?? BehaviorState.pending;
      if (state == BehaviorState.done) continue;

      final inFlightStep = current.inFlightBehaviorId == row.id
          ? current.inFlightStep
          : null;
      // Bug #720: the state claim is only as good as its artifacts. A red
      // (or green) claim whose gen artifacts are gone — a wiped or never-
      // written artifacts.json after an interrupted run — cannot resume at
      // make: make refuses "no gen artifacts" and the run dies at the
      // first behavior. Check the registry, not the claim.
      final hasGenArtifacts = await registry.findRecord(row.id) != null;
      final result = await _driveBehavior(
        row: row,
        steps: _stepsFor(state, inFlightStep, hasGenArtifacts: hasGenArtifacts),
        progressSuffix: '',
        deferralAllowed: true,
        rows: rows,
        current: current,
        projectRoot: projectRoot,
        activeIds: activeIds,
        store: store,
        evidence: evidence,
        runner: runner,
        registry: registry,
        suiteBaselinePath: suiteBaselinePath,
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
        registry: registry,
        suiteBaselinePath: suiteBaselinePath,
      );
      if (result.stop != null) {
        applyStop(result.stop!, result.state);
        return;
      }
      current = result.state;
    }

    // --- Phase 2b: the refactor pass (bugs #635 and #734; issue #922).
    // Every behavior still short of DONE now sits GREEN — the units whose
    // refactor deferred in phase 1 plus the acceptance behaviors phase
    // 2a just flipped — and every pending stub has been driven. The
    // pass is gated PER BEHAVIOR on that behavior's own test being
    // green (bug #734): the green evidence entry make appended when it
    // certified the behavior's test target exiting 0, not the whole
    // suite. A green claim without green evidence (a brownfield/seeded
    // state or a lost cycle-log — the bug #682 reconciliation keeps
    // such claims) is skipped with a recorded reason instead of riding
    // into refactor and dying at the post-spawn evidence misfire,
    // which would stop the pass for every other behavior. And — bug
    // #734 v2 (reopened) — a spawned refactor whose real preflight
    // REFUSES (outcome=not-green: the suite is red from a source the
    // row model cannot see) is skipped the same way instead of
    // stopping the pass for everyone. Behaviors whose own test IS
    // certified green refactor as before; the spawned command's
    // full-suite preflight (spec 048 FR-001) remains the absolute
    // authority — narrowed, per issue #922, by the run baseline each
    // spawn receives (`--suite-baseline`, the issue #741 cache):
    // pre-existing red recorded at baseline is excluded from the
    // verdict, so a suite that is no worse than at run start cannot
    // block the done transition, while any NEW failure still refuses
    // (and skips honestly, never a fake DONE).
    final certifiedGreen = await evidence.greenEvidence();
    final skippedRefactors = <String, String>{};
    for (final row in rows) {
      final state = current.behaviorStates[row.id] ?? BehaviorState.pending;
      if (state != BehaviorState.green) continue;

      // Bug #734 per-behavior gate, decided BEFORE the spawn (the same
      // pre-spawn discipline as the bug #635/#734 deferrals): refactor
      // runs only when THIS behavior's own test is certified green —
      // the green evidence entry naming its test target exiting 0.
      // Skipped behaviors stay GREEN (their last completed state,
      // FR-007 semantics) and the pass moves on; the run reports them
      // honestly at the end instead of faking DONE (FR-008).
      if (!certifiedGreen.contains(row.id)) {
        skippedRefactors[row.id] = 'own test not green';
        print('[run] ${row.id} refactor -> skipped (own test not green)');
        print(
          '   no green evidence entry for "${row.id}" in tdd/cycle-log.md '
          '— make must certify the behavior\'s own test green before '
          'refactor',
        );
        continue;
      }

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
        registry: registry,
        suiteBaselinePath: suiteBaselinePath,
      );
      if (result.stop != null) {
        applyStop(result.stop!, result.state);
        return;
      }
      // Bug #734 v2: the spawned refactor's preflight refused
      // (side-effect-free) — skip the behavior with a recorded reason
      // (stays GREEN, FR-007/FR-008) and let the pass continue for
      // everyone else.
      if (result.refactorBlocked) {
        skippedRefactors[row.id] = 'suite not green';
        current = result.state;
        continue;
      }
      current = result.state;
    }

    // -----------------------------------------------------------------
    // 7. Complete: every behavior DONE with complete evidence (FR-010).
    // -----------------------------------------------------------------
    final allDone = rows.every(
      (r) => current.behaviorStates[r.id] == BehaviorState.done,
    );
    if (!allDone && skippedRefactors.isNotEmpty) {
      // Bug #734 per-behavior gate (+ v2 refusal skips): the pass
      // completed for every behavior that could refactor; the rest stay
      // GREEN with their refactor outstanding — bounded, resumable
      // progress (FR-007), never a fake DONE (FR-008). The run stops
      // honestly, naming the skips, their reasons, and the resume path.
      print(
        'zfa tdd run: refactor skipped for '
        '${skippedRefactors.keys.join(', ')} — '
        '${skippedRefactors.values.toSet().join(' / ')}',
      );
      print(
        '   resume: restore the suite green (re-run make for behaviors '
        'whose own test is red; fix the failing tests the preflight '
        'named otherwise), then re-run `zfa tdd run $feature`',
      );
      _printSummary(
        feature,
        'stopped',
        rows,
        current,
        stoppedAt: '${skippedRefactors.keys.first}:refactor',
      );
      exitCode = _exitStopped;
      return;
    }
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

  /// Complete a write-ahead transaction the previous run died inside
  /// (bug #828). The journal records the intended (behavior, step) before
  /// the spawn; on resume:
  ///
  /// - evidence for the recorded step (red for verify-red, green for
  ///   make, a refactor-kind entry at/after the journal timestamp for
  ///   refactor) means the child finished but the driver died before the
  ///   state commit — the advance is applied here, without re-spawning
  ///   the step;
  /// - no evidence means the step never completed — the journal is
  ///   discarded (it was intent, never a claim) and the in-flight marker
  ///   re-drives the step honestly;
  /// - `gen` carries no cycle-log evidence by contract, so its journal
  ///   is always discarded (a re-spawned gen is an idempotent reuse).
  ///
  /// A null [state] (no run-state.json) has nothing to advance — the
  /// journal is discarded and evidence-based bootstrap reconciles.
  Future<RunState?> _replayJournal(
    TddTransaction tx,
    RunState? state,
    CycleEvidence evidence,
    Map<String, dynamic> journal,
  ) async {
    final behavior = journal['behavior'] as String?;
    final step = journal['step'] as String?;
    await tx.clear();
    if (state == null || behavior == null || step == null) return state;
    if (!StepRunner.stepOrder.contains(step)) return state;
    final claimed = state.behaviorStates[behavior] ?? BehaviorState.pending;
    final target = _targetStateFor(step);
    if (claimed.index >= target.index) return state;
    final landed = await _stepEvidenceLanded(evidence, step, journal);
    if (!landed) return state;
    print('[run] $behavior $step -> replayed (write-ahead journal, bug #828)');
    return state.advance(behavior, target);
  }

  /// Whether the evidence contract of an interrupted [step] is satisfied
  /// in the cycle-log: verify-red requires the behavior's red entry, make
  /// its green entry, refactor a refactor-kind entry stamped at/after the
  /// journal's write-ahead moment. `gen` has no evidence contract.
  Future<bool> _stepEvidenceLanded(
    CycleEvidence evidence,
    String step,
    Map<String, dynamic> journal,
  ) async {
    final behavior = journal['behavior'] as String?;
    switch (step) {
      case 'verify-red':
        return behavior != null &&
            (await evidence.redEvidence()).contains(behavior);
      case 'make':
        return behavior != null &&
            (await evidence.greenEvidence()).contains(behavior);
      case 'refactor':
        final at = DateTime.tryParse(journal['at']?.toString() ?? '');
        if (at == null) return false;
        for (final entry in await evidence.entries()) {
          if (entry.kind != 'refactor') continue;
          final stamped = DateTime.tryParse(entry.at ?? '');
          if (stamped != null && !stamped.isBefore(at)) return true;
        }
        return false;
      default:
        return false; // gen (and any unknown step) re-drives
    }
  }

  /// Merge loaded state with the current test list: new rows enter as
  /// PENDING, removed rows are retained (dropped), and every claim stands
  /// only on the evidence that backs it (FR-003):
  /// - DONE claims without their red+green backing demote to the
  ///   evidence-backed state (U21);
  /// - bug #828: GREEN claims without a green entry demote the same way —
  ///   the interrupted-run state "run-state says green, cycle-log has no
  ///   evidence" re-drives from the earliest incomplete step instead of
  ///   dead-ending at the refactor misfire on every resume;
  /// - when the state file carries no in-flight marker, PENDING claims
  ///   (including the missing-row default from `RunState.empty()`) with
  ///   evidence promote to the evidence-backed state (red+green -> DONE,
  ///   green -> GREEN, red -> RED, none -> PENDING). That promotion is
  ///   the bug #682 bootstrap: a brownfield feature with complete
  ///   `tdd/cycle-log.md` evidence but no (or an all-pending)
  ///   `run-state.json` is recognized as certified instead of being
  ///   re-driven from gen. A marked file describes an interrupted run
  ///   instead — it resumes by its claims (U23), so promotion is gated
  ///   off there. RED claims keep their resume semantics (re-enter at
  ///   make) either way — the red half cannot be fabricated, and the
  ///   refactor misfire gate names it honestly (the bug #682 contract).
  /// In-flight markers survive the merge. A re-prove of a certified
  /// behavior clears its cycle-log evidence (the certification source),
  /// not the state file.
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
      final hasRed = red.contains(row.id);
      final hasGreen = green.contains(row.id);
      if (claimed == BehaviorState.done) {
        // U21: a done claim stands only on complete red+green evidence.
        effective = hasRed && hasGreen
            ? BehaviorState.done
            : hasGreen
            ? BehaviorState.green
            : hasRed
            ? BehaviorState.red
            : BehaviorState.pending;
      } else if (claimed == BehaviorState.mocked ||
          claimed == BehaviorState.green) {
        // Bug #828: a green or mocked claim stands only on its green evidence.
        effective = hasGreen
            ? claimed
            : hasRed
            ? BehaviorState.red
            : BehaviorState.pending;
      } else if (bootstrappable && claimed == BehaviorState.pending) {
        // Bug #682 bootstrap (unchanged): evidence promotes a pending
        // claim of an unmarked state file.
        effective = hasRed && hasGreen
            ? BehaviorState.done
            : hasGreen
            ? BehaviorState.green
            : hasRed
            ? BehaviorState.red
            : BehaviorState.pending;
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
  ///
  /// Bug #720: a state claim without gen artifacts cannot drive its
  /// state-implied resume window. When [inFlightStep] is null/empty (no
  /// crashed-run marker) and [hasGenArtifacts] is false — no record in
  /// the feature's tdd/artifacts.json, the same contract make enforces
  /// with its "no gen artifacts" refusal — the state-implied start is
  /// demoted to gen regardless of [state]: the artifacts, not the claim,
  /// decide whether make/refactor can resume. A marker (U23) or present
  /// artifacts keep the state-implied window untouched.
  List<String> _stepsFor(
    BehaviorState state,
    String? inFlightStep, {
    required bool hasGenArtifacts,
  }) {
    const full = ['gen', 'verify-red', 'make', 'refactor'];
    var start = switch (state) {
      BehaviorState.pending => 0,
      BehaviorState.red => 2,
      BehaviorState.mocked || BehaviorState.green => 3,
      BehaviorState.done => 4,
    };
    if (inFlightStep != null && inFlightStep.isNotEmpty) {
      final index = full.indexOf(inFlightStep);
      if (index >= 0) start = index;
    } else if (!hasGenArtifacts) {
      // Bug #720: a claim without artifacts resumes at gen. `gen` is a
      // no-op reuse when artifacts exist elsewhere on disk and re-creates
      // them when they don't; verify-red then re-certifies the red claim
      // honestly before make re-runs.
      start = 0;
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
      BehaviorState.mocked || BehaviorState.green => 1,
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
      // Unreachable: only GREEN/MOCKED behaviors reach the refactor pass.
      // Defensive: treat as green.
      BehaviorState.pending => 0,
      BehaviorState.red => 0,
      BehaviorState.mocked || BehaviorState.green => 0,
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
  ///   `<id>:refactor` with `outcome=not-green`. Bug #734 extends the
  ///   same deferral to a refactor that comes due while any behavior
  ///   sits PENDING with gen artifacts — a run that stopped early leaves
  ///   later behaviors' generated stubs red on disk, and the preflight
  ///   would refuse for the already-green behaviors exactly the same way
  ///   (`[run] A5 refactor -> not-green`).
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
    required ArtifactRegistry registry,
    String? suiteBaselinePath,
  }) async {
    final feature = current.feature;
    var updated = current;
    var state = updated.behaviorStates[row.id] ?? BehaviorState.pending;
    // Bug #828: the write-ahead journal for this feature. Every spawn is
    // wrapped begin -> spawn -> commit/clear so an interrupted step
    // converges on resume instead of leaving the stores disagreeing.
    final tx = TddTransaction(p.join(projectRoot, 'specs', feature));
    for (final step in steps) {
      // Bug #635/#734 deferral (decided BEFORE the spawn): refactor's
      // contract (spec 048 FR-001) is an absolutely green suite. While
      // any acceptance behavior sits RED — its make deferred to phase 2
      // by design — the suite is knowingly red, so refactor is not even
      // attempted (the real preflight's not-green refusal IS the bug
      // #635 deadlock): defer it like make (bug #625) instead. Bug
      // #734: the same holds while any behavior sits PENDING with gen
      // artifacts — its generated stub's test may sit red, and the
      // preflight would refuse for the already-green behaviors exactly
      // the same way. The behavior stays at its last completed state
      // (GREEN, FR-007 semantics), and the phase-2 refactor pass runs
      // it on the now-fully-green suite.
      if (deferralAllowed &&
          step == 'refactor' &&
          (_hasRedBehavior(rows, updated) ||
              await _hasPendingWithArtifacts(
                rows,
                updated,
                registry,
                projectRoot: projectRoot,
                feature: feature,
              ))) {
        updated = updated.advance(row.id, state);
        await store.save(updated, activeBehaviorIds: activeIds);
        print('[run] ${row.id} refactor -> deferred (phase 2)');
        return (state: updated, stop: null, refactorBlocked: false);
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
          refactorBlocked: false,
        );
      }

      // Bug #828: write-ahead the intended transition BEFORE the spawn.
      // A journal that survives this step marks the exact (behavior,
      // step) the run died inside; the next resume replays or discards it.
      await tx.begin(behavior: row.id, step: step);

      StepResult result;
      try {
        result = await runner.run(
          step: step,
          behaviorId: row.id,
          feature: feature,
          projectRoot: projectRoot,
          suiteBaselinePath: suiteBaselinePath,
        );
      } on StateError catch (e) {
        // Entrypoint resolution failed before any spawn: runner-error.
        updated = updated.advance(row.id, state);
        await store.save(updated, activeBehaviorIds: activeIds);
        await tx.clear();
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
          refactorBlocked: false,
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
        //
        // Bug #826: `no-op` joins the deferral set — make reports it when
        // the behavior's inner `zfa make` plan resolves to ZERO active
        // plugins ("No active plugins to run."), i.e. there is nothing
        // the generation pipeline can do for this behavior yet. Exactly
        // like `unexpressible`, that is a "the capability is not here
        // today" state, not a crash, and stopping the feature on it is
        // the same deadlock; phase 2 re-attempts once plugins (maybe)
        // landed.
        if (deferralAllowed &&
            step == 'make' &&
            (result.outcome == 'unexpressible' || result.outcome == 'no-op')) {
          updated = updated.advance(row.id, state);
          await store.save(updated, activeBehaviorIds: activeIds);
          await tx.clear();
          print('[run] ${row.id} make -> deferred (phase 2)');
          return (state: updated, stop: null, refactorBlocked: false);
        }
        // Bug #691: `unexpected-green` — verify-red on a target test that
        // ALREADY passes — means the behavior is complete from prior
        // work, not a failure. Skip to make instead of stopping the run:
        // the window continues with make, whose pre-generation check
        // re-verifies the green (make's `skipped` outcome — issue #694
        // skip transition — is the honest "already green" report), and
        // refactor proceeds as usual.
        if (step == 'verify-red' && result.outcome == 'unexpected-green') {
          updated = updated.advance(row.id, state);
          await store.save(updated, activeBehaviorIds: activeIds);
          await tx.clear();
          print('[run] ${row.id} verify-red -> skipped (already green)');
          continue;
        }
        // Bug #734 (v2, reopened): a spawned refactor whose absolute-green
        // preflight (spec 048 FR-001) REFUSED — outcome=not-green — is
        // per-behavior information, not a pass-fatal step failure. The
        // refusal is side-effect-free (refactor refuses BEFORE any pass,
        // modifying zero files), and the pre-spawn deferral above can only
        // model redness the driver's row states + registry can SEE — the
        // reopen proved stubs on disk WITHOUT registry records, failures
        // outside the feature's rows, and #741-baseline-tolerated failures
        // all reach the spawn. So:
        //
        // - phase 1: DEFER the behavior (stays GREEN, FR-007 semantics).
        //   The suite may still flip green this run — the pending rows are
        //   driven next — and the deferred refactor re-spawns in the
        //   phase-2b pass.
        // - phase 2b: report the refusal back to the pass, which SKIPS the
        //   behavior with a recorded reason (stays GREEN, never a fake
        //   DONE, FR-008) and completes for everyone else; the honest
        //   end-of-run stop names the skips and the resume path.
        //
        // A regression (re-proof failure), runner-error, or missing-summary
        // keeps the honest stop below — those are NOT safe to continue
        // past (the passes already ran / the spawn misfired).
        if (step == 'refactor' && result.outcome == 'not-green') {
          updated = updated.advance(row.id, state);
          await store.save(updated, activeBehaviorIds: activeIds);
          await tx.clear();
          if (deferralAllowed) {
            print('[run] ${row.id} refactor -> deferred (phase 2)');
            print(
              '   preflight refused (suite not green) — the deferred '
              'refactor re-runs in the phase-2 refactor pass',
            );
            return (state: updated, stop: null, refactorBlocked: false);
          }
          print('[run] ${row.id} refactor -> skipped (suite not green)');
          _printOutputExcerpt(result.output);
          return (state: updated, stop: null, refactorBlocked: true);
        }
        // Honest stop (FR-007): leave the behavior at its last completed
        // state, name what failed, never start later behaviors. A
        // runner-error outcome (spawn/tooling failure) is its own class
        // (FR-011).
        final isRunnerError = result.outcome == 'runner-error';
        updated = updated.advance(row.id, state);
        await store.save(updated, activeBehaviorIds: activeIds);
        await tx.clear();
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
          refactorBlocked: false,
        );
      }

      // Evidence check before advancing: a certified step that did not
      // write its evidence is a misfire (FR-003, FR-011).
      final misfire = await _evidenceMisfire(evidence, step, row.id);
      if (misfire != null) {
        updated = updated.advance(row.id, state);
        await store.save(updated, activeBehaviorIds: activeIds);
        await tx.clear();
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
          refactorBlocked: false,
        );
      }

      final next = _maxState(state, _targetStateFor(step));
      updated = updated.advance(row.id, next);
      await store.save(updated, activeBehaviorIds: activeIds);
      // Bug #828: the transaction is complete — evidence landed and the
      // state advance reached the disk. Clear the journal.
      await tx.clear();
      state = next;
    }
    return (state: updated, stop: null, refactorBlocked: false);
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

  /// Whether any behavior in [rows] sits PENDING with gen artifacts —
  /// in the registry OR on disk (bug #734, v2 reopened): a run that
  /// stopped early in phase 1 (e.g. the #731 false-positive family)
  /// leaves later behaviors' generated stubs on disk — their tests
  /// throw `UnimplementedError`, the full suite is red, and refactor's
  /// absolute-green preflight (spec 048 FR-001) would refuse for the
  /// ALREADY-GREEN behaviors, deadlocking the feature at its first
  /// refactor.
  ///
  /// The original fix consulted the REGISTRY only ("the registry is
  /// the artifact source of truth", bug #720), assuming artifact-less
  /// pending rows contribute no red risk. The reopen proved that
  /// assumption false: a stub can exist on disk WITHOUT a record (an
  /// interrupted gen between the file write and the registry flush, a
  /// wiped or never-written artifacts.json, or gen outside the driver)
  /// — the issue's own state is "U3-U44 pending (not generated)" while
  /// their stubs throw `UnimplementedError`. The suite compiles and
  /// runs from DISK, so the disk check (the gen default layout,
  /// `test/tdd/<snake_id>_test.dart`) closes the gap; a pending row
  /// with neither a record nor a stub file contributes no red risk and
  /// never defers (the fresh-run ordering is preserved). A residual
  /// mismatch (a stub at a non-default path, a failure outside the
  /// feature's rows) is handled by the post-spawn refusal skip instead
  /// of a pass-fatal stop.
  ///
  /// Bug #827: the gen default layout is now NAMESPACED by feature-slug
  /// (`test/tdd/<feature>/<snake_id>_test.dart`), so the disk check looks
  /// there first; the legacy flat path (`test/tdd/<snake_id>_test.dart`)
  /// is still checked so an un-migrated project keeps its deferral
  /// semantics — the migration must not break existing flat-layout
  /// projects.
  Future<bool> _hasPendingWithArtifacts(
    List<BehaviorRow> rows,
    RunState state,
    ArtifactRegistry registry, {
    required String projectRoot,
    required String feature,
  }) async {
    for (final row in rows) {
      if ((state.behaviorStates[row.id] ?? BehaviorState.pending) !=
          BehaviorState.pending) {
        continue;
      }
      if (await registry.findRecord(row.id) != null) {
        return true;
      }
      // Bug #734 v2: the registry is not the only redness source — a
      // generated stub on disk without a record reds the suite exactly
      // the same. Check the gen default layout before declaring the
      // row artifact-less.
      final snakeId = _snakeCase(row.id);
      final namespacedTestPath = p.join(
        projectRoot,
        'test',
        'tdd',
        feature,
        '${snakeId}_test.dart',
      );
      if (File(namespacedTestPath).existsSync()) {
        return true;
      }
      // Legacy flat layout (pre-#827) fallback.
      final defaultTestPath = p.join(
        projectRoot,
        'test',
        'tdd',
        '${snakeId}_test.dart',
      );
      if (File(defaultTestPath).existsSync()) {
        return true;
      }
    }
    return false;
  }

  /// The snake_case form [gen_command.dart] derives file names from
  /// (lowercase, non-alphanumeric runs folded to `_`).
  String _snakeCase(String id) =>
      id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

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

  /// Bug #829 phase 0 — create every declared entity that does not
  /// exist yet (idempotent reuse: an existing entity file is never
  /// regenerated over hand-tuned fields), then run `zfa build` ONCE
  /// when at least one entity was created. Returns the honest [_Stop]
  /// when a spawn fails or hangs; null when phase 0 completed (or had
  /// nothing to do).
  Future<_Stop?> _runEntityPhaseZero({
    required String projectRoot,
    required List<DeclaredEntity> entities,
    required String? zfaBin,
    required Duration? timeout,
  }) async {
    final entry = zfaBin ?? await StepRunner.defaultZfaBin();
    final deadline = timeout ?? TddTimeouts.defaultPipelineStep;

    Future<ProcessResult> spawn(List<String> args) {
      final command = entry.endsWith('.dart')
          ? ['dart', entry, ...args]
          : [entry, ...args];
      return runTimed(
        command.first,
        command.sublist(1),
        workingDirectory: projectRoot,
        timeout: deadline,
      );
    }

    _Stop failedSpawn({required String what, required ProcessResult r}) {
      _printOutputExcerpt((r.stderr.isEmpty ? r.stdout : r.stderr).toString());
      return (
        result: 'runner-error',
        stoppedAt: 'phase-0:$what',
        exitCode: _exitRunnerError,
        message:
            'phase-0 $what failed (exit ${r.exitCode}) — the run '
            'stops before any behavior is driven (bug #829).',
      );
    }

    var created = 0;
    for (final entity in entities) {
      if (await locateEntityFile(projectRoot, entity.name) != null) {
        print('[run] phase-0 entity ${entity.name} -> reused');
        continue;
      }
      final args = [
        'entity',
        'create',
        '-n',
        entity.name,
        for (final field in entity.fields) ...['--field', field],
      ];
      ProcessResult result;
      try {
        result = await spawn(args);
      } on ProcessTimeoutException {
        print(
          '[run] phase-0 entity ${entity.name} -> failed (timed out after '
          '${deadline.inSeconds}s)',
        );
        return (
          result: 'runner-error',
          stoppedAt: 'phase-0:entity',
          exitCode: _exitRunnerError,
          message:
              'phase-0 `entity create -n ${entity.name}` exceeded the '
              'step deadline — the run stops before any behavior is '
              'driven (bug #829).',
        );
      } on ProcessException catch (e) {
        print('[run] phase-0 entity ${entity.name} -> failed (spawn)');
        return (
          result: 'runner-error',
          stoppedAt: 'phase-0:entity',
          exitCode: _exitRunnerError,
          message:
              'phase-0 spawn failed for the zfa entrypoint: '
              '${e.message} (bug #829).',
        );
      }
      if (result.exitCode != 0) {
        print('[run] phase-0 entity ${entity.name} -> failed');
        return failedSpawn(what: 'entity', r: result);
      }
      created++;
      print('[run] phase-0 entity ${entity.name} -> created');
    }

    if (created == 0) {
      // Nothing new on disk — no build needed (idempotent resume).
      print('[run] phase-0 build -> skipped');
      return null;
    }
    ProcessResult build;
    try {
      build = await spawn(const ['build']);
    } on ProcessTimeoutException {
      print(
        '[run] phase-0 build -> failed (timed out after '
        '${deadline.inSeconds}s)',
      );
      return (
        result: 'runner-error',
        stoppedAt: 'phase-0:build',
        exitCode: _exitRunnerError,
        message:
            'phase-0 `zfa build` exceeded the step deadline — the run '
            'stops before any behavior is driven (bug #829).',
      );
    } on ProcessException catch (e) {
      print('[run] phase-0 build -> failed (spawn)');
      return (
        result: 'runner-error',
        stoppedAt: 'phase-0:build',
        exitCode: _exitRunnerError,
        message:
            'phase-0 spawn failed for the zfa entrypoint: '
            '${e.message} (bug #829).',
      );
    }
    if (build.exitCode != 0) {
      print('[run] phase-0 build -> failed');
      return failedSpawn(what: 'build', r: build);
    }
    print('[run] phase-0 build -> ok');
    return null;
  }

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
        case BehaviorState.mocked:
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
typedef _DriveResult = ({RunState state, _Stop? stop, bool refactorBlocked});

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
