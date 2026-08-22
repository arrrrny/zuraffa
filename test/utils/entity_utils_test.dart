// Unit tests for EntityUtils.extractEntityTypes.
//
// extractEntityTypes decides which field types are *custom* (entity/enum)
// references. Anything it returns must resolve to an entity directory or an
// enum file on disk (see EntityTypeValidator), so dart:core types must never
// appear in its output — otherwise `zfa entity create` rejects the field.

import 'package:test/test.dart';
import 'package:zuraffa/src/utils/entity_utils.dart';

void main() {
  group(
    'EntityUtils.extractEntityTypes — dart:core types are not entities',
    () {
      test('Duration is not treated as an entity reference (issue #411)', () {
        expect(EntityUtils.extractEntityTypes('Duration'), isEmpty);
        expect(EntityUtils.extractEntityTypes('Duration?'), isEmpty);
        expect(EntityUtils.extractEntityTypes('List<Duration>'), isEmpty);
        expect(
          EntityUtils.extractEntityTypes('Map<String, Duration>'),
          isEmpty,
        );
      });

      test('other primitives are still excluded', () {
        for (final type in ['String', 'int', 'double', 'bool', 'DateTime']) {
          expect(
            EntityUtils.extractEntityTypes(type),
            isEmpty,
            reason: '$type must not be treated as an entity',
          );
        }
      });
    },
  );

  group('EntityUtils.extractEntityTypes — custom types', () {
    test('still extracts genuine entity and enum references', () {
      expect(EntityUtils.extractEntityTypes('Product'), ['Product']);
      expect(EntityUtils.extractEntityTypes('\$Product'), ['Product']);
      expect(EntityUtils.extractEntityTypes('List<Product?>'), ['Product']);
      expect(EntityUtils.extractEntityTypes('FeedbackType'), ['FeedbackType']);
    });
  });
}
