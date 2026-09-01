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
///      STILL fails (FR-003); an already-green test is reported as
///      `drift` and stops non-zero (US2.AC3).
///   4. Plans the minimal generation through the zuraffa pipeline
///      (FR-005): `entity create` / `make` / `build` (never hand-
///      writes source, never edits tests — FR-004).
///   5. Executes the plan via [PipelineRunner], capturing every
///      invocation as a [GenerationStep] (FR-006). Misfire-stop on
///      unexpressible behaviors (US4) or failing generation steps
///      (US4.AC2).
///   6. Runs the target test via the profile `single` command and
///      requires a PASS (FR-007). Then runs the full suite via the
///      profile `suite` command and requires NO NEW failures
///      relative to a pre-run baseline (US3).
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

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../models/generation_plan.dart';
import '../services/artifact_registry.dart';
import '../services/composition_planner.dart';
import '../services/composition_targets.dart';
import '../services/cycle_log.dart';
import '../services/generation_planner.dart';
import '../services/pipeline_runner.dart';
import '../services/runner.dart';
import '../services/suite_guard.dart';
import '../tdd_plugin.dart';

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
        : Directory.current.path;
    final zfaBinFlag = argResults?['zfa-bin'] as String?;

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
    // 4. Drift check: re-run target test BEFORE generation (FR-003).
    //    If it passes, the behavior was hand-implemented — refuse.
    // ---------------------------------------------------------------
    final driftRun = await runner.runSingle(
      singleTemplate: singleTemplate,
      testPath: testPath,
      testName: testName,
      workingDirectory: cwd,
    );
    if (driftRun.exitCode == 0 && driftRun.startedProcess) {
      print(
        'zfa tdd make: target test already passes — drift detected. '
        'Run `zfa tdd verify-red ${record.behaviorId}` to re-certify '
        'the red, or revert the hand-written implementation.',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: MakeOutcome.drift,
        feature: target.featureName,
      );
      exitCode = 1;
      return;
    }

    // ---------------------------------------------------------------
    // 5. Pre-run suite baseline (FR-007 / US3.AC3).
    // ---------------------------------------------------------------
    print('   suite baseline: $suiteTemplate');
    final baselineRun = await runner.runSuite(
      suiteTemplate: suiteTemplate,
      workingDirectory: cwd,
    );
    final baseline = guard.fromRunRecord(
      record: baselineRun,
      capturedAt: DateTime.now().toUtc().toIso8601String(),
    );
    print(
      '   baseline exit: ${baseline.exitCode}, failed: ${baseline.failedTests.length}',
    );
    if (!baselineRun.startedProcess ||
        !baseline.parseable ||
        baseline.exitCode != 0 && baseline.failedTests.isEmpty) {
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

    // ---------------------------------------------------------------
    // 6. Plan the minimal generation (FR-005).
    // ---------------------------------------------------------------
    final summary = BehaviorSummary.fromRecord(
      record,
      description: _descriptionFor(record),
      target: _targetFor(record),
    );
    final plan = planner.plan(summary);
    GenerationPlan effectivePlan;
    if (plan.isExpressible) {
      effectivePlan = plan;
      print('   plan: ${plan.steps.length} step(s)');
    } else {
      // -------------------------------------------------------------
      // Composition fallback (issue #642, spec 052): the planner is pure
      // and description-keyed, so an acceptance behavior's prose stays
      // unexpressible to it BY DESIGN — deterministically across run
      // phases. When the target's test-list row is acceptance-kind and
      // the feature holds composable green unit subjects, offer the
      // composition plan (compose → build) that wires the acceptance
      // subject against them, so a deferred phase-2 acceptance make can
      // actually flip green. Everything else keeps the honest stop:
      // unit-kind behaviors and unknown rows (fail-closed), and
      // acceptance prose with zero composable anchors (FR-009), report
      // `unexpressible` exactly as before.
      // -------------------------------------------------------------
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

    // ---------------------------------------------------------------
    // 7. Execute the plan via the pipeline (FR-006, US1 / U8-U13).
    // ---------------------------------------------------------------
    PipelineResult pipelineResult;
    try {
      pipelineResult = await pipelineRunner.runPlan(
        plan: effectivePlan,
        workingDirectory: cwd,
        zfaBinOverride: zfaBinFlag,
        feature: target.featureName,
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

    // Misfire-stop on generation failure (FR-004, US4.AC2).
    if (!pipelineResult.completed) {
      final idx = pipelineResult.firstFailureIndex;
      final failed = idx >= 0 && idx < pipelineResult.steps.length
          ? pipelineResult.steps[idx]
          : null;
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

    // ---------------------------------------------------------------
    // 8. Target test post-generation (FR-007).
    // ---------------------------------------------------------------
    final postRun = await runner.runSingle(
      singleTemplate: singleTemplate,
      testPath: testPath,
      testName: testName,
      workingDirectory: cwd,
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

    // ---------------------------------------------------------------
    // 9. Suite guard (FR-007, US3).
    // ---------------------------------------------------------------
    final guardRun = await runner.runSuite(
      suiteTemplate: suiteTemplate,
      workingDirectory: cwd,
    );
    final guardSnap = guard.fromRunRecord(
      record: guardRun,
      capturedAt: DateTime.now().toUtc().toIso8601String(),
    );
    final diff = guard.diff(baseline: baseline, guard: guardSnap);
    if (!guardRun.startedProcess ||
        !guardSnap.parseable ||
        guardSnap.exitCode != 0 && guardSnap.failedTests.isEmpty) {
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
    if (diff.hasNewFailures) {
      print(
        'zfa tdd make: regression detected — ${diff.newFailures.length} '
        'NEW failure(s) introduced by the generation:',
      );
      for (final id in diff.newFailures) {
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

    // ---------------------------------------------------------------
    // 10. Green evidence append (FR-008).
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
        generationSteps: pipelineResult.steps,
        suiteBaselineFailures: baseline.failedTests.length,
        suiteGuardFailures: guardSnap.failedTests.length,
        suiteNewFailures: diff.newFailures,
      ),
    );
    print(
      '   green evidence appended to specs/${target.featureName}/tdd/'
      'cycle-log.md',
    );
    _printSummary(
      behavior: record.behaviorId,
      outcome: MakeOutcome.green,
      feature: target.featureName,
    );
    exitCode = 0;
  }

  // -------------------------------------------------------------------
  // Helpers — resolution + summary (mirror verify_red_command.dart).
  // -------------------------------------------------------------------

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
  /// The fallback shapes the plan through the pure `CompositionPlanner`;
  /// the planner itself (FR-008, SC-006) stays untouched and unaware of
  /// phases, run state, or subjects.
  Future<GenerationPlan?> _compositionFallback({
    required String cwd,
    required ArtifactRecord record,
    required String featureDir,
    required String featureName,
    required BehaviorSummary summary,
  }) async {
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
    print(
      '   composition fallback: ${anchors.length} green unit subject(s) '
      '(${anchors.map((a) => a.behaviorId).join(', ')})',
    );
    return const CompositionPlanner().plan(summary, anchors);
  }

  /// The behavior description the planner will see. The fixture's
  /// registry record carries only the runnable test name composite
  /// (`file::id::description`) — extract the description segment.
  String _descriptionFor(ArtifactRecord record) {
    final parts = record.runnableTestName.split('::');
    return parts.length >= 3 ? parts[2] : record.behaviorId;
  }

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

  /// The runnable test name: the last `::`-separated segment of the
  /// registry's composite `file::group::test` name.
  String _runnableNameOf(ArtifactRecord record) {
    final segments = record.runnableTestName.split('::');
    return segments.isEmpty || segments.last.isEmpty
        ? record.runnableTestName
        : segments.last;
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
