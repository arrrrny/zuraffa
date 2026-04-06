import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/datasource/datasource_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_datasource_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generates datasource interface and remote implementation', () async {
    final plugin = DataSourcePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: false,
        verbose: false,
      ),
    );

    await plugin.generate(
      GeneratorConfig(
        name: 'Product',
        methods: const ['get', 'create'],
        generateData: true,
        outputDir: outputDir,
      ),
    );

    final interfaceFile = File(
      '$outputDir/data/datasources/product/product_datasource.dart',
    );
    final remoteFile = File(
      '$outputDir/data/datasources/product/product_remote_datasource.dart',
    );

    expect(interfaceFile.existsSync(), isTrue);
    expect(remoteFile.existsSync(), isTrue);
    expect(
      interfaceFile.readAsStringSync().contains('class ProductDataSource'),
      isTrue,
    );
    expect(
      remoteFile.readAsStringSync().contains('ProductRemoteDataSource'),
      isTrue,
    );
  });

  test('generates local datasource when cache is enabled', () async {
    final plugin = DataSourcePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: false,
        verbose: false,
      ),
    );

    await plugin.generate(
      GeneratorConfig(
        name: 'Order',
        methods: const ['get', 'getList'],
        generateData: true,
        enableCache: true,
        cacheStorage: 'hive',
        outputDir: outputDir,
      ),
    );

    final localFile = File(
      '$outputDir/data/datasources/order/order_local_datasource.dart',
    );
    final remoteFile = File(
      '$outputDir/data/datasources/order/order_remote_datasource.dart',
    );

    expect(localFile.existsSync(), isTrue);
    expect(remoteFile.existsSync(), isTrue);
    expect(localFile.readAsStringSync().contains('Box<Order>'), isTrue);
  });

  test('appends methods to existing datasource files', () async {
    final plugin = DataSourcePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: false,
        verbose: false,
      ),
    );

    // 1. Initial generation
    await plugin.generate(
      GeneratorConfig(
        name: 'Product',
        methods: const ['get'],
        generateData: true,
        outputDir: outputDir,
      ),
    );

    final interfaceFile = File(
      '$outputDir/data/datasources/product/product_datasource.dart',
    );
    final remoteFile = File(
      '$outputDir/data/datasources/product/product_remote_datasource.dart',
    );

    expect(
      interfaceFile.readAsStringSync().contains('Future<Product> get'),
      isTrue,
    );
    expect(
      interfaceFile.readAsStringSync().contains('Future<Product> create'),
      isFalse,
    );

    // 2. Append generation
    await plugin.generate(
      GeneratorConfig(
        name: 'Product',
        methods: const ['create'],
        appendToExisting: true,
        outputDir: outputDir,
      ),
    );
    expect(
      interfaceFile.readAsStringSync().contains('Future<Product> get'),
      isTrue,
    );
    expect(
      interfaceFile.readAsStringSync().contains('Future<Product> create'),
      isTrue,
    );
    expect(
      interfaceFile.readAsStringSync().contains('import augment'),
      isFalse,
    );
    final augmentFile = File(
      '$outputDir/data/datasources/product/product_datasource.augment.dart',
    );
    expect(augmentFile.existsSync(), isFalse);
    expect(
      remoteFile.readAsStringSync().contains('Future<Product> create'),
      isTrue,
    );
    expect(remoteFile.readAsStringSync().contains('import augment'), isFalse);
    final remoteAugmentFile = File(
      '$outputDir/data/datasources/product/product_remote_datasource.augment.dart',
    );
    expect(remoteAugmentFile.existsSync(), isFalse);
  });

  test('uses graphql constants when gql is enabled', () async {
    final plugin = DataSourcePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: false,
        verbose: false,
      ),
    );

    await plugin.generate(
      GeneratorConfig(
        name: 'Profile',
        methods: const ['get'],
        generateData: true,
        generateGql: true,
        outputDir: outputDir,
      ),
    );

    final remoteFile = File(
      '$outputDir/data/datasources/profile/profile_remote_datasource.dart',
    );

    final content = remoteFile.readAsStringSync();
    expect(
      content.contains("import 'graphql/get_profile_query.dart';"),
      isTrue,
    );
    expect(
      content.contains('throw UnimplementedError(getProfileQuery);'),
      isTrue,
    );
  });
}
