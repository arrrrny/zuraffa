import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/presenter/presenter_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_presenter_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generates presenter with usecase wiring', () async {
    final plugin = PresenterPlugin(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );
    final config = GeneratorConfig(
      name: 'Product',
      methods: const ['get', 'getList'],
      generatePresenter: true,
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    final content = files.first.content ?? '';
    expect(
      content.contains('class ProductPresenter extends Presenter'),
      isTrue,
    );
    expect(
      content.contains('late final GetProductUseCase _getProduct;'),
      isTrue,
    );
    expect(
      content.contains('registerUseCase(GetProductUseCase(productRepository))'),
      isTrue,
    );
    expect(
      content.contains(
        'Future<Result<List<Product>, AppFailure>> getProductList',
      ),
      isTrue,
    );
    expect(content.contains('CancelToken? cancelToken'), isTrue);
  });

  test('generates query param methods with zorphy filter', () async {
    final plugin = PresenterPlugin(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );
    final config = GeneratorConfig(
      name: 'Product',
      methods: const ['get'],
      queryField: 'slug',
      queryFieldType: 'String',
      useZorphy: true,
      generatePresenter: true,
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    final content = files.first.content ?? '';
    expect(content.contains('ProductFields.slug'), isTrue);
    expect(content.contains('filter: Eq(ProductFields.slug, slug)'), isTrue);
    expect(content.contains('cancelToken: cancelToken'), isTrue);
  });

  test('generates watch list method signature', () async {
    final plugin = PresenterPlugin(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );
    final config = GeneratorConfig(
      name: 'Order',
      methods: const ['watchList'],
      generatePresenter: true,
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    final content = files.first.content ?? '';
    expect(
      content.contains(
        'Stream<Result<List<Order>, AppFailure>> watchOrderList',
      ),
      isTrue,
    );
  });
}
