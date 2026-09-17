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
/// meta driver's internal lanes, never duplicated. Issue #1590 carve-out:
/// the machine-contract lines stay byte-identical; the ADDITIVE liveness
/// lines (the pre-spawn step-start banner, the tee'd `→ ` child banners,
/// the elapsed-time heartbeats) are new — see the [RunDriverCore]
/// statics and the `run_command.dart` library doc.
///
/// Exit codes (unchanged): 0 complete, 1 stopped, 2 runner-error,
/// 3 corrupt-state, 4 concurrent-run — plus run-skin's engine-gate refusal
/// (exit 2, handled by the command before the core is invoked).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/behavior.dart';
import '../models/cycle_entry.dart';
import '../models/run_state.dart';
import '../models/artifact_record.dart';
import '../services/artifact_registry.dart';
import '../services/arg_placeholder.dart';
import '../services/born_green.dart';
import '../services/cycle_evidence.dart';
import '../services/cycle_log.dart';
import '../services/declared_routing.dart';
import '../services/entity_lookup.dart';
import '../services/feature_path_resolver.dart';
import '../services/journal.dart';
import '../services/lane_plans.dart';
import '../services/lane_receipts.dart';
import '../services/kernel_cache.dart';
import '../services/make_post_state.dart';
import '../services/pass_batch_ledger.dart';
import '../services/run_baseline_cache.dart';
import '../services/corpus_baseline_cache.dart';
import '../services/run_state_store.dart';
import '../services/runner.dart';
import '../services/scalar_dummy_subject.dart';
import '../services/spec_parser.dart';
import '../services/step_runner.dart';
import '../services/tree_snapshot.dart';
import '../services/contract_blocked_receipt.dart';
import '../services/hand_surface.dart';
import '../services/reproof_failure_classifier.dart' show parseFailingTestNames;
import '../services/suite_guard.dart';
import '../models/routing.dart';
import '../services/test_list_reader.dart';
import '../services/unit_contract_shape.dart';
import '../services/tdd_timeout.dart';
import '../services/step_timeout_receipt.dart';
import '../services/vacuous_guard.dart';
import '../services/widget_scaffold.dart' show scaffoldedMarker;
import '../services/tdd_transaction.dart';
import '../../../core/dependencies/builder_dependency_preflight.dart';
import '../../../cli/zfa_executable.dart';

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
    this.handStepIds = const [],
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

  /// The behavior ids the run parked at the designed hand-step (issue
  /// #1568: the planner's seam forecast + make's still-failing red) —
  /// named in the end-of-run summary (`hand_steps=N`).
  final List<String> handStepIds;

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

/// SPEC 917 (`--stream`, issue #838): one COMPLETED loop step, streamed
/// as NDJSON the moment it finishes — schema_versioned `step-verdict.v1`.
/// The invocation's final `verdict.v1` envelope still closes the output.
class StepStreamEvent {
  const StepStreamEvent({
    required this.command,
    required this.feature,
    required this.behavior,
    required this.step,
    required this.outcome,
    required this.exitCode,
    this.lane,
  });

  /// The driving command's label (`run`, `run-engine`, `run-skin`).
  final String command;

  final String feature;

  final String behavior;

  /// `gen` | `verify-red` | `make` | `refactor`.
  final String step;

  /// The step's outcome token (`green`, `red`, `deferred`, `skipped`, ...).
  final String outcome;

  /// The step process's exit code (0 for transitions without a spawn).
  final int exitCode;

  /// `engine` | `skin` | null (legacy full-list drive).
  final String? lane;

  Map<String, dynamic> toJson() => {
    'schema_version': 'step-verdict.v1',
    'command': command,
    'feature': feature,
    'behavior': behavior,
    'step': step,
    'outcome': outcome,
    'exit_code': exitCode,
    if (lane != null) 'lane': lane,
    'timestamp': DateTime.now().toUtc().toIso8601String(),
  };

  /// One NDJSON line — flushable as-is.
  String toNdjsonLine() => jsonEncode(toJson());
}

class RunDriverCore {
  static const _exitComplete = 0;
  static const _exitStopped = 1;
  static const _exitRunnerError = 2;
  static const _exitCorruptState = 3;
  static const _exitConcurrentRun = 4;

  /// SPEC 917 (`--stream`, issue #838): the per-step stream hook. When
  /// set, the driver fires one [StepStreamEvent] per COMPLETED step as
  /// soon as it completes — the NDJSON `step-verdict.v1` events stream
  /// while the run drives, and the final `verdict.v1` envelope still
  /// closes the output. Null (the default): no events, legacy output.
  void Function(StepStreamEvent event)? onStepEvent;

  /// The no-JIT seam (see `ZfaExecutable`): every child entrypoint the
  /// driver spawns itself — the phase-0 `zfa entity create` step (bug
  /// #829) — is resolved to a compiled artifact first. Settable so tests
  /// inject a fake compiler instead of running a real `dart compile exe`.
  ZfaEnsureCompiled ensureCompiled = ZfaExecutable.ensureCompiled;

  // Issue #1590 (progress liveness): per-invocation output tuning, set by
  // [drive] (the same instance-state pattern as the stream context — drive
  // is non-reentrant on one instance).
  //
  // [_verboseChildLines] — `--verbose`: forward EVERY stdout line the step
  // children print to the run output. Default (false): forward only
  // banner-shaped lines (`^→ `, the pipeline's sub-step announcements).
  bool _verboseChildLines = false;

  // [_heartbeat] — the elapsed-time heartbeat cadence for a running step
  // (`--heartbeat <seconds>`); [Duration.zero] disables, null keeps the
  // 30s default.
  Duration? _heartbeat;

  // The active invocation's stream context, set by [drive] (the hook is
  // instance-level so the per-behavior helpers can fire it too; drive is
  // non-reentrant on one instance, so no cross-call interference).
  String? _streamCommand;
  String? _streamFeature;
  String? _streamLane;

  /// Issue #1590: forward the step child's stdout lines to the run output.
  /// Default: banner-shaped lines only (starting with the pipeline banner
  /// arrow, FR-005); `--verbose` forwards every line verbatim.
  void _forwardChildLine(String line) {
    if (_verboseChildLines || line.startsWith('\u2192 ')) print(line);
  }

  /// Issue #1590: the pre-spawn step announcement (FR-001/FR-007) — the
  /// pre-#1590 driver printed nothing between the spawn and the
  /// completion line (273.7s of silence on one make). The hint is static
  /// per-step knowledge; the SUB-STEP plan is the make child's own
  /// announcement (the pipeline banners ride the stdout tee). When the
  /// loaded run-state marks this exact behavior+step as in-flight under a
  /// foreign pid, the banner names the resume (FR-007).
  static String stepStartLine(
    String behavior,
    String step, {
    bool resumingInFlight = false,
    int? ownerPid,
  }) {
    final hint = switch (step) {
      'gen' => 'scaffold test + stub',
      'verify-red' => 'run target test (expect red)',
      'make' => 'generation pipeline (sub-steps announced as they start)',
      'refactor' => 'format + analyze + re-proof',
      _ => 'running',
    };
    final resume = resumingInFlight
        ? ' (resuming in-flight step from run-state.json, '
              'owner pid ${ownerPid ?? 'unknown'})'
        : '';
    return '[run] $behavior $step \u2014 $hint$resume';
  }

  /// Issue #1590: the elapsed-time heartbeat line for a running step
  /// (FR-006); [elapsed] formatted by `formatTddTimeout`.
  static String heartbeatLine(String behavior, String step, Duration elapsed) {
    return '[run] $behavior $step \u2026 ${formatTddTimeout(elapsed)} elapsed';
  }

  // Issue #1329: the failed step's diagnostic evidence, staged by the
  // error-outcome recording path and consumed by [_finish] for the lane
  // journal entry — the same per-invocation instance-state pattern the
  // stream context uses (drive is non-reentrant per instance). Reset at
  // every drive; set ONLY by the error-outcome arms (the honest stop and
  // the pre-spawn runner-error), never by the named deferral/skip/block
  // arms or by successful steps.
  _StepFailure? _lastStepFailure;

  /// Issue #1589: the parked contracts' seam file paths (project-relative)
  /// the phase-2 refactor gate must tolerate — pre-existing-failure
  /// economics for a BLOCKED verdict. Seeded from the persisted state
  /// (blocked contract + verdict receipt on disk — cross-lane/resume
  /// parkings), the still-blocked skip arm, and this run's parkings; the
  /// set is complete before the first phase-2b refactor spawns and is
  /// handed to every refactor child as `--parked-seam <path>`. Every path
  /// is existence-gated (review fix): the flag only ever names a seam the
  /// driver SAW parked, never `seamPathFor`'s display-only fallback.
  /// Per-run instance state (drive is non-reentrant per instance).
  final Set<String> _parkedSeamPaths = <String>{};

  /// Issue #1589 (review fix): the failing-test identifiers the parked
  /// verdicts RECORDED, handed to refactor children as
  /// `--parked-failure <identifier>` so the tolerance pins to the known
  /// red instead of exempting a whole seam file. Read from each verdict
  /// receipt's `output_excerpt` (the transcript the verdict actually saw)
  /// when it is parseable; a seam with no identifier here keeps the
  /// coarser file-level tolerance, which is what the pre-review flag did
  /// for every seam.
  final Set<String> _parkedFailureIdentifiers = <String>{};

  /// Fires one step-verdict.v1 event for a completed step (a no-op when
  /// the hook is unset — the legacy byte-identical output path).
  void _emitStep(
    String behavior,
    String step,
    String outcome, {
    int exitCode = 0,
  }) {
    final cb = onStepEvent;
    final feature = _streamFeature;
    if (cb == null || feature == null) return;
    cb(
      StepStreamEvent(
        command: _streamCommand ?? 'run',
        feature: feature,
        behavior: behavior,
        step: step,
        outcome: outcome,
        exitCode: exitCode,
        lane: _streamLane,
      ),
    );
  }

  /// Drive [featureRef]'s lane through the two-phase loop. [featureRef] is
  /// the canonical feature REFERENCE (issue #1471): the caller resolved it
  /// once (the bug-extension pin included), and this driver resolves it
  /// again so the lane's paths and its spawned children's `--feature`
  /// agree on one directory.
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
    required String featureRef,
    required String projectRoot,
    String? zfaBin,
    Duration? timeout,
    String? lane,
    String label = 'run',
    bool announce = true,
    bool skipWidget = false,
    Map<String, int>? mockCounts,
    String? baselineScope,

    /// Spec 1520: the caller's per-run scratch environment
    /// (`ScratchTmpDir.childEnvironment`) — handed to the spawned step
    /// children and the phase-0 pipeline spawns so every `dart test`
    /// grandchild writes its kernel dir inside the run's own scratch
    /// instead of the shared user TMPDIR (issue #1520). Null (the default)
    /// preserves the inherit-`Platform.environment` behavior.
    Map<String, String>? childEnvironment,

    /// Issue #1590: forward EVERY stdout line the step children print to
    /// the run output (`--verbose`). Default (false): forward only
    /// banner-shaped lines (`^→ `, the pipeline's sub-step announcements).
    bool verbose = false,

