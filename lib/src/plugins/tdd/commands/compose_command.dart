/// `zfa tdd compose <behavior-id>` — the subject-composition generation
/// step of the acceptance make pipeline (issue #642; spec
/// 052-acceptance-make-composition).
///
/// Issue #642: `generation_planner.plan()` is pure and description-keyed,
/// so an acceptance behavior that reports `unexpressible` in phase 1
/// deterministically reports `unexpressible` again at phase 2 — the
/// driver's scripted phase-2 flip had no real-pipeline counterpart. This
/// command is the missing composition surface: it implements an ACCEPTANCE
/// behavior's gen'd subject stub against the feature's already-green unit
/// subjects (discovered by `CompositionTargets`), so the 047 make
/// pipeline's composition fallback can actually flip a deferred acceptance
/// make green at phase 2.
///
/// The command mirrors `zfa tdd wire` (bug #610's subject-implementation
/// step for the entity pipeline) in every structural respect:
///   1. Resolves the behavior's registry record (same resolution rules as
///      `verify-red`/`make`/`wire`).
///   2. Requires certified-red evidence in `tdd/cycle-log.md` (make's
///      FR-001 precondition — composition implements a certified-red
///      behavior).
///   3. Requires the subject artifact on disk (gen wrote it).
///   4. Discovers the feature's composable green unit subjects via
///      `CompositionTargets` (unit-kind test-list rows ∩ green cycle-log
///      evidence ∩ existing subject artifacts). Zero anchors →
///      `no-green-units` misfire-stop; a missing anchor artifact →
///      `runner-error` misfire-stop; a unit-kind target → fail-closed
///      refusal (composition is the acceptance-subject surface only).
///   5. Replaces the subject's `UnimplementedError` stub body with the
///      minimal composed implementation: the green unit subject files are
///      imported and referenced as the implementation anchor (spec 047
///      FR-005's minimal generation applied to composition). The paired
///      test file is never touched (044 ownership contract).
///   6. Is idempotent: a subject with no `UnimplementedError` left is
///      reported `already-composed` and exits 0, so a resumed pipeline
///      re-running the step stays green.
///
/// The machine contract is the summary line
/// `compose: behavior=<id> outcome=<label> feature=<feature>` as the final
/// stdout line on every code path; exit 0 means exactly "composed (or
/// already composed)".
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../services/artifact_registry.dart';
import '../services/composition_targets.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

/// Outcome labels for the machine-readable summary line.
enum ComposeOutcome {
  composed('composed'),
  alreadyComposed('already-composed'),
  notCertifiedRed('not-certified-red'),
  noGreenUnits('no-green-units'),
  runnerError('runner-error');

  const ComposeOutcome(this.label);
  final String label;
}

