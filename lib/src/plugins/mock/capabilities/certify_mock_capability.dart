/// CertifyMockCapability (spec 1001, issue #1001): `zfa mock certify
/// <Entity>` — re-proves the mock's contract LIVE (auto-generated
/// contract test in a temp sandbox: dart analyze + dart test) and adds
/// the mock to the #832 certification registry entry.
///
/// The registry add is the live re-proof, never a copy of an old
/// receipt: `certifyMockInRegistry` commits the freshly-proven receipt
/// into the feature's `tdd/fixtures/` directory, re-writes the #832
/// manifest (the receipt is hashed into the world digest, `mocks:`
/// provenance records the entity), and appends the hash-chained
/// `kind: mock-cert` cycle-log evidence.
///
/// Refusals (errors-are-an-API, every one names the fix):
/// - missing positional entity name        → exit 1 (usage)
/// - no mock artifacts for the entity      → exit 2
/// - contract red in the sandbox           → exit 3
/// - no feature/fixtures dir resolvable    → exit 4
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/project/project_root.dart';
import '../certification/mock_certifier.dart';
import '../mock_plugin.dart';
import '../../../core/plugin_system/capability.dart';
import '../builders/simulation/fixture_certification.dart';

class CertifyMockCapability implements ZuraffaCapability {
  final MockPlugin plugin;

  CertifyMockCapability(this.plugin);

  @override
  String get name => 'certify_mock';

  @override
  String get description =>
      'Re-certify a mock live and register it in the #832 registry '
      '(spec 1001)';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'Entity whose mock is certified',
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
      'fixtures-dir': {
        'type': 'string',
        'description':
            'Explicit fixtures directory for the #832 registry entry '
            '(default: specs/<feature>/tdd/fixtures)',
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

  /// Exit-code contract.
  static const exitUsage = 1;
  static const exitNoMock = 2;
  static const exitRed = 3;
  static const exitNoRegistry = 4;

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    throw UnsupportedError(
      'zfa mock certify plans through run() — the CLI owns exit codes '
      'and the machine summary line (spec 1001).',
    );
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    throw UnsupportedError('use run() — the CLI owns exit codes');
  }

  /// The CLI entrypoint (`zfa mock certify <Entity>`): owns exit codes +
  /// the machine summary line. Returns the process exit code.
  Future<int> run(List<String> args) async {
    final name = args.isNotEmpty ? args.first : null;
    if (name == null || name.isEmpty) {
      stderr.writeln(
        'zfa mock certify: pass the entity whose mock is certified.\n'
        '--> fix: zfa mock certify <Entity> (after '
        '`zfa mock create <Entity> --certify`).',
      );
      return exitUsage;
    }
    final parsed = _parseArgs(args.skip(1).toList());
    final projectRoot = parsed.project != null && parsed.project!.isNotEmpty
        ? p.absolute(parsed.project!)
        : ProjectRoot.find(anchorDir: 'specs');

    // 1. Live re-proof: extract the contract, render the test, run the
    //    sandbox, build the receipt.
    final certifier = MockCertifier();
    final outcome = await certifier.certify(
      entityName: name,
      projectRoot: projectRoot,
      outputDir: p.join(projectRoot, 'lib', 'src'),
      verbose: parsed.verbose,
    );

    // Refusal BEFORE the sandbox ran: no mock artifacts / no interface
    // to pin — a different failure class than a red contract.
    if (outcome.contractTestSource == null) {
      for (final line in outcome.logs) {
        stderr.writeln('zfa mock certify: $line');
      }
      stderr.writeln(
        '--> fix: `zfa mock create $name --certify` first, then certify.',
      );
      return exitNoMock;
    }

    // 2. Commit the contract test + receipt into the project — on BOTH
    //    outcomes. A red run MUST overwrite any stale green receipt: the
    //    run-engine gate reads this receipt, and leaving a pre-drift
    //    green receipt on disk would let an uncertified mock through.
    final written = await certifier.writeContractArtifacts(
      entityName: name,
      projectRoot: projectRoot,
      outcome: outcome,
    );

    if (!outcome.certified) {
      for (final line in outcome.logs) {
        stderr.writeln('zfa mock certify: $line');
      }
      if (outcome.logs.isEmpty) {
        stderr.writeln(
          'zfa mock certify: the contract test for $name is red — '
          'unsatisfied: ${outcome.methodNames.join(', ')}',
        );
      }
      stderr.writeln(
        '--> fix: regenerate the mock + contract '
        '(`zfa mock create $name --certify`), or restore the drifted '
        'interface, then re-run.',
      );
      return exitRed;
    }

    // 3. Register in the #832 fixture registry.
    final fixturesDir = await _resolveFixturesDir(
      projectRoot: projectRoot,
      feature: parsed.feature,
      fixturesDirFlag: parsed.fixturesDir,
    );
    if (fixturesDir == null) {
      stderr.writeln(
        'zfa mock certify: no fixtures directory resolved for the #832 '
        'registry entry — the certification is proven (receipt written '
        'to ${written.length} file(s)) but not registered.',
      );
      stderr.writeln(
        '--> fix: pass --fixtures-dir <dir>, or --feature <f> '
        '(specs/<f>/tdd/fixtures), or pin .specify/feature.json with '
        '`zfa tdd plan <feature>`.',
      );
      return exitNoRegistry;
    }
    if (!Directory(fixturesDir).existsSync()) {
      stderr.writeln(
        'zfa mock certify: fixtures directory does not exist: '
        '${p.relative(fixturesDir, from: projectRoot)}',
      );
      stderr.writeln(
        '--> fix: scaffold it first '
        '(`zfa mock create <Entity> --fixtures-dir <dir>` or '
        '`zfa simulate --scaffold`), then re-run.',
      );
      return exitNoRegistry;
    }

    try {
      await certifyMockInRegistry(
        fixturesDir: fixturesDir,
        entityName: name,
        receipt: outcome.receipt!.toJson(),
        commandLine: 'zfa mock certify $name',
        verbose: parsed.verbose,
      );
    } catch (e) {
      stderr.writeln('zfa mock certify: registry re-certification failed — $e');
      return exitRed;
    }

    final receipt = outcome.receipt!;
    stdout.writeln(
      'mock-certify: entity=$name '
      'methods=${receipt.methods.length} '
      'satisfied=${receipt.methods.where((m) => m.value).length} '
      'feature=${parsed.feature ?? _pinnedFeature(projectRoot) ?? '-'} '
      'registered=true '
      'receipt=${p.relative(written.last.path, from: projectRoot)}',
    );
    return 0;
  }

