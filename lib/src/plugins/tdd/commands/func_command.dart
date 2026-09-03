/// `zfa tdd func <behavior-id>` — the plain-function generator surface
/// (bug #657).
///
/// Bug #657: the generation planner only mapped behavior descriptions to
/// `zfa entity create` (domain models), `zfa make` (repositories,
/// services, providers), and `zfa build` (build targets). Plain functions
/// (rendering, formatting, parsing, computing, pure logic) had no
/// generator surface, so `zfa tdd make` honestly reported them
/// `unexpressible` — and the TDD run blocked the whole feature at the
/// first such behavior.
///
/// This command is the missing surface, scoped to the tdd plugin for the
/// same reason `zfa tdd wire` is (bug #610 design decision): the subject
/// contract (`lib/tdd/<id>_subject.dart` equivalents under the registry's
/// `subject_path`, SubjectWriter, registry artifacts) is owned by the
/// tdd plugin, and a core command would need a core→plugin dependency the
/// architecture forbids (plugins depend on core, never the reverse).
///
/// The command:
///   1. Resolves the behavior's registry record (same resolution rules
///      as `wire`/`make`) and its `subject_path` artifact.
///   2. Derives only the return type from the behavior DESCRIPTION (never
///      from the test): a described result such as "returns a non-empty
///      string", "returns 42", or "return true when ..." maps to String,
///      int, or bool (with support for double / List / Map and a String
///      fallback). The function name and no-argument shape come from the
///      generated subject stub because the behavior record carries no input
///      parameter schema and the paired generated test invokes it with no args.
///   3. Replaces only the subject stub declaration containing
///      `UnimplementedError` with the minimal implementation satisfying the
///      described contract (spec 047 FR-005 minimal generation). The paired
///      test file is never
///      touched (044 ownership contract), and the stub's function NAME
///      is preserved so the immutable test keeps compiling against it.
///   4. Is idempotent: a subject with no `UnimplementedError` left is
///      reported `already-implemented` and exits 0, so a resumed
///      pipeline re-running the step stays green.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../models/routing.dart';
import '../services/artifact_registry.dart';
import '../services/declared_routing.dart';
import '../services/subject_signature_deriver.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

/// Outcome labels for the machine-readable summary line.
enum FuncOutcome {
  scaffolded('scaffolded'),
  alreadyImplemented('already-implemented'),
  runnerError('runner-error');

  const FuncOutcome(this.label);
  final String label;
}

class FuncCommand extends Command<void> {
  FuncCommand(this.plugin) {
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
  String get name => 'func';

  @override
  String get description =>
      'Scaffold the plain-function subject of a behavior (render, format, '
      'parse, compute, ...) with a description-derived return type '
      '— the function-generation surface of the pipeline (bug #657).';

  @override
  String get invocation =>
      'zfa tdd func <behavior-id> [--feature <name>] [--project <path>]';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    final behaviorId = rest.isNotEmpty ? rest.first : null;
    if (behaviorId == null || behaviorId.isEmpty) {
      print('zfa tdd func: behavior id is required. Usage: $invocation');
      _printSummary(
        behavior: '-',
        outcome: FuncOutcome.runnerError,
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
    } on _FuncResolutionError catch (e) {
      print('zfa tdd func: ${e.message}');
      _printSummary(
        behavior: behaviorId,
        outcome: FuncOutcome.runnerError,
        feature: featureFlag ?? 'unknown',
      );
      exitCode = 1;
      return;
    }
    if (resolved == null) {
      print(
        'zfa tdd func: unknown behavior id "$behaviorId". No matching '
        'record in any specs/<feature>/tdd/artifacts.json'
        '${featureFlag != null && featureFlag.isNotEmpty ? ' for feature $featureFlag' : ''}. Run `zfa tdd gen $behaviorId` first.',
      );
      _printSummary(
        behavior: behaviorId,
        outcome: FuncOutcome.runnerError,
        feature: featureFlag ?? 'unknown',
      );
      exitCode = 1;
      return;
    }
    final record = resolved.record;
    final description = _descriptionFor(record);
    print('zfa tdd func: behavior ${record.behaviorId}');
    print('   feature: ${resolved.featureName}');
    print('   description: $description');

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
        'zfa tdd func: the registry record for behavior '
        '"${record.behaviorId}" points outside the project root at '
        '"$recordedSubject". Run `zfa tdd gen ${record.behaviorId}` to '
        'restore its artifacts.',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: FuncOutcome.runnerError,
        feature: resolved.featureName,
      );
      exitCode = 1;
      return;
    }
    final subjectFile = File(subjectPath);
    if (!await subjectFile.exists()) {
      print(
        'zfa tdd func: the registry record for behavior '
        '"${record.behaviorId}" points to a missing subject file at '
        '"$recordedSubject". Run `zfa tdd gen ${record.behaviorId}` to '
        'restore its artifacts.',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: FuncOutcome.runnerError,
        feature: resolved.featureName,
      );
      exitCode = 1;
      return;
    }

