/// `zfa tdd wire <behavior-id> --entity <Name>` — the subject-wiring
/// generation step of the entity pipeline (bug #610; epic 045
/// precondition 5, FR-003/FR-005; spec 047 FR-005 minimal generation).
///
/// Bug #610: the entity plan (`entity create` + `build`) never
/// implemented the gen'd subject stub (`lib/tdd/<id>_subject.dart`, an
/// `UnimplementedError` stub), so with the REAL pipeline green was
/// unreachable for any entity-bearing behavior — the target test stayed
/// red after a fully successful generation and `make` honestly stopped
/// with `generation-error`. Fake-zfa mocks hid the gap because THEY
/// wired the subject themselves.
///
/// This command is the missing pipeline step. It:
///   1. Resolves the behavior's registry record (same resolution rules
///      as `verify-red`/`make`) and its `subject_path` artifact.
///   2. Requires `--entity <Name>` — the generated entity the behavior
///      is being wired to (the planner passes the same name it emitted
///      to `entity create -n`). Misfire-stop when the entity file does
///      not exist yet: run `zfa entity create -n <Name>` first.
///   3. Replaces the subject's `UnimplementedError` stub body with the
///      minimal wired implementation (spec 047 FR-005): the generated
///      entity is imported and referenced as the implementation anchor.
///      The paired test file is never touched (044 ownership contract).
///   4. Is idempotent: a subject with no `UnimplementedError` left is
///      reported `already-wired` and exits 0, so a resumed pipeline
///      re-running the step stays green.
///
/// Design decision (recorded in the epic 045 harness spec, precondition
/// 5, and the #610 PR): subject wiring lives in the tdd plugin as a
/// dedicated subcommand rather than a `zfa make --with=tdd-subject`
/// flag, because the subject contract (`lib/tdd/<id>_subject.dart`,
/// SubjectWriter, registry artifacts) is owned by the tdd plugin; a
/// core command would need a core→plugin dependency the architecture
/// forbids (plugins depend on core, never the reverse), and a dedicated
/// invocation gives the 045 provenance audit a clean, self-describing
/// attribution record for the subject implementation.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../services/artifact_registry.dart';
import '../services/entity_lookup.dart';
import '../services/subject_signature_deriver.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

/// Outcome labels for the machine-readable summary line.
enum WireOutcome {
  wired('wired'),
  alreadyWired('already-wired'),
  runnerError('runner-error');

  const WireOutcome(this.label);
  final String label;
}