  /// Resolve the #832 fixtures directory: explicit flag → feature →
  /// pinned `.specify/feature.json`. Null when unresolvable.
  Future<String?> _resolveFixturesDir({
    required String projectRoot,
    String? feature,
    String? fixturesDirFlag,
  }) async {
    if (fixturesDirFlag != null && fixturesDirFlag.isNotEmpty) {
      return p.absolute(fixturesDirFlag);
    }
    final featureName = feature ?? _pinnedFeature(projectRoot);
    if (featureName == null || featureName.isEmpty) return null;
    final dir = p.join(projectRoot, 'specs', featureName, 'tdd', 'fixtures');
    return dir;
  }

  static String? _pinnedFeature(String projectRoot) {
    final f = File(p.join(projectRoot, '.specify', 'feature.json'));
    if (!f.existsSync()) return null;
    try {
      final json = f.readAsStringSync();
      final m = RegExp(r'"feature_directory"\s*:\s*"([^"]+)"').firstMatch(json);
      return m?.group(1);
    } on FileSystemException {
      return null;
    }
  }
}

class _ParsedArgs {
  final String? feature;
  final String? project;
  final String? fixturesDir;
  final bool force;
  final bool verbose;
  const _ParsedArgs({
    this.feature,
    this.project,
    this.fixturesDir,
    this.force = false,
    this.verbose = false,
  });
}

_ParsedArgs _parseArgs(List<String> rest) {
  String? feature;
  String? project;
  String? fixturesDir;
  var force = false;
  var verbose = false;
  for (var i = 0; i < rest.length; i++) {
    final a = rest[i];
    if (a == '--force') {
      force = true;
    } else if (a == '--verbose' || a == '-v') {
      verbose = true;
    } else if (a == '--feature' && i + 1 < rest.length) {
      feature = rest[++i];
    } else if (a == '--project' && i + 1 < rest.length) {
      project = rest[++i];
    } else if (a == '--fixtures-dir' && i + 1 < rest.length) {
      fixturesDir = rest[++i];
    }
  }
  return _ParsedArgs(
    feature: feature,
    project: project,
    fixturesDir: fixturesDir,
    force: force,
    verbose: verbose,
  );
}
