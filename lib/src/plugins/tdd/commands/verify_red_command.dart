/// `zfa tdd verify-red` — the honest-red gate for the TDD loop
/// (spec 046-tdd-verify-red, FR-001..010; 041 Phase 7, T055-T061).
///
/// The command:
///   1. Resolves the target behavior's test path + runnable test name
///      from the artifact registry written by `zfa tdd gen` (FR-001) —
///      never by globbing. Explicit unknown ids are rejected before any
///      run (FR-002); with no id, the target is inferred only when
///      exactly one behavior has gen artifacts and no red evidence.
///   2. Loads the `single` command template from
///      `.specify/memory/tdd-profile.md` (FR-003) and executes exactly
///      the target test through it via [SingleTestRunner].
///   3. Classifies the outcome into exactly one of six classes (FR-004)
///      and rejects blended/empty runs (FR-005).
///   4. On `assertion` ONLY, appends the 8-field red-evidence entry to
///      `specs/<feature>/tdd/cycle-log.md` (FR-006). The log is
///      append-only.
///   5. On any other class, exits non-zero with a named classification
///      and a remediation hint, writing no evidence (FR-007).
///   6. Never modifies, creates, or deletes anything under `test/` or
///      `lib/` (FR-008) — the only write is the cycle-log append.
///   7. Prints the machine-readable summary line
///      `verify-red: behavior=<id> classification=<class> certified=<bool> feature=<feature>`
///      as the final stdout line on every code path (FR-009); exit code
///      0 means exactly "honest red certified".
///   8. Misfire-stops: any internal step that cannot complete stops the
///      command immediately, non-zero, with a clear message (FR-010).
///
/// Rejections and misfires are signaled through dart:io `exitCode` (which
/// [CliRunner] honors) rather than by throwing, so the summary line stays
/// the final stdout line. `classification=unresolved` marks pre-run
/// failures (resolution/misfire) where no test was executed.
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/red_classification.dart';
import '../services/artifact_registry.dart';
import '../services/cycle_log.dart';
import '../services/red_classifier.dart';
import '../services/runner.dart';
import '../services/tdd_timeout.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

/// Resolution-stage failure: message + the feature context if known.
class VerifyRedResolutionError implements Exception {
  VerifyRedResolutionError(this.message, {this.feature});

  final String message;
  final String? feature;

  @override
  String toString() => message;
}

