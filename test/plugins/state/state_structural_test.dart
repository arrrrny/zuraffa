import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/state/state_plugin.dart';

/// Spec 1003 (T002) — dedicated structural tests for the `state` trust-tier
/// generator (`test/plugins/state/`).
///
/// Complements the existing `state_builder_test.dart` with plugin-level
/// file-count/imports/stub-body assertions and covers the flavor-driven
/// import switch from #512 (pure-Dart targets import zuraffa core, Flutter
/// targets import zuraffa_flutter).
void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_state_tier_');
    outputDir = tempDir.path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  StatePlugin buildPlugin() => StatePlugin(
    outputDir: outputDir,
    options: const GeneratorOptions(dryRun: false, force: true),
  );

  test('emits exactly one state file at the canonical path', () async {
    final files = await buildPlugin().generate(
      GeneratorConfig(
        name: 'Product',
        methods: ['get', 'getList', 'create'],
        generateState: true,
        outputDir: outputDir,
      ),
    );

    expect(files, hasLength(1));
    expect(
      files.single.path,
      contains('presentation/pages/product/product_state.dart'),
    );

    final content = File(files.single.path).readAsStringSync();
    expect(content, contains('// GENERATED - DO NOT EDIT'));
    expect(content, contains('// END GENERATED'));
  });

  test('declares state class with per-method loading flags', () async {
    final files = await buildPlugin().generate(
      GeneratorConfig(
        name: 'Product',
        methods: ['get', 'getList', 'create'],
        generateState: true,
        outputDir: outputDir,
      ),
    );

    final content = File(files.single.path).readAsStringSync();

    // Class name + entity imports.
    expect(content, contains('class ProductState {'));
    expect(
      content,
      contains("import '../../../domain/entities/product/product.dart';"),
    );

    // Per-method flags + entity/error holders.
    expect(content, contains('final bool isGetting;'));
    expect(content, contains('final bool isGettingList;'));
    expect(content, contains('final bool isCreating;'));
    expect(content, contains('final Product? product;'));
    expect(content, contains('final List<Product> productList;'));
    expect(content, contains('final AppFailure? error;'));
  });

  test('emits copyWith, derived getters and equality stubs', () async {
    final files = await buildPlugin().generate(
      GeneratorConfig(
        name: 'Product',
        methods: ['get', 'getList', 'create'],
        generateState: true,
        outputDir: outputDir,
      ),
    );

    final content = File(files.single.path).readAsStringSync();

    expect(content, contains('ProductState copyWith({'));
    expect(content, contains('bool get isLoading =>'));
    expect(content, contains('bool get hasError =>'));
    expect(content, contains('bool operator ==(Object other)'));
    expect(content, contains('int get hashCode'));
    expect(content, contains("String toString() =>\n      'ProductState("));
  });

  test(
    '#512: pure-Dart flavor imports zuraffa core, Flutter flavor zuraffa_flutter',
    () async {
      // Pure-Dart target: pubspec without `flutter:` → core import.
      await File('${tempDir.path}/pubspec.yaml').writeAsString('''
name: state_pure_dart_fixture
environment:
  sdk: ^3.11.0
''');
      final pureFiles = await buildPlugin().generate(
        GeneratorConfig(
          name: 'Product',
          methods: ['get'],
          generateState: true,
          outputDir: outputDir,
        ),
      );
      expect(pureFiles, hasLength(1));
      final pureContent = File(pureFiles.single.path).readAsStringSync();
      expect(pureContent, contains("import 'package:zuraffa/zuraffa.dart';"));
      expect(
        pureContent,
        isNot(contains('zuraffa_flutter')),
        reason: 'pure-Dart targets must not reference zuraffa_flutter (#512)',
      );

      // Flutter target: pubspec with `flutter:` → flutter import.
      await File('${tempDir.path}/pubspec.yaml').writeAsString('''
name: state_flutter_fixture
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
  zuraffa_flutter: ^6.1.0
''');
      final flutterFiles = await buildPlugin().generate(
        GeneratorConfig(
          name: 'Product',
          methods: ['get'],
          generateState: true,
          outputDir: outputDir,
        ),
      );
      expect(flutterFiles, hasLength(1));
      final flutterContent = File(flutterFiles.single.path).readAsStringSync();
      expect(
        flutterContent,
        contains("import 'package:zuraffa_flutter/zuraffa_flutter.dart';"),
      );
    },
  );
}
