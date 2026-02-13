import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/di/builders/registration_builder.dart';
import 'package:zuraffa/src/plugins/di/di_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_di_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generates repository and datasource registrations', () async {
    final plugin = DiPlugin(
      outputDir: outputDir,
      dryRun: false,
      force: false,
      verbose: false,
    );

    await plugin.generate(
      GeneratorConfig(
        name: 'Product',
        methods: const ['get'],
        generateData: true,
        generateDi: true,
        outputDir: outputDir,
      ),
    );

    final remoteFile = File(
      '$outputDir/di/datasources/product_remote_data_source_di.dart',
    );
    final repoFile = File(
      '$outputDir/di/repositories/product_repository_di.dart',
    );

    expect(remoteFile.existsSync(), isTrue);
    expect(repoFile.existsSync(), isTrue);
    expect(
      remoteFile.readAsStringSync().contains('ProductRemoteDataSource'),
      isTrue,
    );
    expect(
      repoFile.readAsStringSync().contains('DataProductRepository'),
      isTrue,
    );
  });

  test('uses mock datasource when useMockInDi is enabled', () async {
    final plugin = DiPlugin(
      outputDir: outputDir,
      dryRun: false,
      force: false,
      verbose: false,
    );

    await plugin.generate(
      GeneratorConfig(
        name: 'Order',
        methods: const ['get'],
        generateData: true,
        generateDi: true,
        useMockInDi: true,
        outputDir: outputDir,
      ),
    );

    final repoFile = File(
      '$outputDir/di/repositories/order_repository_di.dart',
    );
    final repoContent = repoFile.readAsStringSync();

    expect(repoContent.contains('OrderMockDataSource'), isTrue);
  });

  test('updates index files using AST append', () async {
    final diDir = Directory('$outputDir/di/datasources')
      ..createSync(recursive: true);
    final builder = RegistrationBuilder();
    final initialIndex = builder.buildIndexFile(
      functionName: 'registerAllDataSources',
      registrations: const [Code('registerProductRemoteDataSource(getIt);')],
      directives: const [],
    );
    File('${diDir.path}/index.dart').writeAsStringSync(initialIndex);

    final remoteFile = builder.buildRegistrationFile(
      functionName: 'registerProductRemoteDataSource',
      imports: [
        'package:get_it/get_it.dart',
        '../../data/data_sources/product/product_remote_data_source.dart',
      ],
      body: Block(
        (b) => b
          ..statements.add(
            Code(
              'getIt.registerLazySingleton<ProductRemoteDataSource>(() => ProductRemoteDataSource());',
            ),
          ),
      ),
    );
    File(
      '${diDir.path}/product_remote_data_source_di.dart',
    ).writeAsStringSync(remoteFile);

    final localFile = builder.buildRegistrationFile(
      functionName: 'registerProductLocalDataSource',
      imports: [
        'package:get_it/get_it.dart',
        '../../data/data_sources/product/product_local_data_source.dart',
      ],
      body: Block(
        (b) => b
          ..statements.add(
            Code(
              'getIt.registerLazySingleton<ProductLocalDataSource>(() => ProductLocalDataSource());',
            ),
          ),
      ),
    );
    File(
      '${diDir.path}/product_local_data_source_di.dart',
    ).writeAsStringSync(localFile);

    final plugin = DiPlugin(
      outputDir: outputDir,
      dryRun: false,
      force: false,
      verbose: false,
    );

    await plugin.generate(
      GeneratorConfig(
        name: 'Product',
        methods: const ['get'],
        generateData: true,
        generateDi: true,
        enableCache: true,
        outputDir: outputDir,
      ),
    );

    final updated = File('${diDir.path}/index.dart').readAsStringSync();
    expect(updated.contains('registerProductRemoteDataSource(getIt);'), isTrue);
    expect(updated.contains('registerProductLocalDataSource(getIt);'), isTrue);
    expect(
      updated.contains("import 'product_remote_data_source_di.dart';"),
      isTrue,
    );
    expect(
      updated.contains("import 'product_local_data_source_di.dart';"),
      isTrue,
    );
  });
}
