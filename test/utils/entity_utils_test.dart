// Unit tests for the issue #411 helpers in `EntityUtils`:
//
//   - `extractBaseType` — strips nullable `?`, generic wrappers (`List<...>`,
//     `Map<K, V>`), and the Zorphy entity prefix (`$`) to return the
//     innermost base type, recursing into nested generics.
//   - `isDartCoreType` — `true` for `dart:core` types in `dartCoreTypes`
//     (`Duration`, `Uri`, `BigInt`) — directly, inside `List<...>`, or as
//     the value type of `Map<...>`.
//   - `markDartCoreTypesAsExternal` — returns a new list of
//     `FieldDefinition`s with `isExternal: true` set on every field whose
//     base type is a Dart core type; existing external fields are left
//     unchanged.
//
// These helpers back the `zfa entity create` / `zfa entity add-field` fix
// for issue #411: previously a `Duration` field was silently rejected by
// `EntityTypeValidator` (which is correct for an unresolvable enum/entity
// reference but wrong for a `dart:core` type that needs no on-disk
// declaration and no extra import). Marking the field as external makes
// the validator, the zorphy `FieldNormalizer`, and the `ImportResolver`
// all skip it, so the generated source carries `Duration get x;` — not
// `$Duration get x;` which would not resolve.

import 'package:test/test.dart';
import 'package:zorphy/zorphy.dart' show FieldDefinition;
import 'package:zuraffa/src/utils/entity_utils.dart';

