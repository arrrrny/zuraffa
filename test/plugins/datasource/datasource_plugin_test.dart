import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
      dryRun: false,
      force: false,
      verbose: false,
    );

    await plugin.generate(
      GeneratorConfig(
        name: 'Product',
        methods: const ['get', 'create'],
        generateData: true,
      ),
    );

    final interfaceFile = File(
      '$outputDir/data/data_sources/product/product_data_source.dart',
    );
    final remoteFile = File(
      '$outputDir/data/data_sources/product/product_remote_data_source.dart',
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
      dryRun: false,
      force: false,
      verbose: false,
    );

    await plugin.generate(
      GeneratorConfig(
        name: 'Order',
        methods: const ['get', 'getList'],
        generateData: true,
        enableCache: true,
        cacheStorage: 'hive',
      ),
    );

    final localFile = File(
      '$outputDir/data/data_sources/order/order_local_data_source.dart',
    );
    final remoteFile = File(
      '$outputDir/data/data_sources/order/order_remote_data_source.dart',
    );

    expect(localFile.existsSync(), isTrue);
    expect(remoteFile.existsSync(), isTrue);
    expect(localFile.readAsStringSync().contains('Box<Order>'), isTrue);
  });

  test('uses graphql constants when gql is enabled', () async {
    final plugin = DataSourcePlugin(
      outputDir: outputDir,
      dryRun: false,
      force: false,
      verbose: false,
    );

    await plugin.generate(
      GeneratorConfig(
        name: 'Profile',
        methods: const ['get'],
        generateData: true,
        generateGql: true,
      ),
    );

    final remoteFile = File(
      '$outputDir/data/data_sources/profile/profile_remote_data_source.dart',
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
