import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/plugin_system/discovery_engine.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/test/builders/test_builder.dart';

void main() {
  late Directory tempDir;
  late String projectRoot;
  late String outputDir;
  late TestBuilder builder;

  Future<void> writeSource(String relativePath, String content) async {
    final file = File(path.join(outputDir, relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_test_builder_');
    projectRoot = tempDir.path;
    outputDir = path.join(projectRoot, 'lib', 'src');
    await Directory(outputDir).create(recursive: true);
    await File(path.join(projectRoot, 'pubspec.yaml')).writeAsString('''
name: fixture_app
environment:
  sdk: ^3.11.0
''');

    final fileSystem = FileSystem.create(root: projectRoot);
    builder = TestBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
      fileSystem: fileSystem,
      discovery: DiscoveryEngine(
        projectRoot: projectRoot,
        fileSystem: fileSystem,
      ),
    );
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test(
    'dependency fakes preserve members and use non-null typed defaults',
    () async {
      await writeSource(
        'domain/usecases/example/search_usecase.dart',
        'class SearchUseCase {}',
      );
      await writeSource('domain/entities/search_params/search_params.dart', '''
abstract class SearchParams {
  String get label;
  set label(String value);
}
''');
      await writeSource('domain/repositories/sample_repository.dart', '''
abstract class SampleRepository {
  Object objectValue();
  Future<Object> futureObject();
  CustomResult customValue();
  void positional(String value, [int count = 1]);
  void named({required String name, bool enabled = false});
}
''');

      final generated = await builder.generateCustom(
        GeneratorConfig(
          name: 'Search',
          domain: 'example',
          repo: 'Sample',
          paramsType: 'SearchParams',
          noEntity: true,
          outputDir: outputDir,
        ),
      );
      final content = generated.content!;

      expect(
        content,
        contains('class FakeSearchParams implements SearchParams'),
      );
      expect(content, contains('String get label'));
      expect(content, contains('set label(String value)'));
      expect(content, contains('return Object();'));
      expect(content, contains('return Future.value(Object());'));
      expect(
        content,
        contains(
          "throw UnimplementedError('No typed fake value for customValue')",
        ),
      );
      expect(
        content,
        contains('void positional(String value, [int count = 1])'),
      );
      expect(
        content,
        contains('void named({required String name, bool enabled = false})'),
      );
    },
  );

  test('emits a placeholder dependency fake instead of failing when source is '
      'missing', () async {
    await writeSource(
      'domain/usecases/example/search_usecase.dart',
      'class SearchUseCase {}',
    );

    // The builder degrades gracefully (see test_builder_helpers.dart
    // `_requireFakeClassForDependency`): when a dependency's source file is not
    // on disk, it emits a usable `Fake*` stub instead of aborting generation
    // with a StateError. Verify that contract rather than the old fail-loud one.
    final generated = await builder.generateCustom(
      GeneratorConfig(
        name: 'Search',
        domain: 'example',
        repo: 'Missing',
        noEntity: true,
        outputDir: outputDir,
      ),
    );

    final content = generated.content!;
    expect(
      content,
      contains('class FakeMissingRepository implements MissingRepository'),
    );
  });

  group('entity native-mock tests', () {
    Future<void> writeEntityFixture(String method) async {
      await writeSource(
        'domain/entities/product/product.dart',
        'class Product { String uuid = "1"; bool active = false; }',
      );
      await writeSource(
        'domain/repositories/product_repository.dart',
        'abstract class ProductRepository {}',
      );
      await writeSource(
        'domain/usecases/product/${method}_product_usecase.dart',
        'class ${method[0].toUpperCase()}${method.substring(1)}ProductUseCase {}',
      );
      await writeSource(
        'data/datasources/product/product_datasource.dart',
        'abstract class ProductDataSource {}',
      );
      await writeSource(
        'data/datasources/product/product_mock_datasource.dart',
        'class ProductMockDataSource {}',
      );
      await writeSource(
        'data/mock/product_mock_data.dart',
        'class ProductMockData {}',
      );
      await writeSource(
        'data/repositories/data_product_repository.dart',
        'class DataProductRepository {}',
      );
    }

    GeneratorConfig config() => GeneratorConfig(
      name: 'Product',
      repo: 'Product',
      idField: 'uuid',
      idFieldType: 'String',
      queryField: 'active',
      queryFieldType: 'bool',
      outputDir: outputDir,
    );

    test(
      'uses the identity field for CRUD ids and query type for toggle',
      () async {
        for (final method in ['update', 'toggle', 'delete']) {
          await writeEntityFixture(method);
          final generated = await builder.generateForMethod(config(), method);
          final content = generated.content!;

          expect(content, contains('id: tProduct.uuid'));
          expect(content, isNot(contains('id: tProduct.active')));
          if (method == 'toggle') {
            expect(content, contains('field: ProductFields.active'));
            expect(content, contains('value: true'));
          }
        }
      },
    );

    test('awaits stream assertions and matches subscription errors', () async {
      await writeEntityFixture('watch');
      final generated = await builder.generateForMethod(config(), 'watch');
      final content = generated.content!;

      expect(content, contains('await expectLater('));
      expect(content, contains('emitsError(isA<Object>())'));
      expect(content, isNot(contains('throwsA(')));
    });

    test(
      'skips generation when native mock infrastructure is missing',
      () async {
        await writeEntityFixture('get');
        await File(
          path.join(outputDir, 'data', 'mock', 'product_mock_data.dart'),
        ).delete();

        final generated = await builder.generateForMethod(config(), 'get');

        expect(generated.action, 'skipped');
      },
    );
  });
}