class WireCommand extends Command<void> {
  WireCommand(this.plugin) {
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #964).',
      negatable: false,
    );
    argParser.addOption(
      'entity',
      help:
          'The generated entity the behavior is wired to (same name the '
          'plan passed to `zfa entity create -n`). Required: wiring '
          'without an entity anchor would be hand-implementation, not '
          'generation.',
    );
    argParser.addOption(
      'feature',
      help:
          'Feature name (e.g. 047-tdd-make). Restricts target resolution '
          'to specs/<feature>/tdd/artifacts.json. When omitted, every '
          'feature registry is scanned.',
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/, test/, and lib/. When omitted, '
          'the current working directory is used.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'wire';

  @override
  String get description =>
      'Wire a behavior\'s gen\'d subject stub to its generated entity — '
      'the subject-implementation step of the entity pipeline (bug #610, '
      'epic 045 precondition 5).';

  @override
  String get invocation =>
      'zfa tdd wire <behavior-id> --entity <Name> [--feature <name>] '
      '[--project <path>]';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    final behaviorId = rest.isNotEmpty ? rest.first : null;
    if (behaviorId == null || behaviorId.isEmpty) {
      print('zfa tdd wire: behavior id is required. Usage: $invocation');
      _printSummary(
        behavior: '-',
        outcome: WireOutcome.runnerError,
        feature: 'unknown',
      );
      exitCode = 1;
      return;
    }
    final entityName = argResults?['entity'] as String?;
    if (entityName == null || entityName.isEmpty) {
      print(
        'zfa tdd wire: --entity <Name> is required — the subject must be '
        'wired to the generated entity (the planner passes the same name '
        'it gave `zfa entity create -n`).',
      );
      _printSummary(
        behavior: behaviorId,
        outcome: WireOutcome.runnerError,
        feature: 'unknown',
      );
      exitCode = 1;
      return;
    }
    final featureFlag = argResults?['feature'] as String?;
    final projectFlag = argResults?['project'] as String?;
    final cwd = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');

    // -------------------------------------------------------------
    // 1. Resolve the behavior's registry record (FR-001/FR-002 shape).
    // -------------------------------------------------------------
    _Resolved? resolved;
    try {
      resolved = await _resolve(cwd, behaviorId, featureFlag);
    } on _WireResolutionError catch (e) {
      print('zfa tdd wire: ${e.message}');
      _printSummary(
        behavior: behaviorId,
        outcome: WireOutcome.runnerError,
        feature: featureFlag ?? 'unknown',
      );
      exitCode = 1;
      return;
    }
    if (resolved == null) {
      print(
        'zfa tdd wire: unknown behavior id "$behaviorId". No matching '
        'record in any specs/<feature>/tdd/artifacts.json'
        '${featureFlag != null && featureFlag.isNotEmpty ? ' for feature $featureFlag' : ''}. Run `zfa tdd gen $behaviorId` first.',
      );
      _printSummary(
        behavior: behaviorId,
        outcome: WireOutcome.runnerError,
        feature: featureFlag ?? 'unknown',
      );
      exitCode = 1;
      return;
    }
    final record = resolved.record;
    print('zfa tdd wire: behavior ${record.behaviorId}');
    print('   feature: ${resolved.featureName}');
    print('   entity: $entityName');

    // -------------------------------------------------------------
    // 2. The subject artifact must exist (gen wrote it).
    // -------------------------------------------------------------
    final recordedSubject = record.subjectPath;
    final normalizedCwd = p.normalize(p.absolute(cwd));
    final subjectPath = p.normalize(
      p.isAbsolute(recordedSubject)
          ? recordedSubject
          : p.join(normalizedCwd, recordedSubject),
    );
    if (!p.equals(normalizedCwd, subjectPath) &&
        !p.isWithin(normalizedCwd, subjectPath)) {
      print(
        'zfa tdd wire: the registry record for behavior '
        '"${record.behaviorId}" points outside the project root at '
        '"$recordedSubject". Run `zfa tdd gen ${record.behaviorId}` to '
        'restore its artifacts.',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: WireOutcome.runnerError,
        feature: resolved.featureName,
      );
      exitCode = 1;
      return;
    }
    final subjectFile = File(subjectPath);
    if (!await subjectFile.exists()) {
      print(
        'zfa tdd wire: the registry record for behavior '
        '"${record.behaviorId}" points to a missing subject file at '
        '"$recordedSubject". Run `zfa tdd gen ${record.behaviorId}` to '
        'restore its artifacts.',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: WireOutcome.runnerError,
        feature: resolved.featureName,
      );
      exitCode = 1;
      return;
    }

    // -------------------------------------------------------------
    // 3. The entity file must exist (the pipeline's `entity create`
    //    step ran first — plan order guarantees it; a manual run that
    //    skipped it is misfire-stopped here, not papered over).
    // -------------------------------------------------------------
    final entityFile = await locateEntityFile(cwd, entityName);
    if (entityFile == null) {
      print(
        'zfa tdd wire: no generated entity "$entityName" found under '
        '${p.join(cwd, 'lib', 'src', 'domain', 'entities')}. Run '
        '`zfa entity create -n $entityName` first (the plan orders the '
        'wire step after entity create).',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: WireOutcome.runnerError,
        feature: resolved.featureName,
      );
      exitCode = 1;
      return;
    }

    // -------------------------------------------------------------
    // 4. Parse the subject stub and emit the wired implementation.
    // -------------------------------------------------------------
    final raw = await subjectFile.readAsString();
    final stub = _stubSignature.firstMatch(raw);
    if (stub == null) {
      // Bug #829: classify by EXECUTABLE code, not raw text. The gen'd
      // stub header carries "Throws [UnimplementedError] until the real
      // implementation lands" — a doc comment `tdd func`'s scaffold
      // preserves — so a raw contains() misclassified every
      // pipeline-generated subject as "an unrecognized shape" and
      // refused it. Only an UnimplementedError thrown in CODE (a shape
      // this command did not generate — U-W5's hand-written class, for
      // example) is refused; a mention confined to comments means the
      // subject was already implemented by a pipeline step.
      if (_hasExecutableUnimplementedError(raw)) {
        print(
          'zfa tdd wire: subject at "$recordedSubject" carries an '
          'UnimplementedError in an unrecognized shape — refusing to '
          'rewrite a file this command did not generate.',
        );
      } else {
        // Idempotent re-run (resumed pipeline): nothing to do.
        print(
          'zfa tdd wire: subject at "$recordedSubject" is already '
          'implemented — nothing to wire.',
        );
        _printSummary(
          behavior: record.behaviorId,
          outcome: WireOutcome.alreadyWired,
          feature: resolved.featureName,
        );
        exitCode = 0;
      }
      if (_hasExecutableUnimplementedError(raw)) {
        exitCode = 1;
      }
      return;
    }
    final returnType = stub.group(1)!;
    final functionName = stub.group(2)!;

    final wired = _renderWired(
      record: record,
      returnType: returnType,
      functionName: functionName,
      entityName: entityName,
      entityImport: _packageImportFor(cwd, entityFile),
    );
    await subjectFile.writeAsString(wired);
    print('   wired: $recordedSubject -> entity $entityName');
    _printSummary(
      behavior: record.behaviorId,
      outcome: WireOutcome.wired,
      feature: resolved.featureName,
    );
    // Explicitly clear the process-global exit code on the success path.
    // `dart:io`'s `exitCode` is process-global and retains whatever the last
    // command set, so without this a successful wire inherits a non-zero
    // code from a prior command in the same runner — the exact failure that
    // made `zfa tdd wire` report `outcome=wired` with `exitCode=1` on the CI
    // runner (issue #652).
    exitCode = 0;
  }

