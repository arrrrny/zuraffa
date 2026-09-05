/// `RunDriverCore` — the shared two-phase driver core behind `zfa tdd run`,
/// `zfa tdd run-engine` and `zfa tdd run-skin` (spec 1008-two-cycle-driver,
/// issue #1008; the driving semantics are spec 049-tdd-run's, unchanged).
///
/// This is the driving body the single `RunCommand` owned before the
/// engine/skin split (#1000): state load, journal replay, evidence
/// reconciliation, the phase-0 entity orchestration (bug #829), the
/// once-per-run suite baseline (issue #741 / spec 069 T004), the two-phase
/// outside-in loop with its deferrals (bugs #625, #635, #657, #734, #826)
/// and the honest-stop discipline (FR-007). The three commands share this
/// core — the ONLY difference between them is which behaviors they load:
///
/// - `run-engine` drives the ENGINE lane (CORE + BOTH rows — the engine
///   plan), writes `tdd/04-engine-receipt.json`;
/// - `run-skin` drives the SKIN lane (SKIN + BOTH rows — the skin plan),
///   gated by the caller on a green engine receipt, writes
///   `tdd/04-skin-receipt.json`;
/// - `run` (the meta-driver) chains both lanes and fails fast on the
///   first non-green outcome.
///
/// Lane truth comes from [LanePlanReader]: the `tdd/04-ENGINE.md` /
/// `tdd/04-SKIN.md` plan pair when present (#1000), else the ` [core]` /
/// ` [skin]` / ` [both]` row tags, else the legacy CORE default — every
/// behavior engine-lane, the pre-split `zfa tdd run` behavior exactly.
///
/// The core prints every progress/failure line the single-run driver
/// printed (with the [label] parameterized — the meta run keeps `run`, so
/// its output is byte-identical) but RETURNS the outcome instead of
/// printing the final summary line or setting the process exit code: the
/// commands own the summary line and the exit code. Lane runs also write
/// their receipt here — one code path for the standalone commands and the
/// meta driver's internal lanes, never duplicated.
///
/// Exit codes (unchanged): 0 complete, 1 stopped, 2 runner-error,
/// 3 corrupt-state, 4 concurrent-run — plus run-skin's engine-gate refusal
/// (exit 2, handled by the command before the core is invoked).
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../models/behavior.dart';
import '../models/cycle_entry.dart';
import '../models/run_state.dart';
import '../services/artifact_registry.dart';
import '../services/cycle_evidence.dart';
import '../services/cycle_log.dart';
import '../services/entity_lookup.dart';
import '../services/lane_plans.dart';
import '../services/lane_receipts.dart';
import '../services/run_baseline_cache.dart';
import '../services/corpus_baseline_cache.dart';
import '../services/run_state_store.dart';
import '../services/runner.dart';
import '../services/step_runner.dart';
import '../services/suite_guard.dart';
import '../services/test_list_reader.dart';
import '../services/tdd_timeout.dart';
import '../services/tdd_transaction.dart';

/// One lane invocation's machine outcome — everything the commands need to
/// print their summary line, set the exit code, and (for the meta driver)
/// decide whether to chain the next lane.
class RunDriverOutcome {
  const RunDriverOutcome({
    required this.result,
    required this.exitCode,
    required this.rows,
    required this.state,
    required this.drove,
    required this.counts,
    required this.skippedWidgetIds,
    this.stoppedAt,
    this.message,
    this.lane,
  });

  /// complete | stopped | runner-error | corrupt-state | concurrent-run.
  final String result;

  /// 0 complete, 1 stopped, 2 runner-error, 3 corrupt-state,
  /// 4 concurrent-run (spec 049's contract, unchanged).
  final int exitCode;

  /// The FULL test list as read by this invocation (lane commands count
  /// their lane subset; the meta driver counts the union).
  final List<BehaviorRow> rows;

  /// The final run state (null when the run misfired before loading it).
  final RunState? state;

  /// Whether the driving phase began (the pre-driving checks passed). Only
  /// a driving run writes its receipt — a misfired lane leaves the last
  /// honest verdict standing.
  final bool drove;

  /// Counts over the DRIVEN rows (the lane subset; lane-null = all rows)
  /// under [state] — the receipt counts and the lane summary counts.
  final Map<String, int> counts;

  /// `behavior:step` when the run stopped, else null.
  final String? stoppedAt;

  /// The behavior ids the run skipped via --skip-widget (issue #992:
  /// widget-lane gen refusals the operator chose to skip); named in the
  /// end-of-run summary (`skipped-widget=<n>`).
  final List<String> skippedWidgetIds;

