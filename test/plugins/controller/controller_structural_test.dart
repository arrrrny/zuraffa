import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/controller/controller_plugin.dart';

/// Spec 1003 (T002) — dedicated structural tests for the `controller`
/// trust-tier generator (`test/plugins/controller/`).
///
/// Generates into a throwaway temp dir and asserts file count + key
/// content (class name, imports, method signatures, expected stub body).
void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_ctrl_tier_');
    // Flutter flavor marker — controllers are Flutter-only (#420).
    await File('${tempDir.path}/pubspec.yaml').writeAsString('''
name: controller_structural_fixture
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

  ControllerPlugin buildPlugin() => ControllerPlugin(
    outputDir: outputDir,
    options: const GeneratorOptions(dryRun: false, force: true),
  );

  test('emits exactly one controller file at the canonical path', () async {
    final files = await buildPlugin().generate(
      GeneratorConfig(
        name: 'Product',
        methods: ['get', 'update'],
        generateController: true,
        outputDir: outputDir,
      ),
    );

    expect(files, hasLength(1));
    expect(
      files.single.path,
      contains('presentation/pages/product/product_controller.dart'),
    );

    final content = File(files.single.path).readAsStringSync();
    expect(content, contains('// GENERATED - DO NOT EDIT'));
    expect(content, contains('// END GENERATED'));
  });

  test('declares Controller subclass with presenter wiring', () async {
    final files = await buildPlugin().generate(
      GeneratorConfig(
        name: 'Product',
        methods: ['get', 'update'],
        generateController: true,
        outputDir: outputDir,
      ),
    );

    final content = File(files.single.path).readAsStringSync();

    // Class name + base type.
    expect(content, contains('class ProductController extends Controller {'));

    // Imports: zuraffa_flutter + presenter + entity.
    expect(
      content,
      contains("import 'package:zuraffa_flutter/zuraffa_flutter.dart';"),
    );
    expect(content, contains("import 'product_presenter.dart';"));
    expect(
      content,
      contains("import '../../../domain/entities/product/product.dart';"),
    );

    // Presenter field + constructor wiring.
    expect(content, contains('ProductController(this._presenter);'));
    expect(content, contains('final ProductPresenter _presenter;'));
  });

  test('emits per-method signatures and fold stubs for get/update', () async {
    final files = await buildPlugin().generate(
      GeneratorConfig(
        name: 'Product',
        methods: ['get', 'update'],
        generateController: true,
        outputDir: outputDir,
      ),
    );

    final content = File(files.single.path).readAsStringSync();

    // Method signatures (with cancel-token parameter). The formatter
    // wraps long signatures, so assert on stable fragments.
    expect(content, contains('Future<void> getProduct('));
    expect(content, contains('Future<void> updateProduct('));
    expect(content, contains('String id,'));
    expect(content, contains('ProductPatch data,'));
    expect(content, contains('CancelToken? cancelToken,'));

    // Result-fold stub bodies.
    expect(content, contains('_presenter.getProduct(id, cancelToken)'));
    expect(
      content,
      contains('_presenter.updateProduct(id, data, cancelToken)'),
    );
    expect(content, contains('result.fold((entity) {}, (failure) {})'));
    expect(content, contains('result.fold((updated) {}, (failure) {})'));
  });

  test('overrides onDisposed to dispose the presenter', () async {
    final files = await buildPlugin().generate(
      GeneratorConfig(
        name: 'Product',
        methods: ['get'],
        generateController: true,
        outputDir: outputDir,
      ),
    );

    final content = File(files.single.path).readAsStringSync();
    expect(content, contains('@override'));
    expect(content, contains('void onDisposed() {'));
    expect(content, contains('_presenter.dispose();'));
    expect(content, contains('super.onDisposed();'));
  });

  test('pure-Dart flavor targets are skipped with no output', () async {
    await File('${tempDir.path}/pubspec.yaml').writeAsString('''
name: controller_pure_dart_fixture
environment:
  sdk: ^3.11.0
''');

    final files = await buildPlugin().generate(
      GeneratorConfig(
        name: 'Product',
        methods: ['get'],
        generateController: true,
        outputDir: outputDir,
      ),
    );

    expect(files, isEmpty);
    expect(
      Directory('$outputDir/presentation').existsSync(),
      isFalse,
      reason: 'pure-Dart targets must not receive controller output (#420)',
    );
  });
}
