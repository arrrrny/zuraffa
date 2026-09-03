/// `ReplayRunner` — executes a recorded history's replayable stages and
/// shapes the aggregate report (spec 066-zfa-replay, FR-008–FR-013).
///
/// Gen stage: every recorded generation step re-runs in the sandbox (cwd =
/// sandbox, bare `zfa` resolved through `--zfa-bin`, any recorded
/// `--project` defensively retargeted into the sandbox), then the sandbox's
/// `test/`+`lib/` trees are compared against the real project's via
/// `TreeSnapshot.changedPaths` — a normalized, path-stable diff (project-
/// relative forward-slash paths; the sandbox root never leaks).
///
/// Verify stage: the recorded green command re-runs in the sandbox via the
/// shell and must exit like recorded (green = 0). POSIX 126/127 (not
/// runnable / not found) classify as runner errors; any other non-zero
/// exit is a `verify-exit-mismatch` divergence. A project without a
/// package config skips verify (FR-011 — an environment gap is not a
/// reproduction failure).
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../../core/project/project_root.dart';
import 'replay_events.dart';
import 'replay_history.dart';
import 'replay_paths.dart';
import 'replay_sandbox.dart' show ReplaySandbox;
import 'tree_snapshot.dart';
import 'tdd_timeout.dart';

/// The replay stages, in execution order.
enum ReplayStage { integrity, gen, verify }

/// The per-stage outcomes.
enum ReplayStepStatus {
  /// Integrity stage: chain + red checks passed.
  verified,

  /// Gen stage: the regenerated trees are identical.
  identical,

  /// Verify stage: the recorded command exited like recorded.
  green,

  /// Gen stage: artifact paths differ from the real tree.
  drift,

  /// Any stage: a divergence (integrity break / drift / exit mismatch /
  /// runner error).
  diverged,

  /// Any stage: not replayable (recorded facts absent or environment gap).
  skipped,
}

/// One stage outcome for one behavior.
class ReplayStepResult {
  final String behavior;
  final ReplayStage stage;
  final ReplayStepStatus status;

  /// Skip reason or divergence detail.
  final String? reason;

  /// Drift paths (gen only), project-relative, sorted.
  final List<String> paths;

  /// Recorded exit (verify divergence).
  final int? expected;

  /// Actual exit (verify divergence / runner error).
  final int? actual;

  /// The broken entry kind (integrity divergence).
  final String? entry;

  const ReplayStepResult({
    required this.behavior,
    required this.stage,
    required this.status,
    this.reason,
    this.paths = const [],
    this.expected,
    this.actual,
    this.entry,
  });

  bool get ok =>
      status == ReplayStepStatus.verified ||
      status == ReplayStepStatus.identical ||
      status == ReplayStepStatus.green ||
      status == ReplayStepStatus.skipped;

  bool get executed =>
      (stage == ReplayStage.gen &&
          (status == ReplayStepStatus.identical ||
              status == ReplayStepStatus.drift)) ||
      (stage == ReplayStage.verify &&
          (status == ReplayStepStatus.green ||
              status == ReplayStepStatus.diverged));

  String get stageName => stage.name;

  String get statusName => status.name;
}

/// The aggregate replay report (FR-013).
class ReplayReport {
  final String feature;
  final Map<String, List<ReplayStepResult>> steps;

  const ReplayReport({required this.feature, required this.steps});

  static ReplayReport build({
    required String feature,
    required Map<String, List<ReplayStepResult>> steps,
  }) => ReplayReport(feature: feature, steps: steps);

  int get diverged => steps.values.where((s) => s.any((r) => !r.ok)).length;

  int get replayed => steps.values
      .where((s) => s.any((r) => r.executed))
      .where((s) => !s.any((r) => !r.ok))
      .length;

  int get skipped {
    final divergedCount = diverged;
    final replayedCount = replayed;
    return steps.length - divergedCount - replayedCount;
  }

  String get result => diverged > 0
      ? 'divergent'
      : replayed == 0
      ? 'partial'
      : 'clean';

  int get exit => diverged > 0
      ? 1
      : replayed == 0
      ? 2
      : 0;

  /// The machine summary line — the final stdout line on every code path.
  String get summaryLine =>
      'replay: feature=$feature result=$result '
      'replayed=$replayed skipped=$skipped diverged=$diverged';
}

class ReplayRunner {
  const ReplayRunner._();