class VerifyRedCommand extends Command<void> {
  VerifyRedCommand(this.plugin) {
    argParser.addFlag(
      'all',
      negatable: false,
      defaultsTo: false,
      help:
          'Batch red verification (spec 069-corpus-economics, issue #916): '
          'certify EVERY behavior that has gen artifacts and no red '
          'evidence yet, through ONE suite invocation (the profile `suite` '
          'template + the batch\u2019s test file paths) instead of one '
          '`dart test` spawn per behavior (issues #792/#785). Per-behavior '
          'honesty is preserved: each behavior\u2019s test result is segmented '
          'from the batch transcript and classified independently \u2014 '
          'assertion-failing behaviors are certified, any other class is '
          'a named rejection. The batch machine line '
          '`verify-red: batch behaviors=<n> certified=<x> spawns=<k> '
          'feature=<f>` is the final stdout line.',
    );
    argParser.addOption(
      'feature',
      help:
          'Feature name (e.g. 046-tdd-verify-red). Restricts target '
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
      'timeout',
      valueHelp: 'minutes',
      help:
          'Hard deadline in minutes for the spawned target-test process (bug '
          '#742; default 2). Fractions are allowed (0.5 = 30 seconds). On '
          'timeout the child is killed and the command stops non-zero with '
          'classification runner-error.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'verify-red';

  @override
  String get description =>
      'Prove the target test is honestly red (assertion failure), append '
      'the red evidence to tdd/cycle-log.md, and exit 0 — or name the '
      'dishonest failure class and exit non-zero (spec 046).';

  @override
  String get invocation =>
      'zfa tdd verify-red [<behavior-id>] [--feature <name>] '
      '[--project <path>]';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    final batchAll = argResults!['all'] as bool;
    final behaviorId = rest.isNotEmpty ? rest.first : null;
    if (batchAll && behaviorId != null) {
      usageException(
        'zfa tdd verify-red --all takes no behavior id — it batches every '
        'gen\'d-but-uncertified behavior itself.',
      );
    }
    if (batchAll) {
      await _runBatch(
        cwd: _projectRoot(argResults),
        featureFlag: _normalizedFeatureFlag(argResults),
        timeoutOverride: _parsedTimeout(argResults),
      );
      return;
    }
    final rawFeatureFlag = argResults?['feature'] as String?;
    final featureFlag = (rawFeatureFlag != null && rawFeatureFlag.isNotEmpty)
        ? _stripSpecsPrefix(rawFeatureFlag)
        : rawFeatureFlag;
    if (featureFlag != null && featureFlag.isNotEmpty) {
      _validateFeatureSegment(featureFlag);
    }
    // Prefer an explicit --project root so the command never depends on the
    // process-global Directory.current (which other concurrent tests can
    // mutate). Falls back to the current working directory for real CLI use.
    final projectFlag = argResults?['project'] as String?;
    final cwd = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');

    // Bug #742: the --timeout override for the spawned target-test process.
    Duration? timeoutOverride;
    try {
      timeoutOverride = parseTddTimeoutMinutes(
        argResults?['timeout'] as String?,
      );
    } on TddTimeoutFormatException catch (e) {
      print('zfa tdd verify-red: ${e.message}');
      _printSummary(
        behavior: behaviorId ?? '-',
        classification: 'unresolved',
        certified: false,
        feature: featureFlag ?? 'unknown',
      );
      exitCode = 1;
      return;
    }

    // ---------------------------------------------------------------
    // 1. Resolve the target from the registry (FR-001, FR-002).
    // ---------------------------------------------------------------
    _ResolvedTarget target;
    try {
      target = await _resolveTarget(cwd, behaviorId, featureFlag);
    } on VerifyRedResolutionError catch (e) {
      print('zfa tdd verify-red: ${e.message}');
      _printSummary(
        behavior: behaviorId ?? '-',
        classification: 'unresolved',
        certified: false,
        feature: e.feature ?? featureFlag ?? 'unknown',
      );
      exitCode = 1;
      return;
    }
    final record = target.record;
    print('zfa tdd verify-red: behavior ${record.behaviorId}');
    print('   feature: ${target.featureName}');
    print('   test: ${record.testPath}');

    // ---------------------------------------------------------------
    // 2. Load the profile single template (FR-003, misfire-stop U27).
    // ---------------------------------------------------------------
    final runner = const SingleTestRunner();
    String template;
    try {
      template = await runner.loadSingleTemplate(workingDirectory: cwd);
    } on StateError catch (e) {
      print(e.message);
      _printSummary(
        behavior: record.behaviorId,
        classification: 'unresolved',
        certified: false,
        feature: target.featureName,
      );
      exitCode = 1;
      return;
    }

    // ---------------------------------------------------------------
    // 3. Execute exactly the target test (FR-003).
    // ---------------------------------------------------------------
    final testPath = p.isAbsolute(record.testPath)
        ? record.testPath
        : p.join(cwd, record.testPath);
    final testName = _runnableNameOf(record);
    print('   command: $template');
    _ReadOnlyTreeSnapshot beforeRun;
    try {
      beforeRun = await _ReadOnlyTreeSnapshot.capture(cwd);
    } on FileSystemException catch (e) {
      print('zfa tdd verify-red: cannot snapshot test/ and lib/: ${e.message}');
      _printSummary(
        behavior: record.behaviorId,
        classification: 'unresolved',
        certified: false,
        feature: target.featureName,
      );
      exitCode = 1;
      return;
    }
    final run = await runner.runSingle(
      singleTemplate: template,
      testPath: testPath,
      testName: testName,
      workingDirectory: cwd,
      timeout: timeoutOverride,
    );
    print('   runner exit: ${run.exitCode}');
    if (run.timedOut) {
      // Bug #742: name the behavior, the step, and the command, then stop
      // non-zero — the classification below is runner-error either way.
      print(
        'zfa tdd verify-red: behavior "${record.behaviorId}" — target test '
        'timed out: ${run.output}',
      );
      print(
        '   re-run with a larger --timeout <minutes> if the test '
        'legitimately needs longer.',
      );
    }

    List<String> changedPaths;
    try {
      final afterRun = await _ReadOnlyTreeSnapshot.capture(cwd);
      changedPaths = beforeRun.changedPaths(afterRun);
    } on FileSystemException catch (e) {
      changedPaths = ['snapshot failed: ${e.message}'];
    }
    if (changedPaths.isNotEmpty) {
      const classification = RedClassification.runnerError;
      print('   classification: ${classification.label}');
      print(
        'zfa tdd verify-red: read-only integrity violation under test/ or lib/: '
        '${changedPaths.join(', ')}',
      );
      print('   no evidence written');
      _printSummary(
        behavior: record.behaviorId,
        classification: classification.label,
        certified: false,
        feature: target.featureName,
      );
      exitCode = 1;
      return;
    }

    // ---------------------------------------------------------------
    // 4. Classify (FR-004, FR-005).
    // ---------------------------------------------------------------
    final classification = classify(run);
    print('   classification: ${classification.label}');

    // ---------------------------------------------------------------
    // 5/6. Evidence on assertion only; rejection otherwise (FR-006/007).
    // ---------------------------------------------------------------
    if (classification == RedClassification.assertion) {
      final log = CycleLog(target.featureDir);
      await log.append(
        CycleLogEntry(
          behaviorId: record.behaviorId,
          kind: CycleEntryKind.red,
          runnerCommand: run.command,
          exitCode: run.exitCode,
          capturedOutput: run.output,
          classification: FailureClass.assertionFailure,
          sourceCriterion: record.sourceCriterion,
          testPath: record.testPath,
          timestamp: DateTime.now().toUtc().toIso8601String(),
        ),
      );
      print(
        '   red evidence appended to specs/${target.featureName}/tdd/'
        'cycle-log.md',
      );
      _printSummary(
        behavior: record.behaviorId,
        classification: classification.label,
        certified: true,
        feature: target.featureName,
      );
      exitCode = 0;
      return;
    }

    stderr.writeln(
      'zfa tdd verify-red: classification ${classification.label} — '
      '${classification.remediationHint}',
    );
    stderr.writeln('   no evidence written');
    _printSummary(
      behavior: record.behaviorId,
      classification: classification.label,
      certified: false,
      feature: target.featureName,
    );
    exitCode = 1;
  }

  // -------------------------------------------------------------------
  // Batch mode (spec 069-corpus-economics, issue #916): --all.
  // -------------------------------------------------------------------

  /// The resolved project root for the batch path (the single-mode
  /// resolution contract, extracted so both paths share it).
  String _projectRoot(ArgResults? argResults) {
    final projectFlag = argResults?['project'] as String?;
    return projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');
  }

  /// The --feature flag, `specs/`-prefix stripped and segment-validated.
  String? _normalizedFeatureFlag(ArgResults? argResults) {
    final raw = argResults?['feature'] as String?;
    if (raw == null || raw.isEmpty) return raw;
    final feature = _stripSpecsPrefix(raw);
    if (feature.isNotEmpty) _validateFeatureSegment(feature);
    return feature;
  }

  /// The --timeout override (null when absent; a bad value is a usage
  /// error, the #742 house contract).
  Duration? _parsedTimeout(ArgResults? argResults) {
    final raw = argResults?['timeout'] as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      return parseTddTimeoutMinutes(raw);
    } on TddTimeoutFormatException catch (e) {
      usageException('zfa tdd verify-red: ${e.message}');
    }
  }

