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
      '$outputDir/di/datasources/product_remote_datasource_di.dart',
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

  test('generates service DI with mock provider support', () async {
    final plugin = DiPlugin(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );

    await plugin.generate(
      GeneratorConfig(
        name: 'GetListingByBarcode',
        service: 'Listing',
        domain: 'listing',
        generateDi: true,
        generateData: true,
        useMockInDi: true,
        outputDir: outputDir,
      ),
    );

    final serviceDiFile = File(
      '$outputDir/di/services/listing_service_di.dart',
    );
    expect(serviceDiFile.existsSync(), isTrue);
    final content = serviceDiFile.readAsStringSync();

    expect(content.contains('registerListingService'), isTrue);
    expect(
      content.contains('getIt.registerLazySingleton<ListingService>'),
      isTrue,
    );
    expect(content.contains('ListingMockProvider()'), isTrue);
    expect(
      content.contains(
        "import '../../data/providers/listing/listing_mock_provider.dart';",
      ),
      isTrue,
    );
  });

  test(
    'prevents over-generation of datasource DI when using service',
    () async {
      final plugin = DiPlugin(
        outputDir: outputDir,
        dryRun: false,
        force: true,
        verbose: false,
      );

      await plugin.generate(
        GeneratorConfig(
          name: 'GetListingByBarcode',
          service: 'Listing',
          domain: 'listing',
          generateDi: true,
          generateData: true,
          outputDir: outputDir,
        ),
      );

      final datasourceDiDir = Directory('$outputDir/di/datasources');
      final repoDiDir = Directory('$outputDir/di/repositories');

      // These should NOT exist because we have a service/provider pattern
      expect(datasourceDiDir.existsSync(), isFalse);
      expect(repoDiDir.existsSync(), isFalse);

      // Service and Provider DI SHOULD exist
      expect(
        File('$outputDir/di/services/listing_service_di.dart').existsSync(),
        isTrue,
      );
      expect(
        File('$outputDir/di/providers/listing_provider_di.dart').existsSync(),
        isTrue,
      );
    },
  );

  test(
    'mock provider registration does not duplicate service interface',
    () async {
      final plugin = DiPlugin(
        outputDir: outputDir,
        dryRun: false,
        force: true,
        verbose: false,
      );

      await plugin.generate(
        GeneratorConfig(
          name: 'GetListingByBarcode',
          service: 'Listing',
          domain: 'listing',
          generateDi: true,
          generateData: true,
          useMockInDi: true,
          outputDir: outputDir,
        ),
      );

      final mockProviderDiFile = File(
        '$outputDir/di/providers/listing_mock_provider_di.dart',
      );
      expect(mockProviderDiFile.existsSync(), isTrue);
      final content = mockProviderDiFile.readAsStringSync();

      // Should register ListingMockProvider but NOT as ListingService (that's the service DI's job)
      expect(
        content.contains('getIt.registerLazySingleton<ListingMockProvider>'),
        isFalse,
      );
      expect(
        content.contains(
          'getIt.registerLazySingleton(() => ListingMockProvider())',
        ),
        isTrue,
      );

      // Should NOT import the service interface
      expect(content.contains('listing_service.dart'), isFalse);
    },
  );

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
        '../../data/datasources/product/product_remote_datasource.dart',
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
      '${diDir.path}/product_remote_datasource_di.dart',
    ).writeAsStringSync(remoteFile);

    final localFile = builder.buildRegistrationFile(
      functionName: 'registerProductLocalDataSource',
      imports: [
        'package:get_it/get_it.dart',
        '../../data/datasources/product/product_local_datasource.dart',
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
      '${diDir.path}/product_local_datasource_di.dart',
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
      updated.contains("import 'product_remote_datasource_di.dart';"),
      isTrue,
    );
    expect(
      updated.contains("import 'product_local_datasource_di.dart';"),
      isTrue,
    );
  });
}