  // -------------------------------------------------------------------
  // Resolution + rendering helpers.
  // -------------------------------------------------------------------

  static final RegExp _stubSignature = RegExp(
    r'^(int|void)\s+([A-Za-z_][A-Za-z0-9_]*)\(\)\s*=>\s*'
    r'throw UnimplementedError\(',
    multiLine: true,
  );

  /// Whether [raw] carries an `UnimplementedError` in EXECUTABLE code —
  /// any line whose `//` comment suffix is stripped first (bug #829:
  /// doc-comment mentions are gen-stub residue, not a stub body).
  static bool _hasExecutableUnimplementedError(String raw) {
    for (final line in raw.split('\n')) {
      final commentIdx = line.indexOf('//');
      final code = commentIdx >= 0 ? line.substring(0, commentIdx) : line;
      if (code.contains('UnimplementedError')) return true;
    }
    return false;
  }

  /// The behavior description the record carries — the record's own
  /// parsing contract ([ArtifactRecord.descriptionSegment]), shared with
  /// make/func/compose (bug #871: legacy `<id> — ` echoes stripped).
  static String _descriptionFor(ArtifactRecord record) =>
      record.descriptionSegment;

  String _renderWired({
    required ArtifactRecord record,
    required String returnType,
    required String functionName,
    required String entityName,
    required String entityImport,
  }) {
    final description = _descriptionFor(record);
    final derived = deriveSubjectSignature(description, forWire: true);
    final effectiveReturnType = returnType == 'void'
        ? 'void'
        : (derived.returnType.isNotEmpty ? derived.returnType : returnType);

    String body;
    if (effectiveReturnType == 'void') {
      body =
          '''
  // Implementation anchor: references the generated entity this
  // behavior builds on.
  // ignore: unused_local_variable
  final Type wiredEntityAnchor = $entityName;
''';
    } else if (derived.explicitBody != null) {
      body =
          '''
  // Implementation anchor: references the generated entity this
  // behavior builds on.
  // ignore: unused_local_variable
  final Type wiredEntityAnchor = $entityName;
  ${derived.explicitBody}
''';
    } else if (effectiveReturnType == 'String') {
      body =
          '''
  // Implementation anchor: references the generated entity this
  // behavior builds on.
  // ignore: unused_local_variable
  final Type wiredEntityAnchor = $entityName;
  return '$functionName';
''';
    } else {
      // Bug #920 review: the previous `return 0;` fallback produced a
      // type-wrong body for any non-int/String derived type (bool,
      // List<String>, Map<String, Object?>, double, etc.) once a future
      // matcher added the type without an explicit body. Route through
      // `_defaultBodyFor` so the literal is type-correct by construction.
      body =
          '''
  // Implementation anchor: references the generated entity this
  // behavior builds on.
  // ignore: unused_local_variable
  final Type wiredEntityAnchor = $entityName;
  ${_defaultBodyFor(effectiveReturnType, functionName)}
''';
    }
    return '''
// GENERATED IMPLEMENTATION — `zfa tdd wire ${record.behaviorId}` (bug
// #610; epic 045 precondition 5: the subject is wired by a
// generation-pipeline step, never by a wrapper or by hand).
//
// behavior_id: ${record.behaviorId}
// source_criterion: ${record.sourceCriterion}
// entity: $entityName
// description: $description
//
// This replaces the `zfa tdd gen` stub with the minimal wired
// implementation (spec 047 FR-005): the generated entity $entityName is
// the implementation anchor. Extend the body with real behavior in
// later cycles — the paired test file is immutable (044 ownership).
library;

import '$entityImport';

/// Subject for behavior ${record.behaviorId}, wired to entity
/// $entityName by the generation pipeline.
$effectiveReturnType $functionName() {$body}
''';
  }