  /// The batch flow: resolve every gen'd-but-uncertified behavior, run
  /// ONE suite invocation scoped to their test files, segment the
  /// transcript per file, classify each behavior independently, and
  /// append red evidence for every assertion-classified behavior.
  Future<void> _runBatch({
    required String cwd,
    String? featureFlag,
    Duration? timeoutOverride,
  }) async {
    // 1. Candidates: every behavior with gen artifacts and no red
    //    evidence (the single-mode inference set, ALL of it — with
    //    --feature restricted to that feature).
    final registries = await _scanRegistries(cwd, featureFlag);
    final candidates = <_ResolvedTarget>[];
    for (final entry in registries) {
      final certified = await _certifiedBehaviors(entry.featureDir);
      for (final record in await entry.registry.loadAll()) {
        if (certified.contains(record.behaviorId)) continue;
        candidates.add(
          _ResolvedTarget(record, entry.featureDir, entry.featureName),
        );
      }
    }
    final batchFeatureLabel = featureFlag != null && featureFlag.isNotEmpty
        ? featureFlag
        : (candidates.isEmpty ? 'unknown' : candidates.first.featureName);
    if (candidates.isEmpty) {
      print(
        'zfa tdd verify-red --all: every gen\u2019d behavior already has '
        'red evidence — nothing to certify.',
      );
      _printBatchSummary(
        behaviors: 0,
        certified: 0,
        spawns: 0,
        feature: batchFeatureLabel,
      );
      return;
    }

    // 2. The suite template + ONE scoped spawn (the batch's whole
    //    economics: one compile, one process).
    final runner = const SingleTestRunner();
    String suiteTemplate;
    try {
      suiteTemplate = await runner.loadSuiteTemplate(workingDirectory: cwd);
    } on StateError catch (e) {
      print(e.message);
      _printBatchSummary(
        behaviors: candidates.length,
        certified: 0,
        spawns: 0,
        feature: batchFeatureLabel,
      );
      exitCode = 1;
      return;
    }

    // Read-only integrity: the batch never modifies test/ or lib/.
    final beforeRun = await _ReadOnlyTreeSnapshot.capture(cwd);
    final testPaths = candidates
        .map((c) => p.normalize(p.relative(c.record.testPath, from: cwd)))
        .toList();
    print(
      'zfa tdd verify-red --all: batching ${candidates.length} '
      'behavior(s) into ONE suite invocation [069]',
    );
    print('   command: $suiteTemplate');
    print('   scope: ${testPaths.length} test file(s)');
    final batch = await runner.runScopedSuite(
      suiteTemplate: suiteTemplate,
      testPaths: testPaths,
      workingDirectory: cwd,
      timeout: timeoutOverride,
    );
    print('   runner exit: ${batch.exitCode}');
    if (batch.timedOut) {
      print(
        'zfa tdd verify-red --all: the batch suite timed out: '
        '${batch.output}',
      );
      print(
        '   re-run with a larger --timeout <minutes> if the batch '
        'legitimately needs longer.',
      );
      _printBatchSummary(
        behaviors: candidates.length,
        certified: 0,
        spawns: 1,
        feature: batchFeatureLabel,
      );
      exitCode = 1;
      return;
    }

    // 3. Read-only integrity check (FR-008, the batch contract too).
    List<String> changedPaths;
    try {
      final afterRun = await _ReadOnlyTreeSnapshot.capture(cwd);
      changedPaths = beforeRun.changedPaths(afterRun);
    } on FileSystemException catch (e) {
      changedPaths = ['snapshot failed: ${e.message}'];
    }
    if (changedPaths.isNotEmpty) {
      print(
        'zfa tdd verify-red --all: read-only integrity violation under '
        'test/ or lib/: ${changedPaths.join(', ')}',
      );
      _printBatchSummary(
        behaviors: candidates.length,
        certified: 0,
        spawns: 1,
        feature: batchFeatureLabel,
      );
      exitCode = 1;
      return;
    }

    // 4. Segment the batch transcript per test file and classify each
    //    behavior independently (the per-behavior honesty contract).
    final segments = BatchTranscript.segment(batch.output, testPaths.toSet());
    var certified = 0;
    for (final target in candidates) {
      final relPath = p.normalize(
        p.relative(target.record.testPath, from: cwd),
      );
      final segment = segments[relPath];
      final perRecord = RunRecord(
        command: batch.command,
        exitCode: segment == null || segment.failed ? 1 : 0,
        output: segment?.text ?? '',
        startedProcess: batch.startedProcess,
        testCount: segment?.testCount,
        timedOut: batch.timedOut,
      );
      final classification = classify(perRecord);
      final isCertified = classification == RedClassification.assertion;
      print(
        '   ${target.record.behaviorId}: '
        '${segment == null ? "not-in-transcript" : classification.label}'
        '${isCertified ? " (certified)" : ""}',
      );
      if (isCertified) {
        final log = CycleLog(target.featureDir);
        await log.append(
          CycleLogEntry(
            behaviorId: target.record.behaviorId,
            kind: CycleEntryKind.red,
            runnerCommand: batch.command,
            exitCode: perRecord.exitCode,
            capturedOutput: perRecord.output,
            classification: FailureClass.assertionFailure,
            sourceCriterion: target.record.sourceCriterion,
            testPath: target.record.testPath,
            timestamp: DateTime.now().toUtc().toIso8601String(),
          ),
        );
        certified++;
      } else if (segment == null) {
        stderr.writeln(
          'zfa tdd verify-red --all: behavior '
          '"${target.record.behaviorId}" produced no result in the batch '
          'transcript (${target.record.testPath}) — the runner did not '
          'execute it. No evidence written.',
        );
      } else {
        stderr.writeln(
          'zfa tdd verify-red --all: behavior '
          '"${target.record.behaviorId}" classified '
          '${classification.label} \u2014 ${classification.remediationHint}',
        );
        stderr.writeln('   no evidence written');
      }
    }

    _printBatchSummary(
      behaviors: candidates.length,
      certified: certified,
      spawns: 1,
      feature: batchFeatureLabel,
    );
    exitCode = certified == candidates.length ? 0 : 1;
  }

