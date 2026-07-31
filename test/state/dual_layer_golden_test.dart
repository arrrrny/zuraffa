import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

/// Golden test: zfa build preserves ViewState, regenerates DomainState.
void main() {
  group('Golden: Dual-Layer State Boundary', () {
    late Directory tempDir;

    setUp(
      () => tempDir = Directory.systemTemp.createTempSync('zuraffa_golden_'),
    );
    tearDown(() => tempDir.deleteSync(recursive: true));

    test('golden: full zfa build cycle preserves developer edits', () {
      // Step 1: Initial build generates both files
      final gen1 = StateGenerator(outputDir: tempDir.path);
      gen1.generateDomainState(
        'ProductDetail',
        useCases: [
          UseCaseBinding(
            sliceKey: 'product',
            useCaseFieldName: 'getProductUseCase',
            paramsConstructor: 'GetProductParams',
            returnType: 'Product',
          ),
          UseCaseBinding(
            sliceKey: 'reviews',
            useCaseFieldName: 'getReviewsUseCase',
            paramsConstructor: 'GetReviewsParams',
            returnType: 'List<Review>',
          ),
        ],
      );
      gen1.generateViewState('ProductDetail');

      // Step 2: Developer edits ViewState
      final viewFile = File('${tempDir.path}/product_detail_view_state.dart');
      var viewContent = viewFile.readAsStringSync();
      viewContent = viewContent.replaceFirst(
        'Signal<bool>(false)',
        'Signal<bool>(true) // expanded by default per PM request',
      );
      viewContent +=
          "\n  final userNotes = Signal<String>(''); // added by dev\n";
      viewFile.writeAsStringSync(viewContent);

      // Step 3: Add new UseCase, rebuild
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
          UseCaseBinding(
            sliceKey: 'reviews',
            useCaseFieldName: 'getReviewsUseCase',
            paramsConstructor: 'GetReviewsParams',
            returnType: 'List<Review>',
          ),
          UseCaseBinding(
            sliceKey: 'related',
            useCaseFieldName: 'getRelatedUseCase',
            paramsConstructor: 'GetRelatedParams',
            returnType: 'List<Product>',
          ),
        ],
      );
      gen2.generateViewState('ProductDetail');

      // Assert: DomainState has new slice
      final domainFile = File(
        '${tempDir.path}/product_detail_domain_state.dart',
      );
      final domainContent = domainFile.readAsStringSync();
      expect(domainContent.contains('related'), true);
      expect(domainContent.contains('bind<List<Product>>'), true);

      // Assert: ViewState still has developer edits
      final preservedContent = viewFile.readAsStringSync();
      expect(
        preservedContent.contains('expanded by default per PM request'),
        true,
      );
      expect(preservedContent.contains("userNotes = Signal<String>('')"), true);
      expect(preservedContent.contains('Signal<bool>(true)'), true);
    });
  });
}
