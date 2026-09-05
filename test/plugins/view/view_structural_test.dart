import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/view/view_plugin.dart';

/// Spec 1003 (T001) — dedicated structural tests for the `view` trust-tier
/// generator (`test/plugins/view/`).
///
/// Each test generates into a throwaway temp dir and asserts the file
/// count + key content (class name, imports, method signatures, expected
/// stub body). The temp project carries a `flutter:` pubspec key so the
/// view plugin's flavor gate (#420, Constitution VII) treats it as a
/// Flutter target and emits output instead of skipping.
void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_view_tier_');
    // Flutter flavor marker — the view plugin skips pure-Dart targets.
    await File('${tempDir.path}/pubspec.yaml').writeAsString('''
name: view_structural_fixture
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

  ViewPlugin buildPlugin() => ViewPlugin(
    outputDir: outputDir,
    options: const GeneratorOptions(dryRun: false, force: true),
  );

  test('generates master-detail pair for get + getList (2 files)', () async {
    final files = await buildPlugin().generate(
      GeneratorConfig(
        name: 'Product',
        methods: ['get', 'getList'],
        generateView: true,
        outputDir: outputDir,
      ),
    );

    expect(files, hasLength(2));
    final paths = files.map((f) => f.path).toSet();
    expect(
      paths,
      containsAll(<Matcher>[
        contains('presentation/pages/product/product_view.dart'),
        contains('presentation/pages/product/product_detail_view.dart'),
      ]),
    );

    final view = File(
      '$outputDir/presentation/pages/product/product_view.dart',
    ).readAsStringSync();

    // Class name + base type.
    expect(view, contains('class ProductView extends CleanView {'));

    // Imports: Flutter material + zuraffa_flutter + relative layers.
    expect(view, contains("import 'package:flutter/material.dart';"));
    expect(
      view,
      contains("import 'package:zuraffa_flutter/zuraffa_flutter.dart';"),
    );
    expect(
      view,
      contains("import '../../../domain/entities/product/product.dart';"),
    );
    expect(
      view,
      contains(
        "import '../../../domain/repositories/product_repository.dart';",
      ),
    );
    expect(view, contains("import 'product_controller.dart';"));
    expect(view, contains("import 'product_presenter.dart';"));

    // Constructor signature.
    expect(view, contains('required this.productRepository,'));

    // State wiring stub body.
    expect(
      view,
      contains(
        'ProductController(ProductPresenter(productRepository: '
        'productRepository))',
      ),
    );
    expect(
      view,
      contains('extends CleanViewState<ProductView, ProductController, void>'),
    );
    expect(view, contains('onInitState()'));
    expect(view, contains('controller.getProductList();'));

    // Flutter widget stub body.
    expect(view, contains('ControlledWidgetBuilder<ProductController>'));
    expect(view, contains('Scaffold('));
    expect(view, contains("AppBar(title: const Text('Product'))"));

    // Detail view — id-based bootstrap.
    final detail = File(
      '$outputDir/presentation/pages/product/product_detail_view.dart',
    ).readAsStringSync();
    expect(detail, contains('class ProductDetailView extends CleanView {'));
    expect(detail, contains('final String? id;'));
    expect(detail, contains('controller.getProduct(widget.id!)'));
  });

  test(
    'generates a single view file for get-only (no detail variant)',
    () async {
      final files = await buildPlugin().generate(
        GeneratorConfig(
          name: 'Product',
          methods: ['get'],
          generateView: true,
          outputDir: outputDir,
        ),
      );

      expect(files, hasLength(1));
      expect(
        files.single.path,
        contains('presentation/pages/product/product_view.dart'),
      );

      final content = File(files.single.path).readAsStringSync();
      expect(content, contains('class ProductView extends CleanView {'));
      expect(
        content,
        isNot(contains('ProductDetailView')),
        reason: 'get-only config must not emit the master-detail detail view',
      );
    },
  );

  test('marks generated output and wires createState via builder', () async {
    final files = await buildPlugin().generate(
      GeneratorConfig(
        name: 'Product',
        methods: ['get'],
        generateView: true,
        outputDir: outputDir,
      ),
    );

    final content = File(files.single.path).readAsStringSync();
    expect(content, contains('// Generated by zfa for: Product'));
    expect(content, contains('// ignore_for_file: no_logic_in_create_state'));
    expect(content, contains('State<ProductView> createState()'));
    expect(content, contains('_ProductViewState(super.controller);'));
  });

  test('pure-Dart flavor targets are skipped with no output', () async {
    // Overwrite the pubspec without the `flutter:` key → pure-Dart flavor.
    await File('${tempDir.path}/pubspec.yaml').writeAsString('''
name: view_pure_dart_fixture
environment:
  sdk: ^3.11.0
''');

    final files = await buildPlugin().generate(
      GeneratorConfig(
        name: 'Product',
        methods: ['get'],
        generateView: true,
        outputDir: outputDir,
      ),
    );

    expect(files, isEmpty);
    expect(
      Directory('$outputDir/presentation').existsSync(),
      isFalse,
      reason: 'pure-Dart targets must not receive Flutter view output (#420)',
    );
  });
}
