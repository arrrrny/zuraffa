@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/cli/plugin_loader.dart';
import 'package:zuraffa/src/config/zfa_config.dart';
import 'package:zuraffa/src/core/planning/plan_resolver.dart';

/// BUG 1496 — `zfa config init` wrote ALL 24 builtin plugins `false`, so
/// the first bare `zfa make` in a fresh project resolved zero plugins and
/// printed "No active plugins to run." (exit 0, silent no-op). The same
/// command with `--preset=crud` generated the full slice.
///
/// The fix flips the clean-architecture stack ON in
/// `_builtinPluginDefaults` (12 plugins), keeps the opt-in set OFF, adds
/// a remedy line to the empty-plan message, and adds
/// `zfa config init --minimal` for teams who want the all-off behaviour.
void main() {
  // The stack the issue pins — the framework's standard clean-architecture
  // tier that a fresh project should scaffold without any crutch flags.
  const stackPlugins = <String>[
    'di',
    'datasource',
    'repository',
    'usecase',
    'mock',
    'test',
    'method_append',
    'route',
    'provider',
    'presenter',
    'controller',
    'cache',
  ];

  // Opt-in plugins that must stay false (plus the two unlisted builtins —
  // observer is removed per #1149 and service is a distinct opt-in lane).
  const optInPlugins = <String>[
    'graphql',
    'gql',
    'sqlite',
    'view',
    'skin',
    'state',
    'feature',
    'gym',
    'xray',
    'agent',
    'observer',
    'service',
  ];

  group('BUG 1496 — config defaults enable the clean-architecture stack', () {
    late Directory tempDir;
    late String projectRoot;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bug_1496_init_');
      projectRoot = tempDir.path;
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        try {
          await tempDir.delete(recursive: true);
        } on FileSystemException {
          // A late child may still hold the workspace — teardown best effort.
        }
      }
    });

    test(
      'B1 — ZfaConfig.init writes the stack true and opt-ins false',
      () async {
        await ZfaConfig.init(projectRoot: projectRoot);

        final config = ZfaConfig.load(projectRoot: projectRoot);
        expect(config, isNotNull);
        for (final id in stackPlugins) {
          expect(
            config!.pluginDefaults[id],
            isTrue,
            reason: 'stack plugin "$id" must default true after init',
          );
        }
        for (final id in optInPlugins) {
          expect(
            config!.pluginDefaults[id],
            isFalse,
            reason: 'opt-in plugin "$id" must stay false after init',
          );
        }
      },
    );

    test('B2 — the in-memory default enables the stack for the resolver', () {
      final config = ZfaConfig();

      for (final id in stackPlugins) {
        expect(
          config.isPluginEnabledByDefault(id),
          isTrue,
          reason: 'isPluginEnabledByDefault("$id") must be true',
        );
      }
      for (final id in optInPlugins) {
        expect(
          config.isPluginEnabledByDefault(id),
          isFalse,
          reason: 'isPluginEnabledByDefault("$id") must be false',
        );
      }

      // The resolver turns a bare `make` into the stack plan — the exact
      // path that produced "No active plugins to run." before the fix.
      final registry = PluginLoader(
        outputDir: '/tmp/bug_1496_lib_src',
        dryRun: true,
        force: true,
        verbose: false,
        config: PluginConfig(),
      ).buildRegistry();
      final resolver = PlanResolver(registry: registry, config: config);
      final plan = resolver.resolve(name: 'Note');

      expect(plan.pluginIds, containsAll(stackPlugins));
    });

    test('B3 — explicit false in a custom config still wins', () async {
      await ZfaConfig.init(projectRoot: projectRoot);
      final configFile = File(path.join(projectRoot, '.zfa.json'));
      final json =
          jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
      final defaults =
          (json['plugins'] as Map<String, dynamic>)['defaults']
              as Map<String, dynamic>;
      // A team opting OUT of two stack plugins explicitly.
      defaults['mock'] = false;
      defaults['route'] = false;
      configFile.writeAsStringSync(jsonEncode(json));

      final config = ZfaConfig.load(projectRoot: projectRoot);
      expect(config, isNotNull);
      expect(config!.isPluginEnabledByDefault('mock'), isFalse);
      expect(config.isPluginEnabledByDefault('route'), isFalse);
      // Untouched stack members stay on — the custom config is not broken.
      expect(config.isPluginEnabledByDefault('di'), isTrue);
      expect(config.isPluginEnabledByDefault('repository'), isTrue);
    });

    test('B4 — config init --minimal keeps the all-off behaviour', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing([
        '-C',
        projectRoot,
        'config',
        'init',
        '--minimal',
      ]);

      expect(output, contains('Minimal mode'));
      final config = ZfaConfig.load(projectRoot: projectRoot);
      expect(
        config,
        isNotNull,
        reason: 'minimal init must still write the file',
      );
      for (final id in stackPlugins) {
        expect(
          config!.pluginDefaults[id],
          isFalse,
          reason: 'minimal init must keep "$id" off',
        );
      }
    });
  });

  group('BUG 1496 — make remedy + end-to-end first make', () {
    late Directory workspace;
    late String outputDir;

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('bug_1496_make_');
      outputDir = path.join(workspace.path, 'lib', 'src');
      await Directory(outputDir).create(recursive: true);
      await File(path.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: bug_1496_make_test
environment:
  sdk: ^3.11.0
''');
      final entityDir = Directory(
        path.join(outputDir, 'domain', 'entities', 'note'),
      );
      await entityDir.create(recursive: true);
      await File(path.join(entityDir.path, 'note.dart')).writeAsString('''
class Note {
  final String id;
  final String title;

  const Note({required this.id, required this.title});
}
''');
    });

    tearDown(() async {
      if (workspace.existsSync()) {
        try {
          await workspace.delete(recursive: true);
        } on FileSystemException {
          // Teardown best effort (see #503 note in make_command_test).
        }
      }
    });

    test(
      'B5 — bare zfa make in an init-ed project generates the stack',
      timeout: const Timeout(Duration(minutes: 5)),
      () async {
        await ZfaConfig.init(projectRoot: workspace.path);

        final runner = CliRunner(exitOnCompletion: false);
        final output = await runner.runCapturing([
          '-C',
          workspace.path,
          'make',
          'Note',
          '--output',
          outputDir,
        ]);

        // The pre-fix dead end is gone.
        expect(output, isNot(contains('No active plugins')));
        // The stack actually generated — the artifacts #1496 shows via
        // --preset=crud land WITHOUT the preset crutch.
        expect(
          File(
            path.join(
              outputDir,
              'domain',
              'repositories',
              'note_repository.dart',
            ),
          ).existsSync(),
          isTrue,
          reason: 'repository plugin must have generated the repository',
        );
        expect(
          File(
            path.join(
              outputDir,
              'data',
              'datasources',
              'note',
              'note_datasource.dart',
            ),
          ).existsSync(),
          isTrue,
          reason: 'datasource plugin must have generated the datasource',
        );
        expect(
          File(path.join(outputDir, 'di', 'service_locator.dart')).existsSync(),
          isTrue,
          reason: 'di plugin must have generated the service locator',
        );
        expect(
          File(
            path.join(outputDir, 'data', 'mock', 'note_mock_data.dart'),
          ).existsSync(),
          isTrue,
          reason: 'mock plugin must have generated the mock data',
        );
      },
    );

    test('B6 — the empty-plan message names the remedy', () async {
      // A minimal (all-off) config is the legitimate way to reach the
      // empty-plan branch post-fix.
      await ZfaConfig.init(projectRoot: workspace.path);
      final configFile = File(path.join(workspace.path, '.zfa.json'));
      final json =
          jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
      final defaults =
          (json['plugins'] as Map<String, dynamic>)['defaults']
              as Map<String, dynamic>;
      for (final key in defaults.keys.toList()) {
        defaults[key] = false;
      }
      configFile.writeAsStringSync(jsonEncode(json));

      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing([
        '-C',
        workspace.path,
        'make',
        'Note',
        '--no-entity',
        '--output',
        outputDir,
      ]);

      expect(output, contains('No active plugins'));
      expect(output, contains('--preset=crud'));
      expect(output, contains('--with='));
    });
  });
}
