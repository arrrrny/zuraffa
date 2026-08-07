import 'dart:io';
import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// Tests for the v6 dual-layer state generation pipeline:
/// - ViewTemplateGenerator.generatePresenter (Track 2.4)
/// - ViewTemplateGenerator.generateView with zuraffa_flutter import (Track 2.4 AC#5)
/// - StateGenerator + ViewTemplateGenerator integration (Track 2.4 golden)
void main() {
  late Directory tempDir;
  late StateGenerator stateGen;
  late ViewTemplateGenerator viewGen;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('zuraffa_v6_cli_');
    stateGen = StateGenerator(outputDir: tempDir.path);
    viewGen = ViewTemplateGenerator(outputDir: tempDir.path);
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  group('ViewTemplateGenerator.generatePresenter (Track 2.4)', () {
    test('generates a DualLayerPresenter subclass', () {
      final path = viewGen.generatePresenter('ProductDetail', useCases: ['product', 'reviews']);

      final file = File(path);
      expect(file.existsSync(), true);

      final content = file.readAsStringSync();
      expect(content.contains('class ProductDetailPresenter'), true);
      expect(content.contains('extends DualLayerPresenter'), true);
      expect(content.contains('ProductDetailDomainState'), true);
      expect(content.contains('ProductDetailViewState'), true);
      expect(content.contains('SlicePresenter'), true);
    });

    test('presenter is preserved if it already exists', () {
      // First generation
      final path = viewGen.generatePresenter('Checkout', useCases: ['cart']);
      final file = File(path);
      final original = file.readAsStringSync();

      // Developer edits
      final edited = original.replaceAll(
        'SlicePresenter();',
        'SlicePresenter(); // custom orchestration here',
      );
      file.writeAsStringSync(edited);

      // Second generation — should be preserved
      viewGen.generatePresenter('Checkout', useCases: ['cart', 'payment']);

      final after = file.readAsStringSync();
      expect(after.contains('custom orchestration here'), true,
          reason: 'developer edits to presenter must be preserved');
    });

    test('presenter file imports domain_state and view_state', () {
      viewGen.generatePresenter('OrderDetail', useCases: ['order']);

      final content = File('${tempDir.path}/order_detail_presenter.dart')
          .readAsStringSync();
      expect(content.contains("import 'order_detail_domain_state.dart'"), true);
      expect(content.contains("import 'order_detail_view_state.dart'"), true);
      expect(content.contains("import 'package:zuraffa/zuraffa.dart'"), true);
    });
  });

  group('ViewTemplateGenerator.generateView v6 import (Track 2.4 AC#5)', () {
    test('generated view imports zuraffa_flutter (not just zuraffa)', () {
      viewGen.generateView('ProductDetail', useCases: ['product', 'reviews']);

      final content = File('${tempDir.path}/product_detail_view.dart')
          .readAsStringSync();
      // ControlledWidget/FragmentBuilder/SignalBuilder live in zuraffa_flutter
      expect(
        content.contains("import 'package:zuraffa_flutter/zuraffa_flutter.dart'"),
        true,
        reason: 'generated view must import zuraffa_flutter to access '
            'ControlledWidget, FragmentBuilder, and SignalBuilder',
      );
    });

    test('generated view extends ControlledWidget', () {
      viewGen.generateView('ProductDetail', useCases: ['product']);

      final content = File('${tempDir.path}/product_detail_view.dart')
          .readAsStringSync();
      expect(content.contains('extends ControlledWidget<ProductDetailPresenter>'),
          true);
    });

    test('generated view uses FragmentBuilder and SignalBuilder', () {
      viewGen.generateView(
        'ProductDetail',
        useCases: ['product', 'reviews'],
        uiSignals: ['isDescriptionExpanded'],
      );

      final content = File('${tempDir.path}/product_detail_view.dart')
          .readAsStringSync();
      expect(content.contains('FragmentBuilder'), true);
      expect(content.contains('SignalBuilder'), true);
      expect(content.contains('onLoading'), true);
      expect(content.contains('onError'), true);
    });
  });

  group('v6 full generation cycle (Track 2.4 golden)', () {
    test('DomainState + ViewState + Presenter + View all generated', () {
      // 1. DomainState
      final domainPath = stateGen.generateDomainState(
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
      // 2. ViewState
      final viewStatePath = stateGen.generateViewState('ProductDetail');
      // 3. Presenter
      final presenterPath = viewGen.generatePresenter(
        'ProductDetail',
        useCases: ['product', 'reviews'],
      );
      // 4. View
      final viewPath = viewGen.generateView(
        'ProductDetail',
        useCases: ['product', 'reviews'],
      );

      expect(File(domainPath).existsSync(), true);
      expect(File(viewStatePath).existsSync(), true);
      expect(File(presenterPath).existsSync(), true);
      expect(File(viewPath).existsSync(), true);

      // DomainState references the slices
      final domainContent = File(domainPath).readAsStringSync();
      expect(domainContent.contains('bind<Product>'), true);
      expect(domainContent.contains('bind<List<Review>>'), true);

      // ViewState has Signal fields
      final viewStateContent = File(viewStatePath).readAsStringSync();
      expect(viewStateContent.contains('Signal<bool>'), true);

      // Presenter wires both layers
      final presenterContent = File(presenterPath).readAsStringSync();
      expect(presenterContent.contains('DualLayerPresenter'), true);

      // View uses the v6 widgets
      final viewContent = File(viewPath).readAsStringSync();
      expect(viewContent.contains('ControlledWidget'), true);
      expect(viewContent.contains('FragmentBuilder'), true);
    });

    test('rebuilding preserves ViewState and Presenter, regenerates DomainState', () {
      // Initial generation
      stateGen.generateDomainState(
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
      stateGen.generateViewState('ProductDetail');
      viewGen.generatePresenter('ProductDetail', useCases: ['product']);

      // Developer edits ViewState and Presenter
      final vsFile = File('${tempDir.path}/product_detail_view_state.dart');
      vsFile.writeAsStringSync(
        vsFile.readAsStringSync().replaceFirst(
              'Signal<bool>(false)',
              'Signal<bool>(true) // dev edit',
            ),
      );
      final pFile = File('${tempDir.path}/product_detail_presenter.dart');
      final pOriginal = pFile.readAsStringSync();
      pFile.writeAsStringSync('$pOriginal\n// dev addition\n');

      // Rebuild — add a new use case
      final stateGen2 = StateGenerator(outputDir: tempDir.path);
      stateGen2.generateDomainState(
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
      stateGen2.generateViewState('ProductDetail');
      final viewGen2 = ViewTemplateGenerator(outputDir: tempDir.path);
      viewGen2.generatePresenter('ProductDetail', useCases: ['product', 'reviews']);

      // DomainState has the new slice
      final domainContent = File(
        '${tempDir.path}/product_detail_domain_state.dart',
      ).readAsStringSync();
      expect(domainContent.contains('reviews'), true);

      // ViewState preserved
      final vsContent = vsFile.readAsStringSync();
      expect(vsContent.contains('dev edit'), true);

      // Presenter preserved
      final pContent = pFile.readAsStringSync();
      expect(pContent.contains('dev addition'), true);
    });
  });
}