  /// Minimal compilable return for a wired subject whose description
  /// implies [returnType] but yielded no explicit body. Bug #920 review
  /// — the previous `return 0;` was type-wrong for any non-int type.
  static String _defaultBodyFor(String returnType, String functionName) {
    switch (returnType) {
      case 'bool':
        return 'return false;';
      case 'double':
        return 'return 0.0;';
      case 'List<String>':
        return 'return const <String>[];';
      case 'Map<String, Object?>':
        return 'return const <String, Object?>{};';
      case 'int':
        return 'return 0;';
      case 'String':
        return "return '$functionName';";
      default:
        // Unknown type — emit a null cast so the stub compiles; the
        // real contract must replace this body in a later cycle.
        return 'return null as $returnType;';
    }
  }

  /// The `package:<name>/...` import for [entityFile] under [cwd],
  /// resolved from the target project's pubspec `name:`.
  String _packageImportFor(String cwd, String entityFile) {
    final pubspec = File(p.join(cwd, 'pubspec.yaml'));
    var pkg = 'app';
    if (pubspec.existsSync()) {
      final m = RegExp(
        r'^name:\s*(\S+)',
        multiLine: true,
      ).firstMatch(pubspec.readAsStringSync());
      if (m != null) pkg = m.group(1)!;
    }
    final rel = p.relative(entityFile, from: p.join(cwd, 'lib'));
    return 'package:$pkg/$rel';
  }

  Future<_Resolved?> _resolve(
    String cwd,
    String behaviorId,
    String? featureFlag,
  ) async {
    final matches = <_Resolved>[];
    for (final entry in await _scanRegistries(cwd, featureFlag)) {
      final record = await entry.registry.findRecord(behaviorId);
      if (record != null) {
        matches.add(_Resolved(record, entry.featureName));
      }
    }
    if (matches.length > 1) {
      final list = matches.map((m) => m.featureName).join(', ');
      throw _WireResolutionError(
        'ambiguous behavior id "$behaviorId" registered in multiple '
        'features: $list. Use --feature to disambiguate.',
      );
    }
    return matches.isEmpty ? null : matches.single;
  }

  Future<List<_RegistryEntry>> _scanRegistries(
    String cwd,
    String? featureFlag,
  ) async {
    if (featureFlag != null && featureFlag.isNotEmpty) {
      final featureDir = p.join(cwd, 'specs', featureFlag);
      return [
        _RegistryEntry(featureFlag, ArtifactRegistry(featureDir: featureDir)),
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
            ArtifactRegistry(featureDir: dir.path),
          ),
        );
      }
    }
    return entries;
  }

  void _printSummary({
    required String behavior,
    required WireOutcome outcome,
    required String feature,
  }) {
    print('wire: behavior=$behavior outcome=${outcome.label} feature=$feature');
  }
}

class _WireResolutionError implements Exception {
  _WireResolutionError(this.message);
  final String message;
  @override
  String toString() => message;
}

class _RegistryEntry {
  const _RegistryEntry(this.featureName, this.registry);
  final String featureName;
  final ArtifactRegistry registry;
}

class _Resolved {
  const _Resolved(this.record, this.featureName);
  final ArtifactRecord record;
  final String featureName;
}
