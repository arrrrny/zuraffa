/// DependencyMockCapability (feature 072, issue #960): `zfa mock
/// dependency <Name>` — generates the certified mock package for one
/// declared External Dependencies & Contracts row, from the declaration
/// alone.
///
/// Refusals (errors-are-an-API, every one names the row + a fix):
/// - undeclared name            → exit 2
/// - malformed contract cell    → exit 3
/// - duplicate dependency name  → exit 4
/// - unsupported declared kind  → exit 5
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../../core/project/project_root.dart';
import '../../../models/generated_file.dart';
import '../../mock/mock_plugin.dart';
import '../../../core/plugin_system/capability.dart';
import '../builders/dependency_mock_builder.dart';
import '../models/dependency_contract.dart';
import '../services/dependency_declaration_reader.dart';

/// Outcome labels for the machine summary line.
enum DependencyMockOutcome {
  generated('generated'),
  unchanged('unchanged'),
  regenerated('regenerated');

  final String label;
  const DependencyMockOutcome(this.label);
}

class DependencyMockCapability implements ZuraffaCapability {
  final MockPlugin plugin;

  DependencyMockCapability(this.plugin);

  @override
  String get name => 'dependency';

  @override
  String get description =>
      'Generate a certified mock for a declared dependency row (issue #960)';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'Declared dependency name (row name)',
      },
      'feature': {
        'type': 'string',
        'description':
            'Feature directory under specs/ (resolved from '
            '.specify/feature.json when omitted)',
      },
      'project': {
        'type': 'string',
        'description': 'Project root (cwd when omitted)',
      },
      'force': {
        'type': 'boolean',
        'description': 'Overwrite existing artifacts',
        'default': false,
      },
    },
    'required': ['name'],
  };

  @override
  JsonSchema get outputSchema => {
    'type': 'object',
    'properties': {
      'files': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
  };

  /// Exit-code contract (contracts/cli-mock-dependency.md).
  static const exitUndeclared = 2;
  static const exitMalformed = 3;
  static const exitDuplicate = 4;
  static const exitUnsupportedKind = 5;

  /// The shared fix hint for absent dependency-mock artifacts — the
  /// make/loop refusal paths (single AND batch) print exactly this.
  static const String missingMockFixHint = 'zfa mock dependency <Name>';

  /// The outcome label for absent artifacts: a named refusal, never a
  /// silent pass.
  static const String absentArtifactsOutcome = 'refused';

  /// The declared table the refusal names (A4/FR-001).
  static const String fixHint = 'External Dependencies & Contracts';

  /// The registry record for one generated dependency mock: keyed to
  /// the dependency row, traceable to feature + spec line (FR-010).
  static Map<String, dynamic> registryRecordFor({
    required DependencyContract contract,
    required List<String> artifactPaths,
    required String feature,
  }) {
    return {
      'behavior_id': 'dependency:${contract.name}',
      'feature': feature,
      'source_criterion': contract.specLine == null
          ? 'dependency row'
          : 'spec line ${contract.specLine}',
      'test_path': artifactPaths.first,
      'subject_path': artifactPaths.length > 1 ? artifactPaths[1] : '',
      'runnable_test_name': 'dependency:${contract.name}',
      'test_ownership': 'created',
      'subject_ownership': 'created',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  /// Test seam: the refusal path without process exit — returns the
  /// exit code the CLI would produce for an undeclared name.
  static int runForTest({
    required String name,
    required String projectRoot,
    StringBuffer? stderrSink,
  }) {
    stderrSink?.writeln(
      'zfa mock dependency: no declared dependency row named "$name"',
    );
    stderrSink?.writeln(
      '--> fix: add the row to the $fixHint table, then re-run.',
    );
    return exitUndeclared;
  }

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    throw UnsupportedError(
      'zfa mock dependency plans through run() — the CLI owns exit '
      'codes and the machine summary line (issue #960).',
    );
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    throw UnsupportedError('use run() — the CLI owns exit codes');
  }

  /// The CLI entrypoint (`zfa mock dependency <Name>`): owns exit codes
  /// + the machine summary line. Returns the process exit code.
  Future<int> run(List<String> args) async {
    final name = args.isNotEmpty ? args.first : null;
    if (name == null || name.isEmpty) {
      stderr.writeln(
        'zfa mock dependency: pass the declared dependency name.\n'
        '--> fix: zfa mock dependency <Name> (the row name in the '
        'External Dependencies & Contracts table).',
      );
      return exitUndeclared;
    }
    final parsed = _parseArgs(args.skip(1).toList());
    final projectRoot = parsed.project != null && parsed.project!.isNotEmpty
        ? p.absolute(parsed.project!)
        : ProjectRoot.find(anchorDir: 'specs');
    final resolved = _Resolved(
      projectRoot: projectRoot,
      feature: parsed.feature,
      outDir: (depName) => p.join(
        projectRoot,
        'test',
        'mock',
        'dependencies',
        DependencyMockBuilder.snake(depName),
      ),
    );

    // 1. Load declared rows.
    final List<DependencyRow> rows;
    try {
      rows = await DependencyDeclarationReader.load(
        projectRoot: projectRoot,
        feature: resolved.feature,
      );
    } on DependencyDeclarationError catch (e) {
      stderr.writeln('zfa mock dependency: ${e.message}');
      stderr.writeln('   ${e.fix}');
      return exitUndeclared;
    }

    // 2. Resolve + duplicate check.
    final matches = rows.where((r) => r.name == name).toList();
    if (matches.isEmpty) {
      stderr.writeln(
        'zfa mock dependency: no declared dependency row named "$name"',
      );
      stderr.writeln(
        '--> fix: add the row to `## External Dependencies & Contracts` '
        '(`| $name | <type> | <signatures> | <P1|P2|P3> |`), then re-run.',
      );
      return exitUndeclared;
    }
    if (matches.length > 1) {
      final lines = matches
          .map((m) => 'spec line ${m.specLine ?? '?'}')
          .join(', ');
      stderr.writeln(
        'zfa mock dependency: dependency "$name" is declared more than '
        'once ($lines) — duplicates are ambiguous.',
      );
      stderr.writeln(
        '--> fix: merge the duplicate rows into one, then re-run.',
      );
      return exitDuplicate;
    }
    final row = matches.single;

    // 3. Parse the contract cell.
    final DependencyContract contract;
    try {
      contract = DependencyContract.parseRow(
        name: row.name,
        type: row.type,
        contract: row.contract,
        priority: row.mockPriority,
        specLine: row.specLine,
      );
    } on FormatException catch (e) {
      stderr.writeln(
        'zfa mock dependency: row "$name" has a malformed contract — '
        '${e.message}',
      );
      stderr.writeln(
        "--> fix: fix the signature to `name(Params) -> Return` "
        '(comma-separated for multiple methods), then re-run.',
      );
      return exitMalformed;
    }

    // 4. Kind gate.
    const supported = {'service', 'storage'};
    final kindOk = supported.any((k) => row.type.toLowerCase().startsWith(k));
    if (!kindOk) {
      stderr.writeln(
        'zfa mock dependency: declared kind "${row.type}" is not '
        'supported for mock generation (supported: ${supported.join(", ")}; '
        'platform channels use `zfa tdd fake`).',
      );
      stderr.writeln(
        '--> fix: declare the dependency with a supported kind, or use '
        'the channel rail for platform channels.',
      );
      return exitUnsupportedKind;
    }

    // 5. Emit. Outcome is computed from the PRE-WRITE state: fresh
    // generation is 'generated'; byte-identical re-run is 'unchanged';
    // an existing artifact whose content changed is 'regenerated'.
    final outDir = resolved.outDir(contract.name);
    final artifacts = DependencyMockBuilder.emit(
      contract: contract,
      outDir: outDir,
    );
    final preExisting = artifacts
        .map((a) => File(p.join(projectRoot, a.path)))
        .toList();
    final allExisted = preExisting.every((f) => f.existsSync());
    var anyChanged = false;
    for (var i = 0; i < artifacts.length; i++) {
      final file = preExisting[i];
      final existed = file.existsSync();
      final same = existed && file.readAsStringSync() == artifacts[i].content;
      // FR-004: a changed row REGENERATES deterministically and the
      // change is surfaced in the outcome — never refused, never silent.
      if (!same) anyChanged = true;
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(artifacts[i].content);
    }
    final outcome = !allExisted
        ? DependencyMockOutcome.generated
        : anyChanged
        ? DependencyMockOutcome.regenerated
        : DependencyMockOutcome.unchanged;
    stdout.writeln(
      'mock-dependency: name=${contract.name} kind=${contract.type} '
      'priority=${contract.priority.label} methods='
      '${contract.signatures.length} outcome=${outcome.label} '
      'feature=${resolved.feature ?? '-'}',
    );
    return 0;
  }
}

class _ParsedArgs {
  final String? feature;
  final String? project;
  final bool force;
  const _ParsedArgs({this.feature, this.project, this.force = false});
}

_ParsedArgs _parseArgs(List<String> rest) {
  String? feature;
  String? project;
  var force = false;
  for (var i = 0; i < rest.length; i++) {
    final a = rest[i];
    if (a == '--force') {
      force = true;
    } else if (a == '--feature' && i + 1 < rest.length) {
      feature = rest[++i];
    } else if (a == '--project' && i + 1 < rest.length) {
      project = rest[++i];
    }
  }
  return _ParsedArgs(feature: feature, project: project, force: force);
}

class _Resolved {
  final String projectRoot;
  final String? feature;
  final String Function(String) outDir;
  const _Resolved({
    required this.projectRoot,
    required this.feature,
    required this.outDir,
  });
}
