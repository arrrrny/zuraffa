import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/sync/sync_plugin.dart';
import 'package:zuraffa/src/plugins/sync/capabilities/create_sync_capability.dart';

/// Tests for [SyncPlugin] registration, config schema, and capability
/// resolution (T047, FR-014).
void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_sync_plugin_');
    outputDir = '${tempDir.path}/lib/src';
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  SyncPlugin _plugin() => SyncPlugin(
    outputDir: outputDir,
    options: const GeneratorOptions(force: true),
  );

  test('exposes plugin identity metadata', () {
    final plugin = _plugin();
    expect(plugin.id, equals('sync'));
    expect(plugin.name, equals('Sync Plugin'));
    expect(plugin.version, equals('1.0.0'));
    expect(plugin.runAfter, equals(['datasource', 'repository']));
  });

  test('config schema declares sync options', () {
    final plugin = _plugin();
    final schema = plugin.configSchema;
    expect(schema['type'], equals('object'));
    final properties = schema['properties'] as Map;
    expect(properties.containsKey('sync-direction'), isTrue);
    expect(properties.containsKey('sync-batch-size'), isTrue);
    expect(properties.containsKey('sync-max-retries'), isTrue);

    final direction = properties['sync-direction'] as Map;
    expect(direction['enum'], equals(['push', 'bidirectional']));
    expect(direction['default'], equals('push'));
  });

  test('resolves CreateSyncCapability', () {
    final plugin = _plugin();
    expect(plugin.capabilities, hasLength(1));
    expect(plugin.capabilities.first, isA<CreateSyncCapability>());
  });

  test('creates a SyncCommand', () {
    final plugin = _plugin();
    final command = plugin.createCommand();
    expect(command.name, equals('sync'));
    expect(command.description, contains('sync'));
  });

  test('generate returns no files when sync is disabled', () async {
    final plugin = _plugin();
    final files = await plugin.generate(
      GeneratorConfig(name: 'Product', enableSync: false, outputDir: outputDir),
    );
    expect(files, isEmpty);
  });

  test('generate produces sync files when sync is enabled', () async {
    final plugin = _plugin();
    final files = await plugin.generate(
      GeneratorConfig(
        name: 'Product',
        methods: const ['get', 'getList', 'create', 'update', 'delete'],
        enableSync: true,
        outputDir: outputDir,
        force: true,
      ),
    );
    expect(files, isNotEmpty);

    final paths = files.map((f) => f.path).toList();
    // init + metadata store + strategy + usecase + index
    expect(paths.any((p) => p.endsWith('sync/product_sync.dart')), isTrue);
    expect(
      paths.any((p) => p.endsWith('product_sync_metadata_store.dart')),
      isTrue,
    );
    expect(paths.any((p) => p.endsWith('product_sync_strategy.dart')), isTrue);
    expect(paths.any((p) => p.endsWith('product_sync_usecase.dart')), isTrue);
  });
}
