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
///   4. On `assertion` ONLY — after the issue #964 kind gate confirms the
///      test's assertion KINDS match the scenario verbs (a presence red
///      in a navigation scenario is honest but irrelevant to the
///      scenario; it is refused as kind-mismatch, no evidence) — appends
///      the 8-field red-evidence entry to
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

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/red_classification.dart';
import '../services/artifact_registry.dart';
import '../services/cycle_log.dart';
import '../services/finder_taxonomy.dart';
import '../services/red_classifier.dart';
import '../services/runner.dart';
import '../services/tdd_generation_receipt.dart';
import '../services/tdd_timeout.dart';
import '../services/verdict_emitter.dart';
import '../models/verdict_envelope.dart';
import '../services/widget_scaffold.dart' show contentIsScaffolded;
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
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #964).',
      negatable: false,
    );
    argParser.addFlag(
      'all',
      negatable: false,
      help:
          'Batched red certification (spec 069 T002): certify EVERY '
          'behavior that has gen artifacts but no red evidence through '
          'ONE whole-file runner invocation (the profile\'s `file` '
          'template with every target test path) instead of one '
          'single-test spawn per behavior. Exit 0 only when every '
          'behavior certifies an honest assertion red; evidence is '
          'appended per certified behavior.',
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

  /// Issue #969: the envelope carrier the wrapper reads on exit.
  final VerdictContext _verdict = VerdictContext();

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
  Future<void> run() => runWithVerdictEnvelope(this, _verdict, _run);

  Future<void> _run() async {
    final rest = argResults?.rest ?? const <String>[];
    final behaviorId = rest.isNotEmpty ? rest.first : null;
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
    // Spec 069 T002: the batched red lane — one whole-file invocation
    // for every gen'd-but-not-red behavior. Dispatched BEFORE the
    // single-target resolution (multiple pending behaviors are the
    // batch's normal input, not an ambiguity).
    // ---------------------------------------------------------------
    if (argResults?['all'] as bool? ?? false) {
      if (behaviorId != null) {
        usageException(
          'zfa tdd verify-red --all takes no behavior id — it targets '
          'every behavior lacking red evidence (drop "$behaviorId" or '
          'drop --all).',
        );
      }
      await _runBatch(
        cwd: cwd,
        featureFlag: featureFlag,
        timeout: timeoutOverride,
        runner: const SingleTestRunner(),
      );
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
    //      Issue #964 kind gate: BEFORE evidence, the test's assertion
    //      kinds must match the scenario verbs — a red from a presence
    //      finder in a navigation scenario is honest but IRRELEVANT to
    //      the scenario (the certified lie of issue #964).
    // ---------------------------------------------------------------
    if (classification == RedClassification.assertion) {
      // Issue #964 kind gate: BEFORE evidence, the test's assertion
      // kinds must match the scenario verbs — a red from a presence
      // finder in a navigation scenario is honest but IRRELEVANT to
      // the scenario (the certified lie of issue #964).
      final kindGaps = await _certifyFinderKinds(cwd, record);
      if (kindGaps == null) {
        print('   classification: ${RedClassification.kindMismatch.label}');
        print(
          'zfa tdd verify-red: red observed, but no scenario description '
          'is available from the artifact record or legacy test header; '
          'the assertion kinds cannot be certified.',
        );
        stderr.writeln('   no evidence written');
        _printSummary(
          behavior: record.behaviorId,
          classification: RedClassification.kindMismatch.label,
          certified: false,
          feature: target.featureName,
        );
        exitCode = 1;
        return;
      }
      if (kindGaps.isNotEmpty) {
        print('   classification: ${RedClassification.kindMismatch.label}');
        print(
          'zfa tdd verify-red: red observed, but the test\'s assertion '
          'kinds do not match the scenario verb (issue #964): required '
          '${kindGaps.map((c) => c.label).join(', ')} — a rendered '
          'string, an absence of a finder, or a wrong-kind assertion '
          'never proves this scenario.',
        );
        stderr.writeln(
          'zfa tdd verify-red: ${RedClassification.kindMismatch.label} — '
          '${RedClassification.kindMismatch.remediationHint}',
        );
        stderr.writeln('   no evidence written');
        _printSummary(
          behavior: record.behaviorId,
          classification: RedClassification.kindMismatch.label,
          certified: false,
          feature: target.featureName,
        );
        exitCode = 1;
        return;
      }
      // Issue #959: name the failing authored assertion in the verdict
      // surface — detail line, summary token, and cycle-log field. Null
      // identity (unparseable transcript) omits the detail everywhere
      // rather than fabricating a name.
      final evidence = failingAssertionOf(run.output);
      if (evidence != null) {
        print('   red-evidence: $evidence');
      }
      final log = CycleLog(target.featureDir);
      await log.append(
        CycleLogEntry(
          behaviorId: record.behaviorId,
          kind: CycleEntryKind.red,
          runnerCommand: run.command,
          exitCode: run.exitCode,
          capturedOutput: run.output,
          classification: FailureClass.assertionFailure,
          redEvidence: evidence,
          subjectHash: await _subjectHashAt(cwd, record),
          sourceCriterion: record.sourceCriterion,
          testPath: record.testPath,
          timestamp: DateTime.now().toUtc().toIso8601String(),
        ),
      );
      print(
        '   red evidence appended to specs/${target.featureName}/tdd/'
        'cycle-log.md',
      );
      // Issue #969 T003: the red evidence becomes self-certifying.
      await TddGenerationReceipts.writeBestEffort(
        projectRoot: cwd,
        command: 'tdd verify-red',
        target: record.behaviorId,
        feature: target.featureName,
        files: {p.join(target.featureDir, 'tdd', 'cycle-log.md'): 'update'},
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

  /// The sha256 of the behavior's subject file at certification time
  /// (issue #1036): binds the red evidence to the EXACT subject shape it
  /// exercised, so the make skip transition can refuse a skip on a
  /// subject the certified evidence never captured (the born-green
  /// placeholder class). Null when the subject artifact is missing —
  /// the field is omitted and the downstream validation fails open for
  /// that entry (legacy tolerance).
  Future<String?> _subjectHashAt(String cwd, ArtifactRecord record) async {
    final subjectPath = p.isAbsolute(record.subjectPath)
        ? record.subjectPath
        : p.join(cwd, record.subjectPath);
    final subjectFile = File(subjectPath);
    if (!await subjectFile.exists()) return null;
    return sha256.convert(await subjectFile.readAsBytes()).toString();
  }

  /// The issue #964 kind gate: re-derive the scenario's required
  /// assertion classes from the artifact record's scenario description
  /// and check the file satisfies them. Legacy records without a description
  /// segment fall back to the generated test's description header. Returns
  /// the unsatisfied classes, or null when neither source supplies a scenario
  /// description. An unreadable file, scaffolded test, or non-widget test
  /// does not apply the gate and returns an empty set.
  Future<Set<ScenarioAssertionClass>?> _certifyFinderKinds(
    String cwd,
    ArtifactRecord record,
  ) async {
    final testPath = p.isAbsolute(record.testPath)
        ? record.testPath
        : p.join(cwd, record.testPath);
    final String content;
    try {
      content = await File(testPath).readAsString();
    } on FileSystemException {
      return const <ScenarioAssertionClass>{};
    }
    // Scaffolded tests are already excluded from green certification —
    // their reds stay the bootstrap honest red.
    if (contentIsScaffolded(content)) {
      return const <ScenarioAssertionClass>{};
    }
    // Only the widget lane carries finder kinds.
    if (!content.contains('testWidgets(')) {
      return const <ScenarioAssertionClass>{};
    }
    final descriptionMatch = RegExp(
      r'^// description: (.*)$',
      multiLine: true,
    ).firstMatch(content);
    final segments = record.runnableTestName.split('::');
    final recordDescription = segments.length >= 3
        ? record.descriptionSegment.trim()
        : '';
    final headerDescription = descriptionMatch?.group(1)?.trim() ?? '';
    final description = recordDescription.isNotEmpty
        ? recordDescription
        : headerDescription;
    if (description.isEmpty) return null;
    final analysis = FinderTaxonomy.analyze(description);
    return FinderTaxonomy.unsatisfiedClasses(analysis, content);
  }

  // -----------------------------------------------------------------
  // Spec 069 T002 — the batched red lane.
  // -----------------------------------------------------------------

  /// Certify every gen'd-but-not-red behavior through ONE whole-file
  /// runner invocation. Per-behavior classification from the batch
  /// transcript; evidence appended ONLY for assertion-classified
  /// behaviors; exit 0 only when every behavior certifies.
  Future<void> _runBatch({
    required String cwd,
    required String? featureFlag,
    required Duration? timeout,
    required SingleTestRunner runner,
  }) async {
    // 1. Collect the targets: every registry record whose behavior has
    //    no red evidence yet (the same `_certifiedBehaviors` filter the
    //    single-target inference uses).
    final registries = await _scanRegistries(cwd, featureFlag);
    final targets = <_ResolvedTarget>[];
    for (final entry in registries) {
      final certified = await _certifiedBehaviors(entry.featureDir);
      for (final record in await entry.registry.loadAll()) {
        if (!certified.contains(record.behaviorId)) {
          targets.add(
            _ResolvedTarget(record, entry.featureDir, entry.featureName),
          );
        }
      }
    }

    final featureLabel = featureFlag != null && featureFlag.isNotEmpty
        ? featureFlag
        : 'all';
    if (targets.isEmpty) {
      print(
        'zfa tdd verify-red --all: no behavior with gen artifacts lacks '
        'red evidence — nothing to certify.',
      );
      print(
        'verify-red: batch=true behaviors=0 certified=0 '
        'classification=batch feature=$featureLabel',
      );
      return;
    }

    print(
      'zfa tdd verify-red --all: ${targets.length} behavior(s) '
      '(spec 069 T002 batch)',
    );

    // 2. Load the whole-file template (misfire-stop: the batch lane
    //    needs the `file` runner; never a silent per-behavior fallback).
    final String fileTemplate;
    try {
      fileTemplate = await runner.loadFileTemplate(workingDirectory: cwd);
    } on StateError catch (e) {
      print(e.message);
      for (final target in targets) {
        _printSummary(
          behavior: target.record.behaviorId,
          classification: 'unresolved',
          certified: false,
          feature: target.featureName,
        );
      }
      print(
        'verify-red: batch=true behaviors=${targets.length} certified=0 '
        'classification=unresolved feature=$featureLabel',
      );
      exitCode = 1;
      return;
    }

    // 3. Build the ONE batch invocation: the file template's tokens with
    //    the placeholder tokens dropped, then every target test path
    //    appended (`dart test a_test.dart b_test.dart …`).
    final testPaths = targets.map((t) {
      final path = t.record.testPath;
      return p.isAbsolute(path) ? path : p.join(cwd, path);
    }).toList();
    final templateTokens = fileTemplate
        .trim()
        .split(RegExp(r'\s+'))
        .where(
          (token) => !token.contains('{file}') && !token.contains('{name}'),
        )
        .toList();
    final argv = [...templateTokens, ...testPaths];
    final display = [
      fileTemplate.replaceAll('{file}', testPaths.first),
      ...testPaths.skip(1),
    ].join(' ');
    print('zfa tdd verify-red: batch runner');
    print('   command: $display');

    // 4. Read-only integrity: the batch run must not modify test/ or
    //    lib/ (FR-008), same as the single run.
    _ReadOnlyTreeSnapshot? beforeRun;
    try {
      beforeRun = await _ReadOnlyTreeSnapshot.capture(cwd);
    } on FileSystemException catch (e) {
      print('zfa tdd verify-red: cannot snapshot test/ and lib/: ${e.message}');
      print(
        'verify-red: batch=true behaviors=${targets.length} certified=0 '
        'classification=unresolved feature=$featureLabel',
      );
      exitCode = 1;
      return;
    }

    // 5. Execute the ONE invocation under the deadline (bug #742 unit
    //    contract; the batch budget defaults to the suite-class deadline).
    final started = DateTime.now();
    final ProcessResult batch;
    try {
      batch = await runTimed(
        argv.first,
        argv.skip(1).toList(),
        workingDirectory: cwd,
        timeout: timeout ?? TddTimeouts.defaultSuite,
      );
    } on ProcessTimeoutException catch (e) {
      // Bug #742: the batch child outlived the deadline — nothing about
      // any behavior was observed; no evidence, never a certified red.
      print('zfa tdd verify-red: the batch runner timed out: $e');
      print(
        '   re-run with a larger --timeout <minutes> if the batch '
        'legitimately needs longer.',
      );
      print(
        'verify-red: batch=true behaviors=${targets.length} certified=0 '
        'classification=runner-error feature=$featureLabel',
      );
      exitCode = 1;
      return;
    } on ProcessException catch (e) {
      print('zfa tdd verify-red: batch runner failed to start: ${e.message}');
      print(
        'verify-red: batch=true behaviors=${targets.length} certified=0 '
        'classification=runner-error feature=$featureLabel',
      );
      exitCode = 1;
      return;
    }
    final elapsed = DateTime.now().difference(started);
    final output = '${batch.stdout}${batch.stderr}';
    print('   runner exit: ${batch.exitCode} (${elapsed.inMilliseconds}ms)');

    List<String> changedPaths;
    try {
      final afterRun = await _ReadOnlyTreeSnapshot.capture(cwd);
      changedPaths = beforeRun.changedPaths(afterRun);
    } on FileSystemException catch (e) {
      changedPaths = ['snapshot failed: ${e.message}'];
    }
    if (changedPaths.isNotEmpty) {
      print(
        'zfa tdd verify-red: read-only integrity violation under test/ or '
        'lib/: ${changedPaths.join(', ')}',
      );
      print('   no evidence written');
      print(
        'verify-red: batch=true behaviors=${targets.length} certified=0 '
        'classification=runner-error feature=$featureLabel',
      );
      exitCode = 1;
      return;
    }

    // 6. Classify each behavior from the batch transcript.
    final failingSegments = _failingSegments(output);
    final passingNames = _passingNames(output);
    var certifiedCount = 0;
    final failures = <(String, String)>[]; // (behavior, classification)
    for (final target in targets) {
      final record = target.record;
      var classification = _classifyBatchBehavior(
        record: record,
        output: output,
        failingSegments: failingSegments,
        passingNames: passingNames,
      );
      // Issue #964 kind gate (batch lane): the same refusal as the
      // single-target path — evidence only for verb-matched reds. A
      // behavior whose description is unavailable is refused, never
      // certified on faith.
      if (classification == 'assertion') {
        final kindGaps = await _certifyFinderKinds(cwd, record);
        if (kindGaps == null || kindGaps.isNotEmpty) {
          classification = 'kind-mismatch';
        }
      }
      if (classification == 'assertion') {
        final segment = _segmentFor(record.plainTestName, failingSegments);
        final log = CycleLog(target.featureDir);
        await log.append(
          CycleLogEntry(
            behaviorId: record.behaviorId,
            kind: CycleEntryKind.red,
            runnerCommand: display,
            exitCode: batch.exitCode,
            capturedOutput:
                '${segment ?? output}\n'
                '(batched red — one runner invocation for '
                '${targets.length} behavior(s), spec 069 T002)',
            classification: FailureClass.assertionFailure,
            subjectHash: await _subjectHashAt(cwd, record),
            sourceCriterion: record.sourceCriterion,
            testPath: record.testPath,
            timestamp: DateTime.now().toUtc().toIso8601String(),
          ),
        );
        print(
          '   red evidence appended to specs/${target.featureName}/tdd/'
          'cycle-log.md (${record.behaviorId})',
        );
        // Issue #969 T003: the batched red evidence becomes
        // self-certifying.
        await TddGenerationReceipts.writeBestEffort(
          projectRoot: cwd,
          command: 'tdd verify-red',
          target: record.behaviorId,
          feature: target.featureName,
          files: {p.join(target.featureDir, 'tdd', 'cycle-log.md'): 'update'},
        );
        certifiedCount++;
      } else {
        failures.add((record.behaviorId, classification));
      }
      _printSummary(
        behavior: record.behaviorId,
        classification: classification,
        certified: classification == 'assertion',
        feature: target.featureName,
      );
    }
    for (final (behavior, classification) in failures) {
      print(
        'zfa tdd verify-red: behavior "$behavior" — $classification: not '
        'certified in the batch (no evidence written for it).',
      );
    }

    // 7. The batch summary line — the machine contract's batch form.
    final allCertified = certifiedCount == targets.length;
    print(
      'verify-red: batch=true behaviors=${targets.length} '
      'certified=$certifiedCount '
      'classification=${allCertified ? 'batch' : 'mixed'} '
      'feature=$featureLabel',
    );
    _verdict
      ..exitClass = allCertified ? 'batch' : 'mixed'
      ..outcome = allCertified ? VerdictOutcome.pass : VerdictOutcome.fail
      ..details['batch'] = true
      ..details['behaviors'] = targets.length
      ..details['certified'] = certifiedCount
      ..feature = featureLabel == '-' ? null : featureLabel;
    exitCode = allCertified ? 0 : 1;
  }

  /// The failing test-name → failure-detail segments of a `dart test`
  /// batch transcript (pure). A failing progress line
  /// `HH:MM +N ~S -M: <name> [E]` opens a segment that runs to the next
  /// progress line; loading/summary lines are not test names.
  static Map<String, String> _failingSegments(String output) {
    final segments = <String, String>{};
    final lines = output.split('\n');
    String? currentName;
    final current = StringBuffer();
    for (final line in lines) {
      // The `~N` skipped counter may sit before OR after the `-\d+` fail
      // counter: the real `dart test` expanded reporter prints
      // `+P ~S -F`, while the SuiteGuard precedent parses `-F ~S`.
      // Without it, a transcript containing a skipped test parses no
      // failing segment at all and the whole batch degrades to
      // runner-error.
      final failing = RegExp(
        r'^\d\d:\d\d \+\d+(?: ~\d+)?(?: -\d+(?: ~\d+)?)?: (.+) \[E\]\s*$',
      ).firstMatch(line);
      final progress = RegExp(r'^\d\d:\d\d [+\-~]').hasMatch(line);
      if (failing != null) {
        if (currentName != null) {
          segments[currentName] = current.toString();
        }
        currentName = failing.group(1)!.trim();
        current.clear();
        continue;
      }
      if (progress) {
        if (currentName != null) {
          segments[currentName] = current.toString();
          currentName = null;
          current.clear();
        }
        continue;
      }
      if (currentName != null) current.writeln(line);
    }
    if (currentName != null) {
      segments[currentName] = current.toString();
    }
    return segments;
  }

  /// The names that PASSED in the batch transcript (progress lines
  /// `HH:MM +N: <name>` / `HH:MM +N -M: <name>` / `HH:MM +N ~S -M:
  /// <name>` without the `[E]` failure marker — a test passing AFTER an
  /// earlier failure still counts as passed).
  static Set<String> _passingNames(String output) {
    final names = <String>{};
    for (final line in output.split('\n')) {
      final m = RegExp(
        r'^\d\d:\d\d \+\d+(?: ~\d+)?(?: -\d+(?: ~\d+)?)?: (.+)$',
      ).firstMatch(line);
      if (m == null) continue;
      var name = m.group(1)!.trim();
      if (name.endsWith('[E]')) continue; // a failing line, not a pass.
      name = name.trim();
      if (name.startsWith('loading ') ||
          name == 'All tests passed!' ||
          name == 'Some tests failed.') {
        continue;
      }
      names.add(name);
    }
    return names;
  }

  /// Classify one behavior against the batch transcript (pure): the
  /// behavior's test must appear as a FAILING name with an assertion
  /// signature in its detail segment — everything else is an honest
  /// rejection, never a certified red.
  static String _classifyBatchBehavior({
    required ArtifactRecord record,
    required String output,
    required Map<String, String> failingSegments,
    required Set<String> passingNames,
  }) {
    final name = record.plainTestName;
    // A load failure naming this behavior's file: its test never ran.
    if (output.contains('Failed to load')) {
      final fileRef = p.basename(record.testPath);
      if (RegExp(
        'Failed to load .*${RegExp.escape(fileRef)}',
      ).hasMatch(output)) {
        return 'load-error';
      }
    }
    final segment = _segmentFor(name, failingSegments);
    if (segment != null) {
      final hasAssertion =
          segment.contains('Expected:') ||
          segment.contains('Actual:') ||
          segment.contains('TestFailure');
      return hasAssertion ? 'assertion' : 'runner-error';
    }
    final passed = passingNames.any((n) => _transcriptNameMatches(n, name));
    if (passed) return 'unexpected-green';
    return 'runner-error';
  }

  /// Whether a transcript test name refers to [plainName]: exact, or the
  /// plain name as a whole-suffix word (transcript names carry
  /// `<file>: <groups>` prefixes ahead of it). A bare `contains` is
  /// wrong for natural-language names — "adds item" is contained in
  /// "adds item to cart", so a PASSING behavior would be certified from
  /// a longer FAILING behavior's segment (a fabricated red).
  static bool _transcriptNameMatches(String transcriptName, String plainName) =>
      transcriptName == plainName || transcriptName.endsWith(' $plainName');

  /// The detail segment for [plainName] under the [_transcriptNameMatches]
  /// rule. Several matches resolve to the SHORTEST key — the most
  /// specific suffix.
  static String? _segmentFor(
    String plainName,
    Map<String, String> failingSegments,
  ) {
    String? best;
    for (final key in failingSegments.keys) {
      if (!_transcriptNameMatches(key, plainName)) continue;
      if (best == null || key.length < best.length) best = key;
    }
    return best == null ? null : failingSegments[best];
  }

  void _printSummary({
    required String behavior,
    required String classification,
    required bool certified,
    required String feature,
  }) {
    // `print` (not stdout.writeln) so CliRunner's capturing zone sees it.
    // Byte-identical to the pre-#959 pinned contract on every path (FR-009,
    // spec 046): the failing-assertion identity surfaces in the
    // `red-evidence:` detail line and the cycle-log `- evidence:` field,
    // never as a token on this line.
    print(
      'verify-red: behavior=$behavior classification=$classification '
      'certified=$certified feature=$feature',
    );
    // Issue #969: the classification IS the exit class (shipped
    // taxonomy label, never changed).
    _verdict
      ..exitClass = classification
      ..outcome = certified ? VerdictOutcome.pass : VerdictOutcome.fail
      ..details['behavior'] = behavior
      ..details['certified'] = certified;
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
