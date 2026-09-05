import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/presenter/presenter_plugin.dart';

/// Spec 1003 (T002) — dedicated structural tests for the `presenter`
/// trust-tier generator (`test/plugins/presenter/`).
///
/// Generates into a throwaway temp dir and asserts file count + key
/// content (class name, imports, method signatures, expected stub body).
void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_pres_tier_');
    // Flutter flavor marker — presenters extend the zuraffa_flutter
    // `Presenter` base class (#281/#284).
    await File('${tempDir.path}/pubspec.yaml').writeAsString('''
name: presenter_structural_fixture
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
  zuraffa_flutter: ^6.1.0
''');
    outputDir = tempDir.path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  PresenterPlugin buildPlugin() => PresenterPlugin(
    outputDir: outputDir,
    options: const GeneratorOptions(dryRun: false, force: true),
  );

  test('emits exactly one presenter file at the canonical path', () async {
    final files = await buildPlugin().generate(
      GeneratorConfig(
        name: 'Product',
        methods: ['get'],
        generatePresenter: true,
        outputDir: outputDir,
      ),
    );

    expect(files, hasLength(1));
    expect(
      files.single.path,
      contains('presentation/pages/product/product_presenter.dart'),
    );

    final content = File(files.single.path).readAsStringSync();
    expect(content, contains('// GENERATED - DO NOT EDIT'));
    expect(content, contains('// END GENERATED'));
  });

  test('declares Presenter subclass with repository injection', () async {
    final files = await buildPlugin().generate(
      GeneratorConfig(
        name: 'Product',
        methods: ['get'],
        generatePresenter: true,
        outputDir: outputDir,
      ),
    );

    final content = File(files.single.path).readAsStringSync();

    // Class name + base type.
    expect(content, contains('class ProductPresenter extends Presenter {'));

    // Imports: zuraffa_flutter + entity + repository + usecase.
    expect(
      content,
      contains("import 'package:zuraffa_flutter/zuraffa_flutter.dart';"),
    );
    expect(
      content,
      contains("import '../../../domain/entities/product/product.dart';"),
    );
    expect(
      content,
      contains(
        "import '../../../domain/repositories/product_repository.dart';",
      ),
    );
    expect(
      content,
      contains(
        "import '../../../domain/usecases/product/get_product_usecase.dart';",
      ),
    );

    // Constructor + repository field.
    expect(
      content,
      contains('ProductPresenter({required this.productRepository})'),
    );
    expect(content, contains('final ProductRepository productRepository;'));
  });

  test(
    'registers the use case and exposes the typed method signature',
    () async {
      final files = await buildPlugin().generate(
        GeneratorConfig(
          name: 'Product',
          methods: ['get'],
          generatePresenter: true,
          outputDir: outputDir,
        ),
      );

      final content = File(files.single.path).readAsStringSync();

      // Use-case registration stub body.
      expect(
        content,
        contains('registerUseCase(GetProductUseCase(productRepository))'),
      );
      expect(content, contains('late final GetProductUseCase _getProduct;'));

      // Typed method signature + query stub body. The formatter wraps long
      // signatures, so assert on stable fragments.
      expect(
        content,
        contains('Future<Result<Product, AppFailure>> getProduct('),
      );
      expect(content, contains('String id,'));
      expect(content, contains('CancelToken? cancelToken,'));
      expect(content, contains('_getProduct.call('));
      expect(
        content,
        contains('QueryParams<Product>(filter: Eq(ProductFields.id, id))'),
      );
    },
  );
}
