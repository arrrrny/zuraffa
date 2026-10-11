// Issue #1102 — the auditor wrap: --skin views mount the runtime
// skin-contract auditor at the view getter (pilot lesson 2: the
// overridable skin seam is `Widget get view`, not build).
library;

import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/view/builders/view_class_builder.dart';
import 'package:zuraffa/src/plugins/view/view_plugin.dart';

void main() {
  group('issue #1102 — ViewClassBuilder auditor wrap (unit)', () {
    const builder = ViewClassBuilder();

    ViewClassSpec spec({bool withSkinAudit = false}) => ViewClassSpec(
      viewName: 'ProductView',
      controllerName: 'ProductController',
      presenterName: 'ProductPresenter',
      entityName: 'Product',
      repoFields: const [],
      routeFields: const [],
      repoPresenterArgs: const [],
      initialMethodCall: Block((b) => b),
      imports: const ['package:flutter/material.dart'],
      withState: false,
      withSkinAudit: withSkinAudit,
    );

    test('withSkinAudit wraps the view getter in SkinContractAuditor', () {
      final src = builder.build(spec(withSkinAudit: true));
      expect(src, contains('SkinContractAuditor('));
      expect(src, contains('rows: kProductViewSkinRows'));
      expect(src, contains('Widget get view'));
    });

    test('the wrap emits the starter row list (the hand-edit seam)', () {
      final src = builder.build(spec(withSkinAudit: true));
      expect(src, contains('final List<SkinContractRow> kProductViewSkinRows'));
      // Starter row: the view's own heading text renders.
      expect(src, contains('SkinContractRow.textRenders('));
      expect(src, contains("'Product'"));
    });

    test('the wrap imports the pure core + the emitted kit', () {
      final src = builder.build(spec(withSkinAudit: true));
      expect(src, contains("import 'package:zuraffa/skin.dart'"));
      expect(src, contains('skin/skin_contract_auditor.dart'));
    });

    test(
      'without the flag the output carries NO auditor tokens (byte-compat)',
      () {
        final src = builder.build(spec(withSkinAudit: false));
        expect(src, isNot(contains('SkinContractAuditor')));
        expect(src, isNot(contains('SkinContractRow')));
        expect(src, isNot(contains('package:zuraffa/skin.dart')));
      },
    );
  });

  group('issue #1102 — view plugin --skin generation (structural)', () {
    late Directory tempDir;
    late String outputDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('zuraffa_view_skin_');
      await File('${tempDir.path}/pubspec.yaml').writeAsString('''
name: view_skin_fixture
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

    test('generateSkin emits the view wrap + the kit file', () async {
      final plugin = ViewPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );
      await plugin.generate(
        GeneratorConfig(
          name: 'Product',
          methods: const ['get'],
          generateView: true,
          generateVpcs: true,
          generateSkin: true,
          outputDir: outputDir,
        ),
      );

      final viewFile = File(
        '$outputDir/presentation/pages/product/product_view.dart',
      );
      expect(viewFile.existsSync(), isTrue);
      final src = viewFile.readAsStringSync();
      expect(src, contains('SkinContractAuditor('));
      expect(src, contains('kProductViewSkinRows'));

      // The kit lands alongside the view so the import always resolves.
      final kitFile = File('$outputDir/skin/skin_contract_auditor.dart');
      expect(kitFile.existsSync(), isTrue);
      expect(kitFile.readAsStringSync(), contains('class SkinContractAuditor'));
    });

    test('generateSkin does NOT clobber an existing hand-edited kit', () async {
      final kitFile = File('$outputDir/skin/skin_contract_auditor.dart');
      kitFile.parent.createSync(recursive: true);
      kitFile.writeAsStringSync('// hand-edited kit (1005 seam precedent)');

      final plugin = ViewPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );
      await plugin.generate(
        GeneratorConfig(
          name: 'Product',
          methods: const ['get'],
          generateView: true,
          generateVpcs: true,
          generateSkin: true,
          outputDir: outputDir,
        ),
      );

      expect(kitFile.readAsStringSync(), contains('hand-edited kit'));
    });

    test(
      'without generateSkin the view output has no auditor tokens',
      () async {
        final plugin = ViewPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(dryRun: false, force: true),
        );
        await plugin.generate(
          GeneratorConfig(
            name: 'Product',
            methods: const ['get'],
            generateView: true,
            generateVpcs: true,
            outputDir: outputDir,
          ),
        );

        final viewFile = File(
          '$outputDir/presentation/pages/product/product_view.dart',
        );
        final src = viewFile.readAsStringSync();
        expect(src, isNot(contains('SkinContractAuditor')));
        expect(
          File('$outputDir/skin/skin_contract_auditor.dart').existsSync(),
          isFalse,
        );
      },
    );
  });
}