  /// Gen stage (FR-008/FR-009): re-run the recorded generation steps in the
  /// sandbox, then compare the artifact trees path-stably.
  ///
  /// Spec 0806 FR-003/FR-004: each recorded step command is re-anchored
  /// before execution — the entrypoint pair re-resolves when locally broken
  /// ([zfaBin] takes precedence; otherwise the running dart / entrypoint
  /// via [resolvedDart]/[runningScript], which default to the platform
  /// facts), and every `<recordedRoot>/./` occurrence strips to
  /// sandbox-relative form so the recorded root never survives into a
  /// spawned process argument.
  static Future<ReplayStepResult> runGen(
    ReplayBehavior behavior, {
    required String sandboxPath,
    required String projectRoot,
    String? zfaBin,
    Duration? timeout,
    String? recordedRoot,
    String? resolvedDart,
    String? runningScript,
  }) async {
    if (!behavior.canReplayGen) {
      return ReplayStepResult(
        behavior: behavior.id,
        stage: ReplayStage.gen,
        status: ReplayStepStatus.skipped,
        reason: 'no generation block',
      );
    }
    final budget = timeout ?? TddTimeouts.defaultPipelineStep;
    for (final step in behavior.genSteps) {
      var command = step.command;
      // Spec 0806 FR-004: re-resolve a machine-absolute recorded
      // entrypoint pair when it is locally broken.
      command = ReplayPaths.reAnchorEntrypoint(
        command,
        zfaBin: zfaBin,
        resolvedDart: resolvedDart,
        runningScript: runningScript,
      );
      // Spec 0806 FR-003: strip the recorded root so the command runs
      // sandbox-relative (cwd = sandbox).
      command = ReplayPaths.reAnchorCommand(
        command,
        recordedRoot: recordedRoot,
      );
      // Defensive: a recorded `--project` must never point back at the
      // real project — replay retargets it into the sandbox.
      command = command.replaceAll(
        RegExp(r'--project(=|\s+)\S+'),
        '--project ${_shellQuote(sandboxPath)}',
      );
      try {
        final result = await runTimed(
          'sh',
          ['-c', command],
          workingDirectory: sandboxPath,
          timeout: budget,
        );
        if (result.exitCode != 0) {
          return ReplayStepResult(
            behavior: behavior.id,
            stage: ReplayStage.gen,
            status: ReplayStepStatus.diverged,
            reason:
                'runner-error: recorded gen step failed (exit '
                '${result.exitCode}): ${step.command}',
            actual: result.exitCode,
          );
        }
      } on ProcessTimeoutException {
        return ReplayStepResult(
          behavior: behavior.id,
          stage: ReplayStage.gen,
          status: ReplayStepStatus.diverged,
          reason: 'runner-error: recorded gen step timed out: ${step.command}',
        );
      }
    }
    final sandboxTree = await TreeSnapshot.capture(sandboxPath);
    final realTree = await TreeSnapshot.capture(projectRoot);
    final changed = realTree.changedPaths(sandboxTree);
    if (changed.isEmpty) {
      return ReplayStepResult(
        behavior: behavior.id,
        stage: ReplayStage.gen,
        status: ReplayStepStatus.identical,
        paths: const [],
      );
    }
    return ReplayStepResult(
      behavior: behavior.id,
      stage: ReplayStage.gen,
      status: ReplayStepStatus.drift,
      paths: changed,
      reason: _driftDetail(changed, realTree, sandboxTree),
    );
  }