    // -------------------------------------------------------------
    // 3. Parse the stub and emit the scaffolded implementation.
    // -------------------------------------------------------------
    final raw = await subjectFile.readAsString();
    final stub = _stubSignature.firstMatch(raw);
    if (stub == null) {
      final hasUnimplementedError = raw.contains('UnimplementedError');
      if (hasUnimplementedError) {
        print(
          'zfa tdd func: subject at "$recordedSubject" carries an '
          'UnimplementedError in an unrecognized shape — refusing to '
          'rewrite a file this command did not generate.',
        );
        _printSummary(
          behavior: record.behaviorId,
          outcome: FuncOutcome.runnerError,
          feature: resolved.featureName,
        );
        exitCode = 1;
      } else {
        // Idempotent re-run (resumed pipeline): nothing to do.
        print(
          'zfa tdd func: subject at "$recordedSubject" is already '
          'implemented — nothing to scaffold.',
        );
        _printSummary(
          behavior: record.behaviorId,
          outcome: FuncOutcome.alreadyImplemented,
          feature: resolved.featureName,
        );
        exitCode = 0;
      }
      return;
    }
    // The stub's function NAME is preserved: the paired (immutable) test
    // calls `subject.<name>()` and must keep compiling against the
    // scaffolded signature (044 ownership contract).
    final functionName = stub.group(2)!;

    // Feature 071 (issue #920's durable fix): a DECLARED signature from
    // the behavior's function contract row outranks prose inference.
    // Undeclared behaviors keep the description-keyed deriver (the
    // labeled fallback; strict surfaces are handled at plan).
    // Round-2 review fix 3c: a MALFORMED declaration propagates out of
    // the lookup as a StateError — surfaced here as a refusal (exit 1
    // + fix message), never a silent prose-inference fallback.
    final Signature? declared;
    try {
      declared = await DeclaredRouting.declaredSignatureFor(
        cwd: cwd,
        featureName: resolved.featureName,
        behaviorId: record.behaviorId,
      );
    } on StateError catch (e) {
      print('zfa tdd func: declaration refused — ${e.message}');
      _printSummary(
        behavior: record.behaviorId,
        outcome: FuncOutcome.runnerError,
        feature: resolved.featureName,
      );
      exitCode = 1;
      return;
    }

    final scaffolded = _renderScaffolded(
      description: description,
      functionName: functionName,
      declared: declared,
    );
    final updated = raw.replaceRange(stub.start, stub.end, scaffolded);
    await subjectFile.writeAsString(updated);
    print('   scaffolded: $recordedSubject');
    _printSummary(
      behavior: record.behaviorId,
      outcome: FuncOutcome.scaffolded,
      feature: resolved.featureName,
    );
    exitCode = 0;
  }

  // -------------------------------------------------------------------
  // Resolution + rendering helpers.
  // -------------------------------------------------------------------

  static final RegExp _stubSignature = RegExp(
    r'^(int|void)[ \t]+([A-Za-z_][A-Za-z0-9_]*)\(\)[ \t]*=>[ \t]*'
    r'throw[ \t]+UnimplementedError\([^;\r\n]*\);[ \t]*$',
    multiLine: true,
  );

  /// The behavior description the record carries — the record's own
  /// parsing contract ([ArtifactRecord.descriptionSegment]), shared with
  /// make/wire/compose (bug #871: legacy `<id> — ` echoes stripped).
  static String _descriptionFor(ArtifactRecord record) =>
      record.descriptionSegment;

  String _renderScaffolded({
    required String description,
    required String functionName,
    Signature? declared,
  }) {
    // Feature 071: the declared signature is authoritative when
    // present — the prose deriver runs ONLY on the fallback branch
    // (issue #920: no invented return types when a declaration exists).
    if (declared != null) {
      return '''${declared.returnType} $functionName() {
  ${_declaredStubBody(declared.returnType, functionName)}
}''';
    }
    final derived = deriveSubjectSignature(description);
    final body = derived.explicitBody ?? "return '$functionName';";
    return '''${derived.returnType} $functionName() {
  $body
}''';
  }

  /// A minimal compiling body honoring the declared return type. For
  /// non-primitive declared returns the honest scaffold stays red —
  /// `UnimplementedError` — instead of inventing a vacuous value
  /// (issue #920: a green suite that measures nothing).
  String _declaredStubBody(String returnType, String functionName) {
    if (returnType == 'String') return "return '$functionName';";
    if (returnType == 'int') return 'return 0;';
    if (returnType == 'double') return 'return 0.0;';
    if (returnType == 'bool') return 'return true;';
    if (returnType == 'void') return '';
    return "throw UnimplementedError('implement per declared signature: "
        '$functionName -> $returnType\');';
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
      throw _FuncResolutionError(
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
    required FuncOutcome outcome,
    required String feature,
  }) {
    print('func: behavior=$behavior outcome=${outcome.label} feature=$feature');
  }
}

class _FuncResolutionError implements Exception {
  _FuncResolutionError(this.message);
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
