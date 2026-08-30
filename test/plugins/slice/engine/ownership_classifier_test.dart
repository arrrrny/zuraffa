/// Tests for the file ownership classifier (U27, U28).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   U27: A file under the entry's `presentation/pages/<feature>/` directory
///        classifies as `owned`
///   U28: Entities, domain interfaces, shared widgets, and `core/`/`config/`
///        files classify as `shared`
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/engine/ownership_classifier.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_file.dart';

void main() {
  late OwnershipClassifier classifier;

  setUp(() {
    classifier = OwnershipClassifier();
  });

  group('OwnershipClassifier (FR-010)', () {
    test('U27: files under an entry page directory are owned', () {
      final entries = ['lib/src/presentation/pages/product'];

      expect(
        classifier.classify(
          relativePath: 'lib/src/presentation/pages/product/product_view.dart',
          entryPageDirs: entries,
        ),
        equals(FileOwnership.owned),
      );
      expect(
        classifier.classify(
          relativePath: 'lib/src/presentation/pages/product/product_state.dart',
          entryPageDirs: entries,
        ),
        equals(FileOwnership.owned),
      );
    });

    test('U27: a second entry page directory is owned too', () {
      final entries = [
        'lib/src/presentation/pages/product',
        'lib/src/presentation/pages/profile',
      ];

      expect(
        classifier.classify(
          relativePath: 'lib/src/presentation/pages/profile/profile_view.dart',
          entryPageDirs: entries,
        ),
        equals(FileOwnership.owned),
      );
    });

    test('U28: entities, domain interfaces, shared widgets, core, config are '
        'shared', () {
      const entries = ['lib/src/presentation/pages/product'];

      final sharedPaths = [
        'lib/src/domain/entities/product/product.dart',
        'lib/src/domain/entities/product/product.g.dart',
        'lib/src/domain/repositories/product_repository.dart',
        'lib/src/domain/usecases/product/get_product_usecase.dart',
        'lib/src/presentation/widgets/primary_button.dart',
        'lib/src/core/theme.dart',
        'lib/src/config/app_config.dart',
        'lib/src/di/usecases/get_product_usecase_di.dart',
      ];

      for (final path in sharedPaths) {
        expect(
          classifier.classify(relativePath: path, entryPageDirs: entries),
          equals(FileOwnership.shared),
          reason: '$path should classify as shared',
        );
      }
    });

    test('another feature\'s page directory is shared, not owned', () {
      const entries = ['lib/src/presentation/pages/product'];

      expect(
        classifier.classify(
          relativePath: 'lib/src/presentation/pages/profile/profile_view.dart',
          entryPageDirs: entries,
        ),
        equals(FileOwnership.shared),
      );
    });
  });
}