class ComposeCommand extends Command<void> {
  ComposeCommand(this.plugin) {
    argParser.addOption(
      'feature',
      help:
          'Feature name (e.g. 052-acceptance-make-composition). Restricts '
          'target resolution to specs/<feature>/tdd/artifacts.json. When '
          'omitted, every feature registry is scanned.',
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/, test/, and lib/ (the fixture or '
          'target project). When omitted, the current working directory is '
          'used. Tests pass the temp fixture root here instead of mutating '
          'Directory.current, which is process-global and unsafe under '
          'concurrent test execution.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'compose';

  @override
  String get description =>
      'Compose an acceptance behavior\'s subject against the feature\'s '
      'green unit subjects — the composition step of the acceptance make '
      'pipeline (issue #642, spec 052).';

  @override
  String get invocation =>
      'zfa tdd compose [<behavior-id>] [--feature <name>] [--project <path>]';

  /// The stub signature compose rewrites — exactly wire's (`int|void
  /// <name>() => throw UnimplementedError(`), so compose and wire stay
  /// interchangeable on the same subject contract.
  static final RegExp _stubSignature = RegExp(
    r'^(int|void)\s+([A-Za-z_][A-Za-z0-9_]*)\(\)\s*=>\s*'
    r'throw UnimplementedError\(',
    multiLine: true,
  );

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    final behaviorId = rest.isNotEmpty ? rest.first : null;
    final featureFlag = argResults?['feature'] as String?;
    if (featureFlag != null && featureFlag.isNotEmpty) {
      try {
        _validateFeatureSegment(featureFlag);
      } on UsageException catch (e) {
        print('zfa tdd compose: ${e.message}');
        _printSummary(
          behavior: behaviorId ?? '-',
          outcome: ComposeOutcome.runnerError,
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

    // -------------------------------------------------------------
    // 1. Resolve the behavior's registry record (FR-001).
    // -------------------------------------------------------------
    _ResolvedTarget target;
    try {
      target = await _resolveTarget(cwd, behaviorId, featureFlag);
    } on ComposeResolutionError catch (e) {
      print('zfa tdd compose: ${e.message}');
      _printSummary(
        behavior: behaviorId ?? '-',
        outcome: e.outcome,
        feature: e.feature ?? featureFlag ?? 'unknown',
      );
      exitCode = 1;
      return;
    }
    final record = target.record;
    print('zfa tdd compose: behavior ${record.behaviorId}');
    print('   feature: ${target.featureName}');

    // -------------------------------------------------------------
    // 2. Precondition: certified-red evidence (FR-002).
    // -------------------------------------------------------------
    final certifiedRed = await _hasCertifiedRed(
      target.featureDir,
      record.behaviorId,
    );
    if (!certifiedRed) {
      print(
        'zfa tdd compose: behavior "${record.behaviorId}" has no '
        'certified-red evidence in cycle-log.md. Run `zfa tdd verify-red '
        '${record.behaviorId}` first.',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: ComposeOutcome.notCertifiedRed,
        feature: target.featureName,
      );
      exitCode = 1;
      return;
    }

    // -------------------------------------------------------------
    // 3. The subject artifact must exist (gen wrote it).
    // -------------------------------------------------------------
    final recordedSubject = record.subjectPath;
    final normalizedCwd = p.normalize(p.absolute(cwd));
    final subjectPath = p.normalize(
      p.isAbsolute(recordedSubject)
          ? recordedSubject
          : p.join(normalizedCwd, recordedSubject),
    );
    final unresolvedSubjectFile = File(subjectPath);
    late final String resolvedCwd;
    late final String resolvedSubjectPath;
    try {
      resolvedCwd = await Directory(normalizedCwd).resolveSymbolicLinks();
      if (!await unresolvedSubjectFile.exists()) {
        print(
          'zfa tdd compose: the registry record for behavior '
          '"${record.behaviorId}" points to a missing subject file at '
          '"$recordedSubject". Run `zfa tdd gen ${record.behaviorId}` to '
          'restore its artifacts.',
        );
        _printSummary(
          behavior: record.behaviorId,
          outcome: ComposeOutcome.runnerError,
          feature: target.featureName,
        );
        exitCode = 1;
        return;
      }
      resolvedSubjectPath = await unresolvedSubjectFile.resolveSymbolicLinks();
    } on FileSystemException catch (e) {
      print(
        'zfa tdd compose: could not resolve the subject path '
        '"$recordedSubject": ${e.message}',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: ComposeOutcome.runnerError,
        feature: target.featureName,
      );
      exitCode = 1;
      return;
    }
    if (!p.equals(resolvedCwd, resolvedSubjectPath) &&
        !p.isWithin(resolvedCwd, resolvedSubjectPath)) {
      print(
        'zfa tdd compose: the registry record for behavior '
        '"${record.behaviorId}" points outside the project root at '
        '"$recordedSubject". Run `zfa tdd gen ${record.behaviorId}` to '
        'restore its artifacts.',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: ComposeOutcome.runnerError,
        feature: target.featureName,
      );
      exitCode = 1;
      return;
    }
    final subjectFile = File(resolvedSubjectPath);

    // -------------------------------------------------------------
    // 4. Discover the composable green unit subjects (FR-003). The kind
    //    gate lives here too: a unit-kind target fails closed.
    // -------------------------------------------------------------
    final discovery = await const CompositionTargets().discover(
      projectRoot: resolvedCwd,
      featureDir: target.featureDir,
      behaviorId: record.behaviorId,
    );
    if (discovery is CompositionTargetFailure) {
      print('zfa tdd compose: ${discovery.message}');
      final outcome = discovery.code == 'no-green-units'
          ? ComposeOutcome.noGreenUnits
          : ComposeOutcome.runnerError;
      _printSummary(
        behavior: record.behaviorId,
        outcome: outcome,
        feature: target.featureName,
      );
      exitCode = 1;
      return;
    }
    final anchors = (discovery as CompositionTargetResolved).anchors;
    print(
      '   anchors: ${anchors.map((a) => a.behaviorId).join(', ')} '
      '(${anchors.length} green unit subject(s))',
    );

    // -------------------------------------------------------------
    // 5. Parse the subject stub (FR-005: idempotence + refusal).
    // -------------------------------------------------------------
    late final String raw;
    try {
      raw = await subjectFile.readAsString();
    } on FileSystemException catch (e) {
      print(
        'zfa tdd compose: could not read the subject file at '
        '"$recordedSubject": ${e.message}',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: ComposeOutcome.runnerError,
        feature: target.featureName,
      );
      exitCode = 1;
      return;
    }
    if (!raw.contains('UnimplementedError')) {
      // Idempotent re-run (resumed pipeline): nothing to do.
      print(
        'zfa tdd compose: subject at "$recordedSubject" is already '
        'implemented — nothing to compose.',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: ComposeOutcome.alreadyComposed,
        feature: target.featureName,
      );
      exitCode = 0;
      return;
    }
    final stub = _stubSignature.firstMatch(raw);
    if (stub == null) {
      print(
        'zfa tdd compose: subject at "$recordedSubject" carries an '
        'UnimplementedError in an unrecognized shape — refusing to rewrite '
        'a file this command did not generate.',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: ComposeOutcome.runnerError,
        feature: target.featureName,
      );
      exitCode = 1;
      return;
    }
    final returnType = stub.group(1)!;
    final functionName = stub.group(2)!;

    // -------------------------------------------------------------
    // 6. Emit the composed implementation (FR-004).
    // -------------------------------------------------------------
    final composed = _renderComposed(
      record: record,
      returnType: returnType,
      functionName: functionName,
      anchors: anchors,
      projectRoot: resolvedCwd,
      subjectDir: p.dirname(resolvedSubjectPath),
    );
    try {
      await subjectFile.writeAsString(composed);
    } on FileSystemException catch (e) {
      print(
        'zfa tdd compose: could not write the subject file at '
        '"$recordedSubject": ${e.message}',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: ComposeOutcome.runnerError,
        feature: target.featureName,
      );
      exitCode = 1;
      return;
    }
    print('   composed: $recordedSubject');
    _printSummary(
      behavior: record.behaviorId,
      outcome: ComposeOutcome.composed,
      feature: target.featureName,
    );
    exitCode = 0;
  }

  // -------------------------------------------------------------------
  // Resolution + rendering helpers.
  // -------------------------------------------------------------------

  /// The behavior description the record carries — the record's own
  /// parsing contract ([ArtifactRecord.descriptionSegment]), shared with
  /// make/wire/func (bug #871: legacy `<id> — ` echoes stripped).
  static String _descriptionFor(ArtifactRecord record) =>
      record.descriptionSegment;

  String _renderComposed({
    required ArtifactRecord record,
    required String returnType,
    required String functionName,
    required List<ComposableUnitSubject> anchors,
    required String projectRoot,
    required String subjectDir,
  }) {
    final imports = StringBuffer();
    final symbols = StringBuffer();
    for (var i = 0; i < anchors.length; i++) {
      final anchor = anchors[i];
      imports.writeln(
        "import '${_packageImportFor(projectRoot, anchor, subjectDir)}' "
        'as anchor$i;',
      );
      if (i > 0) symbols.write(', ');
      symbols.write('anchor$i.${anchor.symbol}');
    }
    final body = returnType == 'void'
        ? '''
  // Composition anchor: references the feature's green unit subjects this
  // behavior builds on.
  // ignore: unused_local_variable
  final composedUnitAnchors = <Function>[$symbols];
'''
        : '''
  // Composition anchor: references the feature's green unit subjects this
  // behavior builds on.
  // ignore: unused_local_variable
  final composedUnitAnchors = <Function>[$symbols];
  return 0;
''';
    return '''
// GENERATED IMPLEMENTATION — `zfa tdd compose ${record.behaviorId}` (issue
// #642; spec 052-acceptance-make-composition: the acceptance subject is
// composed against the feature's green unit subjects by a
// generation-pipeline step, never by a wrapper or by hand).
//
// behavior_id: ${record.behaviorId}
// source_criterion: ${record.sourceCriterion}
// composed against: ${anchors.map((a) => '${a.behaviorId} (${a.subjectPath})').join(', ')}
// description: ${_descriptionFor(record)}
//
// This replaces the `zfa tdd gen` stub with the minimal composed
// implementation (spec 047 FR-005): the feature's green unit subjects are
// the implementation anchors. Extend the body with real behavior in later
// cycles — the paired test file is immutable (044 ownership).
library;

$imports
/// Subject for behavior ${record.behaviorId}, composed against the
/// feature's green unit subjects by the generation pipeline.
$returnType $functionName() {$body}
''';
  }

  /// The `package:<name>/...` import for an anchor subject file under the
  /// project root's lib/, resolved from the target project's pubspec
  /// `name:`. A subject outside lib/ falls back to a file-relative path
  /// from the composing subject's directory (gen's default layout keeps
  /// subjects under lib/tdd/, so the package import is the norm).
  String _packageImportFor(
    String projectRoot,
    ComposableUnitSubject anchor,
    String subjectDir,
  ) {
    final libRoot = p.join(projectRoot, 'lib');
    // Resolve symlinks to handle macOS /var/folders -> /private/var/folders
    // mismatch between resolved cwd and unresolved artifact paths.
    var anchorPath = anchor.subjectPath;
    try {
      anchorPath = Link(anchorPath).resolveSymbolicLinksSync();
    } catch (_) {
      // Not a link or doesn't exist — use the original path.
    }
    if (p.isWithin(libRoot, anchorPath)) {
      final pubspec = File(p.join(projectRoot, 'pubspec.yaml'));
      var pkg = 'app';
      if (pubspec.existsSync()) {
        final m = RegExp(
          r'^name:\s*(\S+)',
          multiLine: true,
        ).firstMatch(pubspec.readAsStringSync());
        if (m != null) pkg = m.group(1)!;
      }
      final rel = p.relative(anchorPath, from: libRoot);
      return 'package:$pkg/${rel.replaceAll(r'\', '/')}';
    }
    // Fallback: a relative import from the composing subject's directory.
    return p
        .relative(anchor.subjectPath, from: subjectDir)
        .replaceAll(r'\', '/');
  }

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
        throw ComposeResolutionError(
          'unknown behavior id "$behaviorId". No matching record in any '
          'specs/<feature>/tdd/artifacts.json'
          '${featureFlag != null && featureFlag.isNotEmpty ? ' for feature $featureFlag' : ''}. '
          'Run `zfa tdd gen $behaviorId` to materialize it.',
          outcome: ComposeOutcome.runnerError,
          feature: featureFlag,
        );
      }
      if (matches.length > 1) {
        final list = matches
            .map((m) => '${m.record.behaviorId} (${m.featureName})')
            .join(', ');
        throw ComposeResolutionError(
          'ambiguous behavior id "$behaviorId" registered in multiple '
          'features: $list. Use --feature to disambiguate.',
          outcome: ComposeOutcome.runnerError,
        );
      }
      return matches.single;
    }

    // No id: infer ONLY when exactly one behavior has gen artifacts and
    // certified-red evidence — the precondition for `compose` (mirrors
    // make's single-candidate inference).
    final candidates = <_ResolvedTarget>[];
    for (final entry in registries) {
      final certified = await _certifiedRedBehaviors(entry.featureDir);
      for (final record in await entry.registry.loadAll()) {
        if (certified.contains(record.behaviorId)) {
          candidates.add(
            _ResolvedTarget(record, entry.featureDir, entry.featureName),
          );
        }
      }
    }
    if (candidates.isEmpty) {
      throw ComposeResolutionError(
        'no behavior with both gen artifacts and certified-red evidence — '
        'nothing to compose. Run `zfa tdd verify-red <behavior-id>` first.',
        outcome: ComposeOutcome.notCertifiedRed,
      );
    }
    if (candidates.length > 1) {
      final list = candidates
          .map((c) => '${c.record.behaviorId} (${c.featureName})')
          .join(', ');
      throw ComposeResolutionError(
        'ambiguous invocation: multiple behaviors have certified-red '
        'evidence: $list. Pass an explicit behavior id.',
        outcome: ComposeOutcome.runnerError,
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
        entries.add(
          _RegistryEntry(
            p.basename(dir.path),
            dir.path,
            ArtifactRegistry(featureDir: dir.path),
          ),
        );
      }
    }
    return entries;
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

  void _printSummary({
    required String behavior,
    required ComposeOutcome outcome,
    required String feature,
  }) {
    print(
      'compose: behavior=$behavior outcome=${outcome.label} feature=$feature',
    );
  }
}

/// Resolution-stage failure: message, outcome, and feature context if known.
class ComposeResolutionError implements Exception {
  ComposeResolutionError(this.message, {required this.outcome, this.feature});

  final String message;
  final ComposeOutcome outcome;
  final String? feature;

  @override
  String toString() => message;
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

/// `--feature` lands in a filesystem path: keep it a single plain
/// directory segment (mirrors verify_red_command.dart / make_command.dart).
void _validateFeatureSegment(String feature) {
  if (feature.contains('/') ||
      feature.contains(r'\') ||
      feature == '.' ||
      feature == '..') {
    throw UsageException(
      'invalid --feature "$feature": expected a single spec directory name '
          'such as 052-acceptance-make-composition, not a path.',
      'zfa tdd compose [<behavior-id>] [--feature <name>]',
    );
  }
}
