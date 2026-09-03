/// `zfa tdd make <behavior-id>` — generation-only green step of the
/// TDD loop (spec 047-tdd-make, FR-001..011; 041 Phase 8, T062-T065).
///
/// The command:
///   1. Resolves the target behavior's test path + runnable test name
///      from the artifact registry (FR-001, FR-002) — same resolution
///      rules as `verify-red`.
///   2. Requires certified-red evidence (a red entry from `verify-red`)
///      in `tdd/cycle-log.md` BEFORE generating anything (FR-001).
///      Missing precondition → `not-certified-red` non-zero exit
///      naming the remediation (US2.AC1).
///   3. Re-runs the target test before generating and confirms it
///      STILL fails (FR-003). An already-green test takes the SKIP
///      transition (issue #694, amending US2.AC3): generation is
///      skipped entirely, NO suite run happens — the scoped single-test
///      re-run is the evidence run (issue #741), a green evidence entry
///      with an explicitly empty generation block is appended, and the
///      command exits 0 with `outcome=skipped` so the run loop proceeds
///      past completed behaviors instead of deadlocking on re-runs.
///   4. Plans the minimal generation through the zuraffa pipeline
///      (FR-005): `entity create` / `make` / `build` (never hand-
///      writes source, never edits tests — FR-004).
///   5. Executes the plan via [PipelineRunner], capturing every
///      invocation as a [GenerationStep] (FR-006). Misfire-stop on
///      unexpressible behaviors (US4) or failing generation steps
///      (US4.AC2) — with one per-behavior guard (issue #737): a
///      failure of the plan's TERMINAL `build` step is tolerated when
///      the CURRENT behavior's own test passes (the profile `single`
///      command) after the generation steps ran. The build step
///      validates the whole project, so it can fail on pre-existing
///      red suite state the make is not responsible for; grading the
///      behavior per-behavior (the #694 skip transition,
///      `outcome=skipped`) instead of `generation-error` keeps
///      `zfa tdd run` off a false negative.
///   6. Runs the target test via the profile `single` command and
///      requires a PASS (FR-007). Then requires no NEW suite failures
///      that are attributable to this make, relative to a pre-run
///      baseline (US3; issue #731): a failure counts against the make
///      only when it lives in the current behavior's own test file or
///      in a file that was fully green at baseline. Failures confined
///      to files that were ALREADY red at baseline are pre-existing red
///      behaviors (e.g. deferred acceptance tests) and never block
///      the make — their failing-test identifiers may even vary
///      between the two suite runs. Issue #741: the baseline may come
///      from the run's cached snapshot (`--suite-baseline`, written
///      once per `zfa tdd run`) and the guard may be the scoped
///      single-test result; the live full suite runs only for a
///      standalone make or when the cache/scoped transcript is
///      unusable (safe fallback).
///   7. On success, appends a green-evidence entry to
///      `specs/<feature>/tdd/cycle-log.md` (FR-008) containing the
///      generation commands, runner command, runner exit code,
///      captured passing output, full-suite result, and timestamp.
///   8. On any failure, exits non-zero, appends no green entry, and
///      leaves the test file and cycle log unmodified (FR-009).
///   9. Prints the machine-readable summary line
///      `make: behavior=<id> outcome=<label> feature=<feature>`
///      as the final stdout line on every code path (FR-010); exit
///      code 0 means exactly "green certified" (US5.AC2).
///  10. Honors the misfire-stop policy: any internal step that cannot
///      complete stops the command immediately, non-zero, with a
///      clear report (FR-011).
///
/// Rejections and misfires are signaled through dart:io `exitCode`
/// (which [CliRunner] honors) rather than by throwing, so the summary
/// line stays the final stdout line.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../models/generation_plan.dart';
import '../models/red_classification.dart';
import '../models/routing.dart';
import '../services/artifact_registry.dart';
import '../services/composition_planner.dart';
import '../services/composition_targets.dart';
import '../services/cycle_log.dart';
import '../services/entity_lookup.dart';
import '../services/generation_planner.dart';
import '../services/pipeline_runner.dart';
import '../services/run_baseline_cache.dart';
import '../services/runner.dart';
import '../services/spec_parser.dart';
import '../services/test_list_reader.dart';
import '../services/suite_guard.dart';
import '../services/tdd_timeout.dart';
import '../services/widget_scaffold.dart';
import '../tdd_plugin.dart';
import '../../../cli/plugin_loader.dart';
import '../../../config/zfa_config.dart';
import '../../../core/plugin_system/plugin_manager.dart';
import '../../../core/plugin_system/plugin_registry.dart';
import '../../../core/project/project_root.dart';

/// Resolution-stage failure: message, outcome, and feature context if known.
class MakeResolutionError implements Exception {
  MakeResolutionError(this.message, {required this.outcome, this.feature});

  final String message;
  final MakeOutcome outcome;
  final String? feature;

  @override
  String toString() => message;
}

