import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/api/builders/api_bridge_builder.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_api_builder_');
    outputDir = '${tempDir.path}/lib/src';
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Creates a minimal UseCase file in the expected location.
  /// Naming convention: strip "UseCase" → snake_case → append "_usecase.dart"
  /// (matches DI command convention, e.g. GetProductUseCase → get_product_usecase.dart).
  Future<void> createUseCase({
    required String outputDir,
    required String entitySnake,
    required String className,
    required String content,
  }) async {
    final dir = Directory('$outputDir/domain/usecases/$entitySnake');
    await dir.create(recursive: true);
    final nameWithoutSuffix = className.replaceAll('UseCase', '');
    final snake = nameWithoutSuffix
        .replaceAllMapped(
          RegExp(r'(?<=[a-z])([A-Z])'),
          (m) => '_${m.group(1)!.toLowerCase()}',
        )
        .toLowerCase();
    await File('${dir.path}/${snake}_usecase.dart').writeAsString(content);
  }

  /// Creates a minimal entity file.
  Future<void> createEntity({
    required String outputDir,
    required String entitySnake,
    required String entityName,
    bool includeToJson = true,
  }) async {
    final dir = Directory('$outputDir/domain/entities/$entitySnake');
    await dir.create(recursive: true);
    await File('${dir.path}/$entitySnake.dart').writeAsString(
      'class $entityName { final String id; $entityName({required this.id}); '
      '${includeToJson ? 'Map<String, dynamic> toJson() => {"id": id};' : ''} }',
    );
  }

  group('ApiBridgeBuilder.generate()', () {
    test('rejects return entities without a toJson serializer', () async {
      await createEntity(
        outputDir: outputDir,
        entitySnake: 'product',
        entityName: 'Product',
        includeToJson: false,
      );
      await createUseCase(
        outputDir: outputDir,
        entitySnake: 'product',
        className: 'GetProductUseCase',
        content: 'class GetProductUseCase extends UseCase<Product, String> {}',
      );

      final builder = ApiBridgeBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );

      expect(
        () => builder.generate(
          GeneratorConfig(name: 'Product', outputDir: outputDir),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Product does not expose a toJson() serializer'),
          ),
        ),
      );
    });

    test('accepts a serializer exposed by generated entity extension', () async {
      await createEntity(
        outputDir: outputDir,
        entitySnake: 'product',
        entityName: 'Product',
        includeToJson: false,
      );
      await File(
        '$outputDir/domain/entities/product/product.zorphy.dart',
      ).writeAsString('''
part of 'product.dart';
extension ProductSerialization on Product {
  Map<String, dynamic> toJson() => {'id': id};
}
''');
      await createUseCase(
        outputDir: outputDir,
        entitySnake: 'product',
        className: 'GetProductUseCase',
        content: 'class GetProductUseCase extends UseCase<Product, String> {}',
      );

      final files = await ApiBridgeBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      ).generate(GeneratorConfig(name: 'Product', outputDir: outputDir));

      expect(files, hasLength(1));
    });

    test('generates file at correct path for Product entity', () async {
      await createEntity(
        outputDir: outputDir,
        entitySnake: 'product',
        entityName: 'Product',
      );
      await createUseCase(
        outputDir: outputDir,
        entitySnake: 'product',
        className: 'GetProductUseCase',
        content: 'class GetProductUseCase extends UseCase<Product, String> {}',
      );

      final builder = ApiBridgeBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );

      final files = await builder.generate(
        GeneratorConfig(name: 'Product', outputDir: outputDir),
      );

      expect(files, hasLength(1));
      expect(files.first.path, endsWith('api/bridges/product_api_bridge.dart'));
      expect(files.first.action, anyOf('created', 'overwritten'));
    });

    test(
      'generated file contains registerProductApiBridge() function',
      () async {
        await createEntity(
          outputDir: outputDir,
          entitySnake: 'product',
          entityName: 'Product',
        );
        await createUseCase(
          outputDir: outputDir,
          entitySnake: 'product',
          className: 'GetProductUseCase',
          content:
              'class GetProductUseCase extends UseCase<Product, String> {}',
        );

        final builder = ApiBridgeBuilder(
          outputDir: outputDir,
          options: const GeneratorOptions(dryRun: false, force: true),
        );

        final files = await builder.generate(
          GeneratorConfig(name: 'Product', outputDir: outputDir),
        );

        final content = await File(files.first.path).readAsString();
        expect(content, contains('void registerProductApiBridge()'));
        expect(content, contains('_handleGetProduct'));
        expect(content, contains('ZuraffaApiBridge.registerEndpoint'));
        expect(content, contains("ApiEndpoint("));
      },
    );

    test('generated file has release/profile mode guards as first statements', () async {
      await createEntity(
        outputDir: outputDir,
        entitySnake: 'product',
        entityName: 'Product',
      );
      await createUseCase(
        outputDir: outputDir,
        entitySnake: 'product',
        className: 'GetProductUseCase',
        content: 'class GetProductUseCase extends UseCase<Product, String> {}',
      );

      final builder = ApiBridgeBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );
      final files = await builder.generate(
        GeneratorConfig(name: 'Product', outputDir: outputDir),
      );

      final content = await File(files.first.path).readAsString();
      // Release mode guard must appear inside registerProductApiBridge()
      expect(content, contains("if (const bool.fromEnvironment('dart.vm.product')) return;"));
      // Profile mode guard must appear inside registerProductApiBridge()
      expect(
        content,
        contains("if (const bool.fromEnvironment('dart.vm.profile') &&\n"
            "      !Zuraffa.enableApiInProfile)\n"
            "    return;"),
      );
    });

    test('generates StreamUseCase handler with streaming response', () async {
      await createEntity(
        outputDir: outputDir,
        entitySnake: 'product',
        entityName: 'Product',
      );
      await createUseCase(
        outputDir: outputDir,
        entitySnake: 'product',
        className: 'WatchProductUseCase',
        content:
            'class WatchProductUseCase extends StreamUseCase<Product, QueryParams<Product>> {}',
      );

      final builder = ApiBridgeBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );
      final files = await builder.generate(
        GeneratorConfig(name: 'Product', outputDir: outputDir),
      );

      final content = await File(files.first.path).readAsString();
      expect(content, contains('streaming'));
      expect(content, contains('subscriptionId'));
      expect(content, contains('ZuraffaApiBridge.registerStreamSubscription'));
    });

    test('returns empty list when no UseCases found', () async {
      await createEntity(
        outputDir: outputDir,
        entitySnake: 'product',
        entityName: 'Product',
      );
      // No UseCase files created
      final builder = ApiBridgeBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );
      final files = await builder.generate(
        GeneratorConfig(name: 'Product', outputDir: outputDir),
      );
      expect(files, isEmpty);
    });

    test(
      'dry run returns file with action but does not write to disk',
      () async {
        await createEntity(
          outputDir: outputDir,
          entitySnake: 'product',
          entityName: 'Product',
        );
        await createUseCase(
          outputDir: outputDir,
          entitySnake: 'product',
          className: 'GetProductUseCase',
          content:
              'class GetProductUseCase extends UseCase<Product, String> {}',
        );

        final builder = ApiBridgeBuilder(
          outputDir: outputDir,
          options: const GeneratorOptions(dryRun: true, force: false),
        );
        final files = await builder.generate(
          GeneratorConfig(name: 'Product', outputDir: outputDir, dryRun: true),
        );

        expect(files, hasLength(1));
        final outPath = '$outputDir/api/bridges/product_api_bridge.dart';
        expect(File(outPath).existsSync(), isFalse);
      },
    );

    test('generates correct import filenames with _usecase convention', () async {
      await createEntity(
        outputDir: outputDir,
        entitySnake: 'barcode_listing',
        entityName: 'BarcodeListing',
      );
      // BarcodeSpark is the params type — needs its own entity dir for fromJson detection
      await createEntity(
        outputDir: outputDir,
        entitySnake: 'barcode_spark',
        entityName: 'BarcodeSpark',
      );
      await createUseCase(
        outputDir: outputDir,
        entitySnake: 'barcode_listing',
        className: 'GetBarcodeListingUseCase',
        content:
            'class GetBarcodeListingUseCase extends StreamUseCase<BarcodeListing, BarcodeSpark> {}',
      );

      final builder = ApiBridgeBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );
      final files = await builder.generate(
        GeneratorConfig(name: 'BarcodeListing', outputDir: outputDir),
      );

      final content = await File(files.first.path).readAsString();

      // UseCase import must use _usecase convention (not _use_case)
      expect(
        content,
        contains(
          "import '../../domain/usecases/barcode_listing/get_barcode_listing_usecase.dart'",
        ),
      );
      // Must NOT have the old broken convention
      expect(content, isNot(contains('_use_case.dart')));
      // Entity import must be present
      expect(
        content,
        contains(
          "import '../../domain/entities/barcode_listing/barcode_listing.dart'",
        ),
      );
      // No unused uuid import
      expect(content, isNot(contains('package:uuid')));
    });

    test('skips usecases whose params type lacks fromJson', () async {
      await createEntity(
        outputDir: outputDir,
        entitySnake: 'product',
        entityName: 'Product',
      );
      // Params type is SomeRandomClass — no entity dir, no fromJson
      await createUseCase(
        outputDir: outputDir,
        entitySnake: 'product',
        className: 'SearchMissingUseCase',
        content:
            'class SearchMissingUseCase extends UseCase<Product, SomeRandomClass> {}',
      );

      final builder = ApiBridgeBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );
      final files = await builder.generate(
        GeneratorConfig(name: 'Product', outputDir: outputDir),
      );

      // Should return empty — the usecase was skipped
      expect(files, isEmpty);
    });

    test(
      'entity with multiple usecases produces one file with multiple handlers',
      () async {
        await createEntity(
          outputDir: outputDir,
          entitySnake: 'product',
          entityName: 'Product',
        );
        await createUseCase(
          outputDir: outputDir,
          entitySnake: 'product',
          className: 'GetProductUseCase',
          content: 'class GetProductUseCase extends UseCase<Product, String> {}',
        );
        await createUseCase(
          outputDir: outputDir,
          entitySnake: 'product',
          className: 'CreateProductUseCase',
          content:
              'class CreateProductUseCase extends UseCase<Product, NoParams> {}',
        );

        final builder = ApiBridgeBuilder(
          outputDir: outputDir,
          options: const GeneratorOptions(dryRun: false, force: true),
        );
        final files = await builder.generate(
          GeneratorConfig(name: 'Product', outputDir: outputDir),
        );

        // SC-001: exactly one bridge file for the whole entity, regardless of
        // how many UseCases it exposes.
        expect(files, hasLength(1));
        final content = await File(files.first.path).readAsString();

        // Exactly one top-level registration function for the entity.
        expect('registerProductApiBridge'.allMatches(content), hasLength(1));
        // One handler + one registerEndpoint per UseCase (2 here).
        expect(
          'ZuraffaApiBridge.registerEndpoint'.allMatches(content),
          hasLength(2),
        );
        expect(content, contains('_handleGetProduct'));
        expect(content, contains('_handleCreateProduct'));
      },
    );
  });

  group('generated handler output (regression)', () {
    Future<String> generateBridge(List<Map<String, String>> useCases) async {
      await createEntity(
        outputDir: outputDir,
        entitySnake: 'product',
        entityName: 'Product',
      );
      for (final uc in useCases) {
        await createUseCase(
          outputDir: outputDir,
          entitySnake: 'product',
          className: uc['className']!,
          content: uc['content']!,
        );
      }
      final builder = ApiBridgeBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );
      final files = await builder.generate(
        GeneratorConfig(name: 'Product', outputDir: outputDir),
      );
      expect(files, hasLength(1));
      return File(files.first.path).readAsString();
    }

    test('handlers log the endpoint method name on error', () async {
      final content = await generateBridge([
        {
          'className': 'GetProductUseCase',
          'content':
              'class GetProductUseCase extends UseCase<Product, String> {}',
        },
      ]);
      expect(content, contains('Bridge error: ext.zuraffa.product.getProduct'));
    });

    test('generic type arguments survive discovery intact', () async {
      final content = await generateBridge([
        {
          'className': 'GetProductUseCase',
          'content':
              'class GetProductUseCase extends UseCase<Product, QueryParams<Product>> {}',
        },
      ]);
      // Truncated fragments like these would not compile.
      expect(content, isNot(contains('QueryParams<Product.')));
      expect(content, isNot(contains('QueryParams<Product(')));
      expect(
        content,
        contains('QueryParams<Product>(filter: ProductFields.id.eq(id))'),
      );
    });

    test('QueryParams usecases get a typed id handler', () async {
      final content = await generateBridge([
        {
          'className': 'GetProductUseCase',
          'content':
              'class GetProductUseCase extends UseCase<Product, QueryParams<Product>> {}',
        },
      ]);
      expect(content, contains("params: {'id': 'String'}"));
      expect(content, contains("'id is required'"));
    });

    test('ListQueryParams usecases get a no-params full-list handler', () async {
      final content = await generateBridge([
        {
          'className': 'GetProductListUseCase',
          'content':
              'class GetProductListUseCase extends UseCase<List<Product>, ListQueryParams<Product>> {}',
        },
      ]);
      expect(content, contains('final params = ListQueryParams<Product>();'));
      expect(content, contains('params: {}'));
      expect(content, isNot(contains('id is required')));
      // Generic return type must survive intact for the toJson helper.
      expect(content, contains('(List<Product> v)'));
    });

    test(
      'stream usecase with primitive params reads args value directly',
      () async {
        final content = await generateBridge([
          {
            'className': 'WatchStockUseCase',
            'content':
                'class WatchStockUseCase extends StreamUseCase<Product, int> {}',
          },
        ]);
        expect(content, contains("int.tryParse(args['value']"));
        expect(content, isNot(contains('jsonDecode')));
      },
    );

    test(
      'non-stream primitive usecase reads args value directly',
      () async {
        final content = await generateBridge([
          {
            'className': 'GetProductUseCase',
            'content':
                'class GetProductUseCase extends UseCase<Product, String> {}',
          },
        ]);
        // Primitive String param is read by key name from the args map
        // (the metadata advertises {'value': 'String'} — see _buildParamsMap).
        expect(content, contains("args['value'] ?? ''"));
        // No JSON deserialization for a primitive param.
        expect(content, isNot(contains('jsonDecode')));
      },
    );

    test(
      'NoParams usecase generates a const NoParams() call with empty params map',
      () async {
        final content = await generateBridge([
          {
            'className': 'GetProductUseCase',
            'content':
                'class GetProductUseCase extends UseCase<Product, NoParams> {}',
          },
        ]);
        // The handler invokes the UseCase with a const NoParams() (no args read).
        expect(content, contains('const NoParams()'));
        // The advertised params metadata is an empty map.
        expect(content, contains('params: {}'));
        // A NoParams handler must not deserialize or read the args map.
        expect(content, isNot(contains('jsonDecode')));
        expect(content, isNot(contains('args[')));
      },
    );

    test(
      'complex params usecase emits a deserialization error path',
      () async {
        await createEntity(
          outputDir: outputDir,
          entitySnake: 'barcode_spark',
          entityName: 'BarcodeSpark',
        );
        final content = await generateBridge([
          {
            'className': 'CreateBarcodeSparkUseCase',
            'content':
                'class CreateBarcodeSparkUseCase extends UseCase<Product, BarcodeSpark> {}',
          },
        ]);
        // The handler must guard jsonDecode and surface a structured
        // 'deserialization' error when the JSON blob is malformed.
        expect(content, contains("jsonDecode(args['args']"));
        expect(content, contains("errorResponse('deserialization'"));
      },
    );

    test(
      'stream usecase with complex params keeps the JSON blob contract',
      () async {
        final content = await generateBridge([
          {
            'className': 'WatchProductUseCase',
            'content':
                'class WatchProductUseCase extends StreamUseCase<Product, QueryParams<Product>> {}',
          },
        ]);
        expect(content, contains("params: {'args': 'QueryParams<Product>'}"));
        expect(content, contains('QueryParams<Product>.fromJson(json)'));
      },
    );
  });

  group('custom domain override (US1.3)', () {
    test('uses --domain for the extension method and ApiEndpoint.domain', () async {
      await createEntity(
        outputDir: outputDir,
        entitySnake: 'product',
        entityName: 'Product',
      );
      await createUseCase(
        outputDir: outputDir,
        entitySnake: 'product',
        className: 'GetProductUseCase',
        content: 'class GetProductUseCase extends UseCase<Product, String> {}',
      );

      final builder = ApiBridgeBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );
      final files = await builder.generate(
        GeneratorConfig(name: 'Product', outputDir: outputDir, domain: 'billing'),
      );

      final content = await File(files.first.path).readAsString();
      // Extension method must use the overridden domain segment.
      expect(content, contains('ext.zuraffa.billing.getProduct'));
      // ApiEndpoint metadata must carry the overridden domain.
      expect(content, contains("domain: 'billing'"));
      // And must NOT fall back to the entity snake.
      expect(content, isNot(contains('ext.zuraffa.product.getProduct')));
    });
  });
}