  /// Verify stage (FR-010/FR-011): re-run the recorded green command in the
  /// sandbox and compare the exit with the recorded one.
  ///
  /// Spec 0806 FR-003: the recorded command's `<recordedRoot>/./` paths
  /// strip to sandbox-relative form before execution (cwd = sandbox).
  static Future<ReplayStepResult> runVerify(
    ReplayBehavior behavior, {
    required String sandboxPath,
    required String projectRoot,
    Duration? timeout,
    String? recordedRoot,
  }) async {
    final green = behavior.green;
    if (green == null || !behavior.canReplayVerify) {
      return ReplayStepResult(
        behavior: behavior.id,
        stage: ReplayStage.verify,
        status: ReplayStepStatus.skipped,
        reason: 'no green command',
      );
    }
    // FR-011: an environment gap is not a reproduction failure. A project
    // with a pubspec but no package config cannot run recorded test
    // commands — skip verify, gen replay still ran.
    final pubspec = File(p.join(projectRoot, 'pubspec.yaml'));
    final packageConfig = File(
      p.join(projectRoot, '.dart_tool', 'package_config.json'),
    );
    if (await pubspec.exists() && !await packageConfig.exists()) {
      return ReplayStepResult(
        behavior: behavior.id,
        stage: ReplayStage.verify,
        status: ReplayStepStatus.skipped,
        reason: 'no package resolution',
      );
    }
    final expected = green.exit ?? 0;
    final command = ReplayPaths.reAnchorCommand(
      green.command!,
      recordedRoot: recordedRoot,
    );
    try {
      final result = await runTimed(
        'sh',
        ['-c', command],
        workingDirectory: sandboxPath,
        timeout: timeout ?? TddTimeouts.defaultPipelineStep,
      );
      if (result.exitCode == expected) {
        return ReplayStepResult(
          behavior: behavior.id,
          stage: ReplayStage.verify,
          status: ReplayStepStatus.green,
          actual: result.exitCode,
        );
      }
      if (result.exitCode == 126 || result.exitCode == 127) {
        return ReplayStepResult(
          behavior: behavior.id,
          stage: ReplayStage.verify,
          status: ReplayStepStatus.diverged,
          reason:
              'runner-error: recorded command not runnable (exit '
              '${result.exitCode}): ${green.command}',
          expected: expected,
          actual: result.exitCode,
        );
      }
      return ReplayStepResult(
        behavior: behavior.id,
        stage: ReplayStage.verify,
        status: ReplayStepStatus.diverged,
        reason: 'verify-exit-mismatch',
        expected: expected,
        actual: result.exitCode,
      );
    } on ProcessTimeoutException {
      return ReplayStepResult(
        behavior: behavior.id,
        stage: ReplayStage.verify,
        status: ReplayStepStatus.diverged,
        reason: 'runner-error: recorded verify command timed out',
        expected: expected,
      );
    }
  }

  /// The human drift detail: `1 path: test/x modified` /
  /// `2 paths: test/a modified; lib/b added`.
  static String _driftDetail(
    List<String> paths,
    TreeSnapshot real,
    TreeSnapshot sandbox,
  ) {
    final classified = paths
        .map((path) {
          if (!real.entries.containsKey(path)) return '$path added';
          if (!sandbox.entries.containsKey(path)) return '$path missing';
          return '$path modified';
        })
        .join('; ');
    final noun = paths.length == 1 ? 'path' : 'paths';
    return '${paths.length} $noun: $classified';
  }

  static String _shellQuote(String value) =>
      value.contains(' ') ? "'$value'" : value;