void main() {
  group('EntityUtils.extractBaseType', () {
    test('returns a primitive type unchanged', () {
      expect(EntityUtils.extractBaseType('String'), 'String');
      expect(EntityUtils.extractBaseType('int'), 'int');
      expect(EntityUtils.extractBaseType('bool'), 'bool');
    });

    test('strips the nullable marker (?)', () {
      expect(EntityUtils.extractBaseType('Duration?'), 'Duration');
      expect(EntityUtils.extractBaseType('String?'), 'String');
      expect(EntityUtils.extractBaseType('int?'), 'int');
    });

    test('unwraps List<T> to T', () {
      expect(EntityUtils.extractBaseType('List<Duration>'), 'Duration');
      expect(EntityUtils.extractBaseType('List<String>'), 'String');
      expect(EntityUtils.extractBaseType('List<Product>'), 'Product');
    });

    test('unwraps List<T>? to T', () {
      expect(EntityUtils.extractBaseType('List<Duration>?'), 'Duration');
      expect(EntityUtils.extractBaseType('List<Product>?'), 'Product');
    });

    test('unwraps Map<K, V> to V (the value type)', () {
      expect(
        EntityUtils.extractBaseType('Map<String, Duration>'),
        'Duration',
      );
      expect(
        EntityUtils.extractBaseType('Map<String, Product>'),
        'Product',
      );
    });

    test('unwraps Map<K, V>? to V', () {
      expect(
        EntityUtils.extractBaseType('Map<String, Duration>?'),
        'Duration',
      );
    });

    test('strips the Zorphy entity prefix (\$)', () {
      expect(EntityUtils.extractBaseType(r'$Duration'), 'Duration');
      expect(EntityUtils.extractBaseType(r'$Product'), 'Product');
      expect(EntityUtils.extractBaseType(r'$Duration?'), 'Duration');
    });

    test('recurses into nested generics', () {
      expect(
        EntityUtils.extractBaseType('Map<String, List<Duration>>'),
        'Duration',
      );
      expect(
        EntityUtils.extractBaseType('List<List<Duration>>'),
        'Duration',
      );
      expect(
        EntityUtils.extractBaseType('Map<String, Map<String, Duration>>'),
        'Duration',
      );
    });
  });

  group('EntityUtils.isDartCoreType', () {
    test('true for direct dart:core types in dartCoreTypes', () {
      expect(EntityUtils.isDartCoreType('Duration'), isTrue);
      expect(EntityUtils.isDartCoreType('Uri'), isTrue);
      expect(EntityUtils.isDartCoreType('BigInt'), isTrue);
    });

    test('true for nullable direct dart:core types', () {
      expect(EntityUtils.isDartCoreType('Duration?'), isTrue);
      expect(EntityUtils.isDartCoreType('Uri?'), isTrue);
    });

    test('true inside List<T>', () {
      expect(EntityUtils.isDartCoreType('List<Duration>'), isTrue);
      expect(EntityUtils.isDartCoreType('List<Duration>?'), isTrue);
    });

    test('true as the value type of Map<K, V>', () {
      expect(EntityUtils.isDartCoreType('Map<String, Duration>'), isTrue);
      expect(EntityUtils.isDartCoreType('Map<String, Duration>?'), isTrue);
    });

    test('true inside nested generics', () {
      expect(
        EntityUtils.isDartCoreType('Map<String, List<Duration>>'),
        isTrue,
      );
      expect(
        EntityUtils.isDartCoreType('List<List<Duration>>'),
        isTrue,
      );
    });

    test('true with the Zorphy entity prefix (\$)', () {
      expect(EntityUtils.isDartCoreType(r'$Duration'), isTrue);
    });

    test('false for plain primitives (String, int, ...)', () {
      expect(EntityUtils.isDartCoreType('String'), isFalse);
      expect(EntityUtils.isDartCoreType('int'), isFalse);
      expect(EntityUtils.isDartCoreType('bool'), isFalse);
      expect(EntityUtils.isDartCoreType('DateTime'), isFalse);
    });

    test('false for entity/enum types NOT in dartCoreTypes', () {
      expect(EntityUtils.isDartCoreType('Product'), isFalse);
      expect(EntityUtils.isDartCoreType('FeedbackType'), isFalse);
      expect(EntityUtils.isDartCoreType('List<Product>'), isFalse);
      expect(
        EntityUtils.isDartCoreType('Map<String, Product>'),
        isFalse,
      );
    });

    test('false for the special NoParams/Params family', () {
      expect(EntityUtils.isDartCoreType('NoParams'), isFalse);
      expect(EntityUtils.isDartCoreType('Params'), isFalse);
      expect(EntityUtils.isDartCoreType('QueryParams'), isFalse);
    });
  });

  group('EntityUtils.markDartCoreTypesAsExternal', () {
    test('marks a Duration field as external', () {
      final fields = [
        FieldDefinition(name: 'wallClockTimeout', type: 'Duration'),
      ];
      final result = EntityUtils.markDartCoreTypesAsExternal(fields);
      expect(result, hasLength(1));
      expect(result.first.name, 'wallClockTimeout');
      expect(result.first.type, 'Duration');
      expect(result.first.isExternal, isTrue,
          reason: 'Duration must be marked external');
    });

    test('preserves the nullable flag', () {
      final fields = [
        FieldDefinition(name: 'softTimeout', type: 'Duration', nullable: true),
      ];
      final result = EntityUtils.markDartCoreTypesAsExternal(fields);
      expect(result.first.isExternal, isTrue);
      expect(result.first.nullable, isTrue);
      expect(result.first.fullType, 'Duration?');
    });

    test('marks List<Duration> as external (base type is Duration)', () {
      final fields = [
        FieldDefinition(name: 'tags', type: 'List<Duration>'),
      ];
      final result = EntityUtils.markDartCoreTypesAsExternal(fields);
      expect(result.first.isExternal, isTrue,
          reason: 'List<Duration> base type is Duration');
      expect(result.first.type, 'List<Duration>');
    });

    test('marks Map<String, Duration> as external', () {
      final fields = [
        FieldDefinition(name: 'byKey', type: 'Map<String, Duration>'),
      ];
      final result = EntityUtils.markDartCoreTypesAsExternal(fields);
      expect(result.first.isExternal, isTrue);
    });

    test('does NOT mark a plain entity field as external', () {
      final fields = [
        FieldDefinition(name: 'product', type: 'Product'),
      ];
      final result = EntityUtils.markDartCoreTypesAsExternal(fields);
      expect(result.first.isExternal, isFalse,
          reason: 'Non-dart-core types must be left for normal resolution');
    });

    test('does NOT mark plain primitives (String, int, bool, ...)', () {
      final fields = [
        FieldDefinition(name: 'id', type: 'String'),
        FieldDefinition(name: 'count', type: 'int'),
        FieldDefinition(name: 'active', type: 'bool'),
        FieldDefinition(name: 'createdAt', type: 'DateTime'),
      ];
      final result = EntityUtils.markDartCoreTypesAsExternal(fields);
      for (final f in result) {
        expect(f.isExternal, isFalse,
            reason: '${f.type} should not be marked external');
      }
    });

    test('leaves already-external fields unchanged', () {
      final fields = [
        FieldDefinition(
          name: 'url',
          type: 'WebUri',
          isExternal: true,
        ),
      ];
      final result = EntityUtils.markDartCoreTypesAsExternal(fields);
      expect(result.first.isExternal, isTrue);
      expect(result.first.type, 'WebUri');
    });

    test('returns a NEW list — does not mutate the input', () {
      final original = [
        FieldDefinition(name: 'wallClockTimeout', type: 'Duration'),
      ];
      final result = EntityUtils.markDartCoreTypesAsExternal(original);
      expect(identical(result, original), isFalse);
      // Original field stays non-external.
      expect(original.first.isExternal, isFalse);
      expect(result.first.isExternal, isTrue);
    });

    test('mix: a Duration field is marked, a String field is not', () {
      final fields = [
        FieldDefinition(name: 'name', type: 'String'),
        FieldDefinition(name: 'wallClockTimeout', type: 'Duration'),
        FieldDefinition(name: 'product', type: 'Product'),
        FieldDefinition(name: 'timeout', type: 'Duration?'),
        FieldDefinition(name: 'tags', type: 'List<Duration>'),
      ];
      final result = EntityUtils.markDartCoreTypesAsExternal(fields);
      expect(result, hasLength(5));
      expect(result[0].isExternal, isFalse, reason: 'String');
      expect(result[1].isExternal, isTrue, reason: 'Duration');
      expect(result[2].isExternal, isFalse, reason: 'Product');
      expect(result[3].isExternal, isTrue, reason: 'Duration?');
      expect(result[4].isExternal, isTrue, reason: 'List<Duration>');
    });

    test('handles an empty list', () {
      expect(EntityUtils.markDartCoreTypesAsExternal([]), isEmpty);
    });
  });

  group('EntityUtils.extractEntityTypes — issue #411 (Duration, Uri, BigInt)', () {
    // Issue #411: `extractEntityTypes` is the gate for [EntityTypeValidator].
    // Before the fix it returned `['Duration']` for a Duration field, which
    // made the validator reject the field as an unresolvable entity/enum
    // reference. Now Duration (and Uri, BigInt) are excluded — the helper
    // returns an empty list for them so the validator never sees them as
    // entity candidates in the first place.
    test('returns [] for Duration (now treated as a built-in)', () {
      expect(EntityUtils.extractEntityTypes('Duration'), isEmpty);
    });

    test('returns [] for Duration?', () {
      expect(EntityUtils.extractEntityTypes('Duration?'), isEmpty);
    });

    test('returns [] for List<Duration>', () {
      expect(EntityUtils.extractEntityTypes('List<Duration>'), isEmpty);
    });

    test('returns [] for Map<String, Duration>', () {
      expect(EntityUtils.extractEntityTypes('Map<String, Duration>'), isEmpty);
    });

    test('returns [] for Uri and BigInt', () {
      expect(EntityUtils.extractEntityTypes('Uri'), isEmpty);
      expect(EntityUtils.extractEntityTypes('BigInt'), isEmpty);
    });

    test('still returns the entity type for non-dart-core types', () {
      expect(EntityUtils.extractEntityTypes('Product'), ['Product']);
      expect(
        EntityUtils.extractEntityTypes('List<Product>'),
        ['Product'],
      );
      expect(
        EntityUtils.extractEntityTypes('Map<String, Product>'),
        ['Product'],
      );
    });

    test('still returns [] for plain primitives', () {
      expect(EntityUtils.extractEntityTypes('String'), isEmpty);
      expect(EntityUtils.extractEntityTypes('int'), isEmpty);
      expect(EntityUtils.extractEntityTypes('DateTime'), isEmpty);
    });
  });

  group('dartCoreTypes', () {
    test('contains Duration, Uri, BigInt', () {
      expect(dartCoreTypes, contains('Duration'));
      expect(dartCoreTypes, contains('Uri'));
      expect(dartCoreTypes, contains('BigInt'));
    });

    test('does NOT contain primitives (String, int, ...)', () {
      // These belong to EntityUtils._primitives — they are kept separate
      // so the existing primitives list stays the single source of truth
      // for "no on-disk declaration needed AND no `$`-prefix needed".
      expect(dartCoreTypes, isNot(contains('String')));
      expect(dartCoreTypes, isNot(contains('int')));
      expect(dartCoreTypes, isNot(contains('DateTime')));
    });
  });
}