  void _printBatchSummary({
    required int behaviors,
    required int certified,
    required int spawns,
    required String feature,
  }) {
    print(
      'verify-red: batch behaviors=$behaviors certified=$certified '
      'spawns=$spawns feature=$feature',
    );
  }

  // -------------------------------------------------------------------
  // Target resolution (FR-001, FR-002, SC-004)
  // -------------------------------------------------------------------

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
        // FR-002 / U22: distinguish "planned but not gen'd" from unknown.
        final plannedFeature = await _isPlannedInTestList(
          cwd,
          behaviorId,
          featureFlag,
        );
        if (plannedFeature != null) {
          throw VerifyRedResolutionError(
            'behavior "$behaviorId" is planned in the $plannedFeature test '
            'list but has no gen artifacts. Run `zfa tdd gen $behaviorId` '
            'first.',
            feature: plannedFeature,
          );
        }
        throw VerifyRedResolutionError(
          'unknown behavior id "$behaviorId". No matching record in any '
          'specs/<feature>/tdd/artifacts.json'
          '${featureFlag != null && featureFlag.isNotEmpty ? ' for feature $featureFlag' : ''}. '
          'Run `zfa tdd gen $behaviorId` to materialize it.',
          feature: featureFlag,
        );
      }
      if (matches.length > 1) {
        final list = matches
            .map((m) => '${m.record.behaviorId} (${m.featureName})')
            .join(', ');
        throw VerifyRedResolutionError(
          'ambiguous behavior id "$behaviorId" registered in multiple '
          'features: $list. Use --feature to disambiguate.',
        );
      }
      return matches.single;
    }

    // No id: infer ONLY when exactly one behavior has gen artifacts and
    // no red evidence yet (FR-002, U19-U21).
    final candidates = <_ResolvedTarget>[];
    for (final entry in registries) {
      final certified = await _certifiedBehaviors(entry.featureDir);
      for (final record in await entry.registry.loadAll()) {
        if (!certified.contains(record.behaviorId)) {
          candidates.add(
            _ResolvedTarget(record, entry.featureDir, entry.featureName),
          );
        }
      }
    }
    if (candidates.isEmpty) {
      throw VerifyRedResolutionError(
        'no behavior with gen artifacts lacks red evidence — nothing to '
        'verify. Run `zfa tdd gen <behavior-id>` first.',
      );
    }
    if (candidates.length > 1) {
      final list = candidates
          .map((c) => '${c.record.behaviorId} (${c.featureName})')
          .join(', ');
      throw VerifyRedResolutionError(
        'ambiguous invocation: multiple behaviors have gen artifacts and '
        'no red evidence: $list. Pass an explicit behavior id.',
      );
    }
    return candidates.single;
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

  /// Behavior ids that already have a red entry in the feature's
  /// cycle-log (evidence of a certified red).
  Future<Set<String>> _certifiedBehaviors(String featureDir) async {
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
        // Row shape: `| <id> | <behavior> | ...` — the first cell after
        // the leading pipe is the behavior id.
        final cells = trimmed.split('|').map((s) => s.trim()).toList();
        if (cells.length > 1 && cells[1] == behaviorId) {
          return p.basename(dir.path);
        }
      }
    }
    return null;
  }

  /// The runnable test name for `--plain-name` matching — the record's
  /// own contract ([ArtifactRecord.plainTestName]): the last segment with
  /// any legacy `<id> — ` echo stripped (bug #871).
  String _runnableNameOf(ArtifactRecord record) => record.plainTestName;

  void _printSummary({
    required String behavior,
    required String classification,
    required bool certified,
    required String feature,
  }) {
    // `print` (not stdout.writeln) so CliRunner's capturing zone sees it.
    print(
      'verify-red: behavior=$behavior classification=$classification '
      'certified=$certified feature=$feature',
    );
  }
}