  /// The replay capability both surfaces delegate to (spec 066 FR-001):
  /// resolve the feature, walk every selected behavior through
  /// integrity → gen → verify, print the house contract lines, write the
  /// optional NDJSON events, and return the process exit (FR-013: 0 clean /
  /// 1 divergence or infra failure / 2 nothing replayable; usage errors
  /// throw [UsageException] → 64).
  ///
  /// [featureArg] is a feature id (`066-zfa-replay`), a `specs/<id>`
  /// prefix, or a cycle-log path (`…/specs/<id>/tdd/cycle-log.md` — the
  /// `zfa replay` dream surface). The summary line is emitted as the final
  /// stdout line on every code path; the sandbox is deleted unless
  /// [keepSandbox].
  static Future<int> execute({
    required String featureArg,
    String? projectFlag,
    String? zfaBin,
    Duration? timeout,
    String? behaviorFilter,
    String? eventsPath,
    bool keepSandbox = false,
    void Function(String line) emit = print,
  }) async {
    final events = eventsPath == null || eventsPath.isEmpty
        ? null
        : await ReplayEvents.start(eventsPath);
    final steps = <String, List<ReplayStepResult>>{};
    var infraFailure = false;
    var exitToReturn = 1;
    ReplaySandbox? sandbox;
    String? feature;
    String? projectRoot;

    try {
      // ---- resolution -------------------------------------------------
      final resolvedFeature = await _resolveFeature(
        featureArg,
        projectFlag: projectFlag,
      );
      feature = resolvedFeature.feature;
      projectRoot = resolvedFeature.projectRoot;
      final featureDir = p.join(projectRoot, 'specs', feature);

      if (!await Directory(featureDir).exists()) {
        emit(
          'zfa tdd replay: no feature directory at specs/$feature '
          '(project root: $projectRoot)',
        );
        infraFailure = true;
        return 1;
      }
      final logFile = File(p.join(featureDir, 'tdd', 'cycle-log.md'));
      if (!await logFile.exists()) {
        emit(
          'zfa tdd replay: no recorded history for feature $feature at '
          'specs/$feature/tdd/cycle-log.md',
        );
        infraFailure = true;
        return 1;
      }
      final behaviors = await ReplayHistory.load(featureDir);
      events?.runStart(
        feature: feature,
        behaviors: [for (final b in behaviors) b.id],
      );

      if (behaviors.isEmpty) {
        emit(
          'zfa tdd replay: no machine-format entries recorded for feature '
          '$feature (narrative log?)',
        );
        return 2; // partial — nothing replayable (FR-013).
      }

      var selected = behaviors;
      if (behaviorFilter != null && behaviorFilter.isNotEmpty) {
        final match = behaviors
            .where((b) => b.id == behaviorFilter)
            .toList(growable: false);
        if (match.isEmpty) {
          emit(
            'zfa tdd replay: unknown behavior $behaviorFilter — recorded '
            'behaviors: ${behaviors.map((b) => b.id).join(', ')}',
          );
          infraFailure = true;
          return 1;
        }
        selected = match;
      }

      // Spec 0806 FR-001: detect the recorded project root from the
      // history's `- test:` anchor markers (all markers must agree; zero
      // or conflicting anchors disable re-anchoring entirely — 066
      // behavior). The root never appears in any report line.
      final recordedRoot = ReplayPaths.detectRecordedRoot([
        for (final behavior in behaviors)
          for (final entry in behavior.entries) entry.test,
      ]);

      sandbox = await ReplaySandbox.create(
        projectRoot: projectRoot,
        feature: feature,
        recordedRoot: recordedRoot,
      );
      emit(
        '[replay] feature=$feature project=$projectRoot '
        'sandbox=${sandbox.path}',
      );

      for (final behavior in selected) {
        final results = <ReplayStepResult>[];

        // ---- integrity stage (FR-004/FR-005) ----------------------
        events?.stepStart(behavior: behavior.id, step: ReplayStage.integrity);
        final integrity = await ReplayHistory.verifyIntegrity(
          behavior,
          projectRoot: projectRoot,
          recordedRoot: recordedRoot,
        );
        final integrityResult = integrity.ok
            ? ReplayStepResult(
                behavior: behavior.id,
                stage: ReplayStage.integrity,
                status: ReplayStepStatus.verified,
              )
            : ReplayStepResult(
                behavior: behavior.id,
                stage: ReplayStage.integrity,
                status: ReplayStepStatus.diverged,
                reason: integrity.reason,
                entry: integrity.brokenEntryKind,
              );
        results.add(integrityResult);
        events?.stepEnd(integrityResult);
        emit(
          '[replay] ${behavior.id} integrity -> '
          '${integrity.ok ? 'verified' : 'diverged (${integrity.reason})'}',
        );
        for (final kind in integrity.unverifiedKinds) {
          emit(
            '[replay] warning: ${behavior.id}: unverified: schema-0 '
            '($kind entry)',
          );
        }

        if (!integrity.ok) {
          // FR-004: a tampered history's commands are never executed.
          final genSkipped = ReplayStepResult(
            behavior: behavior.id,
            stage: ReplayStage.gen,
            status: ReplayStepStatus.skipped,
            reason: 'integrity diverged',
          );
          final verifySkipped = ReplayStepResult(
            behavior: behavior.id,
            stage: ReplayStage.verify,
            status: ReplayStepStatus.skipped,
            reason: 'integrity diverged',
          );
          results
            ..add(genSkipped)
            ..add(verifySkipped);
          events?.stepEnd(genSkipped);
          events?.stepEnd(verifySkipped);
          emit('[replay] ${behavior.id} gen -> skipped (integrity diverged)');
          emit(
            '[replay] ${behavior.id} verify -> skipped (integrity diverged)',
          );
          steps[behavior.id] = results;
          continue;
        }

        // ---- gen stage (FR-008/FR-009) ----------------------------
        events?.stepStart(behavior: behavior.id, step: ReplayStage.gen);
        final gen = await ReplayRunner.runGen(
          behavior,
          sandboxPath: sandbox.path,
          projectRoot: projectRoot,
          zfaBin: zfaBin,
          timeout: timeout,
          recordedRoot: recordedRoot,
          runningScript: _runningScriptPath(),
        );
        results.add(gen);
        events?.stepEnd(gen);
        emit('[replay] ${behavior.id} gen -> ${_stageLine(gen)}');

        // ---- verify stage (FR-010/FR-011) -------------------------
        events?.stepStart(behavior: behavior.id, step: ReplayStage.verify);
        final verify = await ReplayRunner.runVerify(
          behavior,
          sandboxPath: sandbox.path,
          projectRoot: projectRoot,
          timeout: timeout,
          recordedRoot: recordedRoot,
        );
        results.add(verify);
        events?.stepEnd(verify);
        emit('[replay] ${behavior.id} verify -> ${_stageLine(verify)}');

        // ---- refactor: recorded, never re-executed (FR-012) -------
        if (behavior.refactors.isNotEmpty) {
          final n = behavior.refactors.length;
          emit(
            '[replay] ${behavior.id} refactor -> recorded, not re-executed '
            '($n ${n == 1 ? 'entry' : 'entries'})',
          );
        }
        steps[behavior.id] = results;
      }
    } catch (error) {
      infraFailure = true;
      emit('zfa tdd replay: $error');
    } finally {
      if (!keepSandbox) {
        await sandbox?.delete();
      }
      final report = ReplayReport.build(
        feature: feature ?? featureArg,
        steps: steps,
      );
      final exit = infraFailure ? 1 : report.exit;
      final result = infraFailure ? 'divergent' : report.result;
      await events?.runEnd(
        result: result,
        replayed: report.replayed,
        skipped: report.skipped,
        diverged: report.diverged,
        exit: exit,
      );
      final sandboxSuffix = keepSandbox && sandbox != null
          ? ' sandbox=${sandbox.path}'
          : '';
      emit(
        'replay: feature=${feature ?? featureArg} result=$result '
        'replayed=${infraFailure ? 0 : report.replayed} '
        'skipped=${infraFailure ? 0 : report.skipped} '
        'diverged=${infraFailure ? 0 : report.diverged}'
        '$sandboxSuffix',
      );
      exitToReturn = exit;
    }
    return exitToReturn;
  }