class MakeCommand extends Command<void> {
  MakeCommand(this.plugin) {
    argParser.addOption(
      'feature',
      help:
          'Feature name (e.g. 047-tdd-make). Restricts target '
          'resolution to specs/<feature>/tdd/artifacts.json. When '
          'omitted, every feature registry is scanned.',
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/, test/, and .specify/ (the fixture '
          'or target project). When omitted, the current working directory is '
          'used. Tests pass the temp fixture root here instead of mutating '
          'Directory.current, which is process-global and unsafe under '
          'concurrent test execution.',
    );
    argParser.addOption(
      'zfa-bin',
      help:
          'Override the zfa entrypoint for pipeline sub-processes. Tests use '
          'this to point at a fake zfa script; production runs auto-resolve '
          'via Platform.script or `zfa` on PATH.',
    );
    argParser.addOption(
      'timeout',
      valueHelp: 'minutes',
      help:
          'Hard deadline in minutes for every process this command spawns — '
          'the target test (default 2 min), the full suite baseline/guard and '
          'each generation pipeline step (default 10 min each). Fractions are '
          'allowed (0.5 = 30 seconds). On timeout the child is killed '
          '(SIGKILL) and the command stops non-zero as runner-error (bug '
          '#742).',
    );
    argParser.addOption(
      'suite-baseline',
      help:
          'Path to a cached full-suite baseline snapshot (run-baseline.json) '
          'written once per run by `zfa tdd run` (issue #741). When given and '
          'readable, make reuses the cached pre-run failure set instead of '
          'running the full suite, and certifies the post-generation guard '
          'from the scoped single-test result — falling back to the live '
          'suite when the cache is missing, corrupt, or unparseable.',
    );
    argParser.addFlag(
      'strict-routing',
      help:
          'Refuse undeclared routing intent (no `**Type**` marker, contract '
          'trace, or kind declaration) instead of falling back to the legacy '
          'description-keyed branches and the composition fallback '
          '(feature 071, issue #951).',
      negatable: false,
    );
    argParser.addFlag(
      'stub',
      help:
          'Demote generation to shallow func-stubs (the legacy escape hatch). '
          'Default generates contract-conforming mocks via zfa mock create.',
      defaultsTo: false,
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'make';

  @override
  String get description =>
      'Generate minimal implementation via zfa make/entity create/build, '
      'run the target test green, certify the suite stays clean, and '
      'append green evidence to tdd/cycle-log.md (spec 047).';

  @override
  String get invocation =>
      'zfa tdd make [<behavior-id>] [--feature <name>] '
      '[--project <path>] [--zfa-bin <path>]';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    final behaviorId = rest.isNotEmpty ? rest.first : null;
    final featureFlag = argResults?['feature'] as String?;
    if (featureFlag != null && featureFlag.isNotEmpty) {
      try {
        _validateFeatureSegment(featureFlag);
      } on UsageException catch (e) {
        print('zfa tdd make: ${e.message}');
        _printSummary(
          behavior: behaviorId ?? '-',
          outcome: MakeOutcome.runnerError,
          feature: 'unknown',
        );
        exitCode = 1;
        return;
      }
    }
    final projectFlag = argResults?['project'] as String?;
    final cwd = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');
    final zfaBinFlag = argResults?['zfa-bin'] as String?;
    final suiteBaselineFlag = argResults?['suite-baseline'] as String?;
    final suiteBaselinePath =
        suiteBaselineFlag != null && suiteBaselineFlag.isNotEmpty
        ? suiteBaselineFlag
        : null;

    // Bug #742: the --timeout override — one uniform deadline for every
    // subprocess this command spawns (single test, suite, pipeline steps).
    Duration? timeoutOverride;
    try {
      timeoutOverride = parseTddTimeoutMinutes(
        argResults?['timeout'] as String?,
      );
    } on TddTimeoutFormatException catch (e) {
      print('zfa tdd make: ${e.message}');
      _printSummary(
        behavior: behaviorId ?? '-',
        outcome: MakeOutcome.runnerError,
        feature: featureFlag ?? 'unknown',
      );
      exitCode = 1;
      return;
    }

    final runner = const SingleTestRunner();
    final planner = const GenerationPlanner();
    final pipelineRunner = const PipelineRunner();
    final guard = const SuiteGuard();

    // ---------------------------------------------------------------
    // 1. Resolve the target from the registry (FR-001, FR-002).
    // ---------------------------------------------------------------
    _ResolvedTarget target;
    try {
      target = await _resolveTarget(cwd, behaviorId, featureFlag);
    } on MakeResolutionError catch (e) {
      print('zfa tdd make: ${e.message}');
      _printSummary(
        behavior: behaviorId ?? '-',
        outcome: e.outcome,
        feature: e.feature ?? featureFlag ?? 'unknown',
      );
      exitCode = 1;
      return;
    }
    final record = target.record;
    print('zfa tdd make: behavior ${record.behaviorId}');
    print('   feature: ${target.featureName}');
    print('   test: ${record.testPath}');

    // ---------------------------------------------------------------
    // 2. Precondition: certified-red evidence (FR-001, US2.AC1).
    // ---------------------------------------------------------------
    final certifiedRed = await _hasCertifiedRed(
      target.featureDir,
      record.behaviorId,
    );
    if (!certifiedRed) {
      print(
        'zfa tdd make: behavior "${record.behaviorId}" has no certified-red '
        'evidence in cycle-log.md. Run `zfa tdd verify-red '
        '${record.behaviorId}` first.',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: MakeOutcome.notCertifiedRed,
        feature: target.featureName,
      );
      exitCode = 1;
      return;
    }

    // ---------------------------------------------------------------
    // 3. Load the profile (single + suite) — misfire-stop U30.
    // ---------------------------------------------------------------
    String singleTemplate;
    String suiteTemplate;
    try {
      singleTemplate = await runner.loadSingleTemplate(workingDirectory: cwd);
      suiteTemplate = await runner.loadSuiteTemplate(workingDirectory: cwd);
    } on StateError catch (e) {
      print(e.message);
      _printSummary(
        behavior: record.behaviorId,
        outcome: MakeOutcome.runnerError,
        feature: target.featureName,
      );
      exitCode = 1;
      return;
    }

    final testPath = p.isAbsolute(record.testPath)
        ? record.testPath
        : p.join(cwd, record.testPath);
    final testName = _runnableNameOf(record);

    // ---------------------------------------------------------------
    // 3b. Scaffolded widget tests cannot certify green (issue #912
    //     defect 3). A generated widget test whose scenario assertions
    //     are still placeholder finders carries the machine-readable
    //     scaffold marker; a green such test proves nothing (a bare
    //     SizedBox() passes it). The behavior is EXCLUDED from
    //     contract-green accounting: refuse with the remedy, exit
    //     non-zero, no green evidence appended.
    // ---------------------------------------------------------------
    final scaffoldCheckFile = File(testPath);
    if (scaffoldCheckFile.existsSync() &&
        contentIsScaffolded(await scaffoldCheckFile.readAsString())) {
      print(
        'zfa tdd make: behavior "${record.behaviorId}" test is SCAFFOLDED '
        '— its scenario assertions are placeholder finders '
        '($scaffoldedMarker, issue #912 defect 3). Replace the '
        'placeholder finders with concrete scenario-derived finders '
        '(find.text / find.byType ...), remove the marker, and re-run '
        'make.',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: MakeOutcome.scaffolded,
        feature: target.featureName,
      );
      exitCode = 1;
      return;
    }

    // ---------------------------------------------------------------
    // 4. Drift check: re-run target test BEFORE generation (FR-003).
    //    If it passes, the behavior is already satisfied (a prior make
    //    run or an equivalent implementation): SKIP transition (issue
    //    #694). Generation never runs; the full suite is re-certified
    //    with no NEW failures below, a green evidence entry with an
    //    explicitly empty generation block is appended, and the summary
    //    reports `outcome=skipped` with exit 0 so `zfa tdd run`
    //    proceeds past already-completed behaviors instead of stopping.
    // ---------------------------------------------------------------
    final driftRun = await runner.runSingle(
      singleTemplate: singleTemplate,
      testPath: testPath,
      testName: testName,
      workingDirectory: cwd,
      timeout: timeoutOverride,
    );
    if (driftRun.timedOut) {
      // Bug #742: the drift-check child outlived the deadline and was
      // killed — misfire-stop naming behavior, step, and command.
      print(
        'zfa tdd make: behavior "${record.behaviorId}" — drift check '
        '(target test re-run before generation) timed out: '
        '${driftRun.output}',
      );
      print(
        '   re-run with a larger --timeout <minutes> if this step '
        'legitimately needs longer.',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: MakeOutcome.runnerError,
        feature: target.featureName,
      );
      exitCode = 1;
      return;
    }
    final alreadyGreen = driftRun.exitCode == 0 && driftRun.startedProcess;
    if (alreadyGreen) {
      print(
        '   target test already passes — skipping generation (issue #694 '
        'skip transition); the suite is not re-run (issue #741)',
      );
    }

    // ---------------------------------------------------------------
    // 5. Pre-run suite baseline (FR-007 / US3.AC3). Issue #741: the
    //    already-green skip transition runs no suite at all, and a
    //    run-cached baseline (`--suite-baseline`, written once per
    //    `tdd run` by the driver) replaces the per-behavior suite run.
    //    The live suite runs only for a standalone make (no flag) or
    //    when the cache is missing/corrupt/unparseable — the same
    //    safe fallback as before this fix.
    // ---------------------------------------------------------------
    SuiteSnapshot? baseline;
    var baselineFromCache = false;
    if (!alreadyGreen) {
      SuiteSnapshot? cached;
      if (suiteBaselinePath != null) {
        cached = await const RunBaselineCache().read(suiteBaselinePath);
        if (cached == null || !cached.parseable) {
          print(
            '   suite baseline cache unreadable — falling back to the '
            'live suite',
          );
        }
      }
      if (cached != null && cached.parseable) {
        baseline = cached;
        baselineFromCache = true;
        print(
          '   suite baseline: cached (${baseline.capturedAt}) — '
          '${baseline.failedTests.length} pre-existing failure(s) '
          '(issue #741)',
        );
      } else {
        print('   suite baseline: $suiteTemplate');
        final baselineRun = await runner.runSuite(
          suiteTemplate: suiteTemplate,
          workingDirectory: cwd,
        );
        final live = guard.fromRunRecord(
          record: baselineRun,
          capturedAt: DateTime.now().toUtc().toIso8601String(),
        );
        print(
          '   baseline exit: ${live.exitCode}, failed: ${live.failedTests.length}',
        );
        if (!baselineRun.startedProcess ||
            !live.parseable ||
            live.exitCode != 0 && live.failedTests.isEmpty) {
          print(
            'zfa tdd make: the suite baseline did not produce a usable snapshot. '
            'Refusing to generate without a trustworthy pre-run failure set.',
          );
          _printSummary(
            behavior: record.behaviorId,
            outcome: MakeOutcome.runnerError,
            feature: target.featureName,
          );
          exitCode = 1;
          return;
        }
        baseline = live;
      }
    }

    // ---------------------------------------------------------------
    // 6-8. Plan, pipeline, and post-generation re-run — the generation
    //      path only. An already-green target (issue #694 skip
    //      transition) never plans or generates; its evidence command is
    //      the drift re-run itself and its generation block is empty.
    // ---------------------------------------------------------------
    PipelineResult? pipelineResult;
    var postRun = driftRun;
    // Issue #737: set when the plan's terminal `build` step failed but
    // the per-behavior guard tolerated it (the behavior's own test
    // passes) — the make then takes the #694 skip transition.
    var buildStepTolerated = false;
    if (!alreadyGreen) {
      // 6. Plan the minimal generation (FR-005). The row's loop kind
      // rides along (bug #835): an ffi-kind row must route to the
      // honest unexpressible plan, never to the id-prefix dispatch that
      // would send a U<n> ffi behavior into `tdd func` (whose scaffold
      // refuses the harness shape) and dead-end the run in a
      // generation-error. The reader is the single format contract; an
      // unreadable list degrades to kindless routing (exactly the
      // pre-#835 behavior) with a note instead of a silent guess.
      final rowKind = await _rowKind(target.featureDir, record.behaviorId);
      final isStub = argResults?['stub'] as bool? ?? false;
      final strictRouting = argResults?['strict-routing'] as bool? ?? false;
      // Round-2 review fix 3b: a MALFORMED spec (the parser's
      // StateError refusals) refuses the make — the same surfacing
      // path as a pipeline resolution error — instead of silently
      // routing on empty declarations (the #920 regression class).
      final SpecDeclarations declarations;
      try {
        declarations = await _declarationsFor(target.featureDir);
      } on StateError catch (e) {
        print('zfa tdd make: declaration refused — ${e.message}');
        _printSummary(
          behavior: record.behaviorId,
          outcome: MakeOutcome.runnerError,
          feature: target.featureName,
        );
        exitCode = 1;
        return;
      }
      final summary = BehaviorSummary.fromRecord(
        record,
        description: _descriptionFor(record),
        target: _targetFor(record),
        entityTraced: await _tracedEntityFor(
          record: record,
          featureDir: target.featureDir,
        ),
        kind: rowKind,
        stub: isStub,
        strictRouting: strictRouting,
        traces: await _rowTraces(target.featureDir, record.behaviorId),
        declarations: declarations,
      );
      final plan = planner.plan(summary);
      GenerationPlan effectivePlan;
      if (plan.isExpressible) {
        effectivePlan = await _gateExistingEntityCreateSteps(
          plan,
          workingDirectory: cwd,
        );
        print('   plan: ${effectivePlan.steps.length} step(s)');
      } else {
        // ---------------------------------------------------------
        // Composition fallback (issue #642, spec 052): the planner is
        // pure and description-keyed, so an acceptance behavior's
        // prose stays unexpressible to it BY DESIGN —
        // deterministically across run phases. When the target's
        // test-list row is acceptance-kind and the feature holds
        // composable green unit subjects, offer the composition plan
        // (compose → build) that wires the acceptance subject against
        // them, so a deferred phase-2 acceptance make can actually
        // flip green.
        //
        // Issue #939 (the widget make path): a WIDGET-kind row — the
        // bug #830 testWidgets lane — dead-ended here forever (the
        // gate refused it, mislabeled as unit-kind). It now routes to
        // the view-builder lane: a deterministic minimal view
        // generated from the spec's declared Presentation layer
        // contract + the behavior's scenario literals, then build —
        // the loop REACHES green through a generated skeleton, exactly
        // as func subjects do. Everything else keeps the honest stop:
        // unit-kind behaviors and unknown rows (fail-closed), and
        // acceptance prose with zero composable anchors (FR-009),
        // report `unexpressible` exactly as before.
        // ---------------------------------------------------------
        // Feature 071 strict gate: under --strict-routing a resolver
        // refusal (errors-are-an-API: the reason carries `--> fix:`) is
        // the honest stop — the composition fallback (legacy lanes)
        // must not engage. Declared widget rows still route to the view
        // lane: their unexpressible plan is the ROUTING (the #950/#939
        // contract), not a strict failure.
        if (summary.strictRouting &&
            (plan.unexpressibleReason ?? '').contains('--> fix:')) {
          print(
            'zfa tdd make: cannot plan a generation for behavior '
            '"${record.behaviorId}". ${plan.unexpressibleReason}',
          );
          _printSummary(
            behavior: record.behaviorId,
            outcome: MakeOutcome.unexpressible,
            feature: target.featureName,
          );
          exitCode = 1;
          return;
        }
        final composed = await _compositionFallback(
          cwd: cwd,
          record: record,
          featureDir: target.featureDir,
          featureName: target.featureName,
          summary: summary,
        );
        if (composed == null) {
          print(
            'zfa tdd make: cannot plan a generation for behavior '
            '"${record.behaviorId}". ${plan.unexpressibleReason}',
          );
          _printSummary(
            behavior: record.behaviorId,
            outcome: MakeOutcome.unexpressible,
            feature: target.featureName,
          );
          exitCode = 1;
          return;
        }
        effectivePlan = composed;
        print(
          '   plan: composition fallback — '
          '${effectivePlan.steps.length} step(s)',
        );
      }

      // Bug #826 remediation (3): an inner `zfa make <name>` whose own
      // plan resolves to ZERO active plugins ("❌ No active plugins to
      // run.") is a no-op, not a generation. Resolve the child's plan
      // in-process — the same cheap PlanResolver the real `zfa make` runs
      // before any analyzer load — and record the no-op WITHOUT spawning
      // the heavy subprocess at all. Fail-open: when the plan shape is not
      // the default make invocation, or the in-process resolution errors,
      // the subprocess path runs exactly as before.
      if (zfaBinFlag == null || zfaBinFlag.isEmpty) {
        final makeName = _bareMakeName(effectivePlan);
        if (makeName != null && _innerMakePlanIsEmpty(cwd, makeName)) {
          print(
            '   plan: `zfa make $makeName` resolves to no active plugins '
            '— nothing to generate (bug #826).',
          );
          print('   verdict: no-op');
          print(
            '--> fix: enable generator plugins for this project in '
            '.zfa.json (e.g. "usecase": true) or implement the subject '
            'manually, then re-run; no subprocess was attempted.',
          );
          _printSummary(
            behavior: record.behaviorId,
            outcome: MakeOutcome.noOp,
            feature: target.featureName,
          );
          exitCode = 1;
          return;
        }
      }

      // 7. Execute the plan via the pipeline (FR-006, US1 / U8-U13).
      try {
        pipelineResult = await pipelineRunner.runPlan(
          plan: effectivePlan,
          workingDirectory: cwd,
          zfaBinOverride: zfaBinFlag,
          feature: target.featureName,
          timeout: timeoutOverride,
        );
      } on PipelineResolutionError catch (e) {
        print('zfa tdd make: ${e.message}');
        _printSummary(
          behavior: record.behaviorId,
          outcome: MakeOutcome.runnerError,
          feature: target.featureName,
        );
        exitCode = 1;
        return;
      }

      // Misfire-stop on generation failure (FR-004, US4.AC2) — with the
      // issue #737 per-behavior guard for the plan's terminal build
      // step.
      if (!pipelineResult.completed) {
        final idx = pipelineResult.firstFailureIndex;
        final failed = idx >= 0 && idx < pipelineResult.steps.length
            ? pipelineResult.steps[idx]
            : null;
        // Bug #826: a step that died by KILL is not a generation failure.
        // The subprocess was killed — by the OS under memory pressure
        // (the SIGKILL/OOM class, exit < 0) or by our own deadline
        // (timeout, bug #742 path). Grading either as a bare
        // `generation-error` is what made the run loop's stop
        // indistinguishable from a genuine red. Emit the classified
        // verdict — class + exit code + `--> fix:` line + the telemetry
        // JSON — and surface it in the summary's outcome token so corpus
        // drivers can tell a transient, re-runnable kill from a real red.
        final killOutcome = switch (failed?.killClass) {
          GenerationKillClass.resourceLimit => MakeOutcome.resourceLimit,
          GenerationKillClass.timeout => MakeOutcome.timeout,
          _ => null,
        };
        if (killOutcome != null && failed != null) {
          print(
            'zfa tdd make: generation step killed at index $idx '
            '(${failed.purpose}):',
          );
          print('   command: `${failed.command}`');
          print('   verdict: ${failed.verdictLabel} (exit ${failed.exitCode})');
          print(
            failed.killClass == GenerationKillClass.timeout
                ? '--> fix: the step outlived its deadline — raise '
                      '--timeout (minutes) on slower machines, or investigate '
                      'the step for a hang.'
                : '--> fix: transient resource kill (SIGKILL/OOM class) — '
                      'free memory or raise ZFA_TDD_STEP_MEMORY_KB headroom, '
                      'then re-run this step; no state changed.',
          );
          print('   telemetry json: ${jsonEncode(failed.verdictJson())}');
          _printSummary(
            behavior: record.behaviorId,
            outcome: killOutcome,
            feature: target.featureName,
          );
          exitCode = 1;
          return;
        }
        // Issue #737: the plan's terminal `build` step validates the
        // WHOLE project (build_runner + analyze over the full tree), so
        // it can exit non-zero for reasons this behavior's generation
        // is not responsible for — e.g. a pre-existing red suite (the
        // pending U* stubs) or build-config noise. The pipeline
        // (FR-006) treats any non-zero exit as a plan failure; grading
        // that failure as `generation-error` is a false negative when
        // the generation steps themselves succeeded and the CURRENT
        // behavior's test passes. The guard is per-behavior BY
        // CONSTRUCTION: only the terminal `build` step qualifies (an
        // earlier failure means real generation work never ran), and
        // the behavior's own test must pass right now. Anything else
        // keeps the honest `generation-error` stop (safe-failure,
        // never a silent pass).
        final toleratedRun = await _toleratedTerminalBuildFailure(
          runner: runner,
          plan: effectivePlan,
          result: pipelineResult,
          singleTemplate: singleTemplate,
          testPath: testPath,
          testName: testName,
          workingDirectory: cwd,
        );
        if (toleratedRun != null) {
          print(
            '   terminal build step failed: `${failed!.command}` '
            '(exit ${failed.exitCode}).',
          );
          print(
            "   per-behavior check: the behavior's own test passes — the "
            'build failure is not attributable to this make (issue #737 '
            'per-behavior guard); taking the #694 skip transition.',
          );
          postRun = toleratedRun;
          buildStepTolerated = true;
        } else {
          print(
            'zfa tdd make: generation step failed at index $idx'
            '${failed != null ? ' (${failed.purpose})' : ''}:',
          );
          if (failed != null) {
            print('   command: `${failed.command}`');
            print('   exit: ${failed.exitCode}');
            print('   output (tail):');
            final tail = failed.output.length > 800
                ? failed.output.substring(failed.output.length - 800)
                : failed.output;
            print(tail.split('\n').take(20).join('\n'));
          }
          _printSummary(
            behavior: record.behaviorId,
            outcome: MakeOutcome.generationError,
            feature: target.featureName,
          );
          exitCode = 1;
          return;
        }
      }

      // 8. Target test post-generation (FR-007). When the terminal
      //    build step was tolerated (issue #737) the per-behavior
      //    guard's passing run IS the post-generation target run.
      if (!buildStepTolerated) {
        postRun = await runner.runSingle(
          singleTemplate: singleTemplate,
          testPath: testPath,
          testName: testName,
          workingDirectory: cwd,
          timeout: timeoutOverride,
        );
        print('   target test exit: ${postRun.exitCode}');
        if (postRun.exitCode != 0) {
          print(
            'zfa tdd make: target test still fails after generation '
            '(exit ${postRun.exitCode}).',
          );
          _printSummary(
            behavior: record.behaviorId,
            outcome: MakeOutcome.generationError,
            feature: target.featureName,
          );
          exitCode = 1;
          return;
        }
      }
    }

    // ---------------------------------------------------------------
    // 9. Suite guard (FR-007, US3). Issue #741: the skip transition
    //    runs no guard (nothing was generated, so no NEW failure is
    //    attributable to this make); with a run-cached baseline the
    //    guard is certified from the scoped single-test result, falling
    //    back to the live full-suite guard only when that transcript is
    //    unusable (safe failure — never a silent pass).
    // ---------------------------------------------------------------
    SuiteSnapshot? guardSnap;
    var regressed = const <String>[];
    if (!alreadyGreen) {
      if (baselineFromCache) {
        final scopedGuard = guard.parse(
          command: postRun.command,
          exitCode: postRun.exitCode,
          output: postRun.output,
          capturedAt: DateTime.now().toUtc().toIso8601String(),
        );
        if (scopedGuard.parseable) {
          print(
            '   suite guard: scoped single-test result (issue #741 '
            'baseline cache)',
          );
          guardSnap = scopedGuard;
        } else {
          print(
            '   scoped guard transcript unusable — falling back to the '
            'live suite',
          );
        }
      }
      if (guardSnap == null) {
        final guardRun = await runner.runSuite(
          suiteTemplate: suiteTemplate,
          workingDirectory: cwd,
          timeout: timeoutOverride,
        );
        final liveGuard = guard.fromRunRecord(
          record: guardRun,
          capturedAt: DateTime.now().toUtc().toIso8601String(),
        );
        if (!guardRun.startedProcess ||
            !liveGuard.parseable ||
            liveGuard.exitCode != 0 && liveGuard.failedTests.isEmpty) {
          print(
            'zfa tdd make: cannot parse the suite output to identify failing '
            'tests. Refusing to certify — the suite guard is a safe-failure '
            '(never a silent pass).',
          );
          _printSummary(
            behavior: record.behaviorId,
            outcome: MakeOutcome.runnerError,
            feature: target.featureName,
          );
          exitCode = 1;
          return;
        }
        guardSnap = liveGuard;
      }
      final baselineSnapshot = baseline!;
      final diff = guard.diff(baseline: baselineSnapshot, guard: guardSnap);
      // Issue #731: scope the regression verdict to failures THIS make
      // could have caused. The name-diff alone false-positives when the
      // suite already carries pre-existing red behaviors (e.g. deferred
      // acceptance tests): a red test's failing-test IDENTIFIER may vary
      // between the baseline and guard runs (dynamic test names), so the
      // guard sees a "new" failure that is really the same pre-existing
      // red behavior — and an already-green target's make reported
      // `regression` instead of `skipped`, deadlocking `tdd run`.
      regressed = _regressionsAttributableToThisMake(
        baseline: baselineSnapshot,
        newFailures: diff.newFailures,
        testPath: testPath,
      );
      if (regressed.length < diff.newFailures.length) {
        final tolerated = diff.newFailures
            .where((id) => !regressed.contains(id))
            .toList();
        print(
          '   suite guard: ${tolerated.length} failing id(s) belong to files '
          'already red at baseline — pre-existing red behaviors, tolerated '
          '(issue #731):',
        );
        for (final id in tolerated) {
          print('   - $id');
        }
      }
      if (regressed.isNotEmpty) {
        print(
          'zfa tdd make: regression detected — ${regressed.length} '
          'NEW failure(s) introduced by the generation:',
        );
        for (final id in regressed) {
          print('   - $id');
        }
        print('   generated source left in place for inspection.');
        _printSummary(
          behavior: record.behaviorId,
          outcome: MakeOutcome.regression,
          feature: target.featureName,
        );
        exitCode = 1;
        return;
      }
    }

    // ---------------------------------------------------------------
    // 10. Green evidence append (FR-008). For the issue #694 skip
    //     transition the generation block is explicitly empty and the
    //     evidence command is the drift re-run. Issue #741: on the skip
    //     transition no suite ran, so the suite numbers record the
    //     honest zeros (nothing generated → no suite risk taken); with
    //     a run-cached baseline the baseline number is the cached
    //     snapshot's and the guard number is the scoped single-test
    //     result's. Every number is real, from the run that produced it.
    // ---------------------------------------------------------------
    final log = CycleLog(target.featureDir);
    await log.append(
      CycleLogEntry(
        behaviorId: record.behaviorId,
        kind: CycleEntryKind.green,
        runnerCommand: postRun.command,
        exitCode: postRun.exitCode,
        capturedOutput: postRun.output,
        sourceCriterion: record.sourceCriterion,
        testPath: record.testPath,
        timestamp: DateTime.now().toUtc().toIso8601String(),
        generationSteps: pipelineResult?.steps ?? const [],
        suiteBaselineFailures: baseline?.failedTests.length ?? 0,
        suiteGuardFailures: guardSnap?.failedTests.length ?? 0,
        suiteNewFailures: regressed,
      ),
    );
    print(
      '   green evidence appended to specs/${target.featureName}/tdd/'
      'cycle-log.md',
    );
    _printSummary(
      behavior: record.behaviorId,
      outcome: alreadyGreen || buildStepTolerated
          ? MakeOutcome.skipped
          : MakeOutcome.green,
      feature: target.featureName,
    );
    exitCode = 0;
  }

  // -------------------------------------------------------------------
  // Helpers — resolution + summary (mirror verify_red_command.dart).
  // -------------------------------------------------------------------

  /// The loop kind the feature's test-list row declares for
  /// [behaviorId] (bug #835), or null when the list is unreadable or the
  /// row is missing — null keeps the pre-#835 kindless routing for every
  /// legacy list. A malformed list prints a note (it is a real problem,
  /// but the kind is only an optimization over the id dispatch and other
  /// steps re-surface the malformation honestly).
  ///
  /// Issue #939: widget rows resolve as WIDGET here (the shared
  /// `TestListReader` contract parses the `## Outer loop: widget
  /// behaviors` header since bug #830) — the kind the composition
  /// fallback's widget lane and the discovery gate now consume. The
  /// pre-#939 disengage message hardcoded "is unit-kind" for every
  /// non-acceptance kind and mislabeled exactly this resolution.
  Future<BehaviorKind?> _rowKind(String featureDir, String behaviorId) async {
    try {
      for (final row in await TestListReader(featureDir).read()) {
        if (row.id == behaviorId) return row.kind;
      }
    } on TestListReadException catch (e) {
      print(
        '   note: test list unreadable ( ${e.message}) — '
        'routing on id/description only',
      );
    }
    return null;
  }

  /// Feature 071: the behavior's raw trace tokens from its test-list
  /// row (`traces:` cell) — the resolver resolves these against
  /// declared contract rows. Empty when the row is missing. Tokens are
  /// split by [SpecParser.traceTokens], so a backticked inline
  /// signature never splits mid-declaration and signature-shaped
  /// tokens never dangle (round-2 review fix 2).
  Future<List<String>> _rowTraces(String featureDir, String behaviorId) async {
    try {
      for (final row in await TestListReader(featureDir).read()) {
        if (row.id != behaviorId) continue;
        return SpecParser.traceTokens(row.traces);
      }
    } on TestListReadException {
      // unreadable list: kindless/traceless routing, as pre-#835
    }
    return const [];
  }

  /// Feature 071: the spec's parsed routing declarations (markers,
  /// contract rows, persistence). A MISSING or UNREADABLE spec yields
  /// EMPTY declarations — the resolver still runs, so under
  /// --strict-routing everything is honestly undeclared (refusal), and
  /// in the fallback window the legacy branches route unchanged. A
  /// MALFORMED spec (the parser's StateError refusals) propagates to
  /// the caller (round-2 review fix 3b): swallowing it would route a
  /// declared behavior on legacy prose — the #920 regression class.
  Future<SpecDeclarations> _declarationsFor(String featureDir) async {
    final specFile = File('$featureDir/spec.md');
    if (!specFile.existsSync()) return const SpecDeclarations();
    final String specMd;
    try {
      specMd = specFile.readAsStringSync();
    } on FileSystemException {
      return const SpecDeclarations(); // unreadable file: empty declarations
    }
    return SpecDeclarations(
      scenarios: SpecParser.parseScenarioTypeMarkers(specMd),
      contractRows: {
        for (final r in const SpecParser().parseContractRows(specMd)) r.name: r,
      },
      persistence: SpecParser.parsePersistenceDeclarations(specMd),
    );
  }

  /// The composition fallback for an unexpressible plan (issue #642, spec
  /// 052). Returns the composition plan (`compose <id>` → `build`) when
  /// the fallback engages, or null when the honest `unexpressible` stop
  /// stands:
  ///
  /// - the behavior has no test-list row, or the list is unreadable —
  ///   fail-closed (the fallback never guesses kinds);
  /// - the row is unit-kind (a unit subject implements its own logic);
  /// - the feature has zero composable green unit subjects (nothing to
  ///   wire against — the acceptance prose remains uncomposable).
  ///
  /// Issue #939 — the WIDGET lane engages BEFORE all of the above: a
  /// widget-kind row's make path is the deterministic view-builder
  /// generation (`tdd view <id>` → `build`), shaped without anchor
  /// discovery because the minimal view is driven by the spec's declared
  /// Presentation layer contract + the behavior's scenario literals, not
  /// by the feature's green unit subjects (no anchor precondition — the
  /// loop must reach green through a generated skeleton exactly as func
  /// subjects do). Scenario-specific behavior inside the emitted view
  /// stays the sanctioned handcraft seam.
  ///
  /// The fallback shapes the acceptance plan through the pure
  /// `CompositionPlanner`; the planner itself (FR-008, SC-006) stays
  /// untouched and unaware of phases, run state, or subjects.
  Future<GenerationPlan?> _compositionFallback({
    required String cwd,
    required ArtifactRecord record,
    required String featureDir,
    required String featureName,
    required BehaviorSummary summary,
  }) async {
    // Issue #939 — the widget lane: a widget-kind target's make path is
    // the deterministic view-builder generation, shaped BEFORE anchor
    // discovery. The minimal view is driven by the spec's declared
    // Presentation layer contract + the behavior's scenario literals
    // (the same finders the paired widget test asserts), not by the
    // feature's green unit subjects, so no anchor precondition applies
    // (unlike the acceptance composition below). The generation step is
    // `zfa tdd view <id>` (registered alongside func/compose); the
    // composition gate's kind fix (widget treated like acceptance,
    // issue #939) governs the shared discovery surface for direct
    // `zfa tdd compose` callers.
    if (summary.kind == BehaviorKind.widget) {
      print(
        '   widget lane: view-builder generation (issue #939) — '
        'deterministic minimal view from the declared Presentation '
        'contract',
      );
      return GenerationPlan(
        behaviorId: summary.behaviorId,
        feature: summary.feature,
        sourceCriterion: summary.sourceCriterion,
        steps: [
          GenerationStepSpec(
            args: [
              'tdd',
              'view',
              summary.behaviorId,
              '--feature',
              summary.feature,
            ],
            purpose:
                'generate the minimal view for behavior '
                '${summary.behaviorId} from the declared Presentation '
                'layer contract (issue #939)',
          ),
          GenerationStepSpec(
            args: ['build'],
            purpose: 'build generated code for behavior ${summary.behaviorId}',
          ),
        ],
      );
    }
    final discovery = await const CompositionTargets().discover(
      projectRoot: cwd,
      featureDir: featureDir,
      behaviorId: record.behaviorId,
    );
    if (discovery is CompositionTargetFailure) {
      // Fail-closed: name the disengagement reason, keep the honest stop.
      print('   composition fallback disengaged: ${discovery.message}');
      return null;
    }
    final anchors = (discovery as CompositionTargetResolved).anchors;
    // Issue #923: the anchors may mix green subjects with entity-wired
    // stubs — name both so the fallback's report stays honest.
    final wiredCount = anchors.where((a) => a.entityWired).length;
    final anchorSummary = wiredCount == 0
        ? '${anchors.length} green unit subject(s)'
        : '${anchors.length - wiredCount} green, $wiredCount entity-wired '
              'unit subject(s)';
    print(
      '   composition fallback: $anchorSummary '
      '(${anchors.map((a) => a.behaviorId).join(', ')})',
    );
    return const CompositionPlanner().plan(summary, anchors);
  }

  // -------------------------------------------------------------------
  // Per-behavior guard for the make plan's terminal build step
  // (issue #737).
  // -------------------------------------------------------------------

  /// The per-behavior guard for the make plan's terminal `build` step
  /// (issue #737). Returns the passing target-test [RunRecord] when the
  /// tolerance engages, null otherwise (the honest `generation-error`
  /// stop stands).
  ///
  /// The plan's terminal `build` step validates the WHOLE project, so
  /// its non-zero exit can reflect pre-existing red suite state or
  /// build-config noise rather than this behavior's generation. The
  /// tolerance engages only when ALL of the following hold:
  ///
  ///   - the pipeline failed at the plan's TERMINAL step (an earlier
  ///     failure means real generation work never ran — no tolerance);
  ///   - that step is a `build` step (the #737 scope: the make plan's
  ///     build/guard logic only);
  ///   - the CURRENT behavior's own test — the profile `single`
  ///     command, e.g. `dart test test/tdd/u3_test.dart` — runs and
  ///     passes right now (the same per-behavior check the TDD loop is
  ///     built on; it also compiles the scaffolded subject, so broken
  ///     generated code still fails here).
  ///
  /// Anything else (launch failure, red target test, non-build step)
  /// returns null: safe-failure, never a silent pass.
  Future<RunRecord?> _toleratedTerminalBuildFailure({
    required SingleTestRunner runner,
    required GenerationPlan plan,
    required PipelineResult result,
    required String singleTemplate,
    required String testPath,
    required String testName,
    required String workingDirectory,
  }) async {
    final idx = result.firstFailureIndex;
    if (idx < 0 || idx != plan.steps.length - 1) return null;
    final args = plan.steps[idx].args;
    if (args.isEmpty || args.first != 'build') return null;
    final run = await runner.runSingle(
      singleTemplate: singleTemplate,
      testPath: testPath,
      testName: testName,
      workingDirectory: workingDirectory,
    );
    if (!run.startedProcess || run.exitCode != 0) return null;
    return run;
  }

  /// The behavior description the planner will see — the record's own
  /// parsing contract ([ArtifactRecord.descriptionSegment]): the
  /// description segment with any legacy `<id> — ` echo stripped
  /// (bug #871). Issue #873: stripping is canonical so the planner
  /// never reads the behavior's own id as an entity name.
  String _descriptionFor(ArtifactRecord record) => record.descriptionSegment;

  /// The target name parsed from the runnable name's description
  /// segment. For entity-bearing descriptions like "create entity
  /// User with email" the planner derives the entity name itself.
  String? _targetFor(ArtifactRecord record) {
    final desc = _descriptionFor(record);
    // For behaviors whose description names a target, return it.
    // Otherwise null and let the planner decide.
    final m = RegExp(r'entity\s+([A-Z][A-Za-z0-9_]*)').firstMatch(desc);
    if (m != null) return m.group(1);
    return null;
  }

  /// The runnable test name for `--plain-name` matching — the record's
  /// own contract ([ArtifactRecord.plainTestName]): the last segment with
  /// any legacy `<id> — ` echo stripped (bug #871), so both the legacy
  /// and the re-rendered test-file shapes substring-match.
  String _runnableNameOf(ArtifactRecord record) => record.plainTestName;

  /// Bug #829: the spec Key Entity this UNIT behavior's FR traces to —
  /// the first declared entity (from the test list's Key entities
  /// section, which plan extracted from the spec) named in the
  /// behavior's description. Null for non-unit behaviors and when
  /// nothing traces (no declared entities / no name match): those keep
  /// their existing routing unchanged.
  Future<String?> _tracedEntityFor({
    required ArtifactRecord record,
    required String featureDir,
  }) async {
    if (!GenerationPlanner.isUnitBehaviorId(record.behaviorId)) return null;
    final List<DeclaredEntity> declared;
    try {
      declared = await TestListReader(featureDir).readEntities();
    } on TestListReadException {
      return null;
    }
    if (declared.isEmpty) return null;
    final desc = _descriptionFor(record);
    for (final entity in declared) {
      final m = RegExp('\\b${RegExp.escape(entity.name)}\\b').firstMatch(desc);
      if (m != null) return entity.name;
    }
    return null;
  }

  /// Bug #829: realize `entity create` steps idempotently. The core
  /// command regenerates the entity file unconditionally, so re-running
  /// it over an existing entity would silently destroy hand-tuned
  /// fields. Any `entity create -n <Name>` step whose entity file
  /// already exists is dropped from the effective plan (printed, never
  /// silent); the rest of the pipeline generates against the existing
  /// entity. Applies to every branch that emits the step (the bug-829
  /// unit entity pipeline and the issue-#758 acceptance branch alike).
  Future<GenerationPlan> _gateExistingEntityCreateSteps(
    GenerationPlan plan, {
    required String workingDirectory,
  }) async {
    final kept = <GenerationStepSpec>[];
    var gated = false;
    for (final step in plan.steps) {
      final name = _entityCreateStepName(step.args);
      if (name != null &&
          await locateEntityFile(workingDirectory, name) != null) {
        print(
          '   entity $name already exists — reuse (never overwrite '
          'hand-tuned fields)',
        );
        gated = true;
        continue;
      }
      kept.add(step);
    }
    if (!gated) return plan;
    return GenerationPlan(
      behaviorId: plan.behaviorId,
      feature: plan.feature,
      sourceCriterion: plan.sourceCriterion,
      steps: kept,
      unexpressibleReason: plan.unexpressibleReason,
    );
  }

  /// The `-n <Name>` of an `entity create` step's args, or null when the
  /// step creates no entity (or carries an unexpected argv shape — left
  /// untouched, fail-open to the un-gated step).
  String? _entityCreateStepName(List<String> args) {
    if (args.length < 4) return null;
    if (args[0] != 'entity' || args[1] != 'create') return null;
    final idx = args.indexOf('-n');
    if (idx < 0 || idx + 1 >= args.length) return null;
    return args[idx + 1];
  }

  // -----------------------------------------------------------------
  // Suite-guard regression scoping (issue #731).
  // -----------------------------------------------------------------

  /// The NEW failures (guard − baseline, by name) that THIS make can
  /// be held responsible for (issue #731). A new failing identifier is
  /// a regression only when
  ///
  ///   - it lives in the current behavior's own test file — the file
  ///     this make owns, so any new red in it is this make's doing; or
  ///   - its file had NO failures at baseline — the whole file was
  ///     passing before this make, so a red there is a genuine
  ///     collateral regression.
  ///
  /// Failures confined to a file that was ALREADY red at baseline
  /// belong to a pre-existing red behavior (e.g. an acceptance test
  /// deferred to phase 2). Such a behavior stays red across the whole
  /// cycle by design, and its failing-test identifier may even vary
  /// between the two suite runs (dynamic test names), so it never
  /// blocks this make: if only the current behavior's test passes,
  /// the make certifies green/skipped regardless of other behaviors
  /// being red.
  List<String> _regressionsAttributableToThisMake({
    required SuiteSnapshot baseline,
    required List<String> newFailures,
    required String testPath,
  }) {
    final baselineRedFiles = baseline.failedTests.map(_testFileOf).toSet();
    final regressed = <String>[];
    for (final id in newFailures) {
      final file = _testFileOf(id);
      final inCurrentBehaviorFile = _sameTestFile(testPath, file);
      final fileWasAlreadyRed = baselineRedFiles.any(
        (redFile) => _sameTestFile(file, redFile),
      );
      if (inCurrentBehaviorFile || !fileWasAlreadyRed) {
        regressed.add(id);
      }
    }
    return regressed;
  }

  /// The test-file path embedded in a failing-test identifier (or in a
  /// target test path). Handles the three shapes the suite transcript
  /// produces:
  ///
  ///   - progress lines: `test/foo_test.dart: group name test name`
  ///     (everything before the first `:` is the file);
  ///   - load failures: `loading test/foo_test.dart`;
  ///   - target test paths, which are already bare file paths.
  String _testFileOf(String id) {
    var s = id.trim();
    const loading = 'loading ';
    if (s.startsWith(loading)) s = s.substring(loading.length);
    final idx = s.indexOf(':');
    if (idx > 0) s = s.substring(0, idx);
    return s.trim();
  }

  /// Whether two test-file paths denote the same file. Paths compared
  /// may mix absolute target paths with runner-printed relative ones,
  /// so the match is a boundary-aware suffix match (the `/` boundary
  /// keeps `xu2_test.dart` from matching `u2_test.dart`).
  bool _sameTestFile(String a, String b) {
    final x = a.replaceAll(r'\', '/');
    final y = b.replaceAll(r'\', '/');
    return x == y || x.endsWith('/$y') || y.endsWith('/$x');
  }

  Future<_ResolvedTarget> _resolveTarget(
    String cwd,
    String? behaviorId,
    String? featureFlag,
  ) async {
    final registries = await _scanRegistries(cwd, featureFlag);

    if (behaviorId != null) {
      final matches = <_ResolvedTarget>[];
      for (final entry in registries) {
        final record = await entry.registry.findRecord(behaviorId);
        if (record != null) {
          matches.add(
            _ResolvedTarget(record, entry.featureDir, entry.featureName),
          );
        }
      }
      if (matches.isEmpty) {
        final plannedFeature = await _isPlannedInTestList(
          cwd,
          behaviorId,
          featureFlag,
        );
        if (plannedFeature != null) {
          throw MakeResolutionError(
            'behavior "$behaviorId" is planned in the $plannedFeature test '
            'list but has no gen artifacts. Run `zfa tdd gen $behaviorId` '
            'first.',
            outcome: MakeOutcome.runnerError,
            feature: plannedFeature,
          );
        }
        throw MakeResolutionError(
          'unknown behavior id "$behaviorId". No matching record in any '
          'specs/<feature>/tdd/artifacts.json'
          '${featureFlag != null && featureFlag.isNotEmpty ? ' for feature $featureFlag' : ''}. '
          'Run `zfa tdd gen $behaviorId` to materialize it.',
          outcome: MakeOutcome.runnerError,
          feature: featureFlag,
        );
      }
      if (matches.length > 1) {
        final list = matches
            .map((m) => '${m.record.behaviorId} (${m.featureName})')
            .join(', ');
        throw MakeResolutionError(
          'ambiguous behavior id "$behaviorId" registered in multiple '
          'features: $list. Use --feature to disambiguate.',
          outcome: MakeOutcome.runnerError,
        );
      }
      final target = matches.single;
      await _requireTestArtifact(cwd, target);
      return target;
    }

    // No id: infer ONLY when exactly one behavior has gen artifacts
    // and certified-red evidence — the precondition for `make`.
    final candidates = <_ResolvedTarget>[];
    for (final entry in registries) {
      final certified = await _certifiedRedBehaviors(entry.featureDir);
      for (final record in await entry.registry.loadAll()) {
        if (certified.contains(record.behaviorId)) {
          final target = _ResolvedTarget(
            record,
            entry.featureDir,
            entry.featureName,
          );
          await _requireTestArtifact(cwd, target);
          candidates.add(target);
        }
      }
    }
    if (candidates.isEmpty) {
      throw MakeResolutionError(
        'no behavior with both gen artifacts and certified-red evidence — '
        'nothing to make. Run `zfa tdd verify-red <behavior-id>` first.',
        outcome: MakeOutcome.notCertifiedRed,
      );
    }
    if (candidates.length > 1) {
      final list = candidates
          .map((c) => '${c.record.behaviorId} (${c.featureName})')
          .join(', ');
      throw MakeResolutionError(
        'ambiguous invocation: multiple behaviors have certified-red '
        'evidence: $list. Pass an explicit behavior id.',
        outcome: MakeOutcome.runnerError,
      );
    }
    return candidates.single;
  }

  Future<void> _requireTestArtifact(String cwd, _ResolvedTarget target) async {
    final recordedPath = target.record.testPath;
    final testPath = p.isAbsolute(recordedPath)
        ? recordedPath
        : p.join(cwd, recordedPath);
    if (!await File(testPath).exists()) {
      throw MakeResolutionError(
        'the registry record for behavior "${target.record.behaviorId}" '
        'points to a missing test file at "$recordedPath". Run '
        '`zfa tdd gen ${target.record.behaviorId}` to restore its artifacts.',
        outcome: MakeOutcome.runnerError,
        feature: target.featureName,
      );
    }
  }

  Future<List<_RegistryEntry>> _scanRegistries(
    String cwd,
    String? featureFlag,
  ) async {
    if (featureFlag != null && featureFlag.isNotEmpty) {
      final featureDir = p.join(cwd, 'specs', featureFlag);
      return [
        _RegistryEntry(
          featureFlag,
          featureDir,
          ArtifactRegistry(featureDir: featureDir),
        ),
      ];
    }
    final specsDir = Directory(p.join(cwd, 'specs'));
    if (!await specsDir.exists()) return const [];
    final dirs = specsDir.listSync().whereType<Directory>().toList()
      ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    final entries = <_RegistryEntry>[];
    for (final dir in dirs) {
      final registryFile = File(p.join(dir.path, 'tdd', 'artifacts.json'));
      if (await registryFile.exists()) {
        final name = p.basename(dir.path);
        entries.add(
          _RegistryEntry(
            name,
            dir.path,
            ArtifactRegistry(featureDir: dir.path),
          ),
        );
      }
    }
    return entries;
  }

  /// Whether [behaviorId] has a red entry in the feature's cycle-log
  /// (the precondition for `make` per FR-001).
  Future<bool> _hasCertifiedRed(String featureDir, String behaviorId) async {
    final file = File(p.join(featureDir, 'tdd', 'cycle-log.md'));
    if (!await file.exists()) return false;
    final raw = await file.readAsString();
    for (final section in raw.split('\n## ')) {
      final behavior = RegExp(
        r'^- behavior: (\S+)',
        multiLine: true,
      ).firstMatch(section);
      if (behavior == null || behavior.group(1) != behaviorId) continue;
      return RegExp(r'^- kind: red$', multiLine: true).hasMatch(section);
    }
    return false;
  }

  /// Behavior ids that have a red entry in the feature's cycle-log.
  Future<Set<String>> _certifiedRedBehaviors(String featureDir) async {
    final file = File(p.join(featureDir, 'tdd', 'cycle-log.md'));
    if (!await file.exists()) return const {};
    final raw = await file.readAsString();
    final certified = <String>{};
    for (final section in raw.split('\n## ')) {
      final behavior = RegExp(
        r'^- behavior: (\S+)',
        multiLine: true,
      ).firstMatch(section);
      if (behavior == null) continue;
      if (RegExp(r'^- kind: red$', multiLine: true).hasMatch(section)) {
        certified.add(behavior.group(1)!);
      }
    }
    return certified;
  }

  /// Whether [behaviorId] appears as a row in any feature's
  /// `tdd/test-list.md`. Returns the feature name when found.
  Future<String?> _isPlannedInTestList(
    String cwd,
    String behaviorId,
    String? featureFlag,
  ) async {
    List<Directory> dirs;
    if (featureFlag != null && featureFlag.isNotEmpty) {
      dirs = [Directory(p.join(cwd, 'specs', featureFlag))];
    } else {
      final specsDir = Directory(p.join(cwd, 'specs'));
      if (!await specsDir.exists()) return null;
      dirs = specsDir.listSync().whereType<Directory>().toList()
        ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    }
    for (final dir in dirs) {
      final file = File(p.join(dir.path, 'tdd', 'test-list.md'));
      if (!await file.exists()) continue;
      final raw = await file.readAsString();
      for (final line in raw.split('\n')) {
        final trimmed = line.trimLeft();
        if (!trimmed.startsWith('|') || trimmed.contains('---')) continue;
        final cells = trimmed.split('|').map((s) => s.trim()).toList();
        if (cells.length > 1 && cells[1] == behaviorId) {
          return p.basename(dir.path);
        }
      }
    }
    return null;
  }

  // -------------------------------------------------------------------
  // Bug #826 — empty inner make plan pre-flight.
  // -------------------------------------------------------------------

  /// The entity/slug name when [plan]'s FIRST step is a bare
  /// `zfa make <name>` invocation — no explicit plugin ids after the name
  /// — i.e. the default-resolution shape whose active-plugin set the
  /// empty-plan pre-flight can mirror in-process. Null for every other
  /// plan shape (entity create, tdd func, tdd wire, composition, or a
  /// make step with explicit plugin ids), so the pre-flight never
  /// short-circuits a plan it cannot model.
  String? _bareMakeName(GenerationPlan plan) {
    if (plan.steps.isEmpty) return null;
    final first = plan.steps.first.args;
    if (first.length < 2 || first.first != 'make') return null;
    // Anything positional after the name is an explicit plugin id — the
    // child plan would not be the default-resolution shape.
    final explicitIds = first
        .skip(2)
        .where((a) => !a.startsWith('-'))
        .toList(growable: false);
    if (explicitIds.isNotEmpty) return null;
    return first[1];
  }

  /// Whether a real `zfa make <name>` child in [projectRoot] would resolve
  /// to zero active plugins — the "❌ No active plugins to run." branch of
  /// the make command. Mirrors the child's own resolution: same process
  /// registry, same project config, no explicit plugin ids, no preset.
  /// Any resolution error fails OPEN (the subprocess path runs as before).
  bool _innerMakePlanIsEmpty(String projectRoot, String name) {
    try {
      final manager = PluginManager(
        registry: PluginRegistry.instance,
        config: ZfaConfig.load(projectRoot: projectRoot),
        pluginConfig: PluginConfig.load(projectRoot: projectRoot),
        projectRoot: projectRoot,
      );
      return manager.resolvePlan(name: name).activePlugins.isEmpty;
    } catch (_) {
      return false;
    }
  }

  void _printSummary({
    required String behavior,
    required MakeOutcome outcome,
    required String feature,
  }) {
    print('make: behavior=$behavior outcome=${outcome.label} feature=$feature');
  }
}

/// `--feature` lands in a filesystem path: keep it a single plain
/// directory segment (mirrors verify_red_command.dart).
void _validateFeatureSegment(String feature) {
  if (feature.contains('/') ||
      feature.contains(r'\') ||
      feature == '.' ||
      feature == '..') {
    throw UsageException(
      'invalid --feature "$feature": expected a single spec directory name '
          'such as 047-tdd-make, not a path.',
      'zfa tdd make [<behavior-id>] [--feature <name>]',
    );
  }
}

class _RegistryEntry {
  const _RegistryEntry(this.featureName, this.featureDir, this.registry);

  final String featureName;
  final String featureDir;
  final ArtifactRegistry registry;
}

class _ResolvedTarget {
  const _ResolvedTarget(this.record, this.featureDir, this.featureName);

  final ArtifactRecord record;
  final String featureDir;
  final String featureName;
}