  /// A refusal/corruption message printed before the summary line (the
  /// concurrent-run refusal and the corruption recovery path name their
  /// reason).
  final String? message;

  /// The lane this outcome drove ('engine' | 'skin' | null).
  final String? lane;

  /// The receipt verdict vocabulary for this outcome (green | red | error).
  String get verdict => verdictForDriverResult(result);
}

class RunDriverCore {
  static const _exitComplete = 0;
  static const _exitStopped = 1;
  static const _exitRunnerError = 2;
  static const _exitCorruptState = 3;
  static const _exitConcurrentRun = 4;

  /// Drive [feature]'s lane through the two-phase loop.
  ///
  /// - [lane] null — drive EVERY behavior of the test list (the legacy
  ///   single-run contract; used by the meta driver's pre-split fallback
  ///   and by any full-drive caller).
  /// - [lane] 'engine' / 'skin' — drive that lane's rows only (CORE+BOTH /
  ///   SKIN+BOTH), write the lane receipt when the driving phase ran.
  /// - [label] names the command in every progress/failure line (`run` for
  ///   the meta driver so its output stays byte-identical to the pre-split
  ///   driver; `run-engine` / `run-skin` for the lane commands).
  /// - [announce] prints the `feature X — N behavior(s)` banner (the meta
  ///   driver announces its engine lane and silences the skin lane's).
  Future<RunDriverOutcome> drive({
    required String feature,
    required String projectRoot,
    String? zfaBin,
    Duration? timeout,
    String? lane,
    String label = 'run',
    bool announce = true,
    bool skipWidget = false,
  }) async {
    final featureDir = p.join(projectRoot, 'specs', feature);
    final receipts = LaneReceipts(featureDir);

    // -----------------------------------------------------------------
    // 1. Feature directory (misfire-stop when absent).
    // -----------------------------------------------------------------
    if (!await Directory(featureDir).exists()) {
      return _outcome(
        result: 'runner-error',
        exitCode: _exitRunnerError,
        rows: const [],
        state: null,
        drove: false,
        lane: lane,
        message:
            'no feature directory at '
            '${p.relative(featureDir, from: projectRoot)} (project root: '
            '$projectRoot)',
      );
    }

    final store = RunStateStore(featureDir);

    // -----------------------------------------------------------------
    // 2. Load state — corruption stops with the recovery path (FR-006).
    // -----------------------------------------------------------------
    RunState? loaded;
    try {
      loaded = await store.load();
    } on RunStateCorruptException catch (e) {
      return _outcome(
        result: 'corrupt-state',
        exitCode: _exitCorruptState,
        rows: const [],
        state: null,
        drove: false,
        lane: lane,
        message: e.message,
      );
    }

    // -----------------------------------------------------------------
    // 3. Concurrent-run refusal via the in-flight marker (FR-006).
    // -----------------------------------------------------------------
    final refusal = store.refusalReason(loaded);
    if (refusal != null) {
      return _outcome(
        result: 'concurrent-run',
        exitCode: _exitConcurrentRun,
        rows: const [],
        state: loaded,
        drove: false,
        lane: lane,
        message: refusal,
      );
    }

    // -----------------------------------------------------------------
    // 4. Read the test list (misfire-stop on malformed rows, FR-011).
    // -----------------------------------------------------------------
    List<BehaviorRow> allRows;
    try {
      allRows = await TestListReader(featureDir).read();
    } on TestListReadException catch (e) {
      return _outcome(
        result: 'runner-error',
        exitCode: _exitRunnerError,
        rows: const [],
        state: loaded,
        drove: false,
        lane: lane,
        message: e.message,
      );
    }
    if (allRows.isEmpty) {
      return _outcome(
        result: 'runner-error',
        exitCode: _exitRunnerError,
        rows: const [],
        state: loaded,
        drove: false,
        lane: lane,
        message:
            'test list at specs/$feature/tdd/test-list.md has no behaviors',
      );
    }
    final activeIds = allRows.map((r) => r.id).toSet();

    // Lane resolution (issue #1008): which rows this invocation drives.
    List<BehaviorRow> rows;
    if (lane == null) {
      rows = allRows;
    } else {
      final assignment = await LanePlanReader(featureDir).resolve(allRows);
      final laneIds = lane == 'skin'
          ? assignment.skinIds
          : assignment.engineIds;
      rows = allRows.where((r) => laneIds.contains(r.id)).toList();
    }

    // -----------------------------------------------------------------
    // 5. Reconcile state with evidence: evidence beats state (FR-003).
    // -----------------------------------------------------------------
    final evidence = CycleEvidence(featureDir);

    // -----------------------------------------------------------------
    // 4b. Bug #828: replay the write-ahead journal BEFORE reconciling.
    // -----------------------------------------------------------------
    final tx = TddTransaction(featureDir);
    final journal = await tx.pending();
    if (journal != null) {
      loaded = await _replayJournal(tx, loaded, evidence, journal, label);
    }

    var current = _reconcile(
      loaded ?? RunState.empty(feature),
      allRows,
      await evidence.redEvidence(),
      await evidence.greenEvidence(),
    );

    // Persist the reconciled state only when something actually changed.
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
    if (announce) {
      print('zfa tdd $label: feature $feature — ${rows.length} behavior(s)');
      if (skipped > 0) print('   $skipped already done — skipping');
    }
    if (rows.isEmpty) {
      // A lane with no behaviors is a vacuous green (issue #1008: legacy
      // features have no skin lane; an all-skin feature has no engine
      // work). Nothing is driven, the receipt records the empty lane.
      return _finish(
        result: 'complete',
        exitCode: _exitComplete,
        rows: allRows,
        state: current,
        drove: true,
        lane: lane,
        laneRows: rows,
        receipts: receipts,
        stoppedAt: null,
        message: null,
      );
    }

    // From here the run drives: a later misfire writes its receipt.
    // -----------------------------------------------------------------
    // 6. Drive the loop in two phases (FR-001, FR-004..FR-008; bugs
    //    #625, #635, #657 and #734) — the semantics of run_command.dart,
    //    with the deferral checks consulting the WHOLE suite (allRows):
    //    a red or pending-with-artifacts behavior reds the suite for
    //    every lane's refactors exactly like it did for the single run.
    // -----------------------------------------------------------------
    // Bug #742: the step spawner carries the deadline.
    final runner = StepRunner(zfaBin: zfaBin, timeout: timeout);

    // Issue #992: --skip-widget turns a widget-lane gen refusal (#938
    // shadcn gate) into a recorded per-behavior skip instead of a run
    // stop. The map is keyed by behavior id (transcript + summary) and
    // gates phases 2a/2b so a skipped behavior is never re-driven.
    final skippedWidgets = <String, String>{};

    String? suiteBaselinePath;
    final anyMakeOutstanding = rows.any(
      (r) => current.behaviorStates[r.id] != BehaviorState.done,
    );

    // ---------------------------------------------------------------
    // 6a. Phase 0 — spec Key Entities orchestration (bug #829).
    // ---------------------------------------------------------------
    if (anyMakeOutstanding) {
      final declaredEntities = await TestListReader(featureDir).readEntities();
      if (declaredEntities.isNotEmpty) {
        final stop = await _runEntityPhaseZero(
          projectRoot: projectRoot,
          entities: declaredEntities,
          zfaBin: zfaBin,
          timeout: timeout,
          label: label,
          feature: feature,
        );
        if (stop != null) {
          return _finish(
            result: stop.result,
            exitCode: stop.exitCode,
            rows: allRows,
            state: current,
            drove: true,
            lane: lane,
            laneRows: rows,
            receipts: receipts,
            stoppedAt: stop.stoppedAt,
            message: stop.message,
          );
        }
      }
    }

    // ---------------------------------------------------------------
    // 6b. Cache the full-suite baseline ONCE per run (issue #741).
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

    // --- Phase 1: the uniform cycle in list order, with the deferrals.
    final registry = ArtifactRegistry(featureDir: featureDir);
    for (final row in rows) {
      final state = current.behaviorStates[row.id] ?? BehaviorState.pending;
      if (state == BehaviorState.done) continue;

      final inFlightStep = current.inFlightBehaviorId == row.id
          ? current.inFlightStep
          : null;
      final hasGenArtifacts = await registry.findRecord(row.id) != null;
      final result = await _driveBehavior(
        row: row,
        steps: _stepsFor(state, inFlightStep, hasGenArtifacts: hasGenArtifacts),
        progressSuffix: '',
        deferralAllowed: true,
        rows: allRows,
        current: current,
        projectRoot: projectRoot,
        activeIds: activeIds,
        store: store,
        evidence: evidence,
        runner: runner,
        registry: registry,
        suiteBaselinePath: suiteBaselinePath,
        skipWidget: skipWidget,
        skippedWidgets: skippedWidgets,
        label: label,
        feature: feature,
      );
      if (result.stop != null) {
        return _finish(
          result: result.stop!.result,
          exitCode: result.stop!.exitCode,
          rows: allRows,
          state: result.state,
          drove: true,
          lane: lane,
          laneRows: rows,
          receipts: receipts,
          skippedWidgets: skippedWidgets,
          stoppedAt: result.stop!.stoppedAt,
          message: result.stop!.message,
        );
      }
      current = result.state;
    }

    // --- Phase 2a: re-attempt every behavior deferred at its phase-1 make.
    for (final row in rows) {
      final state = current.behaviorStates[row.id] ?? BehaviorState.pending;
      if (state == BehaviorState.done) continue;
      if (state == BehaviorState.green) continue;
      // Issue #992: a widget-skipped behavior has no gen artifacts —
      // re-driving its make would refuse "no gen artifacts" and stop the
      // run for a behavior the operator already chose to skip.
      if (skippedWidgets.containsKey(row.id)) continue;

      final inFlightStep = current.inFlightBehaviorId == row.id
          ? current.inFlightStep
          : null;
      final result = await _driveBehavior(
        row: row,
        steps: _phaseTwoMakeSteps(state, inFlightStep),
        progressSuffix: ' (phase 2)',
        deferralAllowed: false,
        rows: allRows,
        current: current,
        projectRoot: projectRoot,
        activeIds: activeIds,
        store: store,
        evidence: evidence,
        runner: runner,
        registry: registry,
        suiteBaselinePath: suiteBaselinePath,
        skipWidget: skipWidget,
        skippedWidgets: skippedWidgets,
        label: label,
        feature: feature,
      );
      if (result.stop != null) {
        return _finish(
          result: result.stop!.result,
          exitCode: result.stop!.exitCode,
          rows: allRows,
          state: result.state,
          drove: true,
          lane: lane,
          laneRows: rows,
          receipts: receipts,
          skippedWidgets: skippedWidgets,
          stoppedAt: result.stop!.stoppedAt,
          message: result.stop!.message,
        );
      }
      current = result.state;
    }

    // --- Phase 2b: the refactor pass (bugs #635 and #734; issue #922).
    final certifiedGreen = await evidence.greenEvidence();
    final skippedRefactors = <String, String>{};
    for (final row in rows) {
      final state = current.behaviorStates[row.id] ?? BehaviorState.pending;
      if (state != BehaviorState.green) continue;
      // Issue #992: never re-drive a widget-skipped behavior.
      if (skippedWidgets.containsKey(row.id)) continue;

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
        rows: allRows,
        current: current,
        projectRoot: projectRoot,
        activeIds: activeIds,
        store: store,
        evidence: evidence,
        runner: runner,
        registry: registry,
        suiteBaselinePath: suiteBaselinePath,
        skipWidget: skipWidget,
        skippedWidgets: skippedWidgets,
        label: label,
        feature: feature,
      );
      if (result.stop != null) {
        return _finish(
          result: result.stop!.result,
          exitCode: result.stop!.exitCode,
          rows: allRows,
          state: result.state,
          drove: true,
          lane: lane,
          laneRows: rows,
          receipts: receipts,
          skippedWidgets: skippedWidgets,
          stoppedAt: result.stop!.stoppedAt,
          message: result.stop!.message,
        );
      }
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
    if (!allDone &&
        (skippedRefactors.isNotEmpty || skippedWidgets.isNotEmpty)) {
      // Bug #734 per-behavior gate (+ v2 refusal skips, issue #992): the
      // pass completed for every behavior that could proceed; the rest
      // stay at their last completed state with their outstanding work
      // named — bounded, resumable progress (FR-007), never a fake DONE
      // (FR-008). One terminal block reports BOTH skip kinds: a stop can
      // carry refactors and widget skips together, and the summary must
      // name each with its resume path (review finding on #1071).
      if (skippedRefactors.isNotEmpty) {
        print(
          'zfa tdd $label: refactor skipped for '
          '${skippedRefactors.keys.join(', ')} — '
          '${skippedRefactors.values.toSet().join(' / ')}',
        );
        print(
          '   resume: restore the suite green (re-run make for behaviors '
          'whose own test is red; fix the failing tests the preflight '
          'named otherwise), then re-run `zfa tdd $label $feature`',
        );
      }
      if (skippedWidgets.isNotEmpty) {
        print(
          'zfa tdd $label: widget-lane skipped for '
          '${skippedWidgets.keys.join(', ')} — '
          '${skippedWidgets.values.toSet().join(' / ')}',
        );
        print(
          '   resume: add shadcn_ui (flutter pub add shadcn_ui --dev) or '
          'drop --skip-widget, then re-run `zfa tdd $label $feature`',
        );
      }
      return _finish(
        result: 'stopped',
        exitCode: _exitStopped,
        rows: allRows,
        state: current,
        drove: true,
        lane: lane,
        laneRows: rows,
        receipts: receipts,
        stoppedAt: skippedRefactors.isNotEmpty
            ? '${skippedRefactors.keys.first}:refactor'
            : '${skippedWidgets.keys.first}:gen',
        skippedWidgets: skippedWidgets,
        message: null,
      );
    }
    if (!allDone) {
      print(
        'zfa tdd $label: internal error — loop finished with non-DONE '
        'behaviors',
      );
      return _finish(
        result: 'runner-error',
        exitCode: _exitRunnerError,
        rows: allRows,
        state: current,
        drove: true,
        lane: lane,
        laneRows: rows,
        receipts: receipts,
        stoppedAt: null,
        message: 'internal error — loop finished with non-DONE behaviors',
      );
    }
    return _finish(
      result: 'complete',
      exitCode: _exitComplete,
      rows: allRows,
      state: current,
      drove: true,
      lane: lane,
      laneRows: rows,
      receipts: receipts,
      stoppedAt: null,
      message: null,
    );
  }

