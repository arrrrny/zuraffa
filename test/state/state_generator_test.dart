import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('StateGenerator', () {
    late Directory tempDir;
    late StateGenerator gen;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('zuraffa_test_');
      gen = StateGenerator(outputDir: tempDir.path);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('generates DomainState file', () {
      gen.generateDomainState(
        'ProductDetail',
        useCases: [
          UseCaseBinding(
            sliceKey: 'product',
            useCaseFieldName: 'getProductUseCase',
            paramsConstructor: 'GetProductParams',
            returnType: 'Product',
          ),
        ],
      );

      final file = File('${tempDir.path}/product_detail_domain_state.dart');
      expect(file.existsSync(), true);

      final content = file.readAsStringSync();
      expect(content.contains('ProductDetailDomainState'), true);
      expect(content.contains('extends DomainState'), true);
      expect(content.contains('bind<Product>'), true);
      expect(content.contains("'product'"), true);
    });

    test('generates ViewState file on first run', () {
      gen.generateViewState('ProductDetail');

      final file = File('${tempDir.path}/product_detail_view_state.dart');
      expect(file.existsSync(), true);

      final content = file.readAsStringSync();
      expect(content.contains('ProductDetailViewState'), true);
      expect(content.contains('extends ViewState'), true);
      expect(content.contains('Signal<bool>'), true);
      expect(content.contains('Signal<int>'), true);
    });

    test('preserves existing ViewState on regeneration', () {
      // First generation
      gen.generateViewState('ProductDetail');

      // Developer edits the file
      final file = File('${tempDir.path}/product_detail_view_state.dart');
      final originalContent = file.readAsStringSync();
      final editedContent = originalContent.replaceFirst(
        'Signal<bool>(false)',
        'Signal<bool>(true) // developer changed default',
      );
      file.writeAsStringSync(editedContent);

      // Second generation (simulating zfa build)
      final gen2 = StateGenerator(outputDir: tempDir.path);
      gen2.generateViewState('ProductDetail');

      // The developer edit must be preserved
      final contentAfter = file.readAsStringSync();
      expect(contentAfter.contains('developer changed default'), true);
      expect(gen2.preservedFiles, isNotEmpty);
    });

    test('DomainState is regenerated every time', () {
      gen.generateDomainState(
        'ProductDetail',
        useCases: [
          UseCaseBinding(
            sliceKey: 'product',
            useCaseFieldName: 'getProductUseCase',
            paramsConstructor: 'GetProductParams',
            returnType: 'Product',
          ),
        ],
      );

      // Developer edits domain state (should be overwritten)
      final file = File('${tempDir.path}/product_detail_domain_state.dart');
      file.writeAsStringSync('// HACK: developer edit\n');

      // Regenerate
      final gen2 = StateGenerator(outputDir: tempDir.path);
      gen2.generateDomainState(
        'ProductDetail',
        useCases: [
          UseCaseBinding(
            sliceKey: 'product',
            useCaseFieldName: 'getProductUseCase',
            paramsConstructor: 'GetProductParams',
            returnType: 'Product',
          ),
        ],
      );

      // Should be regenerated, not preserved
      final content = file.readAsStringSync();
      expect(content.contains('HACK'), false);
      expect(content.contains('ProductDetailDomainState'), true);
      expect(gen2.generatedFiles.length, 1);
    });

    test('ViewState with custom fields', () {
      gen.generateViewState(
        'ProductDetail',
        fields: [
          ViewStateField('isDescriptionExpanded', 'bool', 'false'),
          ViewStateField('selectedVariantId', 'String', "''"),
          ViewStateField('quantity', 'int', '1'),
        ],
      );

      final file = File('${tempDir.path}/product_detail_view_state.dart');
      final content = file.readAsStringSync();
      expect(content.contains('isDescriptionExpanded'), true);
      expect(content.contains('selectedVariantId'), true);
      expect(content.contains('quantity'), true);
    });

    test('tracks generated and preserved files', () {
      gen.generateDomainState('ProductDetail', useCases: []);
      gen.generateViewState('ProductDetail');

      expect(gen.generatedFiles.length, 2);
      expect(gen.preservedFiles.length, 0);

      // Second run
      final gen2 = StateGenerator(outputDir: tempDir.path);
      gen2.generateDomainState('ProductDetail', useCases: []);
      gen2.generateViewState('ProductDetail');

      expect(gen2.generatedFiles.length, 1); // only domain state
      expect(gen2.preservedFiles.length, 1); // view state preserved
    });
  });
}
