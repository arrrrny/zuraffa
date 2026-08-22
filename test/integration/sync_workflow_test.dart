@Tags(['integration', 'slow'])
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';

import '../regression/regression_test_utils.dart';

void main() {
  late RegressionWorkspace workspace;
  late String outputDir;
  late RepositoryPlugin plugin;

  setUp(() async {
    workspace = await createWorkspace('sync_workflow');
    await writePubspec(workspace);
    await runFlutterPubGet(workspace);
    await writeEntityStub(workspace, name: 'Product');
    outputDir = workspace.outputDir;
    plugin = RepositoryPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  group('Sync-Enabled Repository Generation', () {
    test(
      'generates repository with sync dependencies and local-first writes',
      () async {
        final config = GeneratorConfig(
          name: 'Product',
          methods: const ['get', 'getList', 'create', 'update', 'delete'],
          generateData: true,
          generateDataSource: true,
          enableSync: true,
          outputDir: outputDir,
          force: true,
        );

        await plugin.generate(config);

        final repoFile = File(
          '$outputDir/data/repositories/data_product_repository.dart',
        );
        expect(repoFile.existsSync(), isTrue);
        final content = repoFile.readAsStringSync();

        // Constructor must have 4 dependencies: local, remote, metadataStore, syncStrategy
        expect(content, contains('_localDataSource'));
        expect(content, contains('_remoteDataSource'));
        expect(content, contains('_syncMetadataStore'));
        expect(content, contains('_syncStrategy'));

        // Local-first create: writes to local, marks pending
        expect(content, contains('_localDataSource.create'));
        expect(content, contains('_syncStrategy.markPending'));
        expect(content, contains('SyncOperation.create'));

        // Local-first update: writes to local, marks pending
        expect(content, contains('_syncStrategy.markPending'));
        expect(content, contains('SyncOperation.update'));

        // Delete with tombstone
        expect(content, contains('_syncStrategy.markDeleted'));

        // Read from local only
        expect(content, contains('_localDataSource.get'));
        expect(content, contains('_localDataSource.getList'));

        // Sync delegation methods
        expect(content, contains('syncPending'));
        expect(content, contains('pullRemote'));
        expect(content, contains('_syncStrategy.syncPending'));
        expect(content, contains('_syncStrategy.pullRemote'));
      },
    );

    test(
      'reads delegate to local only (no remote calls in get/getList)',
      () async {
        final config = GeneratorConfig(
          name: 'Product',
          methods: const ['get', 'getList'],
          generateData: true,
          generateDataSource: true,
          enableSync: true,
          outputDir: outputDir,
          force: true,
        );

        await plugin.generate(config);

        final repoFile = File(
          '$outputDir/data/repositories/data_product_repository.dart',
        );
        final content = repoFile.readAsStringSync();

        // Extract the get() method body
        final getMatch = RegExp(
          r'Future<Product>\s+get\([^)]+\)\s*async\s*\{([^}]+)\}',
        ).firstMatch(content);
        expect(getMatch, isNotNull, reason: 'get() method not found');
        final getBody = getMatch!.group(1)!;
        expect(getBody, contains('_localDataSource.get'));
        expect(getBody, isNot(contains('_remoteDataSource')));
      },
    );

    test('throws error when both cache and sync are enabled', () async {
      final config = GeneratorConfig(
        name: 'Product',
        methods: const ['get'],
        generateData: true,
        enableCache: true,
        enableSync: true,
        outputDir: outputDir,
        force: true,
      );

      expect(() => plugin.generate(config), throwsA(isA<ArgumentError>()));
    });
  });
}