  // -------------------------------------------------------------------
  // Outcome assembly (the receipt write lives here — ONE code path for
  // the standalone lane commands and the meta driver's internal lanes).
  // -------------------------------------------------------------------

  RunDriverOutcome _outcome({
    required String result,
    required int exitCode,
    required List<BehaviorRow> rows,
    required RunState? state,
    required bool drove,
    required String? lane,
    String? stoppedAt,
    String? message,
  }) => RunDriverOutcome(
    result: result,
    exitCode: exitCode,
    rows: rows,
    state: state,
    drove: drove,
    counts: const {'total': 0, 'pending': 0, 'red': 0, 'green': 0, 'done': 0},
    skippedWidgetIds: const [],
    stoppedAt: stoppedAt,
    message: message,
    lane: lane,
  );

  Future<RunDriverOutcome> _finish({
    required String result,
    required int exitCode,
    required List<BehaviorRow> rows,
    required RunState? state,
    required bool drove,
    required String? lane,
    required List<BehaviorRow> laneRows,
    required LaneReceipts receipts,
    Map<String, String> skippedWidgets = const {},
    String? stoppedAt,
    String? message,
  }) async {
    final counts = laneCounts(laneRows, state?.behaviorStates ?? const {});
    if (lane != null && drove) {
      // The lane receipt: written on every driving run (complete ->
      // green, stopped -> red, runner-error -> error); a pre-driving
      // misfire wrote nothing (this outcome is always post-driving).
      try {
        await receipts.write(
          lane: lane,
          verdict: verdictForDriverResult(result),
          result: result,
          behaviors: laneRows.map((r) => r.id).toList(),
          counts: counts,
          stoppedAt: stoppedAt,
        );
      } on FileSystemException {
        // The receipt is a record, never a gate for the driving that
        // already happened: a failed write is reported, not fatal.
        stderr.writeln(
          'zfa tdd: failed to write the $lane receipt at '
          '${receipts.receiptPath(lane)}',
        );
      }
    }
    return RunDriverOutcome(
      result: result,
      exitCode: exitCode,
      rows: rows,
      state: state,
      drove: drove,
      counts: counts,
      skippedWidgetIds: skippedWidgets.keys.toList(),
      stoppedAt: stoppedAt,
      message: message,
      lane: lane,
    );
  }

