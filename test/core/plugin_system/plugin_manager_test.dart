import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zuraffa/src/cli/plugin_loader.dart';
import 'package:zuraffa/src/config/zfa_config.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/core/plugin_system/discovery_engine.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_context.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_interface.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_manager.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_registry.dart';
import 'package:zuraffa/src/models/generated_file.dart';
import 'package:zuraffa/src/models/generator_config.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_plugin_manager_test_');
    outputDir = p.join(tempDir.path, 'lib', 'src');
    await Directory(outputDir).create(recursive: true);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('applies plugin defaults from .zfa.json and honors disabled plugins', () async {
    await ZfaConfig.save(
      ZfaConfig(
        pluginDefaults: const {'repository': true, 'di': true, 'route': true},
        disabledPlugins: const {'route'},
      ),
      projectRoot: tempDir.path,
    );

    final registry = PluginRegistry()
      ..registerAll([
        _FakePlugin('repository'),
        _FakePlugin('di', configKey: 'diByDefault'),
        _FakePlugin('route', configKey: 'routeByDefault'),
      ]);

    final manager = PluginManager(
      registry: registry,
      config: ZfaConfig.load(projectRoot: tempDir.path),
      pluginConfig: PluginConfig.load(projectRoot: tempDir.path),
      projectRoot: tempDir.path,
    );

    final plan = manager.resolvePlan(name: 'Product');

    expect(plan.pluginIds, equals(['repository', 'di']));
  });

  test('fails fast when entity-first generation is requested without an entity', () async {
    final registry = PluginRegistry()..register(_NoopFilePlugin('usecase'));
    final manager = PluginManager(
      registry: registry,
      config: ZfaConfig(),
      projectRoot: tempDir.path,
    );

    final context = PluginContext(
      core: CoreConfig(
        name: 'Product',
        projectRoot: tempDir.path,
        outputDir: outputDir,
        dryRun: true,
      ),
      discovery: DiscoveryEngine(projectRoot: tempDir.path),
      fileSystem: FileSystem.create(root: tempDir.path),
      data: const {'methods': ['get']},
    );

    expect(
      () => manager.run(context, [_NoopFilePlugin('usecase')]),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Create it first with `zfa entity create -n Product`'),
        ),
      ),
    );
  });
}

class _FakePlugin extends ZuraffaPlugin {
  @override
  final String id;

  final String? _configKey;

  _FakePlugin(this.id, {String? configKey}) : _configKey = configKey;

  @override
  String? get configKey => _configKey;

  @override
  String get name => id;

  @override
  String get version => '1.0.0';
}

class _NoopFilePlugin extends FileGeneratorPlugin {
  @override
  final String id;

  _NoopFilePlugin(this.id);

  @override
  String get name => id;

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async => const [];
}