  /// Feature resolution for both surfaces: a cycle-log path (the dream
  /// surface) derives the feature name and walks up from it for the
  /// project root; an id strips a `specs/` prefix and resolves against the
  /// standard root.
  static Future<({String feature, String projectRoot})> _resolveFeature(
    String featureArg, {
    String? projectFlag,
  }) async {
    if (p.basename(featureArg) == 'cycle-log.md') {
      final logPath = p.absolute(featureArg);
      final tddDir = p.dirname(logPath);
      final featureDir = p.dirname(tddDir);
      if (p.basename(tddDir) != 'tdd') {
        throw UsageException(
          'invalid cycle-log path "$featureArg": expected '
              '<project>/specs/<feature>/tdd/cycle-log.md',
          'zfa replay <feature|path/to/tdd/cycle-log.md>',
        );
      }
      final feature = p.basename(featureDir);
      _validateFeatureSegment(feature);
      final projectRoot = projectFlag != null && projectFlag.isNotEmpty
          ? p.absolute(projectFlag)
          : ProjectRoot.find(startPath: featureDir);
      return (feature: feature, projectRoot: projectRoot);
    }
    var stripped = featureArg;
    if (stripped.startsWith('specs/')) {
      final tail = stripped.substring('specs/'.length);
      stripped = tail.isEmpty ? featureArg : tail;
    }
    _validateFeatureSegment(stripped);
    final projectRoot = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find();
    return (feature: stripped, projectRoot: projectRoot);
  }

  /// Single plain directory segment (mirrors run_command.dart).
  static void _validateFeatureSegment(String feature) {
    if (feature.contains('/') ||
        feature.contains(r'\') ||
        feature == '.' ||
        feature == '..') {
      throw UsageException(
        'invalid feature "$feature": expected a single spec directory name '
            'such as 066-zfa-replay, not a path.',
        'zfa tdd replay <feature> [--project <dir>] [--zfa-bin <path>]',
      );
    }
  }

  /// The running CLI's own entrypoint script, when this CLI runs from source
  /// (spec 0806 FR-004's missing-zfa fallback): `Platform.script` is a
  /// `file://` URL whose path ends in `/bin/zfa.dart` or
  /// `/bin/zuraffa.dart`. A compiled/AOT CLI returns null — the recorded
  /// script is then kept and the spawn fails honestly as a runner-error.
  static String? _runningScriptPath() {
    final uri = Platform.script;
    if (uri.scheme != 'file') return null;
    final path = uri.toFilePath();
    final base = p.basename(path);
    if (base != 'zfa.dart' && base != 'zuraffa.dart') return null;
    return path;
  }

  /// The human rendering of one stage result (contracts/replay.md).
  static String _stageLine(ReplayStepResult result) {
    switch (result.status) {
      case ReplayStepStatus.verified:
        return 'verified';
      case ReplayStepStatus.identical:
        return 'identical (0 paths)';
      case ReplayStepStatus.green:
        return 'green (exit ${result.actual ?? 0})';
      case ReplayStepStatus.drift:
        return 'drift (${result.reason})';
      case ReplayStepStatus.diverged:
        if (result.reason == 'verify-exit-mismatch') {
          return 'diverged (exit expected ${result.expected}, '
              'actual ${result.actual})';
        }
        return 'diverged (${result.reason})';
      case ReplayStepStatus.skipped:
        return 'skipped (${result.reason})';
    }
  }
}
