import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_repo_cache_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'generates cache-aware watch streams with local and remote sources',
    () async {
      final plugin = RepositoryPlugin(
        outputDir: outputDir,
        dryRun: false,
        force: true,
        verbose: false,
      );

      final config = GeneratorConfig(
        name: 'Order',
        methods: const ['watch', 'watchList'],
        generateData: true,
        enableCache: true,
        cacheStorage: 'hive',
      );

      final files = await plugin.generate(config);
      final impl = files.firstWhere(
        (f) => f.path.contains('data_order_repository.dart'),
      );
      final content = impl.content ?? '';

      expect(content, contains('Stream<Order> watch'));
      expect(content, contains('Stream<List<Order>> watchList'));
      expect(content, contains('StreamController<Order>'));
      expect(content, contains('StreamController<List<Order>>'));
      expect(content, contains('_localDataSource'));
      expect(content, contains('_remoteDataSource'));
      
      final normalized = content.replaceAll(RegExp(r'\s+'), '');
      expect(normalized, contains('_localDataSource.watch'));
      expect(normalized, contains('_remoteDataSource.watch'));
      expect(normalized, contains('_localDataSource.watchList'));
      expect(normalized, contains('_remoteDataSource.watchList'));
      expect(content, contains('.save('));
      expect(content, contains('.saveAll('));
      expect(content, contains('localSub'));
      expect(content, contains('remoteSub'));
    },
  );
}
