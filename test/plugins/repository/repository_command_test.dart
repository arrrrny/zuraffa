// SPEC 1124 (issue #1124) — `zfa repository create` speaks the canonical
// `zuraffa.verdict.v1` envelope.
//
// The repository plugin carries the conformance gate, the contract
// manifests and `explainEmission`, but its CLI surface (`zfa repository
// create`) emitted NO `--json` envelope — the generic `CapabilityCommand`
// owns `--json` as the JSON-INPUT option, so the machine-readability gap
// is structural: the flag cannot even be passed bare.
//
// Contract under test (issue #1105 envelope, orders #1124):
//   * `zfa repository create Product --json` — the last stdout line is a
//     single-line `{schema: zuraffa.verdict.v1, command, verdict,
//     exit_class, subject: {kind: repository, entity}, findings[],
//     manifest: {path, sha256, methods}, drifts[], details, timestamp}`
//     envelope;
//   * the human-readable channel is unchanged when `--json` is absent;
//   * a conformance-gate failure with `--json` carries the gate findings
//     in `findings[]` and the expected/actual methods in `details`;
//   * the standalone proof receipt (issue #996/#1130) keeps flowing.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/cli/exit_protocol.dart';
import 'package:zuraffa/src/commands/repository_create_command.dart';
import 'package:zuraffa/src/core/plugin_system/capability.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/plugins/repository/conformance/repository_conformance_checker.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';

