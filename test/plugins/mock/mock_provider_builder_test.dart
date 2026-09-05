import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generated_file.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/mock/builders/mock_provider_builder.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';

import '../../helpers/project_root.dart';

/// Spec 1003 (T003) — dedicated test tier for the mock plugin's
/// `MockProviderBuilder` (885 LOC, previously only 2 tests).
///
/// Coverage: structural assertions (file path/count, class declaration,
/// imports, method signatures, stub bodies, constructor) for the get
/// variant plus a compile gate (`dart analyze` exit 0) over the generated
/// provider inside a self-contained pure-Dart temp project.
void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_mock_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('useZorphy flag for update method in mock provider', () {
    test(
      'mock provider emits EntityPatch when useZorphy=true (default)',
      () async {
        // Scaffold the entity file
        await _scaffoldEntity(outputDir, 'Product');

        final plugin = MockPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );
        final config = GeneratorConfig(
          name: 'Product',
          service: 'Product',
          domain: 'product',
          methods: ['update'],
          generateMock: true,
          generateData: true, // Required to trigger mock provider generation
          useZorphy: true,
          outputDir: outputDir,
        );
        final files = await plugin.generate(config);
        // Filter for mock provider files
        final mockProviderFiles = files
            .where((f) => f.type == 'mock_provider')
            .toList();
        expect(mockProviderFiles.isNotEmpty, isTrue);
        final content = mockProviderFiles.first.content ?? '';

        // With useZorphy=true (default), should emit ProductPatch
        expect(
          content.contains('UpdateParams<String, ProductPatch>'),
          isTrue,
          reason: 'useZorphy=true should emit EntityPatch for update params',
        );
        expect(
          content.contains('Partial<Product>'),
          isFalse,
          reason: 'useZorphy=true should NOT emit Partial<Entity>',
        );
      },
    );

    test('mock provider emits Partial<Entity> when useZorphy=false', () async {
      // Scaffold the entity file
      await _scaffoldEntity(outputDir, 'Product');

      final plugin = MockPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final config = GeneratorConfig(
        name: 'Product',
        service: 'Product',
        domain: 'product',
        methods: ['update'],
        generateMock: true,
        generateData: true, // Required to trigger mock provider generation
        useZorphy: false,
        outputDir: outputDir,
      );
      final files = await plugin.generate(config);
      // Filter for mock provider files
      final mockProviderFiles = files
          .where((f) => f.type == 'mock_provider')
          .toList();
      expect(mockProviderFiles.isNotEmpty, isTrue);
      final content = mockProviderFiles.first.content ?? '';

      // With useZorphy=false, should emit Partial<Product>
      expect(
        content.contains('UpdateParams<String, Partial<Product>>'),
        isTrue,
        reason: 'useZorphy=false should emit Partial<Entity> for update params',
      );
      expect(
        content.contains('ProductPatch'),
        isFalse,
        reason: 'useZorphy=false should NOT emit EntityPatch',
      );
    });
  });

  group('spec 1003 — provider builder structural tier', () {
    test('writes exactly one provider file at the canonical path', () async {
      final file = await _buildProvider(outputDir, methods: const ['get']);

      expect(
        file.path,
        contains('data/providers/product/product_mock_provider.dart'),
      );
      final written = File(file.path).readAsStringSync();
      expect(written, contains('// GENERATED - DO NOT EDIT'));
      expect(written, contains('// END GENERATED'));
    });

    test(
      'declares the provider class with mixins and service contract',
      () async {
        final file = await _buildProvider(outputDir, methods: const ['get']);
        final content = File(file.path).readAsStringSync();

        expect(
          content,
          contains(
            'class ProductMockProvider\n'
            '    with Loggable, FailureHandler\n'
            '    implements ProductService {',
          ),
        );
        expect(content, contains('/// Mock provider for ProductService'));
      },
    );

    test('imports the mock barrel, entity, service and mock data', () async {
      final file = await _buildProvider(outputDir, methods: const ['get']);
      final content = File(file.path).readAsStringSync();

      expect(content, contains("import 'package:zuraffa/mock.dart';"));
      expect(
        content,
        contains("import '../../../domain/entities/product/product.dart';"),
      );
      expect(
        content,
        contains(
          "import '../../../domain/services/product/product_service.dart';",
        ),
      );
      expect(content, contains("import '../../mock/product_mock_data.dart';"));
    });

    test(
      'get variant emits typed signature with delayed-sample stub body',
      () async {
        final file = await _buildProvider(outputDir, methods: const ['get']);
        final content = File(file.path).readAsStringSync();

        expect(
          content,
          contains('Future<Product> get(QueryParams<Product> params) async {'),
        );
        expect(content, contains('@override'));
        expect(content, contains("logger.info('get called with params:"));
        expect(content, contains('await Future.delayed(_delay);'));
        expect(content, contains('return ProductMockData.sampleProduct;'));
      },
    );

    test('constructor accepts an optional response delay', () async {
      final file = await _buildProvider(outputDir, methods: const ['get']);
      final content = File(file.path).readAsStringSync();

      expect(content, contains('ProductMockProvider([Duration? delay])'));
      expect(
        content,
        contains('_delay = delay ?? const Duration(milliseconds: 100);'),
      );
      expect(content, contains('final Duration _delay;'));
    });
  });

  group('spec 1003 — provider builder compile gate', () {
    late Directory projectRoot;
    late String repoRoot;

    setUpAll(() async {
      repoRoot = await findProjectRoot();
      projectRoot = await Directory.systemTemp.createTemp(
        'zuraffa_mock_compile_',
      );
      await File('${projectRoot.path}/pubspec.yaml').create(recursive: true);
      await File('${projectRoot.path}/pubspec.yaml').writeAsString('''
name: mock_compile_fixture
publish_to: none
environment:
  sdk: ^3.11.0
dependencies:
  zuraffa:
    path: $repoRoot
''');
      // Entity stub — the provider imports the canonical entity file.
      await File(
        p.join(
          projectRoot.path,
          'domain',
          'entities',
          'product',
          'product.dart',
        ),
      ).create(recursive: true);
      await File(
        p.join(
          projectRoot.path,
          'domain',
          'entities',
          'product',
          'product.dart',
        ),
      ).writeAsString('''
class Product {
  Product({this.id});

  final String? id;
}
''');
      // Service stub — the provider implements it.
      await File(
        p.join(
          projectRoot.path,
          'domain',
          'services',
          'product',
          'product_service.dart',
        ),
      ).create(recursive: true);
      await File(
        p.join(
          projectRoot.path,
          'domain',
          'services',
          'product',
          'product_service.dart',
        ),
      ).writeAsString('''
import 'package:zuraffa/zuraffa.dart';

import '../../entities/product/product.dart';

abstract class ProductService {
  Future<Product> get(QueryParams<Product> params);
}
''');
      // Mock-data stub — the provider's stub body returns its sample.
      await File(
        p.join(projectRoot.path, 'data', 'mock', 'product_mock_data.dart'),
      ).create(recursive: true);
      await File(
        p.join(projectRoot.path, 'data', 'mock', 'product_mock_data.dart'),
      ).writeAsString('''
import '../../domain/entities/product/product.dart';

class ProductMockData {
  static final Product sampleProduct = Product();
}
''');
      // The provider builder's service-scan feeds `QueryParams<Product>`
      // through EntityUtils.extractEntityTypes, which flattens generics and
      // emits an entity import for a phantom `query_params_product` entity.
      // This is current generator behavior (spec 1003 gates behavior, it
      // does not change it), so the fixture backs those imports with stubs
      // so the generated provider can be compile-gated.
      await File(
        p.join(
          projectRoot.path,
          'domain',
          'entities',
          'query_params_product',
          'query_params_product.dart',
        ),
      ).create(recursive: true);
      await File(
        p.join(
          projectRoot.path,
          'domain',
          'entities',
          'query_params_product',
          'query_params_product.dart',
        ),
      ).writeAsString('class QueryParamsProduct {}\n');
      await File(
        p.join(
          projectRoot.path,
          'data',
          'mock',
          'query_params_product_mock_data.dart',
        ),
      ).create(recursive: true);
      await File(
        p.join(
          projectRoot.path,
          'data',
          'mock',
          'query_params_product_mock_data.dart',
        ),
      ).writeAsString('class QueryParamsProductMockData {}\n');
      final pub = await Process.run('dart', [
        'pub',
        'get',
        '--no-example',
      ], workingDirectory: projectRoot.path);
      expect(
        pub.exitCode,
        0,
        reason:
            'dart pub get must succeed in the compile fixture.\n'
            '${pub.stdout}\n${pub.stderr}',
      );
    });

    tearDownAll(() async {
      if (projectRoot.existsSync()) {
        await projectRoot.delete(recursive: true);
      }
    });

    test('generated mock provider passes dart analyze (exit 0)', () async {
      final builder = MockProviderBuilder(
        outputDir: projectRoot.path,
        options: const GeneratorOptions(dryRun: false, force: true),
      );
      final file = await builder.generateMockProvider(
        GeneratorConfig(
          name: 'Product',
          service: 'ProductService',
          methods: const ['get'],
          generateMock: true,
          outputDir: projectRoot.path,
        ),
      );
      expect(
        File(file.path).existsSync(),
        isTrue,
        reason: 'mock provider must be written to disk, not just returned',
      );

      final result = await Process.run('dart', [
        'analyze',
        '--no-fatal-warnings',
        projectRoot.path,
      ], workingDirectory: projectRoot.path);
      final output = '${result.stdout}${result.stderr}';

      expect(
        result.exitCode,
        0,
        reason:
            'generated mock provider must analyze clean. Output:\n'
            '$output',
      );
      expect(
        output,
        isNot(contains(' error - ')),
        reason:
            'no analyzer errors allowed in generated mock provider:\n'
            '$output',
      );
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

/// Generates a mock provider via [MockProviderBuilder] (the 885-LOC builder
/// under test) and returns its written [GeneratedFile].
Future<GeneratedFile> _buildProvider(
  String outputDir, {
  List<String> methods = const ['get'],
}) async {
  final builder = MockProviderBuilder(
    outputDir: outputDir,
    options: const GeneratorOptions(dryRun: false, force: true),
  );
  final file = await builder.generateMockProvider(
    GeneratorConfig(
      name: 'Product',
      service: 'ProductService',
      methods: methods,
      generateMock: true,
      outputDir: outputDir,
    ),
  );
  return file;
}

/// Scaffolds a minimal entity file at the canonical v5 location
/// `lib/src/domain/entities/<snake>/<snake>.dart` so that
/// `CommonPatterns.entityImports`' filesystem resolver finds it.
Future<void> _scaffoldEntity(String outputDir, String entityName) async {
  final snake = _camelToSnake(entityName);
  final dir = Directory('$outputDir/domain/entities/$snake');
  await dir.create(recursive: true);
  final file = File('${dir.path}/$snake.dart');
  await file.writeAsString('class $entityName {}\n');
}

String _camelToSnake(String input) {
  final out = input.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (m) => '_${m.group(0)!.toLowerCase()}',
  );
  return out.startsWith('_') ? out.substring(1) : out;
}