  /// The machine summary line the commands print as their final line
  /// (FR-009/FR-010, shape unchanged; lane commands carry `lane=`):
  /// `run: feature=<f> result=<r> pending=<n> red=<n> green=<n> done=<n>`
  /// plus ` stopped_at=<behavior>:<step>` when stopped.
  static String summaryLine({
    required String label,
    required String feature,
    required String result,
    required Map<String, int> counts,
    String? lane,
    String? stoppedAt,
    List<String> skippedWidgetIds = const [],
  }) {
    final lanePart = lane == null ? '' : ' lane=$lane';
    // Issue #1007: the BLOCKED contract verdict is counted on its own
    // token, never folded into red (restored from the pre-split driver —
    // the lane receipt's laneCounts() already emits it, bug #1107).
    final blocked = counts['blocked'];
    final blockedPart = (blocked == null || blocked == 0)
        ? ''
        : ' blocked=$blocked';
    return '$label: feature=$feature$lanePart result=$result '
        'pending=${counts['pending']} red=${counts['red']} '
        'green=${counts['green']} done=${counts['done']}'
        '$blockedPart'
        '${skippedWidgetIds.isNotEmpty ? ' skipped-widget=${skippedWidgetIds.length}' : ''}'
        '${stoppedAt != null ? ' stopped_at=$stoppedAt' : ''}';
  }