/// `--feature` lands in a filesystem path: keep it a single plain
/// directory segment (mirrors verify_command.dart).
void _validateFeatureSegment(String feature) {
  if (feature.contains('/') ||
      feature.contains(r'\') ||
      feature == '.' ||
      feature == '..') {
    throw UsageException(
      'invalid --feature "$feature": expected a single spec directory name '
          'such as 046-tdd-verify-red, not a path.',
      'zfa tdd verify-red [<behavior-id>] [--feature <name>]',
    );
  }
}

/// Strip a leading `specs/` prefix from a user-supplied --feature
/// reference. Lets users paste the path format shown throughout
/// zuraffa's docs and error messages (`specs/<feature>`) without
/// triggering the segment check above. The traversal guard on
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

/// Content and shape snapshot for the command's read-only source trees.
class _ReadOnlyTreeSnapshot {
  const _ReadOnlyTreeSnapshot(this.entries);

  final Map<String, String> entries;

  static Future<_ReadOnlyTreeSnapshot> capture(String projectRoot) async {
    final entries = <String, String>{};
    for (final treeName in const ['test', 'lib']) {
      final tree = Directory(p.join(projectRoot, treeName));
      if (!await tree.exists()) continue;
      entries['$treeName/'] = 'directory';
      await for (final entity in tree.list(
        recursive: true,
        followLinks: false,
      )) {
        final relative = p.normalize(
          p.relative(entity.path, from: projectRoot),
        );
        if (entity is File) {
          entries[relative] =
              'file:${sha256.convert(await entity.readAsBytes())}';
        } else if (entity is Directory) {
          entries['$relative/'] = 'directory';
        } else if (entity is Link) {
          entries[relative] = 'link:${await entity.target()}';
        }
      }
    }
    return _ReadOnlyTreeSnapshot(entries);
  }

  List<String> changedPaths(_ReadOnlyTreeSnapshot other) {
    final paths = {...entries.keys, ...other.entries.keys}.toList()..sort();
    return paths.where((path) => entries[path] != other.entries[path]).toList();
  }
}

/// One test file's slice of a batch suite transcript (spec 069 T002):
/// the progress lines naming that file plus the detail lines that
/// follow them (failure dumps, assertion diffs), the number of DISTINCT
/// tests observed for the file, and whether any of them failed.
class BatchFileSegment {
  const BatchFileSegment({
    required this.text,
    required this.testCount,
    required this.failed,
  });

  final String text;
  final int testCount;
  final bool failed;
}

/// Segments a package:test compact-reporter transcript per test file
/// (spec 069-corpus-economics: the batch verify-red classifies each
/// behavior from ITS file's slice of the ONE batch invocation).
///
/// Grammar (shared with the red classifier / suite guard):
///   `HH:MM +<passed> [-<failed>] [~<skipped>]: <path>: <name> [E]`
/// A progress line whose `<path>` is one of [testPaths] opens that
/// file's segment; every non-progress line that follows (until the
/// next progress line) belongs to the same file (failure detail
/// blocks). Distinct `<name>` values per file are the executed-test
/// count — the start line and the failure line of ONE test share a
/// name and must not count twice.
class BatchTranscript {
  static final RegExp _progressLine = RegExp(
    r'^\d\d:\d\d \+\d+(?: -\d+)?(?: ~\d+)?: (.+)$',
  );

  /// Segment [transcript] per file in [testPaths]. Paths not in the set
  /// (e.g. other suites in a wider run) are ignored; detail lines with
  /// no open segment are ignored.
  static Map<String, BatchFileSegment> segment(
    String transcript,
    Set<String> testPaths,
  ) {
    final buffers = <String, List<String>>{};
    final names = <String, Set<String>>{};
    final failures = <String, bool>{};
    String? current;
    for (final rawLine in transcript.split('\n')) {
      final line = rawLine.trimRight();
      if (line.isEmpty) continue;
      final match = _progressLine.firstMatch(line);
      if (match != null) {
        final rest = match.group(1)!;
        // `<path>: <name>` — split at the first `: ` after the path.
        final colon = rest.indexOf(': ');
        String? matched;
        if (colon > 0) {
          final candidate = rest.substring(0, colon);
          if (testPaths.contains(candidate)) matched = candidate;
        }
        if (matched == null) {
          // A summary line ("All tests passed!", "Some tests failed.")
          // or a foreign suite: keep the current file open only for
          // attribution of stray detail lines, but do not open a new
          // segment.
          continue;
        }
        current = matched;
        buffers.putIfAbsent(current, () => []);
        names.putIfAbsent(current, () => {});
        final testName = rest
            .substring(colon + 2)
            .replaceAll(RegExp(r'\s*\[E\]\s*$'), '');
        final isFailure = line.contains('[E]');
        if (isFailure) failures[current] = true;
        // A failure line repeats the SAME test name as its start line —
        // distinct names (the [E] marker stripped) are the executed
        // count.
        names[current]!.add(testName);
        buffers[current]!.add(line);
        continue;
      }
      // Detail line: attribute to the open segment (failure dumps
      // print directly under their [E] progress line).
      if (current != null && buffers.containsKey(current)) {
        buffers[current]!.add(line);
      }
    }
    return {
      for (final entry in buffers.entries)
        entry.key: BatchFileSegment(
          text: entry.value.join('\n'),
          testCount: names[entry.key]!.length,
          failed: failures[entry.key] ?? false,
        ),
    };
  }
}
