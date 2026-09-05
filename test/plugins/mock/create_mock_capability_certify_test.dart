import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/capability_command.dart';
import 'package:zuraffa/src/commands/mock_command.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/plugin_system/capability.dart';
import 'package:zuraffa/src/models/generated_file.dart';
import 'package:zuraffa/src/plugins/mock/capabilities/certify_mock_capability.dart';
import 'package:zuraffa/src/plugins/mock/capabilities/create_mock_capability.dart';
import 'package:zuraffa/src/plugins/mock/certification/mock_certifier.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';

/// Spec 1001 (issue #1001): the CLI surface — `zfa mock create <Entity>
/// --certify` / `--seed=<int>` materialize through the CapabilityCommand
/// schema bridge, and `zfa mock certify <Entity>` exists as its own
/// subcommand owning exit codes.
void main() {
  late Directory tempDir;
  late String outputDir;
  late MockPlugin plugin;
  late CreateMockCapability capability;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_1001_surface_');
    outputDir = p.join(tempDir.path, 'lib', 'src');
    final entityDir = Directory(
      p.join(outputDir, 'domain', 'entities', 'login'),
    );
    entityDir.createSync(recursive: true);
    File(p.join(entityDir.path, 'login.dart')).writeAsStringSync(
      'class Login { final String id; final String username; '
      'const Login({required this.id, required this.username}); }',
    );
    plugin = MockPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(dryRun: false, force: true),
    );
    capability = CreateMockCapability(plugin);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('spec 1001 — CLI surface', () {
    test('inputSchema declares certify and seed', () {
      final props =
          capability.inputSchema['properties'] as Map<String, dynamic>;
      expect((props['certify'] as Map<String, dynamic>)['type'], 'boolean');
      expect((props['seed'] as Map<String, dynamic>)['type'], 'integer');
    });

    test('CapabilityCommand materializes --certify and --seed (coerced '
        'to int, the issue #773 path)', () async {
      var capturedArgs = <String, dynamic>{};
      final probe = _RecordingCapability(
        'create',
        onCreate: (args) => capturedArgs = args,
      );
      final runner = CommandRunner<void>('zfa_test', 'surface test')
        ..addCommand(CapabilityCommand(probe));

      await runner.run([
        'create',
        '--name',
        'Login',
        '--certify',
        '--seed',
        '42',
      ]);

      expect(capturedArgs['certify'], isTrue);
      expect(
        capturedArgs['seed'],
        42,
        reason:
            'the schema-declared integer must arrive coerced, not as '
            'the String "42" (issue #773)',
      );
    });

    test('zfa mock exposes the certify subcommand (owns exit codes)', () {
      final command = MockCommand(plugin);
      expect(
        command.subcommands.keys,
        containsAll(['create', 'json', 'dependency', 'certify']),
      );
      final certify = command.subcommands['certify']!;
      expect(certify.description, contains('spec 1001'));
    });

    test('certify with no name prints usage + the usage exit code', () async {
      final command = MockCommand(plugin);
      final runner = CommandRunner<void>('zfa_test', 'certify usage')
        ..addCommand(command);
      await runner.run(['mock', 'certify']);
      expect(exitCode, CertifyMockCapability.exitUsage);
      exitCode = 0;
    });

    test('zfa mock certify refuses an entity with no mock artifacts '
        '(honest red, exit 2)', () async {
      final cap = CertifyMockCapability(plugin);
      final code = await cap.run(['Ghost', '--project', tempDir.path]);
      expect(code, CertifyMockCapability.exitNoMock);
    });

    test('zfa mock create --certify with no interface for the entity '
        'fails honestly (no receipt lies)', () async {
      // The entity exists but no mock/interface was generated for it —
      // certification must refuse without writing a receipt that lies.
      final certifier = MockCertifier();
      final outcome = await certifier.certify(
        entityName: 'Login',
        projectRoot: tempDir.path,
        outputDir: outputDir,
      );

      expect(outcome.certified, isFalse);
      expect(outcome.contractTestSource, isNull);
      expect(outcome.logs.join('\n'), contains('no mock datasource'));
      expect(
        outcome.logs.join('\n'),
        contains('--certify'),
        reason: 'the refusal names the fix',
      );

      // And nothing was written (no contract test, no receipt).
      final written = await certifier.writeContractArtifacts(
        entityName: 'Login',
        projectRoot: tempDir.path,
        outcome: outcome,
      );
      expect(written, isEmpty);
    });
  });
}

/// A minimal capability that records the args CapabilityCommand built —
/// proves the schema bridge (flags → typed args) without executing the
/// heavy certification machinery.
class _RecordingCapability implements ZuraffaCapability {
  _RecordingCapability(this.name, {required this.onCreate});

  @override
  final String name;

  final void Function(Map<String, dynamic>) onCreate;

  @override
  String get description => 'record args';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
      'certify': {'type': 'boolean', 'default': false},
      'seed': {'type': 'integer'},
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

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async => EffectReport(
    planId: 'plan_probe',
    pluginId: 'mock',
    capabilityName: name,
    args: args,
    changes: const [],
  );

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    onCreate(args);
    return ExecutionResult(
      success: true,
      files: ['lib/src/probe.dart'],
      data: {
        'generatedFiles': [
          GeneratedFile(
            path: 'lib/src/probe.dart',
            content: '// probe',
            action: 'created',
            type: 'probe',
          ),
        ],
      },
    );
  }
}
