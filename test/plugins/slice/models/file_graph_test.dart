/// Unit tests for the slice depth classification (spec 043 data model,
/// issue #597 regression guard).
///
/// The depth filter's correctness rests on two functions:
///   - `classifyLayer` maps a lib-relative path to its architecture layer.
///   - `layerAllowedAtDepth` is the tier table deciding which layers each
///     `--depth` value mirrors.
///
/// #597: `--depth view` mirrored the presenter layer. The committed A13
/// acceptance test covers the canonical pages/ layout; these unit tests pin
/// the classification so the presenter layer cannot leak back in through a
/// different path shape (a presenter anywhere under `lib/src/presentation/`
/// is still the presenter layer, not `presentation_shared`).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/models/file_graph.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_depth.dart';

void main() {
  group('classifyLayer', () {
    test('view/controller/state under pages/ are the view layer', () {
      expect(
        classifyLayer('lib/src/presentation/pages/product/product_view.dart'),
        equals('view'),
      );
      expect(
        classifyLayer(
          'lib/src/presentation/pages/product/product_controller.dart',
        ),
        equals('view'),
      );
      expect(
        classifyLayer('lib/src/presentation/pages/product/product_state.dart'),
        equals('view'),
      );
    });

    test('a presenter under pages/ is the presenter layer (A13 shape)', () {
      expect(
        classifyLayer(
          'lib/src/presentation/pages/product/product_presenter.dart',
        ),
        equals('presenter'),
      );
    });

    test(
      'a presenter anywhere under presentation/ is the presenter layer (597)',
      () {
        // Regression guard for #597: the depth ordering must not treat
        // `view` as including presentation wholesale. A presenter file that
        // lives outside pages/ is still the presenter layer and must be
        // excluded at view depth, not smuggled in as presentation_shared.
        expect(
          classifyLayer(
            'lib/src/presentation/presenters/product_presenter.dart',
          ),
          equals('presenter'),
        );
        expect(
          classifyLayer('lib/src/presentation/product_presenter.dart'),
          equals('presenter'),
        );
      },
    );

    test('shared widgets stay presentation_shared', () {
      expect(
        classifyLayer('lib/src/presentation/widgets/primary_button.dart'),
        equals('presentation_shared'),
      );
      expect(
        classifyLayer('lib/src/presentation/widgets/index.dart'),
        equals('presentation_shared'),
      );
    });

    test('domain, data, di, and cross-cutting files keep their layers', () {
      expect(
        classifyLayer('lib/src/domain/entities/product/product.dart'),
        equals('domain'),
      );
      expect(
        classifyLayer('lib/src/data/repositories/data_product_repository.dart'),
        equals('data'),
      );
      expect(
        classifyLayer('lib/src/di/usecases/get_product_usecase_di.dart'),
        equals('di'),
      );
      expect(
        classifyLayer('lib/src/mocks/mock_product_presenter.dart'),
        equals('other'),
      );
      expect(classifyLayer('lib/main.dart'), equals('other'));
    });
  });

  group('layerAllowedAtDepth', () {
    test('view tier stops at view/shared/other — no presenter or deeper', () {
      for (final allowed in ['view', 'presentation_shared', 'other']) {
        expect(
          layerAllowedAtDepth(allowed, SliceDepth.view),
          isTrue,
          reason: allowed,
        );
      }
      for (final excluded in ['presenter', 'domain', 'data', 'di']) {
        expect(
          layerAllowedAtDepth(excluded, SliceDepth.view),
          isFalse,
          reason: excluded,
        );
      }
    });

    test('presentation tier adds the presenter, still no domain', () {
      expect(layerAllowedAtDepth('presenter', SliceDepth.presentation), isTrue);
      expect(layerAllowedAtDepth('view', SliceDepth.presentation), isTrue);
      expect(
        layerAllowedAtDepth('presentation_shared', SliceDepth.presentation),
        isTrue,
      );
      expect(layerAllowedAtDepth('domain', SliceDepth.presentation), isFalse);
      expect(layerAllowedAtDepth('data', SliceDepth.presentation), isFalse);
    });

    test('feature tier adds domain and di, still no data', () {
      expect(layerAllowedAtDepth('presenter', SliceDepth.feature), isTrue);
      expect(layerAllowedAtDepth('domain', SliceDepth.feature), isTrue);
      expect(layerAllowedAtDepth('di', SliceDepth.feature), isTrue);
      expect(layerAllowedAtDepth('data', SliceDepth.feature), isFalse);
    });

    test('full tier includes every layer', () {
      for (final layer in [
        'view',
        'presenter',
        'presentation_shared',
        'domain',
        'data',
        'di',
        'other',
      ]) {
        expect(
          layerAllowedAtDepth(layer, SliceDepth.full),
          isTrue,
          reason: layer,
        );
      }
    });
  });
}
