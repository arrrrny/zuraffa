import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/gym/gym_plugin.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_context.dart';
import 'package:zuraffa/src/core/plugin_system/discovery_engine.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_interface.dart'
    show ZuraffaPlugin, FileGeneratorPlugin;
import 'package:zuraffa/src/core/plugin_system/cli_aware_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_gym_plugin_test_');
    outputDir = p.join(tempDir.path, 'lib', 'src');
    await Directory(outputDir).create(recursive: true);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('GymPlugin identity (mirrors TestPlugin shape)', () {
    test('id is "gym"', () {
      final plugin = GymPlugin(outputDir: outputDir);
      expect(plugin.id, equals('gym'));
    });

    test('name is "Gym Plugin"', () {
      final plugin = GymPlugin(outputDir: outputDir);
      expect(plugin.name, equals('Gym Plugin'));
    });

    test('version is "1.0.0"', () {
      final plugin = GymPlugin(outputDir: outputDir);
      expect(plugin.version, equals('1.0.0'));
    });

    test('configKey is "gymByDefault"', () {
      final plugin = GymPlugin(outputDir: outputDir);
      expect(plugin.configKey, equals('gymByDefault'));
    });

    test('configSchema is an empty object for v1', () {
      final plugin = GymPlugin(outputDir: outputDir);
      expect(plugin.configSchema['type'], equals('object'));
      expect((plugin.configSchema['properties'] as Map).isEmpty, isTrue);
    });

    test('extends FileGeneratorPlugin and implements CliAwarePlugin', () {
      final plugin = GymPlugin(outputDir: outputDir);
      expect(plugin, isA<FileGeneratorPlugin>());
      expect(plugin, isA<CliAwarePlugin>());
      expect(plugin, isA<ZuraffaPlugin>());
    });

    test('exposes exactly one CreateGymCapability', () {
      final plugin = GymPlugin(outputDir: outputDir);
      expect(plugin.capabilities, hasLength(1));
      expect(plugin.capabilities.first.name, equals('create'));
    });

    test('runAfter includes every layer the gym must follow', () {
      final plugin = GymPlugin(outputDir: outputDir);
      // Gym exercises reference the generated code AND its tests, so they
      // must run after every codegen layer AND after the test plugin.
      expect(plugin.runAfter, contains('feature'));
      expect(plugin.runAfter, contains('usecase'));
      expect(plugin.runAfter, contains('repository'));
      expect(plugin.runAfter, contains('service'));
      expect(plugin.runAfter, contains('datasource'));
      expect(plugin.runAfter, contains('provider'));
      expect(plugin.runAfter, contains('view'));
      expect(plugin.runAfter, contains('presenter'));
      expect(plugin.runAfter, contains('controller'));
      expect(plugin.runAfter, contains('di'));
      expect(plugin.runAfter, contains('gql'));
      expect(plugin.runAfter, contains('cache'));
      expect(plugin.runAfter, contains('route'));
      expect(plugin.runAfter, contains('shadcn'));
      expect(plugin.runAfter, contains('test'));
    });
  });

  group('GymPlugin.generateWithContext', () {
    test(
      'emits the gym/ artifact per entity (warmup + exercise + yaml)',
      () async {
        final plugin = GymPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(dryRun: false, force: true),
        );

        final context = PluginContext(
          core: CoreConfig(
            name: 'Product',
            projectRoot: tempDir.path,
            outputDir: outputDir,
          ),
          discovery: DiscoveryEngine(projectRoot: outputDir),
        );

        final results = await plugin.generateWithContext(context);

        // 4 files: 2 warmup reps + 1 exercise + 1 gym.yaml
        expect(results, hasLength(4));

        final paths = results.map((f) => f.path).toList();
        expect(
          paths,
          containsAll([
            p.join(tempDir.path, 'gym', 'warmup', '01-smoke.dart'),
            p.join(tempDir.path, 'gym', 'warmup', '02-build.dart'),
            p.join(tempDir.path, 'gym', 'exercise-implement-feature.dart'),
            p.join(tempDir.path, 'gym', 'gym.yaml'),
          ]),
        );

        // Every file was actually written to disk.
        for (final file in results) {
          expect(
            File(file.path).existsSync(),
            isTrue,
            reason: '${file.path} should exist on disk',
          );
          expect(
            file.action,
            equals('created'),
            reason: '${file.path} should be created (force=true)',
          );
        }
      },
    );

    test('warmup smoke rep references the entity and its UseCase', () async {
      final plugin = GymPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );

      final context = PluginContext(
        core: CoreConfig(
          name: 'Product',
          projectRoot: tempDir.path,
          outputDir: outputDir,
        ),
        discovery: DiscoveryEngine(projectRoot: outputDir),
      );

      final results = await plugin.generateWithContext(context);
      final smoke = results.firstWhere(
        (f) => f.path.endsWith(p.join('warmup', '01-smoke.dart')),
      );
      final content = smoke.content ?? '';

      expect(content, contains('Product'));
      expect(content, contains('ProductUseCase'));
      expect(content, contains('drop-card'));
      expect(content, contains('dart run gym/warmup/01-smoke.dart'));
    });

    test(
      'gym.yaml is a machine-readable spec the runner can consume',
      () async {
        final plugin = GymPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(dryRun: false, force: true),
        );

        final context = PluginContext(
          core: CoreConfig(
            name: 'Product',
            projectRoot: tempDir.path,
            outputDir: outputDir,
          ),
          discovery: DiscoveryEngine(projectRoot: outputDir),
        );

        final results = await plugin.generateWithContext(context);
        final yaml = results.firstWhere((f) => f.path.endsWith('gym.yaml'));
        final content = yaml.content ?? '';

        // The miki GYM runner (gym.mjs) consumes these top-level keys.
        expect(content, contains('name: product'));
        expect(content, contains('version: 1.0.0'));
        expect(content, contains('warmup:'));
        expect(content, contains('exercises:'));
        expect(content, contains('id: 01-smoke'));
        expect(content, contains('id: 02-build'));
        expect(content, contains('id: implement-feature'));
        expect(content, contains('verifyCommand:'));
        expect(content, contains('evaluate:'));
        expect(content, contains('flutter test test/product/'));
      },
    );

    test('returns no files when generateGym is false', () async {
      final plugin = GymPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(),
      );

      // generateWithContext always sets generateGym=true, so test the legacy
      // generate() path directly with generateGym=false.
      final config = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        generateGym: false,
      );
      final files = await plugin.generate(config);
      expect(files, isEmpty);
    });

    test('revert mode deletes the gym artifact', () async {
      final plugin = GymPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );

      // First, create the artifact.
      final context = PluginContext(
        core: CoreConfig(
          name: 'Product',
          projectRoot: tempDir.path,
          outputDir: outputDir,
          force: true,
        ),
        discovery: DiscoveryEngine(projectRoot: outputDir),
      );
      await plugin.generateWithContext(context);

      final gymYaml = File(p.join(tempDir.path, 'gym', 'gym.yaml'));
      expect(gymYaml.existsSync(), isTrue);

      // Now revert: should delete the files.
      final revertPlugin = GymPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          revert: true,
        ),
      );
      final revertConfig = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        generateGym: true,
        revert: true,
      );
      await revertPlugin.generate(revertConfig);

      expect(
        gymYaml.existsSync(),
        isFalse,
        reason: 'gym.yaml should be deleted on revert',
      );
    });
  });

  group('GymPlugin capability contract', () {
    test('create capability plan() reports the 4 gym files', () async {
      final plugin = GymPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: true, force: true),
      );
      final capability = plugin.capabilities.first;
      final report = await capability.plan({
        'name': 'Order',
        'domain': 'general',
      });

      expect(report.pluginId, equals('gym'));
      expect(report.capabilityName, equals('create'));
      // Plan runs in dry-run mode but the gym builder still emits 4 files
      // (dryRun only suppresses disk writes, not the GeneratedFile list).
      expect(report.changes, hasLength(4));
    });

    test('create capability execute() writes the gym files', () async {
      final plugin = GymPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );
      final capability = plugin.capabilities.first;
      final result = await capability.execute({
        'name': 'Order',
        'domain': 'general',
      });

      expect(result.success, isTrue);
      expect(result.files, hasLength(4));
      expect(result.files, contains(p.join(tempDir.path, 'gym', 'gym.yaml')));
    });
  });
}