void main() {
  late Directory workspace;
  late CliRunner runner;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_1124_');
    await Directory(
      p.join(workspace.path, 'lib', 'src'),
    ).create(recursive: true);
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: spec_1124_fixture
environment:
  sdk: ^3.11.0
''');
    runner = CliRunner(exitOnCompletion: false);
  });

  tearDown(() {
    exitCode = 0;
    if (workspace.existsSync()) {
      try {
        workspace.deleteSync(recursive: true);
      } on FileSystemException {
        // Best-effort cleanup.
      }
    }
  });

  /// The LAST stdout line must be a single-line JSON envelope — the
  /// line-oriented consumer contract every --json emitter shares.
  Map<String, dynamic> decodeLastLine(String output) {
    final lines = output
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    expect(lines, isNotEmpty);
    final last = lines.last;
    try {
      return jsonDecode(last) as Map<String, dynamic>;
    } catch (e) {
      fail(
        'the last stdout line must be a single-line JSON envelope, got: '
        '"$last" ($e)\nfull output:\n$output',
      );
    }
  }

  group('SPEC 1124 — zfa repository create --json envelope', () {
    test('SC-1 positive: emits the canonical zuraffa.verdict.v1 envelope '
        'as the last stdout line', () async {
      final output = await runner.runCapturing([
        '-C',
        workspace.path,
        'repository',
        'create',
        'Product',
        '--json',
      ]);
      expect(
        output,
        isNot(contains('❌')),
        reason: 'generation must succeed:\n$output',
      );

      final envelope = decodeLastLine(output);

      expect(
        envelope['schema'],
        'zuraffa.verdict.v1',
        reason: 'the single canonical schema identifier (issue #1105)',
      );
      expect(envelope['command'], 'zfa repository create');
      expect(envelope['verdict'], 'pass');
      expect(
        envelope['exit_class'],
        ExitProtocol.success,
        reason: 'exit_class matches the zuraffa exit protocol',
      );
      expect(envelope['subject'], {
        'kind': 'repository',
        'entity': 'Product',
      }, reason: 'subject identifies WHAT the verdict is about');
      expect(
        envelope['findings'],
        isEmpty,
        reason: 'a pass carries no finding',
      );
      expect(envelope['drifts'], isEmpty);

      final manifest = envelope['manifest'] as Map<String, dynamic>?;
      expect(
        manifest,
        isNotNull,
        reason: 'a conforming fresh pair ships its contract manifest',
      );
      expect(
        manifest!['path'],
        '.zfa/receipts/repository-product.json',
        reason: 'the manifest path is project-relative POSIX',
      );
      expect(
        manifest['sha256'],
        matches(RegExp(r'^[0-9a-f]{64}$')),
        reason: 'the manifest is digest-bound',
      );
      expect(
        manifest['methods'],
        containsAll(<String>['get', 'update']),
        reason: 'the manifest carries the interface method set',
      );

      // The generated artifacts really landed (not just envelope prose).
      expect(
        File(
          p.join(
            workspace.path,
            'lib/src/domain/repositories/product_repository.dart',
          ),
        ).existsSync(),
        isTrue,
        reason: 'interface file is written',
      );
      expect(
        File(
          p.join(
            workspace.path,
            'lib/src/data/repositories/data_product_repository.dart',
          ),
        ).existsSync(),
        isTrue,
        reason: 'implementation file is written',
      );
      expect(
        File(
          p.join(workspace.path, '.zfa/receipts/repository-product.json'),
        ).existsSync(),
        isTrue,
        reason: 'the contract manifest file exists on disk',
      );
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('SC-2 positive: the standalone proof receipt keeps flowing '
        '(issue #996/#1130 parity on the manual command)', () async {
      final output = await runner.runCapturing([
        '-C',
        workspace.path,
        'repository',
        'create',
        'Cart',
        '--json',
      ]);
      expect(output, isNot(contains('❌')), reason: 'output:\n$output');

      final records = await ReceiptStore(projectRoot: workspace.path).loadAll();
      final capabilityReceipts = records
          .where((r) => r.receipt.plugin == 'repository')
          .where((r) => r.receipt.capability == 'create')
          .toList();
      expect(
        capabilityReceipts,
        isNotEmpty,
        reason:
            'the manual create command persists the proof receipt '
            'through CapabilityInvocationWrapper (the sole writer)',
      );
      expect(capabilityReceipts.last.receipt.entity, 'Cart');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('SC-3 human channel preserved: no --json keeps the existing '
        'prose and emits no envelope', () async {
      final output = await runner.runCapturing([
        '-C',
        workspace.path,
        'repository',
        'create',
        'Product',
      ]);
      expect(
        output,
        contains('✅ Success! Created/Modified'),
        reason: 'the human-readable summary is unchanged:\n$output',
      );
      expect(
        output,
        isNot(contains('zuraffa.verdict.v1')),
        reason: 'no envelope leaks into the human channel',
      );
      expect(exitCode, 0);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('SC-4 negative: missing --name under --json is a machine-actionable '
        'usage refusal in the envelope', () async {
      final output = await runner.runCapturing([
        '-C',
        workspace.path,
        'repository',
        'create',
        '--json',
      ]);

      final envelope = decodeLastLine(output);
      expect(envelope['schema'], 'zuraffa.verdict.v1');
      expect(envelope['verdict'], 'fail');
      expect(envelope['exit_class'], ExitProtocol.usage);

      final findings = envelope['findings'] as List;
      expect(findings, hasLength(1));
      final finding = findings.single as Map<String, dynamic>;
      expect(finding['kind'], 'missing_argument');
      expect(
        finding['fix'],
        contains('zfa repository create --name'),
        reason: 'the fix names the invocation',
      );
      expect(exitCode, ExitProtocol.usage);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('SC-5 gate-failure: conformance findings ride findings[] and the '
        'expected/actual methods ride details', () async {
      const failure = ConformanceFailure(
        method: 'update',
        side: 'implementation',
        message:
            'interface method `update` declared on ProductRepository has no '
            'implementation in DataProductRepository',
        fix:
            "--> fix: implement 'update' on the implementation side "
            '(DataProductRepository) — ProductRepository declares it '
            'without an overriding member.',
      );
      const gateResult = ConformanceResult(
        ok: false,
        interfaceClass: 'ProductRepository',
        implementationClass: 'DataProductRepository',
        interfaceMethods: ['get', 'update'],
        implementationOverrides: ['get'],
        failures: [failure],
      );

      final plugin = RepositoryPlugin(outputDir: workspace.path);
      final parent = _NamedParent('repository');
      parent.addSubcommand(
        RepositoryCreateCommand(
          plugin,
          projectRoot: workspace.path,
          capability: _GateFailingCapability(gateResult),
        ),
      );
      final runner = CommandRunner<void>('zfa', 'test')..addCommand(parent);

      final output = await _capture(
        () => runner.run(['repository', 'create', 'Product', '--json']),
      );

      final envelope = decodeLastLine(output);
      expect(envelope['schema'], 'zuraffa.verdict.v1');
      expect(envelope['command'], 'zfa repository create');
      expect(envelope['verdict'], 'fail');
      expect(envelope['exit_class'], ExitProtocol.failure);
      expect(envelope['subject'], {'kind': 'repository', 'entity': 'Product'});

      final findings = envelope['findings'] as List;
      expect(findings, hasLength(1));
      final finding = findings.single as Map<String, dynamic>;
      expect(finding['side'], 'implementation');
      expect(finding['kind'], 'conformance_mismatch');
      expect(finding['method'], 'update');
      expect(finding['fix'], contains('--> fix:'));

      final details = envelope['details'] as Map<String, dynamic>;
      expect(details['expected_methods'], [
        'get',
        'update',
      ], reason: 'the manifest expected method set');
      expect(details['actual_methods'], [
        'get',
      ], reason: 'the actually-implemented method set');
      expect(
        envelope['manifest'],
        isNull,
        reason:
            'a failed gate writes no contract manifest — the envelope '
            'must not claim one',
      );
      expect(exitCode, ExitProtocol.failure);
    });

    test('SC-6 gate-failure without --json: the exception propagates so the '
        'existing human channel is unchanged', () async {
      const failure = ConformanceFailure(
        method: 'update',
        side: 'implementation',
        message: 'interface method `update` has no implementation',
        fix: "--> fix: implement 'update' on the implementation side.",
      );
      const gateResult = ConformanceResult(
        ok: false,
        interfaceClass: 'ProductRepository',
        implementationClass: 'DataProductRepository',
        interfaceMethods: ['get', 'update'],
        implementationOverrides: ['get'],
        failures: [failure],
      );

      final plugin = RepositoryPlugin(outputDir: workspace.path);
      final parent = _NamedParent('repository');
      parent.addSubcommand(
        RepositoryCreateCommand(
          plugin,
          projectRoot: workspace.path,
          capability: _GateFailingCapability(gateResult),
        ),
      );
      final runner = CommandRunner<void>('zfa', 'test')..addCommand(parent);

      await expectLater(
        runner.run(['repository', 'create', 'Product']),
        throwsA(isA<RepositoryConformanceException>()),
        reason:
            'without --json the gate failure keeps its existing '
            'human-readable channel (the CLI runner catch-all prints it '
            'and exits 1)',
      );
    });
  });
}

/// Captures stdout printed inside [action] via a zoned override — direct
/// CommandRunner invocations (no CliRunner) print to the real stdout.
Future<String> _capture(Future<void> Function() action) async {
  final buffer = <String>[];
  await runZoned(
    action,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => buffer.add(line),
    ),
  );
  return buffer.join('\n');
}

/// A parent command whose name emulates a PluginCommand (name == plugin.id)
/// so the manual subcommand is exercised exactly as the live wiring does.
class _NamedParent extends Command<void> {
  _NamedParent(this._name);

  final String _name;

  @override
  String get name => _name;

  @override
  String get description => 'parent';
}

/// A stub capability that reproduces a conformance-gate failure — the
/// plugin template pair always conforms by construction, so the envelope's
/// gate-failure branch is driven through the same exception the real gate
/// throws (RepositoryConformanceException, spec 0973).
class _GateFailingCapability implements ZuraffaCapability {
  _GateFailingCapability(this.result);

  final ConformanceResult result;

  @override
  String get name => 'create';

  @override
  String get description => 'gate-failing stub';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
    },
    'required': ['name'],
  };

  @override
  JsonSchema get outputSchema => {'type': 'object'};

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async => EffectReport(
    planId: 'plan_stub',
    pluginId: 'repository',
    capabilityName: name,
    args: args,
    changes: const [],
  );

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    throw RepositoryConformanceException(result);
  }
}