    /// Issue #1590: the heartbeat cadence for a running step —
    /// `[run] <behavior> <step> … <elapsed> elapsed` every [heartbeat]
    /// while the child runs. Null keeps the 30s default;
    /// [Duration.zero] disables (`--heartbeat 0`, the parser-strict mode).
    Duration? heartbeat,
  }) async {
    // Issue #1471: the caller hands the canonical REFERENCE — the parent
    // resolved it once (pin included) and its child steps must resolve the
    // same directory. [feature] (the NAME) namespaces artifacts and
    // labels; [featureDir] is every path.
    final resolved = TddFeaturePaths.resolve(
      projectRoot: projectRoot,
      featureRef: featureRef,
    );
    final feature = resolved.name;
    final featureDir = resolved.dir;
    final receipts = LaneReceipts(featureDir);
    // Spec 1113: the lane's journal entry bounds — the cycle started
    // when the driver began, finished when it records its outcome.
    final journalStartedAt = DateTime.now().toUtc().toIso8601String();

    // SPEC 917 (--stream): publish this invocation's stream context for
    // the instance-level _emitStep (drive is non-reentrant per instance).
    _streamCommand = label;
    _streamFeature = feature;
    _streamLane = lane;
    // Issue #1590: publish this invocation's liveness tuning.
    _verboseChildLines = verbose;
    _heartbeat = heartbeat ?? const Duration(seconds: 30);
    // Issue #1329: one failure detail per drive — staged by the
    // error-outcome arms below, consumed by _finish.
    _lastStepFailure = null;

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
            'test list at '
            '${TddFeaturePaths.displayDir(cwd: projectRoot, dir: p.join(featureDir, 'tdd', 'test-list.md'))} '
            'has no behaviors',
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
      // Bug #1271 (tdd-run-widget-lane-stalls-engine): widget-kind
      // behaviors are SKIN-lane work (spec 1008 — widget subjects run
      // only after a green engine receipt), whatever route carried them
      // into the engine bucket (a ` [both]` tag, the plan pair / split
      // receipt, or the legacy CORE default). Driving them through the
      // engine steps stalls the lane: verify-red sees the widget subject
      // already green and refuses with not-certified-red at make.
      //
      // - ENGINE lane: defer every widget-kind row — it keeps its
      //   pending state (never a fake DONE, FR-007/FR-008) and no engine
      //   step is spawned for it.
      // - SKIN lane: the deferral queue — the widget-kind rows deferred
      //   OUT of the engine bucket join the skin bucket (SKIN + BOTH),
      //   so run-skin (and the meta run's second lane) picks them up
      //   behind the green engine receipt. The skin lane's own
      //   widget-kind processing is unchanged (bug #1271 constraint 4).
      if (lane == 'engine') {
        rows = rows.where((r) => r.kind != BehaviorKind.widget).toList();
      } else if (lane == 'skin') {
        final deferredWidgetIds = <String>{
          for (final r in allRows)
            if (r.kind == BehaviorKind.widget &&
                assignment.engineIds.contains(r.id))
              r.id,
        };
        if (deferredWidgetIds.isNotEmpty) {
          rows = allRows
              .where(
                (r) =>
                    laneIds.contains(r.id) || deferredWidgetIds.contains(r.id),
              )
              .toList();
        }
      }
    }

    // -----------------------------------------------------------------
    // 5. Reconcile state with evidence: evidence beats state (FR-003).
    //    Issue #1264: a reset's tombstoned behaviors are subtracted from
    //    the evidence sets first — reset drops the artifacts but never
    //    the append-only cycle-log, and reconciling off that surviving
    //    green evidence skipped the dropped behaviors as "already done"
    //    (the phantom done-state). The tombstone is the per-behavior
    //    evidence invalidation record the reset wrote.
    // -----------------------------------------------------------------
    final evidence = CycleEvidence(featureDir);
    final tombstoned = await JournalReader.tombstonedBehaviors(featureDir);
    final redEvidence = (await evidence.redEvidence()).difference(tombstoned);
    final greenEvidence = (await evidence.greenEvidence()).difference(
      tombstoned,
    );

    // -----------------------------------------------------------------
    // 4b. Bug #828: replay the write-ahead journal BEFORE reconciling.
    // -----------------------------------------------------------------
    final tx = TddTransaction(featureDir);
    final journal = await tx.pending();
    if (journal != null) {
      loaded = await _replayJournal(tx, loaded, evidence, journal, label);
    }

    // Issue #1324: the behaviors whose current-generation green evidence
    // is backed by its certified test file on disk — computed AFTER WAL
    // replay so a green append pending in the journal is visible.
    final certifiedGreenBacked = await _certifiedGreenBacked(
      evidence,
      projectRoot,
    );
    // Review #1608: the registry resolves each behavior's registered
    // subject path — the born-green subject binding below (and every
    // later phase) reads it, so it is constructed once, here.
    final registry = ArtifactRegistry(featureDir: featureDir);
    // Issue #1592: the behaviors whose LAST green entry certifies the
    // born-green hand transition (the #1411 journal marker) AND binds the
    // current subject — the class whose blocked re-entry converges at
    // refactor (the #1542 evidence check), never at the flagless make
    // that refuses not-certified-red. Review #1608: the certification is
    // a SHORTCUT over the honest verify-red -> make re-drive, so it must
    // pin the subject shape it exercised (the #1036/#1587 rule) — a
    // hashless or mismatched entry keeps the pre-#1592 window.
    final bornGreenCertifiedBehaviors = await _bornGreenCertifiedBehaviors(
      evidence,
      registry: registry,
      projectRoot: projectRoot,
    );

    var current = _reconcile(
      loaded ?? RunState.empty(feature),
      allRows,
      redEvidence,
      greenEvidence,
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
      // SPEC 1489: the unit lane's hand-step forecast — the same seam
      // cost `zfa tdd plan` surfaced. Output-only here: the announce
      // reads the entity registry as it stands now, and the loop, the
      // BehaviorState transitions and the two-phase driver semantics
      // stay untouched. Issue #1568's park gate resolves the SAME
      // forecast lazily on the failure path instead (after phase-0 has
      // created the pass's declared entities) — see `_driveBehavior`.
      final unitRowCount = rows
          .where((r) => r.kind == BehaviorKind.unit)
          .length;
      if (unitRowCount > 0) {
        final seamIds = await _entityReturnSeamIds(
          projectRoot: projectRoot,
          featureName: feature,
          featureDir: featureDir,
          rows: rows,
        );
        final seamLine = UnitContractShape.entityReturnSeamCostLine(
          seams: seamIds.length,
          total: unitRowCount,
        );
        if (seamLine != null) print('   $seamLine');
      }
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
        journalStartedAt: journalStartedAt,
        projectRoot: projectRoot,
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
    // Bug #742: the step spawner carries the deadline. Spec 1529: the
    // budget may be UPGRADED below (scaled from the measured baseline
    // suite duration) — the runner is rebuilt there when it changes.
    // Spec 1520: it also carries the run's scratch-TMPDIR map for every
    // step child. Issue #1590: it also tees the child's stdout lines so
    // the driver can forward the make child's sub-step banners while the
    // step runs.
    var runner = StepRunner(
      zfaBin: zfaBin,
      timeout: timeout,
      childEnvironment: childEnvironment,
      onChildLine: _forwardChildLine,
    );

    // Issue #992: --skip-widget turns a widget-lane gen refusal (#938
    // skin gate) into a recorded per-behavior skip instead of a run
    // stop. The map is keyed by behavior id (transcript + summary) and
    // gates phases 2a/2b so a skipped behavior is never re-driven.
    final skippedWidgets = <String, String>{};

    // Issue #1568: the behaviors this pass parked at the designed
    // hand-step (planner seam forecast + make's still-failing red), with
    // the reason recorded for the end-of-pass summary and the journal.
    final handSteps = <String, String>{};

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
          childEnvironment: childEnvironment,
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
            journalStartedAt: journalStartedAt,
            projectRoot: projectRoot,
            stoppedAt: stop.stoppedAt,
            message: stop.message,
          );
        }
      }
    }

    // ---------------------------------------------------------------
    // 6b. Cache the full-suite baseline ONCE per run (issue #741).
    // Spec 1529: the capture's measured wall time (fresh or recorded in
    // a reused cache) scales the per-step budget (US2) — a make step's
    // cost is bounded by the suite it re-certifies against, and that
    // suite grows every behavior, so a FIXED budget gets less safe as
    // the run progresses.
    // ---------------------------------------------------------------
    int? measuredBaselineMs;
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
        // Issue #1374: a scoped baseline is per-feature — the
        // corpus-wide cache is bypassed entirely (a scoped snapshot must
        // not masquerade as corpus-wide reuse).
        if (corpusReused != null &&
            corpusReused.parseable &&
            baselineScope == null) {
          // Spec 1529: the corpus cache rides the capture duration so a
          // REUSE run scales the per-step budget without re-measuring.
          final reusedMs = await corpusCache.readDurationMs(
            projectRoot: projectRoot,
          );
          suiteBaselinePath = await const RunBaselineCache().write(
            featureDir: featureDir,
            snapshot: corpusReused,
            durationMs: reusedMs,
            // Spec 1529: the fingerprint rides the feature-local cache so
            // make's trimmed re-certification can prove the environment
            // is the one the baseline certified (FR-9a).
            fingerprint: fingerprint,
          );
          measuredBaselineMs = reusedMs;
          print(
            '   suite baseline: corpus-wide reuse '
            '(fingerprint match; spec 069 T004) — '
            '${corpusReused.failedTests.length} pre-existing failure(s) '
            'captured ${corpusReused.capturedAt}; the suite is not '
            're-run for this feature',
          );
        } else {
          // Issue #1374: the constrained-agent escape hatch — scope the
          // baseline suite command to a path (canonically the feature's
          // test directory) so the FIRST baseline can be produced on a
          // 10 GB-disk agent where the whole-tree kernel compile cannot.
          final scopedTemplate = baselineScope == null
              ? suiteTemplate
              : '$suiteTemplate $baselineScope';
          // Issue #1642: an UNSCOPED baseline is a full-suite `dart test`
          // sweep — ~765 suites × ~69 MB of self-contained kernel snapshots
          // ≈ 50 GB in the temp volume, and an ENOSPC death mid-sweep leaks
          // everything compiled so far. Fail FAST with the remedy instead:
          // this refusal unwinds past the StateError guard below (which
          // means "no template" — a silent skip here would re-arm the
          // leak) and stops the run before the first spawn.
          if (baselineScope == null) {
            final refusal = await fullSuiteBaselinePreflight(
              projectRoot,
              environment: childEnvironment,
            );
            if (refusal != null) {
              print(refusal);
              throw DiskPreflightRefusal(refusal);
            }
          }
          print(
            '   suite baseline: $scopedTemplate (once per run — issue #741)',
          );
          // Spec 1529: the capture's wall time is the measured baseline
          // the per-step budget scales from — measure the REAL run.
          final captureStopwatch = Stopwatch()..start();
          final baselineRecord = await const SingleTestRunner().runSuite(
            suiteTemplate: scopedTemplate,
            workingDirectory: projectRoot,
            // Issue #1159: the run-level --timeout override is ONE uniform
            // deadline for every spawned process (bug #742 contract) — the
            // baseline suite included. Dropping it here left the hardcoded
            // 10-minute defaultSuite in charge, killing the baseline (and
            // with it every make step) on repos whose fast suite runs long.
            // Spec 1529: without an override the capture is bounded by at
            // least the derived FLOOR, never by the old fixed 10-minute
            // default — a measurement killed at 10 minutes is exactly the
            // case the scaling exists for (no duration recorded ⇒ the
            // budget silently degrades to the floor).
            timeout: timeout ?? scaledStepBudget(measuredBaseline: null),
          );
          captureStopwatch.stop();
          final snapshot = const SuiteGuard().fromRunRecord(
            record: baselineRecord,
            capturedAt: DateTime.now().toUtc().toIso8601String(),
          );
          if (snapshot.parseable) {
            final durationMs = captureStopwatch.elapsed.inMilliseconds;
            measuredBaselineMs = durationMs;
            suiteBaselinePath = await const RunBaselineCache().write(
              featureDir: featureDir,
              snapshot: snapshot,
              durationMs: durationMs,
              // Spec 1529: the fingerprint rides the feature-local cache
              // (FR-9a) — make's trimmed re-certification keys on it.
              fingerprint: fingerprint,
            );
            // Issue #1374: a scoped snapshot never enters the
            // corpus-wide cache.
            if (fingerprint != null && baselineScope == null) {
              await corpusCache.write(
                projectRoot: projectRoot,
                snapshot: snapshot,
                fingerprint: fingerprint,
                durationMs: durationMs,
              );
            }
            print(
              '   baseline cached for this run: '
              '${p.relative(suiteBaselinePath, from: projectRoot)} '
              '(${snapshot.failedTests.length} pre-existing failure(s)); '
              'make steps reuse it instead of re-running the suite',
            );
          } else {
            // Spec 1529, FR-5: an unusable capture is reported, never a
            // silent degrade to the floor — the operator must be able to
            // tell that the scaling did not apply, and why.
            print(
              '   note: the suite baseline capture produced no usable '
              'snapshot (exit ${baselineRecord.exitCode}'
              '${baselineRecord.timedOut ? ', timed out' : ''}) — the '
              'per-step budget falls back to the floor (spec 1529)',
            );
          }
        }
      } on StateError {
        // No profile / no suite template
      }
    }

    // ---------------------------------------------------------------
    // 6c. Derive the per-step budget (spec 1529, US2 / FR-4..FR-6).
    // An explicit --timeout ALWAYS wins; the default scales from the
    // measured baseline suite duration (floor 25 min). When the
    // projection meets or exceeds an EXPLICIT budget, warn loudly
    // BEFORE the first step spawns — the issue's misfire came from a
    // budget that was safe on an idle machine and unsafe under load.
    // The budget stays ONE uniform deadline handed to every step child
    // (issue #1159's contract), passed down as the child's --timeout.
    // ---------------------------------------------------------------
    if (anyMakeOutstanding) {
      final measuredBaseline = measuredBaselineMs == null
          ? null
          : Duration(milliseconds: measuredBaselineMs);
      final budget = scaledStepBudget(
        measuredBaseline: measuredBaseline,
        explicit: timeout,
      );
      if (timeout != null) {
        final projected = projectedMakeCost(measuredBaseline: measuredBaseline);
        if (projected != null && projected >= timeout) {
          print(
            'WARNING: the explicit --timeout looks unsafe for this run '
            '(issue #1529):',
          );
          print(
            '   measured baseline suite: ${formatBudget(measuredBaseline!)}',
          );
          print(
            '   projected per-step make cost: 4 x baseline = '
            '${formatBudget(projected)}',
          );
          print(
            '   explicit budget: ${formatBudget(timeout)} — a make step '
            'under load may be killed mid-suite (the budget was measured '
            'on an idle machine)',
          );
          print(
            '   consider raising --timeout, or drop it to use the scaled '
            'default (max(25m floor, 4 x baseline))',
          );
        }
      }
      if (budget != timeout && budget != TddTimeouts.defaultStepProcess) {
        runner = StepRunner(
          zfaBin: zfaBin,
          timeout: budget,
          childEnvironment: childEnvironment,
          onChildLine: _forwardChildLine,
        );
        print(
          '   per-step budget: ${formatBudget(budget)} '
          '(scaled from the measured baseline, issue #1529)',
        );
      }
    }

    // Issue #1589: seed the parked seams the phase-2 refactor gate must
    // tolerate. A persisted BLOCKED contract (any lane's rows — the parked
    // verdict poisons every later refactor spawn, not just its own lane's)
    // whose verdict receipt exists contributes its seam file: the failing
    // seam test is a KNOWN red for the rest of this run, not new damage.
    // Fail-closed: no receipt on disk — no tolerance (the honest refusal
    // stands). This run's parkings and still-blocked skips are added by
    // their arms below (authoritative — the driver SAW the verdict).
    // Review fix: the seam is existence-gated (never a display-only guess)
    // and the receipt's own transcript contributes the attested failing
    // identifiers the gate pins its tolerance to.
    final blockedReceiptStore = ContractBlockedReceiptStore(
      projectRoot: projectRoot,
    );
    for (final row in allRows) {
      if (row.kind != BehaviorKind.contract) continue;
      if ((current.behaviorStates[row.id] ?? BehaviorState.pending) !=
          BehaviorState.blocked) {
        continue;
      }
      final receipt = ContractBlockedReceipt.fromFile(
        blockedReceiptStore.pathFor(row.id),
      );
      if (receipt == null) continue;
      _addParkedSeam(
        behaviorId: row.id,
        projectRoot: projectRoot,
        feature: feature,
        attestedOutput: receipt.outputExcerpt,
      );
    }

    // --- Phase 1: the uniform cycle in list order, with the deferrals.
    // Issue #1544 (review fix): the rows whose BLOCKED verdict THIS run's
    // verify-red lifted (`unexpected-green` against a blocked contract).
    // That arm keeps the persisted state at BLOCKED, so the phase-2a guard
    // cannot tell a still-parked contract from one the run just unblocked;
    // without this set the deferred make's phase-2 re-attempt is lost and
    // the run reports a factually wrong `result=blocked` for a contract
    // verify-red just certified satisfied.
    final unblockedThisRun = <String>{};
    for (final row in rows) {
      final state = current.behaviorStates[row.id] ?? BehaviorState.pending;
      if (state == BehaviorState.done) continue;

      // Issue #1544: an ALREADY-blocked contract behavior whose world is
      // unchanged since its blocked verdict is skipped, not re-driven —
      // the pre-#1544 resume re-attempted the SAME verify-red (a full
      // refactor pass) for zero progress. Any change signal (the seam
      // file, the contract row, the implementation) — or a missing or
      // unreadable verdict receipt (fail open) — re-drives it honestly,
      // so implementing the contract still unblocks the cycle.
      if (state == BehaviorState.blocked && row.kind == BehaviorKind.contract) {
        final since = await _unchangedBlockedSince(
          row: row,
          projectRoot: projectRoot,
          featureDir: featureDir,
          feature: feature,
        );
        if (since != null) {
          print(
            '[run] ${row.id} verify-red -> skipped (still blocked since '
            '$since)',
          );
          _emitStep(row.id, 'verify-red', 'skipped');
          // Issue #1589: the parked verdict's seam test stays red for the
          // rest of this run — the phase-2 refactor gate must tolerate it.
          _addParkedSeam(
            behaviorId: row.id,
            projectRoot: projectRoot,
            feature: feature,
          );
          continue;
        }
      }

      final inFlightStep = current.inFlightBehaviorId == row.id
          ? current.inFlightStep
          : null;
      final hasGenArtifacts = await registry.findRecord(row.id) != null;
      final result = await _driveBehavior(
        row: row,
        steps: _stepsFor(
          state,
          inFlightStep,
          hasGenArtifacts: hasGenArtifacts,
          hasGreenEvidence: greenEvidence.contains(row.id),
          greenTestBacked: certifiedGreenBacked.contains(row.id),
          bornGreenCertified: bornGreenCertifiedBehaviors.contains(row.id),
        ),
        progressSuffix: '',
        deferralAllowed: true,
        unblockedThisRun: unblockedThisRun,
        rows: allRows,
        current: current,
        projectRoot: projectRoot,
        featureDir: featureDir,
        featureRef: featureRef,
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
        greenEvidenceIds: greenEvidence,
        handSteps: handSteps,
        // Issue #1624: the phase-1 per-behavior refactor opts into the
        // pass-batch ledger too. Phase 1 was the remaining spawn shape
        // that never did, so every behavior's refactor re-paid the whole
        // pipeline (~85-190s) even though the previous one just proved
        // the identical tree. The ledger's byte-identity check is what
        // makes this safe: only a byte-identical `lib/` + `test/` tree
        // under the same suite/baseline/config/exempt set inherits a
        // previously proven gate, so a phase-1 spawn that changed
        // anything re-runs the full pipeline.
        batchRefactor: true,
        // Issue #1652: the ledger can never inherit during FORWARD
        // progress — every make changes `lib/`, so each spawn's tree
        // differs from the last refactor's proved tree. What it does
        // equal is this make's certified post-state; record it at
        // make-green so the spawn right after can inherit honestly.
        recordMakePostState: true,
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
          journalStartedAt: journalStartedAt,
          projectRoot: projectRoot,
          skippedWidgets: skippedWidgets,
          // Issue #1568 (review fix): the parked hand-steps ride every
          // stop path, not just the terminal hand-step branch — a later
          // behavior's genuine failure must not drop the record of the
          // behavior this pass deliberately parked (`hand_steps=N` in
          // the summary, `parked-hand-step=` in the journal).
          handSteps: handSteps,
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
      // Issue #1007/#1544: make NEVER spawns for a BLOCKED contract —
      // the parked behavior keeps its state and waits for an
      // implementation that satisfies the declared contract (the
      // pre-#1544 driver never reached this phase with a parked
      // behavior; continuing past blocked does).
      //
      // Issue #1544 (review fix): a blocked contract whose block THIS
      // run's verify-red lifted is exempt — its state is still BLOCKED
      // (the unexpected-green arm does not transition it), but its
      // phase-1 make was deferred and owes this phase-2 re-attempt.
      if (state == BehaviorState.blocked &&
          !unblockedThisRun.contains(row.id)) {
        continue;
      }
      // Issue #992: a widget-skipped behavior has no gen artifacts —
      // re-driving its make would refuse "no gen artifacts" and stop the
      // run for a behavior the operator already chose to skip.
      if (skippedWidgets.containsKey(row.id)) continue;
      // Issue #1568: a hand-stepped behavior already burned its phase-1
      // make — the designed hand step cannot succeed mechanically, so
      // re-attempting it in phase 2 would just re-print the park. The
      // behavior keeps its honest red; the end-of-pass summary names it.
      if (handSteps.containsKey(row.id)) continue;

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
        featureDir: featureDir,
        featureRef: featureRef,
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
        greenEvidenceIds: greenEvidence,
        handSteps: handSteps,
        // Issue #1652: the phase-2a re-attempted make also green-applies
        // (and may be the last tree change before a phase-2b spawn).
        recordMakePostState: true,
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
          journalStartedAt: journalStartedAt,
          projectRoot: projectRoot,
          skippedWidgets: skippedWidgets,
          // Issue #1568 (review fix): the parked hand-steps ride every
          // stop path, not just the terminal hand-step branch — a later
          // behavior's genuine failure must not drop the record of the
          // behavior this pass deliberately parked (`hand_steps=N` in
          // the summary, `parked-hand-step=` in the journal).
          handSteps: handSteps,
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
        _emitStep(row.id, 'refactor', 'skipped');
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
        featureDir: featureDir,
        featureRef: featureRef,
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
        greenEvidenceIds: greenEvidence,
        handSteps: handSteps,
        // Issue #1588: the phase-2 refactor pass is the batch — every
        // spawn opts into the pass-batch ledger and hands the lane's
        // parked BLOCKED ids as exempt from the gate.
        batchRefactor: true,
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
          journalStartedAt: journalStartedAt,
          projectRoot: projectRoot,
          skippedWidgets: skippedWidgets,
          // Issue #1568 (review fix): the parked hand-steps ride every
          // stop path, not just the terminal hand-step branch — a later
          // behavior's genuine failure must not drop the record of the
          // behavior this pass deliberately parked (`hand_steps=N` in
          // the summary, `parked-hand-step=` in the journal).
          handSteps: handSteps,
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
    // Issue #1544: the parked BLOCKED behaviors are the pass's terminal
    // condition — the run names them, prints any bounded-progress skips
    // beside them, and stops with `result=blocked blocked=N` (exit 1).
    // Bounded, resumable progress (FR-007), never a fake DONE (FR-008):
    // the blocked behaviors keep their verdict, the driven ones theirs.
    final blockedRows = rows
        .where((r) => current.behaviorStates[r.id] == BehaviorState.blocked)
        .toList();
    if (blockedRows.isNotEmpty) {
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
          '   resume: add zuraffa_ui (flutter pub add zuraffa_ui --dev) or '
          'drop --skip-widget, then re-run `zfa tdd $label $feature`',
        );
      }
      print(
        'zfa tdd $label: blocked for '
        '${blockedRows.map((r) => r.id).join(', ')} — the declared '
        'contract(s) are not satisfied (issue #1007)',
      );
      // Issue #1589: the resume instructions are followable as written —
      // each parked contract's stop names its hand surface (the seam file
      // + the wire command). Issue #1625: the seam is the subject stub
      // (the implementation seam, not the generated test) and the wire
      // example only prints when the traced entity exists. Messaging only:
      // the stop contract (result, stopped_at, exit code) is the
      // #1007/#1544 one.
      for (final row in blockedRows) {
        print(
          '   ${HandSurface.hintLine(
            behaviorId: row.id,
            seamPath: HandSurface.seamPathFor(projectRoot: projectRoot, feature: feature, behaviorId: row.id),
            contract: row.traces,
            projectRoot: projectRoot,
          )}',
        );
      }
      print(
        '   resume: implement the declared contract, then re-run '
        '`zfa tdd $label $feature` — unchanged blocked behaviors are '
        'skipped with receipt on resume (issue #1544)',
      );
      return _finish(
        result: 'blocked',
        exitCode: _exitStopped,
        rows: allRows,
        state: current,
        drove: true,
        lane: lane,
        laneRows: rows,
        receipts: receipts,
        journalStartedAt: journalStartedAt,
        projectRoot: projectRoot,
        skippedWidgets: skippedWidgets,
        stoppedAt: '${blockedRows.first.id}:verify-red',
        message: null,
      );
    }
    // Issue #1568: the hand-stepped behaviors are the pass's terminal
    // condition beside the blocked ones — the run names them, prints any
    // bounded-progress skips beside them, and stops with
    // `stopped_at=<id>:hand` (the #1308 named-hand-step stop shape) and
    // `hand_steps=N` in the summary. Bounded, resumable progress
    // (FR-007), never a fake DONE (FR-008): the hand-stepped behaviors
    // keep their honest red, the driven ones their verdicts.
    if (handSteps.isNotEmpty) {
      if (skippedRefactors.isNotEmpty) {
        print(
          'zfa tdd $label: refactor skipped for '
          '${skippedRefactors.keys.join(', ')} — '
          '${skippedRefactors.values.toSet().join(' / ')}',
        );
      }
      if (skippedWidgets.isNotEmpty) {
        print(
          'zfa tdd $label: widget-lane skipped for '
          '${skippedWidgets.keys.join(', ')} — '
          '${skippedWidgets.values.toSet().join(' / ')}',
        );
      }
      print(
        'zfa tdd $label: hand-step for ${handSteps.keys.join(', ')} — '
        'the planner declared these unit behaviors hand-step '
        '(entity-return contract subjects): make cannot implement them '
        'mechanically (issue #1568)',
      );
      print(
        '   resume: implement the subject by hand (or certify a '
        'hand-implemented subject with `zfa tdd make <id> --born-green`), '
        'then re-run `zfa tdd $label $feature` — the mechanical '
        'behaviors were driven this pass',
      );
      return _finish(
        result: 'stopped',
        exitCode: _exitStopped,
        rows: allRows,
        state: current,
        drove: true,
        lane: lane,
        laneRows: rows,
        receipts: receipts,
        journalStartedAt: journalStartedAt,
        projectRoot: projectRoot,
        skippedWidgets: skippedWidgets,
        handSteps: handSteps,
        stoppedAt: '${handSteps.keys.first}:hand',
        message: null,
      );
    }
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
          '   resume: add zuraffa_ui (flutter pub add zuraffa_ui --dev) or '
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
        journalStartedAt: journalStartedAt,
        projectRoot: projectRoot,
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
        journalStartedAt: journalStartedAt,
        projectRoot: projectRoot,
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
      journalStartedAt: journalStartedAt,
      projectRoot: projectRoot,
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
    required String journalStartedAt,
    required String projectRoot,
    Map<String, String> skippedWidgets = const {},
    Map<String, String> handSteps = const {},
    String? stoppedAt,
    String? message,
    Map<String, int>? mockCounts,
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

      // Spec 1113 (issue #1113): every lane cycle ALSO appends its
      // structured entry to tdd/journal.json — the unified, machine-
      // parseable record of run-engine then run-skin that status,
      // prove and theater read through JournalReader. Same discipline
      // as the receipt write: a record, never a gate — a failed
      // journal write is reported, never fatal to the driving that
      // already happened.
      final journalWriter = JournalWriter(receipts.featureDir);
      try {
        final refs = await journalWriter.resolveRefs(
          engineOverride: lane == 'engine'
              ? JournalWriter.engineReceiptRef
              : null,
          skinOverride: lane == 'skin' ? JournalWriter.skinReceiptRef : null,
        );
        // Issue #1308: a stop at the named hand step (the traced
        // entity/void vacuous-green seam) carries the hand-step violation
        // — what to write (the outcome assertion) and where (the
        // generated test file).
        //
        // Review fix on #1568: a PARKED hand-step is NOT a #1308 stop.
        // The #1308 remedy prescribes replacing a placeholder guard, a
        // scaffolded marker or a born-green header — none of which the
        // generated subject of an entity-return seam need contain — so
        // emitting it for a park would prescribe a change that does not
        // apply. The park carries its own `parked-hand-step=` line below;
        // the lookup stands down only for the behavior this pass parked,
        // so a `:hand` stop for any OTHER behavior keeps the remedy.
        final handStepViolation =
            stoppedAt != null &&
                stoppedAt.endsWith(':hand') &&
                !handSteps.containsKey(
                  stoppedAt.substring(0, stoppedAt.lastIndexOf(':')),
                )
            ? _handStepViolationFor(
                stoppedAt,
                receipts.featureDir,
                projectRoot: projectRoot,
              )
            : null;
        // Issue #1329: the journal entry carries the failed step's
        // diagnostic evidence (the structured error object) beside the
        // machine-greppable step_error violations line — the entry no
        // longer reads only "violations": ["stopped_at=<id>:<step>"]
        // when the stop is a step error.
        final failure = _lastStepFailure;
        final violations = <String>[
          if (stoppedAt != null) 'stopped_at=$stoppedAt',
          ?handStepViolation,
          if (failure != null)
            'step_error=${failure.behaviorId}:${failure.step} '
                'outcome=${failure.outcome} exit=${failure.exitCode}',
          for (final id in skippedWidgets.keys)
            'skipped-widget=$id (${skippedWidgets[id]})',
          // Issue #1568: the parked hand-steps ride the journal the same
          // way the #992 widget skips do — machine-greppable, named. The
          // token is its OWN (`parked-hand-step=`): `hand-step=<id>:hand
          // — <sentence>` is the long-standing #1308/#1323/#1373/#1411
          // remedy grammar (review fix), and a consumer grepping
          // `hand-step=` must not have to parse two field shapes.
          for (final id in handSteps.keys)
            'parked-hand-step=$id (${handSteps[id]})',
        ];
        await journalWriter.append(
          JournalEntry(
            feature: p.basename(receipts.featureDir),
            cycle: lane,
            phase: 'drive',
            startedAt: journalStartedAt,
            finishedAt: DateTime.now().toUtc().toIso8601String(),
            gateState: switch (verdictForDriverResult(result)) {
              'green' => 'green',
              _ => 'red',
            },
            receipts: [
              lane == 'skin'
                  ? JournalWriter.skinReceiptRef
                  : JournalWriter.engineReceiptRef,
            ],
            violations: violations,
            engineReceipt: refs.engine,
            skinReceipt: refs.skin,
            contractSchema: refs.contract,
            result: result,
            behaviors: laneRows.map((r) => r.id).toList(),
            counts: counts,
            stoppedAt: stoppedAt,
            mocks: lane == 'engine' ? mockCounts : null,
            error: failure == null
                ? null
                : JournalStepError(
                    behavior: failure.behaviorId,
                    step: failure.step,
                    outcome: failure.outcome,
                    exitCode: failure.exitCode,
                    command: failure.command,
                    output: failure.outputTail,
                  ),
          ),
        );
      } on FileSystemException {
        stderr.writeln(
          'zfa tdd: failed to write the $lane journal entry at '
          '${journalWriter.journalPath}',
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
      handStepIds: handSteps.keys.toList(),
      stoppedAt: stoppedAt,
      message: message,
      lane: lane,
    );
  }

  /// The machine summary line the commands print as their final line
  /// (FR-009/FR-010, shape unchanged; lane commands carry `lane=`):
  /// `run: feature=<f> result=<r> pending=<n> red=<n> green=<n> done=<n>`
  /// plus ` hand_steps=<n>` when the pass parked hand-steps (issue
  /// #1568) and ` stopped_at=<behavior>:<step>` when stopped.
  static String summaryLine({
    required String label,
    required String feature,
    required String result,
    required Map<String, int> counts,
    String? lane,
    String? stoppedAt,
    List<String> skippedWidgetIds = const [],
    List<String> handStepIds = const [],
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
        '${handStepIds.isNotEmpty ? ' hand_steps=${handStepIds.length}' : ''}'
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
    _emitStep(behavior, step, 'replayed');
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
          // Failed refactor diagnostics are intentionally recorded, but they
          // cannot certify that an interrupted refactor step completed.
          if (entry.kind != 'refactor' || entry.exit != 0) continue;
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
    bool hasGreenEvidence = false,
    bool greenTestBacked = false,
    bool bornGreenCertified = false,
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
    // Issue #1324: a behavior whose cycle-log already carries green
    // evidence for the current artifact generation (tombstone-filtered)
    // and whose certified test file is backed on disk must NEVER re-enter
    // at gen — gen would clobber the certified pair with a fresh
    // guard-only test, verify-red unexpected-greens against the
    // implemented subject, make refuses subject-drift, and the feature
    // is wedged (re-driving clobbers, making refuses). The window
    // resumes at the phase-2 steps instead: make for a pending claim
    // (the #694 skip / #1331 adoption transitions re-certify honestly),
    // refactor for a green/mocked claim. Behaviors without backed green
    // evidence keep the exact pre-#1324 windows (SC-4).
    //
    // Issue #1592: the guard's scope extends to the BLOCKED state for
    // the born-green-certified class — the behavior whose LAST green
    // entry certifies the #1411 hand transition. The #1007 blocked arm
    // re-enters at index 1 (verify-red), so a born-green-certified
    // blocked contract skipped the `start == 0` guard and re-drove
    // verify-red -> make forever: verify-red unexpected-greens the
    // already-passing test, the flagless make refuses not-certified-red
    // (no certified red can exist for the lane / the born-green class),
    // and the #1411 stop arm prescribes the `--born-green` command that
    // ALREADY ran — the transition never converges. A born-green-
    // certified blocked behavior re-enters at refactor instead, where
    // the #1542 evidence check already accepts the green-only born-green
    // certification: the run completes without manual re-entry. The
    // marker-less blocked shapes (a plain green-only contract, U-1542-1's
    // pinned window) and blocked claims without backed green evidence
    // keep the exact pre-#1592 window — the #1007 re-entry at verify-red
    // is unchanged.
    //
    // Review #1608 (CodeRabbit): `bornGreenCertified` is only true when
    // the certification BINDS the current subject — the caller
    // (_bornGreenCertifiedBehaviors) requires the certifying entry's
    // `- subject-hash:` to match the registered subject file's sha256
    // (the #1036/#1587 byte-identical-subject rule). A subject edited
    // after `make --born-green` therefore keeps the pre-#1592 window and
    // falls back to the honest ladder instead of completing on a stale
    // certification.
    // Review #1608 (zuraffa-review): the refactor child's own suite gate
    // stays baseline-relative (#741/#922) — a certified test already red
    // at the run-start baseline is tolerated by that pre-existing design;
    // the subject binding above is what keeps a drifted subject out of
    // this window.
    if (hasGreenEvidence &&
        greenTestBacked &&
        (start == 0 ||
            (state == BehaviorState.blocked && bornGreenCertified))) {
      start = state == BehaviorState.pending ? 2 : 3;
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
    required String featureDir,
    required String featureRef,
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
    required Set<String> greenEvidenceIds,
    Set<String>? unblockedThisRun,
    // Issue #1568: the hand-steps recorded THIS pass — the end-of-pass
    // summary names them and `_finish` journals them. Required: every
    // lane passes it so a missed call site can never silently drop the
    // park record. (The park gate's forecast ids are NOT threaded — the
    // arm resolves them itself, on the failure path, so the registry
    // read is fresh; see below.)
    required Map<String, String> handSteps,

    /// Issue #1588: the refactor pass opts its spawns into the feature
    /// pass-batch ledger (--pass-batch) and hands the lane's parked
    /// BLOCKED behavior ids as --exempt-behaviors, so their designed red
    /// tests cannot poison the refactor gate. Issue #1624: BOTH refactor
    /// call sites — the phase-1 per-behavior refactor and the phase-2b
    /// batch — pass true; the ledger's byte-identity check is what makes
    /// that safe. Every other step keeps the default (no batch flags).
    bool batchRefactor = false,

    /// Issue #1652: record make's certified post-state at every make
    /// green-application, so the immediately-following `--pass-batch`
    /// refactor spawn can inherit the pipeline when the tree and gate
    /// context still match (forward progress changes `lib/` every make,
    /// which is exactly why the #1588 ledger never inherits there).
    /// Best-effort: a write failure is a warning, never an error.
    bool recordMakePostState = false,
  }) async {
    var updated = current;
    var state = updated.behaviorStates[row.id] ?? BehaviorState.pending;
    final tx = TddTransaction(featureDir);
    // Issue #1324: whether THIS drive saw the verify-red unexpected-green
    // skip — the fresh-test signal of the stale-artifacts contradiction
    // when the following make refuses subject-drift.
    var sawUnexpectedGreen = false;
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
        _emitStep(row.id, 'refactor', 'deferred');
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

      // Issue #1590: announce the step BEFORE the spawn — the pre-#1590
      // driver printed nothing between the spawn and the completion line
      // (a single make ran 273.7s in silence). The hint is static
      // per-step knowledge; the sub-step plan is the make child's own
      // announcement (the pipeline banners ride the stdout tee). The
      // loaded state (`current`, pre-markInFlight) names the resumed
      // in-flight step when it was ours, under a foreign pid.
      print(
        stepStartLine(
          row.id,
          step,
          resumingInFlight:
              current.inFlightBehaviorId == row.id &&
              current.inFlightStep == step &&
              current.inFlightOwnerPid != pid,
          ownerPid: current.inFlightOwnerPid,
        ),
      );

      StepResult result;
      final stepClock = Stopwatch()..start();
      final heartbeatInterval = _heartbeat;
      final heartbeat =
          heartbeatInterval != null && heartbeatInterval > Duration.zero
          ? Timer.periodic(
              heartbeatInterval,
              (_) => print(heartbeatLine(row.id, step, stepClock.elapsed)),
            )
          : null;
      try {
        // Issue #1471: hand the child the canonical REFERENCE (never the
        // bare name), so a bug-directory feature resolves to the same
        // directory this run resolved.
        result = await runner.run(
          step: step,
          behaviorId: row.id,
          feature: featureRef,
          projectRoot: projectRoot,
          suiteBaselinePath: suiteBaselinePath,
          // Issue #1589: the parked seams the refactor gate must tolerate
          // (pre-existing-failure economics for a BLOCKED verdict), plus
          // the verdict-attested failing identifiers that pin that
          // tolerance to the known red. The StepRunner appends both to
          // REFACTOR spawns only.
          parkedSeamPaths: _parkedSeamPaths,
          parkedFailureIdentifiers: _parkedFailureIdentifiers,
          extraArgs: step == 'refactor' && batchRefactor
              ? _refactorBatchArgs(rows, updated)
              : const [],
        );
      } on StateError catch (e) {
        // Entrypoint resolution failed before any spawn: runner-error.
        // Issue #1329: record what is known — no spawned command, exit
        // -1, the resolution error message as the captured output — so
        // even a pre-spawn misfire leaves its diagnostic on disk.
        await _recordStepFailure(
          _StepFailure(
            behaviorId: row.id,
            step: step,
            outcome: 'runner-error',
            exitCode: -1,
            command:
                '(none — the zfa entrypoint did not resolve; no step was '
                'spawned)',
            outputTail: _outputTail(e.message),
          ),
          featureDir: featureDir,
          criterion: row.traces,
        );
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
      } finally {
        // Issue #1590: the heartbeat dies the moment the step completes
        // (or the run stops) — no elapsed lines AFTER the completion line.
        heartbeat?.cancel();
      }

      print('[run] ${row.id} $step -> ${result.outcome}$progressSuffix');
      _emitStep(row.id, step, result.outcome, exitCode: result.exitCode);

      // Issue #1308: the gen child's guard-only warning is impossible to
      // miss in the run output — the run captures the gen child's stdout
      // and a successful gen prints none of it, so the warning the writer
      // emitted would be invisible here without the forward. The token
      // keeps the scan surgical (issue #1518: the remedy line is the one
      // that immediately follows the token line — the branched wording is
      // dynamic, so the token is the only stable key).
      if (step == 'gen' && result.success) {
        _forwardGuardOnlyWarning(result.output);
      }

      // Issue #1652: a make that green-applied just certified the current
      // tree with its live post-generation evidence — record the
      // post-state so the refactor spawn right after inherits it instead
      // of re-running the full suite + registry over an untouched tree.
      // The #741 already-green skip (`skipped`) certifies no new tree
      // state and deliberately writes nothing: the standing record still
      // describes the certified tree.
      if (step == 'make' && result.outcome == 'green' && recordMakePostState) {
        await _recordMakePostState(
          behaviorId: row.id,
          exitCode: result.exitCode,
          rows: rows,
          state: updated,
          projectRoot: projectRoot,
          featureDir: featureDir,
          suiteBaselinePath: suiteBaselinePath,
        );
      }

      if (!result.success) {
        // Bug #986: `skipped` — make's issue #694 skip transition (the
        // target test already passes, generation skipped by design) — is a
        // TERMINAL make success, never a step failure. Issue #1331:
        // `adopted` — the #1331 re-drive transition (the last reset
        // tombstone invalidated the surviving certification, make adopted
        // the passing subject) — is the same terminal success. StepRunner
        // grades the exit-0 skip/adopt as success; this mapping closes the
        // fall-through for a token whose exit code disagrees (binary
        // skew, or the #657/#694-era drift contract where the
        // already-green report exited non-zero): make's outcome token is
        // the step's own terminal classification, and halting the feature
        // on an already-green behavior is the #693/#694 deadlock family.
        // Record the green evidence when make's write did not land
        // (idempotent — never a duplicate, the #693 driver-recorded
        // pattern), advance the behavior GREEN, and let refactor proceed
        // as usual.
        if (step == 'make' &&
            (result.outcome == 'skipped' ||
                result.outcome == 'adopted' ||
                result.outcome == 'adopted-placeholder' ||
                result.outcome == 'adopted-interrupted')) {
          final adopted = result.outcome == 'adopted';
          final placeholderReDrive = result.outcome == 'adopted-placeholder';
          final adoptedInterrupted = result.outcome == 'adopted-interrupted';
          if (!await _hasEvidence(evidence.greenEvidence, row.id)) {
            await CycleLog(featureDir).append(
              CycleLogEntry(
                behaviorId: row.id,
                kind: CycleEntryKind.green,
                runnerCommand: 'zfa tdd make ${row.id} (${result.outcome})',
                exitCode: result.exitCode,
                capturedOutput: adopted
                    ? 'adopted — the target test already passes against the '
                          'on-disk subject and the last reset tombstone '
                          'invalidated the surviving certification (issue '
                          '#1331); green evidence recorded by the run '
                          'driver (bug #986) because make did not write it. '
                          'Exit code ${result.exitCode} disagrees with the '
                          'outcome token; the token is the terminal '
                          'classification.\n'
                          '${result.output.split('\n').take(2).join('\n')}'
                    : adoptedInterrupted
                    ? 'adopted-interrupted — the target test already passes '
                          'against the subject the previous make mutated '
                          'before it died mid-flight; the write-ahead '
                          'interrupt marker legitimized the adoption '
                          '(issue #1398); green evidence recorded by the run '
                          'driver (bug #986) because make did not write it. '
                          'Exit code ${result.exitCode} disagrees with the '
                          'outcome token; the token is the terminal '
                          'classification.\n'
                          '${result.output.split('\n').take(2).join('\n')}'
                    : placeholderReDrive
                    ? 'adopted-placeholder — the target test already passes '
                          'and the tombstoned acceptance re-drive re-entered '
                          'the acceptance pipeline at compose/make phase-2 '
                          '(issue #1345); green evidence recorded by the run '
                          'driver (bug #986) because make did not write it. '
                          'Exit code ${result.exitCode} disagrees with the '
                          'outcome token; the token is the terminal '
                          'classification.\n'
                          '${result.output.split('\n').take(2).join('\n')}'
                    : 'skipped — the target test already passes (issue #694 '
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
          print(
            '[run] ${row.id} make -> green (${result.outcome})$progressSuffix',
          );
          _emitStep(
            row.id,
            'make',
            adopted
                ? 'adopted'
                : placeholderReDrive
                ? 'adopted-placeholder'
                : adoptedInterrupted
                ? 'adopted-interrupted'
                : 'green',
            exitCode: result.exitCode,
          );
          if (result.exitCode != 0) {
            print(
              adopted
                  ? '   exit code ${result.exitCode} disagrees with '
                        'outcome=adopted — the token is the terminal #1331 '
                        'adopted re-drive transition; advancing.'
                  : adoptedInterrupted
                  ? '   exit code ${result.exitCode} disagrees with '
                        'outcome=adopted-interrupted — the token is the '
                        'terminal #1398 crash-recovery adoption transition; '
                        'advancing.'
                  : placeholderReDrive
                  ? '   exit code ${result.exitCode} disagrees with '
                        'outcome=adopted-placeholder — the token is the '
                        'terminal #1345 compose re-entry transition; '
                        'advancing.'
                  : '   exit code ${result.exitCode} disagrees with '
                        'outcome=skipped — the token is the terminal skip '
                        'transition (issue #694); advancing (bug #986).',
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
          _emitStep(row.id, 'make', 'deferred');
          return (state: updated, stop: null, refactorBlocked: false);
        }
        if (step == 'verify-red' && result.outcome == 'unexpected-green') {
          // Issue #1544 (review fix): a blocked contract that unblocks via
          // unexpected-green keeps its persisted BLOCKED state (the
          // advance below is a no-op for blocked), which would make the
          // phase-2a guard skip the make this drive just deferred. Record
          // the lifted block so phase 2a re-attempts that make like every
          // other deferred behavior.
          if (state == BehaviorState.blocked) unblockedThisRun?.add(row.id);
          updated = updated.advance(row.id, state);
          await store.save(updated, activeBehaviorIds: activeIds);
          await tx.clear();
          sawUnexpectedGreen = true;
          print('[run] ${row.id} verify-red -> skipped (already green)');
          _emitStep(row.id, 'verify-red', 'skipped');
          continue;
        }
        if (step == 'refactor' && result.outcome == 'not-green') {
          updated = updated.advance(row.id, state);
          await store.save(updated, activeBehaviorIds: activeIds);
          await tx.clear();
          if (deferralAllowed) {
            print('[run] ${row.id} refactor -> deferred (phase 2)');
            _emitStep(row.id, 'refactor', 'deferred');
            print(
              '   preflight refused (suite not green) — the deferred '
              'refactor re-runs in the phase-2 refactor pass',
            );
            return (state: updated, stop: null, refactorBlocked: false);
          }
          print('[run] ${row.id} refactor -> skipped (suite not green)');
          _emitStep(row.id, 'refactor', 'skipped');
          _printOutputExcerpt(result.output);
          return (state: updated, stop: null, refactorBlocked: true);
        }
        // Issue #992: a widget-lane gen refusal (#938 skin gate) is
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
          skippedWidgets[row.id] = 'zuraffa_ui not declared (issue #938)';
          print(
            '[run] ${row.id} gen -> skipped-widget '
            '(--skip-widget; zuraffa_ui not declared, issue #938)',
          );
          return (state: updated, stop: null, refactorBlocked: false);
        }
        // Issue #1007: a CONTRACT behavior whose verify-red reported the
        // `blocked` verdict is BLOCKED — distinct from RED. RED is the
        // honest first state of a unit/widget behavior (the loop EXPECTS
        // the failing test and proceeds to make/GREEN); a failing
        // CONTRACT test means the declared contract is unsatisfied, so
        // the behavior is parked at BLOCKED and make/refactor NEVER spawn
        // for it (the receipt lives at
        // .zfa/receipts/contract-blocked.<id>.json — verify-red wrote
        // it). Resume re-enters at verify-red: once the implementation
        // satisfies the contract, the verdict flips (the unexpected-green
        // skip transitions the behavior on) and the cycle proceeds.
        // Restored verbatim from the pre-split single-run driver — the
        // spec 1008 two-cycle refactor (issue #1092) dropped this arm and
        // the blocked verdict degraded into a generic result=stopped
        // (bug #1107).
        //
        // Issue #1544: blocked is a PER-BEHAVIOR verdict, not a run-fatal
        // stop. The pre-#1544 arm TERMINATED the lane at the first
        // blocked contract — every resume re-attempted the SAME
        // behavior's verify-red and the remaining contracts were
        // unreachable, each attempt costing a full refactor pass for
        // zero progress. The behavior is parked at BLOCKED (unchanged
        // issue #1007 semantics) and the loop CONTINUES with the
        // remaining behaviors, each driving to its own verdict; the run
        // stops with `result=blocked blocked=N` at the end of the pass,
        // where the resume hint lives.
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
          // Issue #1589: name the hand surface — where the declared
          // contract is implemented (the seam) and the command that binds
          // it (wire), so the parked verdict is actionable as written.
          // Issue #1625: the seam is the subject stub (the implementation
          // seam, not the generated test) and the wire example only prints
          // when the traced entity exists. Messaging only: the verdict,
          // the state advance and the park semantics are the #1007/#1544
          // ones.
          final parkedSeam = HandSurface.seamPathFor(
            projectRoot: projectRoot,
            feature: feature,
            behaviorId: row.id,
          );
          print(
            '   ${HandSurface.hintLine(behaviorId: row.id, seamPath: parkedSeam, contract: row.traces, projectRoot: projectRoot)}',
          );
          print(
            '   parked — the run continues with the remaining behaviors '
            '(issue #1544)',
          );
          // Review fix: the file is existence-gated (the printed
          // `parkedSeam` above stays the display path) and the tolerance is
          // pinned to the failure the verify-red transcript just attested.
          _addParkedSeam(
            behaviorId: row.id,
            projectRoot: projectRoot,
            feature: feature,
            attestedOutput: result.output,
          );
          return (state: updated, stop: null, refactorBlocked: false);
        }
        // Issue #1308: the vacuous-green make stop is not a dead end —
        // the driver names the remedy. The generated test's
        // [vacuousGuardMarker] distinguishes the two classes: the traced
        // entity/void path (marker present) IS the DESIGNED hand-delta
        // seam — one explicit, named hand step `stopped_at=<id>:hand`
        // replacing the generic make stop; the fallback-routed path
        // (marker absent) gets the exact `traces:` remedy (the summary
        // machine contract keeps `stopped_at=<id>:make`). Messaging only:
        // the state advance and the honest-stop semantics are the generic
        // ones (issue #1259's refusal stands).
        // Issue #1373: a not-certified-red make stop on a SCAFFOLDED
        // widget test (the `zfa:tdd: scaffolded` marker, issue #912
        // defect 3) is the designed author hand-off, not a dead end —
        // the placeholder finder trivially passes, so verify-red
        // classified it unexpected-green and make found no certified
        // red. Name the hand step and the exact --author remedy.
        if (step == 'make' && result.outcome == 'not-certified-red') {
          final testPath = _existingGeneratedTestPath(
            projectRoot: projectRoot,
            feature: feature,
            behaviorId: row.id,
          );
          if (_testCarriesScaffoldedMarker(testPath)) {
            updated = updated.advance(row.id, state);
            await store.save(updated, activeBehaviorIds: activeIds);
            await tx.clear();
            print(
              'zfa tdd $label: step failed — behavior=${row.id} step=$step '
              'outcome=${result.outcome}',
            );
            _printOutputExcerpt(result.output);
            print(
              '   hand step: ${row.id}:hand — this is a SCAFFOLDED widget '
              'test (the $scaffoldedMarker marker, issue #912 defect 3): '
              'the placeholder finder passes trivially, so verify-red '
              'saw unexpected-green and make found no certified red.',
            );
            print(
              '   Author concrete scenario finders in the test, then '
              'run: `zfa tdd make ${row.id} --author --finders-file '
              '<finders.txt>` (issue #1258), then re-run '
              '`zfa tdd $label $feature`.',
            );
            return (
              state: updated,
              stop: (
                result: 'stopped',
                stoppedAt: '${row.id}:hand',
                exitCode: _exitStopped,
                message: null,
              ),
              refactorBlocked: false,
            );
          }
          // Issue #1411: the hand-first born-green catch-22 — the
          // subject was hand-implemented before the pipeline's first
          // red certification (the designed hand-step flow, guide §5a
          // item 1), so verify-red graded the already-passing test
          // unexpected-green (no evidence) and make refused
          // not-certified-red. The generic stop is a dead end: no
          // supported ordering existed. The arm keys on THIS drive's
          // unexpected-green (the passing-test signature — an in-order
          // red-first cycle never produces not-certified-red after one,
          // so the red-first messaging stands untouched) + the
          // generated test's content state, which picks the hand-off
          // vocabulary: attested → the exact `--born-green` command;
          // un-attested → the exact header line AND the command; the
          // marker still present (the partial hand step) → the
          // completion + the command. Messaging only: the state advance
          // and the honest-stop semantics are the generic ones; the
          // recovery is make's own born-green transition, which
          // re-verifies the whole gate honestly.
          if (sawUnexpectedGreen && testPath != null) {
            final bornContent = _readTestContentFailOpen(testPath);
            if (bornContent != null) {
              final attested = contentCarriesHandStepHeader(
                bornContent,
                row.id,
              );
              final markerPresent = contentCarriesVacuousGuardMarker(
                bornContent,
              );
              final relPath = p
                  .relative(testPath, from: projectRoot)
                  .replaceAll('\\', '/');
              updated = updated.advance(row.id, state);
              await store.save(updated, activeBehaviorIds: activeIds);
              await tx.clear();
              print(
                'zfa tdd $label: step failed — behavior=${row.id} step=$step '
                'outcome=${result.outcome}',
              );
              _printOutputExcerpt(result.output);
              if (attested) {
                print(
                  '   hand step: ${row.id}:hand — the test carries the '
                  '${row.id}:hand attestation and the vacuous-guard marker '
                  'is absent: the designed hand step was completed BEFORE '
                  'the first red certification (issue #1411) — verify-red '
                  'saw the test already green (skipped) and make found no '
                  'certified red (the catch-22).',
                );
                print(
                  '   Certify the born-green hand transition: '
                  '`zfa tdd make ${row.id} --born-green` — then re-run '
                  '`zfa tdd $label $feature`.',
                );
              } else if (markerPresent) {
                print(
                  '   hand step: ${row.id}:hand — the subject was '
                  'hand-implemented before the first red certification '
                  '(the hand-first ordering, issue #1411): the guard-only '
                  'test passes, verify-red saw unexpected-green, and make '
                  'found no certified red.',
                );
                print(
                  '   Complete the hand step — replace the guard with an '
                  'assertion on the observable outcome in $relPath, remove '
                  'the $vacuousGuardMarker marker, add the attestation '
                  'header (${handStepHeader(row.id)}) — then run '
                  '`zfa tdd make ${row.id} --born-green`, and re-run '
                  '`zfa tdd $label $feature`.',
                );
              } else {
                print(
                  '   hand step: ${row.id}:hand — the subject was '
                  'hand-implemented before the first red certification '
                  '(the hand-first ordering, issue #1411): verify-red saw '
                  'the test already green (skipped) and make found no '
                  'certified red — the catch-22 with no red-first '
                  'recovery.',
                );
                print(
                  '   If the designed hand step is complete, add the '
                  'attestation header line to $relPath:',
                );
                print('     ${handStepHeader(row.id)}');
                print(
                  '   Then certify the born-green hand transition: '
                  '`zfa tdd make ${row.id} --born-green` — and re-run '
                  '`zfa tdd $label $feature`.',
                );
              }
              return (
                state: updated,
                stop: (
                  result: 'stopped',
                  stoppedAt: '${row.id}:hand',
                  exitCode: _exitStopped,
                  message: null,
                ),
                refactorBlocked: false,
              );
            }
          }
        }
        if (step == 'make' && result.outcome == 'vacuous-green') {
          final testPath = _existingGeneratedTestPath(
            projectRoot: projectRoot,
            feature: feature,
            behaviorId: row.id,
          );
          updated = updated.advance(row.id, state);
          await store.save(updated, activeBehaviorIds: activeIds);
          await tx.clear();
          print(
            'zfa tdd $label: step failed — behavior=${row.id} step=$step '
            'outcome=${result.outcome}',
          );
          _printOutputExcerpt(result.output);
          if (_testCarriesVacuousGuardMarker(testPath)) {
            final relPath = p.relative(testPath!, from: projectRoot);
            print(
              '   the traced contract\'s return is void/an entity — the '
              '$vacuousGuardMarker marker IS the designed hand-delta seam '
              '(issue #1308): the assertion set is the UnimplementedError '
              'guard only, which make refuses vacuous-green (issue #1259).',
            );
            print(
              '   hand step: ${row.id}:hand — write an assertion on the '
              'observable outcome in $relPath (replace the vacuous-guard '
              'guard, remove the marker), then re-run '
              '`zfa tdd $label $feature`.',
            );
            return (
              state: updated,
              stop: (
                result: 'stopped',
                stoppedAt: '${row.id}:hand',
                exitCode: _exitStopped,
                message: null,
              ),
              refactorBlocked: false,
            );
          }
          // Issue #1483: name the seam that EXISTS for the feature shape
          // the message is talking to — the lane plan's traces cell only
          // when the lane plan pair is actually on disk; the legacy
          // single-file feature (no `## Lanes`, no plan pair) hand-edits
          // the TEST LIST's traces cell instead (04-ENGINE.md does not
          // exist there and never will). The full path is printed (the
          // feature dir is not obvious from a bare filename). Messaging
          // only — the detection, the stop and the loop are untouched.
          //
          // Issue #1626: the traces/re-plan/re-gen remedy above is
          // UNIT/fallback vocabulary — it WORKS there, and those rows keep
          // it. An ACCEPTANCE row cannot consume it: the lane ignores the
          // contract shape by design (issue #1512), so re-plan/re-gen can
          // never add a real acceptance assertion and the author who
          // follows the printed advice loops forever. The acceptance arm
          // names the HAND STEP instead — the outcome assertion OUTSIDE
          // the capture, the scenario runner implemented in the subject,
          // the attestation header, `--born-green` — with BOTH file paths
          // (test + subject, project-relative posix). Messaging only: the
          // stop stays `stopped_at=<id>:make` (the honest fallback-routed
          // class, #1512) and the state advance is untouched. The wording
          // is single-sourced in `acceptanceVacuousHandStepRemedyFor` so
          // this stop and make's own refusal cannot drift.
          //
          // Issue #1626 (review): BOTH paths come from the same rule —
          // `acceptanceHandStepPathsFor`, shared with make's refusal. The
          // artifact registry record is the single path contract (the
          // generated TEST is read from the record exactly like the
          // SUBJECT, issue #1397 anchoring included): probing the disk
          // alone made the remedy name a synthetic conventional test path
          // for a row whose registered `testPath` sits elsewhere, and
          // editing that file leaves the registered artifact unchanged —
          // the same "which file do I edit?" failure this issue fixes on
          // the subject side. The disk probe stays as the registry-less
          // fallback (the legacy flat layout).
          if (row.kind == BehaviorKind.acceptance) {
            final record = await registry.findRecord(row.id);
            final handStepPaths = acceptanceHandStepPathsFor(
              behaviorId: row.id,
              projectRoot: projectRoot,
              feature: feature,
              knownTestPath: record?.testPath ?? testPath,
              knownSubjectPath: record?.subjectPath,
            );
            print(
              '   the generated test is the ACCEPTANCE guard-only fallback '
              '[$acceptanceFallbackGuardToken] — the acceptance lane '
              'ignores the contract shape (issue #1512), so re-plan/re-gen '
              'can never add a real acceptance assertion and make refuses '
              'it vacuous-green (issue #1488).',
            );
            print(
              '   --> fix: ${acceptanceVacuousHandStepRemedyFor(behaviorId: row.id, testPath: handStepPaths.testPath, subjectPath: handStepPaths.subjectPath)}',
            );
            return (
              state: updated,
              stop: (
                result: 'stopped',
                stoppedAt: '${row.id}:make',
                exitCode: _exitStopped,
                message: null,
              ),
              refactorBlocked: false,
            );
          }
          // Issue #1651: the PLACEHOLDER arm — the fallback vocabulary
          // above says "GUARD-ONLY", which is false for the dummy class:
          // the test carries a real expect (`isA<int>()`), it just
          // asserts no VALUE, so the #1517 func-scaffold dummy
          // (`return 0;`) satisfies it. When the registry record's
          // subject body is the scalar dummy and the test is type-only,
          // the stop names the placeholder remedy (make's refusal line,
          // single-sourced) while the machine contract below is
          // unchanged. Fail-open on any missing artifact — the fallback
          // arm keeps serving shapes this probe cannot classify.
          if (row.kind == BehaviorKind.unit) {
            final placeholderRecord = await registry.findRecord(row.id);
            final dummyDetected = await _placeholderGreenDetected(
              projectRoot: projectRoot,
              featureDir: featureDir,
              featureName: feature,
              record: placeholderRecord,
            );
            if (dummyDetected) {
              print(
                '   the generated test asserts NO VALUE — its matcher set '
                'is type-only, and the paired subject body is a scalar '
                'dummy that satisfies every type check (issue #1651). '
                'make refuses it vacuous-green.',
              );
              print(
                '   --> fix: ${scalarDummyGreenRemedy(behaviorId: row.id, testPath: placeholderRecord!.testPath, subjectPath: placeholderRecord.subjectPath)}',
              );
              return (
                state: updated,
                stop: (
                  result: 'stopped',
                  stoppedAt: '${row.id}:make',
                  exitCode: _exitStopped,
                  message: null,
                ),
                refactorBlocked: false,
              );
            }
          }
          // Issue #1420: the "no traces" claim is a FACT about the traces
          // cell, not a constant — probe the declared routing (the same
          // single-sourced resolution gen consumes) before printing it. A
          // traces cell that resolves declared contract row(s) — the
          // issue's class: a Key Entity row passed through row-only — makes
          // the fallback wording FALSE (the trace exists) and its remedy
          // IMPOSSIBLE (entity rows declare no methods to qualify). The
          // declared-trace arm names the declared class and the re-gen /
          // hand-step remedy instead; the machine contract is untouched
          // (the stop stays `stopped_at=<id>:make` — marker presence, not
          // the traces cell, is the `:hand` discriminator).
          //
          // Fail-open: an unreadable/missing artifact resolves to nothing
          // declared and keeps the exact legacy wording — the probe must
          // never turn a messaging fix into a new refusal surface.
          String? declaredTraceContext;
          try {
            final decision = await DeclaredRouting.declaredRoutingFor(
              cwd: projectRoot,
              featureName: feature,
              featureDir: featureDir,
              behaviorId: row.id,
            );
            if (decision != null) {
              // Same predicate gen's synthesis gates on
              // (`_declaredSignatureForGen`: signature-bearing decisions
              // are the contract lane, entity rows are the row-only
              // entityPipeline class) so the two single-sourced callers
              // cannot drift if a future surface ever carries an entity
              // name.
              final entity = decision.entityName;
              declaredTraceContext =
                  decision.signature == null &&
                      decision.surface == GenerationSurface.entityPipeline &&
                      entity != null &&
                      entity.isNotEmpty
                  ? 'the traces cell resolves the declared entity row '
                        '`$entity` (surface: entity pipeline)'
                  : 'the traces cell resolves a declared contract row';
            }
          } on StateError catch (e) {
            // A MALFORMED declaration must NOT land on the legacy wording:
            // "no traces: to a declared contract row" + "add traces:" is
            // precisely the false/impossible advice for the one class the
            // declaration refusal names (the #920 regression class —
            // declared_routing.dart's contract). Surface the refusal in
            // gen's `declaration refused — <message>` shape instead. This
            // whole block is an already-terminal messaging path (the
            // vacuous-green stop has happened), so printing the fix line
            // inside the same stop stays fail-open mechanically — no new
            // refusal surface — while the null/unreadable cases above keep
            // the exact legacy wording.
            print(
              '   the generated test is GUARD-ONLY '
              '[$vacuousGuardWarningToken] — the declared-intent '
              'artifacts for "${row.id}" are malformed, so the traces '
              'cell cannot be resolved honestly.',
            );
            print('   --> fix: declaration refused — ${e.message}');
            return (
              state: updated,
              stop: (
                result: 'stopped',
                stoppedAt: '${row.id}:make',
                exitCode: _exitStopped,
                message: null,
              ),
              refactorBlocked: false,
            );
          }
          if (declaredTraceContext != null) {
            final declaredTestPath =
                _existingGeneratedTestPath(
                  projectRoot: projectRoot,
                  feature: feature,
                  behaviorId: row.id,
                ) ??
                p.join(
                  'test',
                  'tdd',
                  feature,
                  '${_snakeCase(row.id)}_test.dart',
                );
            print(
              '   the generated test is GUARD-ONLY '
              '[$vacuousGuardWarningToken] — $declaredTraceContext, but the '
              'pair predates gen\'s declared-trace engagement, so gen could '
              'not derive a real outcome assertion and make refuses it '
              'vacuous-green (issue #1420, #1259).',
            );
            print(
              '   --> fix: ${vacuousGuardDeclaredTraceRemedyFor(
                behaviorId: row.id,
                testPath: p.relative(declaredTestPath, from: projectRoot).replaceAll(r'\', '/'),
              )}',
            );
            return (
              state: updated,
              stop: (
                result: 'stopped',
                stoppedAt: '${row.id}:make',
                exitCode: _exitStopped,
                message: null,
              ),
              refactorBlocked: false,
            );
          }
          print(
            '   the generated test is GUARD-ONLY [$vacuousGuardWarningToken] '
            '— the behavior is fallback-routed (no traces: to a declared '
            'contract row), so gen could not derive a real outcome '
            'assertion and make refuses it vacuous-green (issue #1259, '
            '#1308).',
          );
          print(
            '   --> fix: ${_vacuousFallbackRemedy(projectRoot: projectRoot, featureDir: featureDir)}',
          );
          return (
            state: updated,
            stop: (
              result: 'stopped',
              stoppedAt: '${row.id}:make',
              exitCode: _exitStopped,
              message: null,
            ),
            refactorBlocked: false,
          );
        }
        // Issue #1323 (spec 991 FR-006): the `hand-delta-required` make
        // stop is not a dead end — the driver names the remedy with the
        // SAME messaging parity the #1308 vacuous-green arm established.
        // The generated test's `_argN()` placeholder helper is the
        // DESIGNED hand-delta seam for a non-scalar declared param; make
        // already diagnosed it (two-signal: marker + transcript token)
        // and stopped naming the exact edit. One explicit, named hand
        // step `stopped_at=<id>:hand` replaces the generic make stop;
        // messaging only — the state advance and the honest-stop
        // semantics are the generic ones.
        if (step == 'make' && result.outcome == 'hand-delta-required') {
          final testPath = _existingGeneratedTestPath(
            projectRoot: projectRoot,
            feature: feature,
            behaviorId: row.id,
          );
          updated = updated.advance(row.id, state);
          await store.save(updated, activeBehaviorIds: activeIds);
          await tx.clear();
          print(
            'zfa tdd $label: step failed — behavior=${row.id} step=$step '
            'outcome=${result.outcome}',
          );
          _printOutputExcerpt(result.output);
          // The declared type and the placeholder index the remedy names
          // come from the generated test's marker helper (the
          // content-only probe — the make child already verified the
          // transcript signal). Unreadable or hand-edited content
          // degrades to the generic noun and index 0; the make stop's
          // own remedy line (in the excerpt above) always carries the
          // exact type.
          final hit = _testArgPlaceholderHit(testPath);
          final relPath = testPath != null
              ? p.relative(testPath, from: projectRoot).replaceAll('\\', '/')
              : p.join(
                  'test',
                  'tdd',
                  feature,
                  '${_snakeCase(row.id)}_test.dart',
                );
          print(
            '   the generated test\'s _argN() placeholder IS the designed '
            'hand-delta seam for a non-scalar declared param '
            '(issue #1323): the remedy requires HAND-editing the '
            'generated test, which make itself never does.',
          );
          print(
            '   hand step: ${row.id}:hand — ${argPlaceholderRemedy(index: hit?.index ?? 0, testPath: relPath, declaredType: hit?.declaredType ?? 'value', behaviorId: row.id)}.',
          );
          return (
            state: updated,
            stop: (
              result: 'stopped',
              stoppedAt: '${row.id}:hand',
              exitCode: _exitStopped,
              message: null,
            ),
            refactorBlocked: false,
          );
        }
        // Issue #1324: verify-red unexpected-green followed by make
        // subject-drift — or a subject-drift on a behavior whose
        // cycle-log already carries green evidence — is the
        // stale-artifacts contradiction (a freshly regenerated test
        // against an already-implemented subject). The generic
        // "fix the failing step" hint wedges the feature here: re-driving
        // gen clobbers the certified pair and make refuses the drift, so
        // the run names the contradiction and prescribes the one
        // recovery that works, matching the doctor's prescription.
        if (step == 'make' &&
            result.outcome == 'subject-drift' &&
            (sawUnexpectedGreen || greenEvidenceIds.contains(row.id))) {
          await _recordStepFailure(
            _StepFailure(
              behaviorId: row.id,
              step: step,
              outcome: result.outcome,
              exitCode: result.exitCode,
              command: result.command,
              outputTail: _outputTail(result.output),
            ),
            featureDir: featureDir,
            criterion: row.traces,
          );
          updated = updated.advance(row.id, state);
          await store.save(updated, activeBehaviorIds: activeIds);
          await tx.clear();
          print(
            'zfa tdd $label: step failed — behavior=${row.id} step=$step '
            'outcome=${result.outcome} (stale-artifacts)',
          );
          _printOutputExcerpt(result.output);
          print(
            '   the contradiction: "${row.id}" carries green evidence in '
            'tdd/cycle-log.md for the current artifact generation, but the '
            'on-disk pair no longer matches it — the test was regenerated '
            'over the certification (guard-only against an implemented '
            'subject), or the subject was rewritten to a placeholder and '
            'make failed before re-certifying (issue #1324/#1036). '
            'Re-driving gen clobbers the certified pair and make refuses '
            'the drift, so this state cannot resume through the loop.',
          );
          print(
            '   --> fix: zfa tdd reset $feature — drop the stale registry '
            'records and owned artifacts, then re-run '
            '`zfa tdd $label $feature` in one uninterrupted pass; '
            're-apply any test-side hand-deltas when the run stops for '
            'them.',
          );
          return (
            state: updated,
            stop: (
              result: 'stale-artifacts',
              stoppedAt: '${row.id}:make',
              exitCode: _exitStopped,
              message: null,
            ),
            refactorBlocked: false,
          );
        }
        // Issue #1568: a make failure on a behavior the planner already
        // declared HAND-STEP (the entity-return seam forecast, SPEC
        // 1489) is the DESIGNED non-green state, not a generation
        // defect: the subject is a gen contract-derived stub (issue
        // #1259) with no mechanical implementation surface, so the
        // target test failing "after generation" is the honest red the
        // forecast pre-declared. Grading it generation-error stopped
        // the whole run at the first hand-step and left every
        // mechanical behavior behind it unreachable (the #1544
        // hard-stop family). The behavior keeps its honest red, the
        // pass continues with the remaining behaviors, and the
        // end-of-pass summary names the hand-steps (`hand_steps=N`,
        // `stopped_at=<id>:hand`). Two signals must agree (FR-001):
        // the seam forecast contains the behavior AND make's own
        // transcript carries the still-failing-target-test shape — a
        // real generation bug keeps the honest generic stop.
        //
        // Review fix: the forecast is resolved HERE, on the failure
        // path, not once before the loop. Phase-0 has already created
        // the pass's declared entities by now, so a behavior whose
        // entity this same pass generated is correctly OUT of the set —
        // the pre-phase-0 read the announce prints is stale for it, and
        // the arm's premise ("no mechanical implementation surface") no
        // longer holds. Cost: one lookup per failed make, not one per
        // unit behavior.
        if (step == 'make' &&
            result.outcome == 'generation-error' &&
            result.output.contains('still fails after generation') &&
            (await _entityReturnSeamIds(
              projectRoot: projectRoot,
              featureName: feature,
              featureDir: featureDir,
              rows: rows,
            )).contains(row.id)) {
          updated = updated.advance(row.id, state);
          await store.save(updated, activeBehaviorIds: activeIds);
          await tx.clear();
          handSteps[row.id] =
              'entity-return contract subject (planner seam forecast, '
              'SPEC 1489)';
          print(
            'zfa tdd $label: step failed — behavior=${row.id} step=$step '
            'outcome=${result.outcome}',
          );
          _printOutputExcerpt(result.output);
          print(
            '   hand step: ${row.id}:hand — the planner declared this '
            'behavior hand-step (entity-return contract subject): make '
            'cannot implement it mechanically; the failing target test '
            'is the honest red (issue #1568).',
          );
          print(
            '   parked — the run continues with the remaining behaviors '
            '(issue #1568). Certify the hand implementation '
            'deliberately: implement the subject, then run '
            '`zfa tdd make ${row.id} --born-green`, and re-run '
            '`zfa tdd $label $feature`.',
          );
          return (state: updated, stop: null, refactorBlocked: false);
        }
        // Honest stop (FR-007).
        final isRunnerError = result.outcome == 'runner-error';
        // Issue #1329: the error-outcome path records the same
        // diagnostic evidence the red/green cycles record — the spawned
        // command, the exit code, and the truncated stderr/stdout tail —
        // in the append-only cycle log, and stages the detail for the
        // lane journal entry (_finish). Recording is never a gate: a
        // failed append is reported, not fatal (the receipt discipline).
        await _recordStepFailure(
          _StepFailure(
            behaviorId: row.id,
            step: step,
            outcome: result.outcome,
            exitCode: result.exitCode,
            command: result.command,
            outputTail: _outputTail(result.output),
          ),
          featureDir: featureDir,
          criterion: row.traces,
        );
        // Spec 1529 (U8/FR-1/FR-12): a make step killed at the deadline
        // leaves an INSPECTABLE receipt in the feature tdd dir — phase,
        // argv, actual elapsed, captured tail — so resume is an informed
        // decision instead of a blind re-roll. The write is best-effort:
        // a failed write is reported, never fatal (the receipt is
        // additive evidence, not a gate).
        if (step == 'make' && result.timeoutReceipt != null) {
          final outcome = await writeStepTimeoutReceiptReported(
            featureDir: featureDir,
            receipt: result.timeoutReceipt!.toReceipt(
              capturedAt: DateTime.now().toUtc().toIso8601String(),
            ),
          );
          if (outcome.written) {
            print(
              '   timeout receipt: ${p.relative(outcome.path!, from: projectRoot)} '
              '(phase=${result.timeoutReceipt!.phase.phase}, '
              'elapsed=${formatTddTimeout(result.timeoutReceipt!.elapsed)})',
            );
          } else {
            stderr.writeln(
              '   note: the timeout receipt could not be written '
              '(${outcome.error}) — the runner-error stands unchanged',
            );
          }
        }
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
      // write its evidence is a misfire (FR-003, FR-011). Issue #1542:
      // the row's kind rides along — the contract lane's red evidence is
      // defined out of existence by the #1007 BLOCKED verdict.
      final misfire = await _evidenceMisfire(
        evidence,
        step,
        row.id,
        kind: row.kind,
      );
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

  /// Issue #1588: the batch context a refactor pass hands every spawn —
  /// `--pass-batch` (the ledger opt-in) plus the lane's parked BLOCKED
  /// behavior ids as `--exempt-behaviors` (their red tests are the
  /// designed park state, #1007/#1544, and must not poison the gate the
  /// baseline cannot know about). Issue #1624: every refactor spawn —
  /// phase 1 and phase 2b — carries these args. Sorted for a stable
  /// ledger key and stable spawn argv.
  /// Issue #1652: snapshot make's certified post-state (context keys +
  /// `lib`/`test` byte digests + the honest green verdict) into
  /// `tdd/make-post-state.json`. Best-effort by contract: any failure is
  /// one warning line — a missing record costs the NEXT refactor spawn
  /// one full pipeline, never correctness (the ledger's own stance for
  /// derived data).
  Future<void> _recordMakePostState({
    required String behaviorId,
    required int exitCode,
    required List<BehaviorRow> rows,
    required RunState state,
    required String projectRoot,
    required String featureDir,
    required String? suiteBaselinePath,
  }) async {
    try {
      final suiteTemplate = await const SingleTestRunner().loadSuiteTemplate(
        workingDirectory: projectRoot,
      );
      final libNow = await TreeSnapshot.capture(
        projectRoot,
        trees: const ['lib'],
      );
      final testNow = await TreeSnapshot.capture(
        projectRoot,
        trees: const ['test'],
      );
      // The same exempt set the batch refactor args hand the spawn: the
      // currently-blocked behavior ids, canonical order.
      final blocked = _blockedIds(rows, state);
      final record = MakePostState(
        capturedAt: DateTime.now().toUtc().toIso8601String(),
        behaviorId: behaviorId,
        suite: suiteTemplate,
        baselineKey: await PassBatchLedger.baselineKeyFor(suiteBaselinePath),
        configKey: await PassBatchLedger.configKeyFor(projectRoot),
        exemptBehaviors: blocked,
        libDigest: PassBatchLedger.treeDigest(libNow),
        testDigest: PassBatchLedger.treeDigest(testNow),
        greenVerdict:
            'make $behaviorId outcome=green exit $exitCode '
            '(post-generation green evidence)',
      );
      await record.write(featureDir: featureDir);
    } catch (e) {
      print(
        'zfa tdd run: make-post-state record could not be written '
        '(issue #1652) — the next refactor pays one full pipeline: $e',
      );
    }
  }

  /// The currently-blocked behavior ids in canonical order — the exempt
  /// set shared by the make-post-state record and the refactor spawn's
  /// `--exempt-behaviors`, so both sides of the #1652 gate compute it
  /// from one place.
  List<String> _blockedIds(List<BehaviorRow> rows, RunState state) {
    return [
      for (final r in rows)
        if ((state.behaviorStates[r.id] ?? BehaviorState.pending) ==
            BehaviorState.blocked)
          r.id,
    ]..sort();
  }

  List<String> _refactorBatchArgs(List<BehaviorRow> rows, RunState state) {
    final blocked = _blockedIds(rows, state);
    return [
      '--pass-batch',
      if (blocked.isNotEmpty) ...['--exempt-behaviors', blocked.join(',')],
    ];
  }

  bool _hasRedBehavior(List<BehaviorRow> rows, RunState state) {
    for (final row in rows) {
      if ((state.behaviorStates[row.id] ?? BehaviorState.pending) ==
          BehaviorState.red) {
        return true;
      }
    }
    return false;
  }

  /// Issue #1324: the behavior ids whose LAST green evidence entry is
  /// backed by its certified test file on disk — the "current artifact
  /// generation" backing check. The green entry's `- test:` line names
  /// the registered test path it certified (absolute or project-relative,
  /// with the `::behaviorId` suffix convention); a present file means the
  /// certified pair is still the on-disk pair, so resume must not gen
  /// over it. Entries without a `- test:` line are conservatively backed
  /// (legacy tolerance — the same fail-open rule
  /// [CycleEvidence.orphanedGreenEvidence] applies), so a behavior is
  /// only re-driven from gen when its certified test file is provably
  /// gone (the #1264 orphaned class, whose recovery re-enters at gen).
  Future<Set<String>> _certifiedGreenBacked(
    CycleEvidence evidence,
    String projectRoot,
  ) async {
    final lastGreen = <String, ParsedCycleEntry>{};
    for (final entry in await evidence.entries()) {
      if (entry.kind != 'green') continue;
      lastGreen[entry.behaviorId] = entry;
    }
    final backed = <String>{};
    for (final MapEntry(key: behaviorId, value: entry) in lastGreen.entries) {
      final test = entry.test;
      if (test == null || test.isEmpty) {
        backed.add(behaviorId);
        continue;
      }
      final cleanTest = test.contains('::') ? test.split('::').first : test;
      final resolved = p.isAbsolute(cleanTest)
          ? p.normalize(cleanTest)
          : p.normalize(p.join(projectRoot, cleanTest));
      if (File(resolved).existsSync()) backed.add(behaviorId);
    }
    return backed;
  }

  /// Issue #1592: the behavior ids whose LAST green evidence entry
  /// certifies the born-green hand transition — the entry's `- evidence:`
  /// field carries the shared journal marker the `make --born-green`
  /// transition writes (`bornGreenEvidenceMarker`, issue #1411), anchored
  /// to the note's start (the review #1566 probe) — AND whose
  /// certification binds the current subject. The append-order last-green
  /// rule lives in [CycleEvidence.bornGreenCertifiedEntries] (review
  /// #1608: one home); this pass adds the binding the #1592 refactor
  /// re-entry requires, so the run driver keys the window on the
  /// certification the #1542 refactor evidence check accepts, restricted
  /// to the entries whose subject is still the one the transition
  /// certified.
  Future<Set<String>> _bornGreenCertifiedBehaviors(
    CycleEvidence evidence, {
    required ArtifactRegistry registry,
    required String projectRoot,
  }) async {
    final certified = <String>{};
    for (final MapEntry(key: behaviorId, value: entry)
        in (await evidence.bornGreenCertifiedEntries()).entries) {
      if (await _bornGreenSubjectBinds(
        entry,
        behaviorId: behaviorId,
        registry: registry,
        projectRoot: projectRoot,
      )) {
        certified.add(behaviorId);
      }
    }
    return certified;
  }

  /// Review #1608 (CodeRabbit): whether the born-green certification
  /// still binds the CURRENT subject — the refactor re-entry is a
  /// short-cut over the honest verify-red -> make re-drive, so the
  /// certification must pin the subject shape it exercised (the same
  /// "the subject the certification ran against is byte-identical" rule
  /// the make dedup requires, issue #1587, and the make drift check
  /// applies, issue #1036). The recorded `- subject-hash:` (a 64-hex
  /// sha256 — [ParsedCycleEntry.subjectHash] only parses that shape) must
  /// equal the registered subject file's current sha256; a hashless or
  /// mismatched entry refuses the short-cut and the behavior keeps the
  /// pre-#1592 window (verify-red re-grades, the flagless make refuses
  /// `not-certified-red`, and the #1411 arm re-prescribes the
  /// `--born-green` command, whose re-run re-certifies honestly).
  Future<bool> _bornGreenSubjectBinds(
    ParsedCycleEntry entry, {
    required String behaviorId,
    required ArtifactRegistry registry,
    required String projectRoot,
  }) async {
    final certified = entry.subjectHash;
    if (certified == null) return false;
    final record = await registry.findRecord(behaviorId);
    if (record == null) return false;
    final subjectPath = normalizeArtifactPath(projectRoot, record.subjectPath);
    final subjectFile = File(subjectPath);
    if (!await subjectFile.exists()) return false;
    return sha256.convert(await subjectFile.readAsBytes()).toString() ==
        certified;
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

  /// Issue #1589 (review fix): record [behaviorId]'s parked verdict for the
  /// phase-2 refactor gate — the seam file ONLY when it exists on disk (the
  /// `--parked-seam` handoff must never name a file the driver did not see
  /// parked), plus the failing-test identifiers the verdict RECORDED, so
  /// the gate pins its tolerance to the known red instead of exempting the
  /// whole seam file. [attestedOutput] overrides the verdict receipt's
  /// transcript for a parking this run observed directly (the verify-red
  /// step's own output); otherwise the persisted receipt's
  /// `output_excerpt` is used. An unparseable transcript contributes no
  /// identifier — the seam keeps the coarse file-level tolerance, which is
  /// all a caller could attest.
  void _addParkedSeam({
    required String behaviorId,
    required String projectRoot,
    required String feature,
    String? attestedOutput,
  }) {
    final seamPath = _existingSeamRelativePath(
      behaviorId,
      projectRoot: projectRoot,
      feature: feature,
    );
    if (seamPath != null) _parkedSeamPaths.add(seamPath);
    final output =
        attestedOutput ??
        ContractBlockedReceipt.fromFile(
          ContractBlockedReceiptStore(
            projectRoot: projectRoot,
          ).pathFor(behaviorId),
        )?.outputExcerpt;
    if (output != null && output.trim().isNotEmpty) {
      _parkedFailureIdentifiers.addAll(parseFailingTestNames(output));
    }
  }

  /// Issue #1589 (review fix): the project-relative POSIX path of
  /// [behaviorId]'s generated contract test, or null when no seam file is
  /// on disk — the existence-gated counterpart of
  /// [HandSurface.seamPathFor]'s display-only canonical fallback, resolved
  /// through the same two candidates.
  String? _existingSeamRelativePath(
    String behaviorId, {
    required String projectRoot,
    required String feature,
  }) {
    final existing = _existingGeneratedTestPath(
      projectRoot: projectRoot,
      feature: feature,
      behaviorId: behaviorId,
    );
    if (existing == null) return null;
    return p.relative(existing, from: projectRoot).replaceAll(r'\', '/');
  }

  /// The generated unit test file for [behaviorId] when one exists on
  /// disk — the #827 namespaced layout first, the legacy flat fallback
  /// second (the same resolution `_hasPendingWithArtifacts` uses). The
  /// file is the single source of truth the #1308 vacuous-green stop arm
  /// keys on: the traced entity/void path's test carries the
  /// [vacuousGuardMarker], the fallback path's does not.
  String? _existingGeneratedTestPath({
    required String projectRoot,
    required String feature,
    required String behaviorId,
  }) {
    final snakeId = _snakeCase(behaviorId);
    final candidates = [
      p.join(projectRoot, 'test', 'tdd', feature, '${snakeId}_test.dart'),
      p.join(projectRoot, 'test', 'tdd', '${snakeId}_test.dart'),
    ];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }

  /// Issue #1544: the `blocked_at` timestamp to skip a still-blocked
  /// contract behavior with, when NOTHING watched changed since the
  /// behavior's blocked verdict — the verdict's receipt exists AND the
  /// seam (generated contract test) file, the contract row
  /// (`tdd/test-list.md`) and the implementation (`lib/`) are all older
  /// than the verdict. Null — re-drive honestly — when the receipt is
  /// missing or unreadable (fail open: the driver never fabricates a
  /// `blocked since` timestamp), the seam file is gone, any watched
  /// input is newer than the verdict (something changed: the unblock
  /// path must re-classify), or a probe errors out.
  Future<String?> _unchangedBlockedSince({
    required BehaviorRow row,
    required String projectRoot,
    required String featureDir,
    required String feature,
  }) async {
    final receipt = ContractBlockedReceipt.fromFile(
      ContractBlockedReceiptStore(projectRoot: projectRoot).pathFor(row.id),
    );
    if (receipt == null) return null;
    final blockedAt = DateTime.tryParse(receipt.blockedAt);
    if (blockedAt == null) return null;
    // 1. The seam file — the generated contract test the verdict ran.
    final testPath = _existingGeneratedTestPath(
      projectRoot: projectRoot,
      feature: feature,
      behaviorId: row.id,
    );
    if (testPath == null) return null;
    // Issue #1544 (review fix): re-check existence at the mtime read — a
    // seam file vanishing between `_existingGeneratedTestPath`'s probe and
    // this read must fail open (re-drive), not be read as "not newer".
    if (!File(testPath).existsSync()) return null;
    if (_isNewerThan(File(testPath), blockedAt)) return null;
    // 2. The contract row — the test list the behavior is declared in.
    if (_isNewerThan(
      File(p.join(featureDir, 'tdd', 'test-list.md')),
      blockedAt,
    )) {
      return null;
    }
    // 3. The implementation — any lib/ source newer than the verdict.
    if (await _treeChangedAfter(
      Directory(p.join(projectRoot, 'lib')),
      blockedAt,
    )) {
      return null;
    }
    return receipt.blockedAt;
  }

  /// Whether [file] exists and was modified after [at]. An unreadable
  /// file is treated as changed (fail open — re-drive).
  bool _isNewerThan(File file, DateTime at) {
    try {
      if (!file.existsSync()) return false;
      return file.lastModifiedSync().isAfter(at);
    } on FileSystemException {
      return true;
    }
  }

  /// Whether any file under [dir] was modified after [at] (recursive; a
  /// missing directory changed nothing). An unreadable entry is treated
  /// as changed (fail open — re-drive).
  Future<bool> _treeChangedAfter(Directory dir, DateTime at) async {
    if (!await dir.exists()) return false;
    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        try {
          if ((await entity.lastModified()).isAfter(at)) return true;
        } on FileSystemException {
          return true;
        }
      }
    } on FileSystemException {
      return true;
    }
    return false;
  }

  /// Whether the generated test at [testPath] carries the
  /// [vacuousGuardMarker]. Unreadable files (deleted between
  /// `_existingGeneratedTestPath`'s exists check and this read,
  /// permission-denied, or a directory at the test path) fail OPEN —
  /// marker absent — so the vacuous-green stop falls into the
  /// fallback-remedy arm instead of crashing the whole run with an
  /// unhandled FileSystemException.
  bool _testCarriesVacuousGuardMarker(String? testPath) {
    if (testPath == null) return false;
    try {
      return contentCarriesVacuousGuardMarker(
        File(testPath).readAsStringSync(),
      );
    } on FileSystemException {
      return false;
    }
  }

  /// Issue #1373: whether the generated test at [testPath] carries the
  /// [scaffoldedMarker] (issue #912 defect 3). Unreadable files fail
  /// OPEN — marker absent — mirroring the vacuous-guard probe.
  bool _testCarriesScaffoldedMarker(String? testPath) {
    if (testPath == null) return false;
    try {
      return File(testPath).readAsStringSync().contains(scaffoldedMarker);
    } on FileSystemException {
      return false;
    }
  }

  /// Issue #1651: whether the registry [record]'s artifact state is the
  /// placeholder-green class — the subject body is a scalar dummy AND
  /// the paired test's assertion set is type-only. Both reads fail OPEN
  /// (the same contract as the marker probe above): a missing or
  /// unreadable artifact keeps the fallback arm serving the stop.
  ///
  /// The classification rides the ONE decision predicate make's 9b gate
  /// uses ([scalarDummyGreenMustRefuse]) so the two surfaces never
  /// disagree: the declared routing and the spec's parsed scenarios are
  /// resolved through the shared fail-open shims
  /// ([DeclaredRouting.declaredSignatureFailOpen],
  /// [DeclaredRouting.scenariosFailOpen] — review fix: one posture for
  /// gen, make, and the driver) and the #1310 floor exempts the
  /// declared-routed pair whose scenario carries no derivable value.
  /// [featureDir] is the already-resolved feature directory (bug
  /// features live outside `specs/`), [featureName] the canonical
  /// feature name.
  Future<bool> _placeholderGreenDetected({
    required String projectRoot,
    required String featureDir,
    required String featureName,
    ArtifactRecord? record,
  }) async {
    if (record == null) return false;
    try {
      final subjectPath = p.isAbsolute(record.subjectPath)
          ? record.subjectPath
          : p.join(projectRoot, record.subjectPath);
      final testPath = p.isAbsolute(record.testPath)
          ? record.testPath
          : p.join(projectRoot, record.testPath);
      final subjectFile = File(subjectPath);
      final testFile = File(testPath);
      if (!subjectFile.existsSync() || !testFile.existsSync()) return false;
      final subjectContent = await subjectFile.readAsString();
      final testContent = await testFile.readAsString();
      if (!contentCarriesScalarDummyBody(subjectContent) ||
          !contentIsTypeOnlyAssertion(testContent)) {
        return false;
      }
      // Both resolutions fail open (null / empty) via the shared shims
      // (review fix: one posture for gen, make, and the driver).
      final declared = await DeclaredRouting.declaredSignatureFailOpen(
        cwd: projectRoot,
        featureName: featureName,
        featureDir: featureDir,
        behaviorId: record.behaviorId,
      );
      final scenarios = DeclaredRouting.scenariosFailOpen(featureDir);
      return scalarDummyGreenMustRefuse(
        subjectSource: subjectContent,
        testSource: testContent,
        declared: declared,
        scenarios: scenarios,
      );
    } on FileSystemException {
      return false;
    }
  }

  /// Issue #1411: the generated test's CURRENT content for the
  /// born-green hand-off dispatch. Null when the file is missing
  /// between the path probe and this read, permission-denied, or a
  /// directory — the arm then stands down (no hand-off can be trusted
  /// without the content).
  String? _readTestContentFailOpen(String testPath) {
    try {
      return File(testPath).readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }

  /// Issue #1323: the generated test's FIRST (lowest-index) `_argN()`
  /// placeholder helper — the index and declared type the hand-step
  /// remedy names. The content-only probe (the make child already
  /// verified the transcript signal before reporting the outcome).
  /// Unreadable files or a hand-edited test (the placeholder already
  /// replaced) return null — the remedy degrades to the generic noun and
  /// index 0; the make stop's own remedy line, which the output excerpt
  /// carries, always names the exact type.
  ArgPlaceholderHit? _testArgPlaceholderHit(String? testPath) {
    if (testPath == null) return null;
    try {
      return argPlaceholderHitInContent(File(testPath).readAsStringSync());
    } on FileSystemException {
      return null;
    }
  }

  /// Issue #1308: the journal hand-step violation for a stop reported at
  /// the named hand step (`<id>:hand`): what to write (an assertion on
  /// the observable outcome) and where (the generated test file,
  /// project-relative). Shared by the lane journal entries so the ONE
  /// explicit, named hand step is machine-parseable everywhere.
  ///
  /// Issue #1323: the dispatch keys on the test's OWN marker — the
  /// `_argN()` placeholder helper means the hand-delta seam stop (the
  /// #1323 vocabulary: the exact representative edit); the vacuous-guard
  /// marker (or no marker, the degenerate fallback) keeps the #1308
  /// vocabulary. Content-keyed because the aggregate outcome carries
  /// only `stoppedAt` — and each arm's stop condition is itself keyed on
  /// the same content, so the dispatch is exact for both.
  /// [projectRoot] is the caller's real project root (issue #1471: the
  /// `specs`-segment walk-up assumed `<root>/specs/<feature>` and
  /// mis-resolved a bug directory, `.specify/bugs/<slug>`).
  String _handStepViolationFor(
    String stoppedAt,
    String featureDir, {
    required String projectRoot,
  }) {
    final behaviorId = stoppedAt.substring(0, stoppedAt.lastIndexOf(':'));
    final feature = p.basename(featureDir);
    final testPath = _existingGeneratedTestPath(
      projectRoot: projectRoot,
      feature: feature,
      behaviorId: behaviorId,
    );
    final relativeTestPath = testPath != null
        ? p.relative(testPath, from: projectRoot)
        : p.join('test', 'tdd', feature, '${_snakeCase(behaviorId)}_test.dart');
    if (testPath != null) {
      try {
        final hit = argPlaceholderHitInContent(
          File(testPath).readAsStringSync(),
        );
        if (hit != null) {
          return argPlaceholderHandStepViolation(
            index: hit.index,
            behaviorId: behaviorId,
            testPath: relativeTestPath,
            declaredType: hit.declaredType,
          );
        }
        // Issue #1373: the scaffolded placeholder's own vocabulary — the
        // remedy is the author finders flow, not the #1308 outcome
        // assertion.
        if (File(testPath).readAsStringSync().contains(scaffoldedMarker)) {
          return 'hand-step=$behaviorId:hand — this is a SCAFFOLDED widget '
              'test (the $scaffoldedMarker marker, issue #912 defect 3): '
              'author concrete scenario finders, then run '
              '`zfa tdd make $behaviorId --author --finders-file '
              '<finders.txt>` (issue #1258)';
        }
        // Issue #1411: the born-green hand-first vocabulary — the test
        // carries the <id>:hand attestation (the designed hand step was
        // completed before the first red certification); the remedy is
        // make's born-green transition, which re-verifies the whole
        // gate honestly.
        if (contentCarriesHandStepHeader(
          File(testPath).readAsStringSync(),
          behaviorId,
        )) {
          return 'hand-step=$behaviorId:hand — the hand step was completed '
              'before the first red certification (issue #1411): certify '
              'the born-green hand transition with `zfa tdd make '
              '$behaviorId --born-green`';
        }
      } on FileSystemException {
        // Fall through to the #1308 vocabulary — a record, never a gate.
      }
    }
    return vacuousGuardHandStepViolation(
      behaviorId: behaviorId,
      testPath: relativeTestPath,
    );
  }

  /// Issue #1308: forward the gen child's guard-only warning lines into
  /// the run transcript. Issue #1518: the writer's remedy is BRANCHED by
  /// feature shape (dynamic seam paths), so the scan keys on the stable
  /// two-line shape the writer prints — the warning token line and the
  /// `--> fix:` line that immediately follows it — via the shared
  /// [guardOnlyWarningLinesToForward] scanner. The scan stays surgical:
  /// never a dump of the whole captured output.
  void _forwardGuardOnlyWarning(String output) {
    for (final line in guardOnlyWarningLinesToForward(output)) {
      print(line);
    }
  }

  /// Issue #1483: the #1308 fallback remedy, branched by feature shape —
  /// through the ONE shared [lanePlanSeamPath] resolver the gen-time
  /// writer warning also uses (issue #1518), so the RULE that picks the
  /// seam path cannot drift between the two sides. The lane plan pair on
  /// disk (`tdd/04-ENGINE.md`, else `tdd/04-SKIN.md`) is the hand-delta
  /// seam; their absence is the legacy single-file shape and the seam is
  /// the test list itself. Paths are printed relative to [projectRoot] —
  /// the full path of the file to edit. Messaging only: no detection,
  /// stop, or loop change.
  String _vacuousFallbackRemedy({
    required String projectRoot,
    required String featureDir,
  }) => vacuousGuardFallbackRemedyFor(
    lanePlanPath: lanePlanSeamPath(
      projectRoot: projectRoot,
      featureDir: featureDir,
    ),
    testListPath: p.relative(
      p.join(featureDir, 'tdd', 'test-list.md'),
      from: projectRoot,
    ),
  );

  /// Issue #1626 (review): the acceptance hand-step paths are resolved by
  /// the ONE shared rule in `vacuous_guard.dart`
  /// ([acceptanceHandStepPathsFor]) — make's refusal and this stop must not
  /// name different files. The registry record is the single path contract
  /// for BOTH the test and the subject (issue #1397 anchoring included);
  /// the disk probe stays the registry-less fallback.
  BehaviorState _maxState(BehaviorState a, BehaviorState b) =>
      a.index >= b.index ? a : b;

  Future<String?> _evidenceMisfire(
    CycleEvidence evidence,
    String step,
    String behaviorId, {
    // Review #1566: REQUIRED, not optional — a nullable `kind` defaulting
    // to null would let a future call site that omits it silently revert
    // every contract row to the pre-#1542 dead-end with no analyzer
    // signal (`hasGreen && kind == BehaviorKind.contract` is false for
    // null).
    required BehaviorKind kind,
  }) async {
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
        // Issue #1542: red is defined out of existence for two classes —
        // (a) the CONTRACT lane, whose verify-red verdict is BLOCKED,
        // never a certified red (issue #1007); (b) the born-green hand
        // transition, which certifies green WITHOUT a prior red (issue
        // #1411) — the journal probe reads the LAST green entry's
        // `- evidence:` marker, so the certification survives state
        // resets. For both classes the GREEN half stays mandatory (a
        // refactor with no green evidence at all still misfires), and
        // every other class keeps the exact red→green→refactor triple
        // (the bug #682 honesty contract).
        //
        // Review #1608: this arm is the certification ACCEPTANCE (the
        // #1542 contract — hashless legacy entries included); the #1592
        // re-entry gate is deliberately stricter (the guard also
        // requires the certification's `- subject-hash:` to bind the
        // current subject), so the refactor window can never be entered
        // on a certification this check would reject.
        final redDefinedOutOfExistence =
            (hasGreen && kind == BehaviorKind.contract) ||
            (hasGreen &&
                !hasRed &&
                await evidence.bornGreenCertified(behaviorId));
        if ((!hasRed || !hasGreen) && !redDefinedOutOfExistence) {
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

  /// The unit lane's hand-step forecast (SPEC 1489): WHICH of the lane's
  /// unit behaviors have a declared contract returning an entity that
  /// does not exist on disk yet. Best-effort by contract: any resolution
  /// failure contributes an empty set — the forecast is observability
  /// and (issue #1568) the run-level park gate, never a run stopper, and
  /// it never touches the state.
  Future<Set<String>> _entityReturnSeamIds({
    required String projectRoot,
    required String featureName,
    required String featureDir,
    required List<BehaviorRow> rows,
  }) async {
    final unitRows = rows.where((r) => r.kind == BehaviorKind.unit).toList();
    if (unitRows.isEmpty) return const {};
    try {
      final declared = <Signature?>[
        for (final row in unitRows)
          await DeclaredRouting.declaredSignatureFor(
            cwd: projectRoot,
            featureName: featureName,
            featureDir: featureDir,
            behaviorId: row.id,
          ),
      ];
      final seamIndices =
          await UnitContractShape.entityReturnSeamIndicesResolved(
            declared: declared,
            cwd: projectRoot,
          );
      return {
        for (final index in seamIndices)
          if (index >= 0 && index < unitRows.length) unitRows[index].id,
      };
    } on Exception {
      return const {};
    }
  }

  Future<_Stop?> _runEntityPhaseZero({
    required String projectRoot,
    required List<DeclaredEntity> entities,
    required String? zfaBin,
    required Duration? timeout,
    required String label,
    required String feature,
    Map<String, String>? childEnvironment,
  }) async {
    // No-JIT policy (see `ZfaExecutable`): the phase-0 child is a compiled
    // binary. The `--zfa-bin` override is compiled here too; the default
    // chain already compiles inside `defaultZfaBin`.
    final entry = zfaBin != null
        ? await ensureCompiled(zfaBin)
        : await StepRunner.defaultZfaBin(ensureCompiled: ensureCompiled);
    final deadline = timeout ?? TddTimeouts.defaultPipelineStep;

    Future<ProcessResult> spawn(List<String> args) {
      final command = ZfaExecutable.commandFor(entry, args);
      return runTimed(
        command.first,
        command.sublist(1),
        workingDirectory: projectRoot,
        timeout: deadline,
        environment: childEnvironment,
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
      final entityPath = await locateEntityFile(projectRoot, entity.name);
      if (entityPath != null) {
        print('[run] phase-0 entity ${entity.name} -> reused');
        await _logPhaseZeroFieldMismatch(entity, entityPath);
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
      // Issue #1322 (AC-3): a build failure caused by a MISSING builder
      // package is project state, not runner noise — the outcome label and
      // stop message must name the package and prescribe the exact fix,
      // not the generic runner-error.
      final missing = BuilderDependencyPreflight.missingBuildersForFailedBuild(
        projectRoot: projectRoot,
        buildOutput: '${build.stdout}${build.stderr}',
      );
      if (missing.isNotEmpty) {
        print('[run] phase-0 build -> failed (missing builder dependency)');
        return (
          result: 'missing-builder-dependency',
          stoppedAt: 'phase-0:build',
          exitCode: _exitRunnerError,
          message: BuilderDependencyPreflight.missingBuilderStopMessage(
            missing: missing,
            context: 'phase-0 `zfa build`',
          ),
        );
      }
      print('[run] phase-0 build -> failed');
      return failedSpawn(what: 'build', r: build);
    }
    print('[run] phase-0 build -> ok');
    return null;
  }

  /// Issue #1486: phase-0 reuse keeps the on-disk entity AS-IS — but a
  /// pre-fix run could create a FIELD-LESS entity (the parser dropped
  /// unbackticked `name: Type` pairs silently), and a later, fixed run
  /// reused that starved shape with no signal anywhere. When the plan's
  /// declared fields and the fields the entity file actually declares
  /// diverge, name both sets. Print-only by design: reuse semantics are
  /// unchanged, and any read/parse hiccup stays quiet — the warning is
  /// observability, never a run stopper.
  Future<void> _logPhaseZeroFieldMismatch(
    DeclaredEntity entity,
    String entityPath,
  ) async {
    if (entity.fields.isEmpty) return;
    try {
      final source = await File(entityPath).readAsString();
      final onDisk = SpecParser.entityFieldNamesFromDartSource(source);
      final declared = <String>{
        for (final f in entity.fields)
          f.contains(':') ? f.substring(0, f.indexOf(':')).trim() : f.trim(),
      };
      final onDiskSet = onDisk.toSet();
      final missingOnDisk = declared.difference(onDiskSet).toList()..sort();
      final undeclared = onDiskSet.difference(declared).toList()..sort();
      if (missingOnDisk.isEmpty && undeclared.isEmpty) return;
      print(
        '[run] phase-0 entity ${entity.name} -> field mismatch: plan '
        'declares [${declared.join(', ')}], entity file declares '
        '[${onDiskSet.join(', ')}] — reuse keeps the on-disk shape '
        '(issue #1486)',
      );
    } on Exception {
      // Best-effort: an unreadable entity file must never stop the run.
    }
  }

  // -------------------------------------------------------------------
  // Issue #1329 — the error-outcome recording path. The red/green
  // cycles record command + exit code + output; until now a failed step
  // discarded all of it (no cycle-log entry, a journal entry naming
  // only stopped_at), so a transient failure left nothing to diagnose
  // against. The recording here is evidence-shaped, append-only, and
  // never a gate.
  // -------------------------------------------------------------------

  /// Append the failed step's diagnostic evidence to the feature's
  /// cycle log (one `error` entry in the same evidence shape the
  /// red/green cycles record) and stage [failure] for the lane journal
  /// entry `_finish` writes. A failed append is reported on stderr,
  /// never fatal to the driving that already happened.
  Future<void> _recordStepFailure(
    _StepFailure failure, {
    required String featureDir,
    required String criterion,
  }) async {
    try {
      await CycleLog(featureDir).append(
        CycleLogEntry(
          behaviorId: failure.behaviorId,
          kind: CycleEntryKind.error,
          outcome: failure.outcome,
          runnerCommand: failure.command,
          exitCode: failure.exitCode,
          capturedOutput: failure.outputTail,
          sourceCriterion: criterion,
          testPath: 'test/',
          timestamp: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    } on FileSystemException catch (e) {
      stderr.writeln(
        'zfa tdd: failed to record the failed-step diagnostics in '
        'tdd/cycle-log.md ($e)',
      );
    }
    _lastStepFailure = failure;
  }

  /// The diagnostic output tail (issue #1329): the LAST [maxLines] lines
  /// of the step's combined stderr/stdout — failures end in the error
  /// (stack traces, the failing summary line), the head is the least
  /// diagnostic part — with an honest marker naming the dropped count
  /// when truncation happens. The same tail the cycle-log error entry
  /// and the journal error object record.
  static String _outputTail(String output, {int maxLines = 200}) {
    final lines = output.split('\n');
    // A trailing newline yields a final empty segment — not a line.
    if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
    if (lines.length <= maxLines) return lines.join('\n').trimRight();
    return '[... output truncated — showing the last $maxLines of '
        '${lines.length} lines (first ${lines.length - maxLines} dropped) '
        '...]\n'
        '${lines.sublist(lines.length - maxLines).join('\n')}';
  }

  /// The console excerpt depth (issue #1412): the LAST 10 non-empty lines
  /// of the failed step's captured output. The same tail semantics issue
  /// #1329 established for the cycle-log/journal ("failures end in the
  /// error... the head is the least diagnostic part") at a
  /// console-appropriate depth — for a refactor step the transcript always
  /// OPENS with the passing preflight block, so a head excerpt shows
  /// `runner-error` next to `preflight exit: 0` (a contradiction) and
  /// hides the failing pass the operator needs.
  static const int _consoleExcerptLines = 10;

  void _printOutputExcerpt(String output) {
    // Issue #1412: the excerpt is the diagnostic TAIL, routed through the
    // SAME _outputTail helper the cycle-log/journal paths record (no
    // second tail implementation — the honest truncation marker rides
    // along). Empty lines are filtered BEFORE the tail is taken so blank
    // padding never consumes excerpt slots (the pre-#1412 excerpt was
    // compact; it stays compact). Empty output prints nothing.
    final compact = output
        .split('\n')
        .map((l) => l.trimRight())
        .where((l) => l.isNotEmpty)
        .join('\n');
    if (compact.isEmpty) return;
    final tail = _outputTail(compact, maxLines: _consoleExcerptLines);
    for (final line in tail.split('\n')) {
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

/// Issue #1329: one failed step's diagnostic evidence — what the
/// error-outcome path records in the cycle log (the `error` entry) and
/// the lane journal entry (the structured `error` object): the failed
/// step's identity, the spawned command, the exit code, and the
/// truncated stderr/stdout tail.
class _StepFailure {
  const _StepFailure({
    required this.behaviorId,
    required this.step,
    required this.outcome,
    required this.exitCode,
    required this.command,
    required this.outputTail,
  });

  final String behaviorId;
  final String step;
  final String outcome;
  final int exitCode;
  final String command;
  final String outputTail;
}

/// The outcome of driving one behavior through its step window: the
/// updated run state plus, when the run must stop, the [_Stop] report.
typedef _DriveResult = ({RunState state, _Stop? stop, bool refactorBlocked});

/// Reference check for the positional feature argument: it lands in a
/// filesystem path, so accept exactly the shapes [TddFeaturePaths]
/// resolves (a plain segment, `specs/<name>`, `.specify/bugs/<slug>`, or
/// an absolute path) and refuse the rest — `.`, `..`, a traversal shape,
/// or a trailing separator (issue #1471). Shared by every driver command.
void validateFeatureSegment(String feature, String invocation) {
  if (TddFeaturePaths.isSupportedRef(feature) &&
      !feature.endsWith('/') &&
      !feature.endsWith(r'\')) {
    return;
  }
  throw UsageException(
    'invalid feature "$feature": expected a single spec directory name '
    'such as 049-tdd-run, not a path.',
    invocation,
  );
}