  // -------------------------------------------------------------------
  // Reconciliation (FR-003: evidence beats state) — verbatim from
  // run_command.dart (the single-run driver); `rows` is the FULL list.
  // -------------------------------------------------------------------

  Future<RunState?> _replayJournal(
    TddTransaction tx,
    RunState? state,
    CycleEvidence evidence,
    Map<String, dynamic> journal,
    String label,
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
        effective = hasRed && hasGreen
            ? BehaviorState.done
            : hasGreen
            ? BehaviorState.green
            : hasRed
            ? BehaviorState.red
            : BehaviorState.pending;
      } else if (claimed == BehaviorState.mocked ||
          claimed == BehaviorState.green) {
        effective = hasGreen
            ? claimed
            : hasRed
            ? BehaviorState.red
            : BehaviorState.pending;
      } else if (bootstrappable && claimed == BehaviorState.pending) {
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
  // Step sequencing (FR-001, FR-005; two-phase outside-in driving).
  // -------------------------------------------------------------------

  List<String> _stepsFor(
    BehaviorState state,
    String? inFlightStep, {
    required bool hasGenArtifacts,
  }) {
    const full = ['gen', 'verify-red', 'make', 'refactor'];
    var start = switch (state) {
      BehaviorState.pending => 0,
      BehaviorState.red => 2,
      // Spec 1007: a BLOCKED contract behavior re-enters at verify-red —
      // an implemented contract either unblocks the cycle or keeps it
      // honestly blocked.
      BehaviorState.blocked => 1,
      BehaviorState.mocked || BehaviorState.green => 3,
      BehaviorState.done => 4,
    };
    if (inFlightStep != null && inFlightStep.isNotEmpty) {
      final index = full.indexOf(inFlightStep);
      if (index >= 0) start = index;
    } else if (!hasGenArtifacts) {
      start = 0;
    }
    return full.sublist(start.clamp(0, full.length));
  }

  List<String> _phaseTwoMakeSteps(BehaviorState state, String? inFlightStep) {
    const window = ['make'];
    var start = switch (state) {
      BehaviorState.pending => 0,
      BehaviorState.red => 0,
      BehaviorState.blocked => 0,
      BehaviorState.mocked || BehaviorState.green => 1,
      BehaviorState.done => 1,
    };
    if (inFlightStep != null) {
      final index = window.indexOf(inFlightStep);
      if (index >= 0) start = index;
    }
    return window.sublist(start.clamp(0, window.length));
  }

  List<String> _phaseTwoRefactorSteps(
    BehaviorState state,
    String? inFlightStep,
  ) {
    const window = ['refactor'];
    var start = switch (state) {
      BehaviorState.pending => 0,
      BehaviorState.red => 0,
      BehaviorState.blocked => 0,
      BehaviorState.mocked || BehaviorState.green => 0,
      BehaviorState.done => 1,
    };
    if (inFlightStep != null) {
      final index = window.indexOf(inFlightStep);
      if (index >= 0) start = index;
    }
    return window.sublist(start.clamp(0, window.length));
  }

  // -------------------------------------------------------------------
  // The per-behavior step loop — verbatim from run_command.dart with the
  // command [label]/[feature] parameterized (the resume hints and failure
  // blocks name the invoking command) and `rows` carrying the FULL list
  // (deferral semantics are suite-global: a red or pending-with-artifacts
  // behavior of ANY lane defers refactor, bugs #635/#734).
  // -------------------------------------------------------------------

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
    required bool skipWidget,
    required Map<String, String> skippedWidgets,
    required String label,
    required String feature,
  }) async {
    var updated = current;
    var state = updated.behaviorStates[row.id] ?? BehaviorState.pending;
    final tx = TddTransaction(p.join(projectRoot, 'specs', feature));
    for (final step in steps) {
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
      // in-flight marker was written (FR-006).
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
          'zfa tdd $label: step failed — behavior=${row.id} step=$step '
          'outcome=runner-error',
        );
        print('   ${e.message}');
        print(
          '   resume: fix the issue, then re-run `zfa tdd $label $feature`',
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

      print('[run] ${row.id} $step -> ${result.outcome}$progressSuffix');

      if (!result.success) {
        // Bug #986: `skipped` — make's issue #694 skip transition (the
        // target test already passes, generation skipped by design) — is a
        // TERMINAL make success, never a step failure. StepRunner grades
        // the exit-0 skip as success; this mapping closes the fall-through
        // for a skipped token whose exit code disagrees (binary skew, or
        // the #657/#694-era drift contract where the already-green report
        // exited non-zero): make's outcome token is the step's own
        // terminal classification, and halting the feature on an
        // already-green behavior is the #693/#694 deadlock family. Record
        // the green evidence when make's write did not land (idempotent —
        // never a duplicate, the #693 driver-recorded pattern), advance
        // the behavior GREEN, and let refactor proceed as usual.
        if (step == 'make' && result.outcome == 'skipped') {
          if (!await _hasEvidence(evidence.greenEvidence, row.id)) {
            await CycleLog(p.join(projectRoot, 'specs', feature)).append(
              CycleLogEntry(
                behaviorId: row.id,
                kind: CycleEntryKind.green,
                runnerCommand: 'zfa tdd make ${row.id} (skipped)',
                exitCode: result.exitCode,
                capturedOutput:
                    'skipped — the target test already passes (issue #694 '
                    'skip transition); green evidence recorded by the run '
                    'driver (bug #986) because make did not write it. Exit '
                    'code ${result.exitCode} disagrees with the outcome '
                    'token; the token is the terminal classification.\n'
                    '${result.output.split('\n').take(2).join('\n')}',
                sourceCriterion: row.traces,
                testPath: 'test/',
                timestamp: DateTime.now().toUtc().toIso8601String(),
              ),
            );
          }
          final next = _maxState(state, _targetStateFor(step));
          updated = updated.advance(row.id, next);
          await store.save(updated, activeBehaviorIds: activeIds);
          await tx.clear();
          state = next;
          print('[run] ${row.id} make -> green (skipped)$progressSuffix');
          if (result.exitCode != 0) {
            print(
              '   exit code ${result.exitCode} disagrees with '
              'outcome=skipped — the token is the terminal skip transition '
              '(issue #694); advancing (bug #986).',
            );
          }
          continue;
        }
        if (deferralAllowed &&
            step == 'make' &&
            (result.outcome == 'unexpressible' || result.outcome == 'no-op')) {
          updated = updated.advance(row.id, state);
          await store.save(updated, activeBehaviorIds: activeIds);
          await tx.clear();
          print('[run] ${row.id} make -> deferred (phase 2)');
          return (state: updated, stop: null, refactorBlocked: false);
        }
        if (step == 'verify-red' && result.outcome == 'unexpected-green') {
          updated = updated.advance(row.id, state);
          await store.save(updated, activeBehaviorIds: activeIds);
          await tx.clear();
          print('[run] ${row.id} verify-red -> skipped (already green)');
          continue;
        }
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
        // Issue #992: a widget-lane gen refusal (#938 shadcn gate) is
        // per-behavior information, not a run-fatal step failure — the
        // refusal is side-effect-free (gen refuses BEFORE any artifact
        // write, registry append, or re-render). With --skip-widget the
        // behavior keeps its current state (FR-007: never a fake DONE),
        // the skip is named in the transcript and the end-of-run summary,
        // and the run continues with the remaining behaviors. Without
        // the flag the honest stop below stands (the default contract).
        if (step == 'gen' &&
            result.outcome == 'refused' &&
            result.verdictKind == 'widget' &&
            skipWidget) {
          updated = updated.advance(row.id, state);
          await store.save(updated, activeBehaviorIds: activeIds);
          await tx.clear();
          skippedWidgets[row.id] = 'shadcn_ui not declared (issue #938)';
          print(
            '[run] ${row.id} gen -> skipped-widget '
            '(--skip-widget; shadcn_ui not declared, issue #938)',
          );
          return (state: updated, stop: null, refactorBlocked: false);
        }
        // Issue #1007: a CONTRACT behavior whose verify-red reported the
        // `blocked` verdict is BLOCKED — distinct from RED. RED is the
        // honest first state of a unit/widget behavior (the loop EXPECTS
        // the failing test and proceeds to make/GREEN); a failing
        // CONTRACT test means the declared contract is unsatisfied, so
        // the behavior is parked at BLOCKED, make/refactor NEVER spawn for
        // it, and the run stops with `result=blocked` (the receipt lives
        // at .zfa/receipts/contract-blocked.<id>.json — verify-red wrote
        // it). Resume re-enters at verify-red: once the implementation
        // satisfies the contract, the verdict flips (the unexpected-green
        // skip transitions the behavior on) and the cycle proceeds.
        // Restored verbatim from the pre-split single-run driver — the
        // spec 1008 two-cycle refactor (issue #1092) dropped this arm and
        // the blocked verdict degraded into a generic result=stopped
        // (bug #1107).
        if (step == 'verify-red' &&
            result.outcome == 'blocked' &&
            row.kind == BehaviorKind.contract) {
          updated = updated.advance(row.id, BehaviorState.blocked);
          await store.save(updated, activeBehaviorIds: activeIds);
          await tx.clear();
          print(
            '   the declared contract ${row.traces} is not satisfied — the '
            'cycle is BLOCKED and cannot proceed to GREEN (issue #1007)',
          );
          print(
            '   resume: implement the declared contract, then re-run '
            '`zfa tdd $label $feature`',
          );
          return (
            state: updated,
            stop: (
              result: 'blocked',
              stoppedAt: '${row.id}:verify-red',
              exitCode: _exitStopped,
              message: null,
            ),
            refactorBlocked: false,
          );
        }
        // Honest stop (FR-007).
        final isRunnerError = result.outcome == 'runner-error';
        updated = updated.advance(row.id, state);
        await store.save(updated, activeBehaviorIds: activeIds);
        await tx.clear();
        print(
          'zfa tdd $label: step failed — behavior=${row.id} step=$step '
          'outcome=${result.outcome}',
        );
        _printOutputExcerpt(result.output);
        print(
          '   resume: fix the failing step, then re-run '
          '`zfa tdd $label $feature`',
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
          'zfa tdd $label: step failed — behavior=${row.id} step=$step '
          'outcome=runner-error',
        );
        print('   $misfire');
        print(
          '   resume: fix the failing step, then re-run '
          '`zfa tdd $label $feature`',
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
      await tx.clear();
      state = next;
    }
    return (state: updated, stop: null, refactorBlocked: false);
  }

  BehaviorState _targetStateFor(String step) => switch (step) {
    'gen' => BehaviorState.pending,
    'verify-red' => BehaviorState.red,
    'make' => BehaviorState.green,
    'refactor' => BehaviorState.done,
    _ => throw ArgumentError.value(step, 'step', 'unknown TDD step'),
  };

  bool _hasRedBehavior(List<BehaviorRow> rows, RunState state) {
    for (final row in rows) {
      if ((state.behaviorStates[row.id] ?? BehaviorState.pending) ==
          BehaviorState.red) {
        return true;
      }
    }
    return false;
  }

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

  String _snakeCase(String id) =>
      id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  BehaviorState _maxState(BehaviorState a, BehaviorState b) =>
      a.index >= b.index ? a : b;

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
  // Phase 0 (bug #829) — verbatim, with the failure messages naming the
  // invoking command label.
  // -------------------------------------------------------------------

  Future<_Stop?> _runEntityPhaseZero({
    required String projectRoot,
    required List<DeclaredEntity> entities,
    required String? zfaBin,
    required Duration? timeout,
    required String label,
    required String feature,
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
      print('[run] phase-0 build -> skipped');
      return null;
    }
    ProcessResult build;
    try {
      // Bug #991: --no-analyze — the phase-0 build is a generation gate,
      // not an analysis gate. Pre-existing warnings in the target repo
      // (unused imports, dead code) must not fail the run before any
      // behavior is driven; verify/refactor keep their own analyze.
      build = await spawn(const ['build', '--no-analyze']);
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

/// A stop report from `_driveBehavior`: the summary [result] name, the
/// optional [stoppedAt] `behavior:step`, the process [exitCode], and an
/// optional [message] printed before the summary line.
typedef _Stop = ({
  String result,
  String? stoppedAt,
  int exitCode,
  String? message,
});

/// The outcome of driving one behavior through its step window: the
/// updated run state plus, when the run must stop, the [_Stop] report.
typedef _DriveResult = ({RunState state, _Stop? stop, bool refactorBlocked});

/// Strip a leading `specs/` prefix from a user-supplied feature reference
/// (shared by every driver command: run, run-engine, run-skin, status).
String stripSpecsPrefix(String feature) {
  if (feature.startsWith('specs/') || feature.startsWith('specs\\')) {
    final stripped = feature.substring('specs/'.length);
    if (stripped.isEmpty) return feature;
    return stripped;
  }
  return feature;
}

/// Segment check for the positional feature argument: it lands in a
/// filesystem path, so keep it a single plain directory segment (mirrors
/// verify_red_command.dart; shared by every driver command).
void validateFeatureSegment(String feature, String invocation) {
  if (feature.contains('/') ||
      feature.contains(r'\') ||
      feature == '.' ||
      feature == '..') {
    throw UsageException(
      'invalid feature "$feature": expected a single spec directory name '
      'such as 049-tdd-run, not a path.',
      invocation,
    );
  }
}
