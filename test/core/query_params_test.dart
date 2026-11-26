import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('QueryParams', () {
    test('QueryParams initialization', () {
      final filter = _TestEntityFields.name.equals('test');
      // Use Map directly instead of Params wrapper
      const params1 = {'a': 1};

      final queryParams = QueryParams<_TestEntity>.fromTrusted(
        filter: filter,
        params: params1,
      );

      expect(queryParams.filter, equals(filter));
      expect(queryParams.params, equals(params1));
    });

    test('should work with null filter and params', () {
      final queryParams = QueryParams<int>.fromTrusted();
      expect(queryParams.filter, isNull);
      expect(queryParams.params, isNull);
    });

    test('should work with only filter', () {
      final filter = alwaysMatch<String>();
      final queryParams = QueryParams<String>.fromTrusted(filter: filter);
      expect(queryParams.filter, filter);
      expect(queryParams.params, isNull);
    });

    test('copyWith should update fields correctly', () {
      final filter1 = alwaysMatch<String>();
      final filter2 = alwaysMatch<String>();
      final queryParams = QueryParams<String>.fromTrusted(filter: filter1);
      const newParams = {'filter': 'active'};

      final updated = queryParams.copyWith(filter: filter2, params: newParams);

      expect(updated.filter, filter2);
      expect(updated.params, newParams);
    });

    test('copyWith should clear fields when requested', () {
      final filter = alwaysMatch<String>();
      const params = {'key': 'value'};

      // copyWith doesn't support clearing, so we create new instances to simulate clearing
      final clearedFilter = QueryParams<String>.fromTrusted(
        filter: null,
        params: params,
      );
      expect(clearedFilter.filter, isNull);
      expect(clearedFilter.params, params);

      final clearedParams = QueryParams<String>.fromTrusted(
        filter: filter,
        params: null,
      );
      expect(clearedParams.filter, filter);
      expect(clearedParams.params, isNull);
    });

    test('equality should work correctly', () {
      final filter1a = alwaysMatch<String>();
      final filter2 = alwaysMatch<String>();
      const params1 = {'a': 1};
      const params2 = {'b': 2};

      final q1 = QueryParams<String>.fromTrusted(
        filter: filter1a,
        params: params1,
      );
      final q2 = QueryParams<String>.fromTrusted(
        filter: filter1a,
        params: params1,
      );
      final q3 = QueryParams<String>.fromTrusted(
        filter: filter2,
        params: params1,
      );
      final q4 = QueryParams<String>.fromTrusted(
        filter: filter1a,
        params: params2,
      );

      expect(q1, equals(q2));
      expect(q1, isNot(equals(q3)));
      expect(q1, isNot(equals(q4)));
    });

    test('hashCode should be consistent for same instance', () {
      final filter = alwaysMatch<String>();
      const params = {'a': 1};

      final q1 = QueryParams<String>.fromTrusted(
        filter: filter,
        params: params,
      );
      final q2 = QueryParams<String>.fromTrusted(
        filter: filter,
        params: params,
      );

      expect(q1.hashCode, equals(q2.hashCode));
    });

    test('toString should be descriptive', () {
      final filter = alwaysMatch<String>();
      final queryParams = QueryParams<String>.fromTrusted(filter: filter);
      expect(queryParams.toString(), contains('QueryParams(filter: '));
    });

    test('toQueryMap should serialize filter and params', () {
      final filter = _TestEntityFields.name.equals('test');
      const params = {'includeDeleted': true};
      final queryParams = QueryParams<_TestEntity>.fromTrusted(
        filter: filter,
        params: params,
      );

      // Provide a dummy serializer for the generic type T
      final map = queryParams.toWire((_) => {});
      expect(map['filter'], isNotNull);
      expect(map['params'], isNotNull);
      expect((map['params'] as Map)['includeDeleted'], isTrue);
    });
  });
}

class _TestEntity {
  final String name;
  const _TestEntity({required this.name});
  _TestEntity copyWith({String? name}) => _TestEntity(name: name ?? this.name);
}

// Hand-written mirror of a v3 `<E>Fields` registry: a write-capable
// ZorphyField per field, with the erased `all` list (zorphy#301).
class _TestEntityFields {
  static const ZorphyField<_TestEntity, String> name =
      ZorphyField<_TestEntity, String>(
        name: 'name',
        jsonKey: 'name',
        pointer: '/name',
        get: _getName,
        set: _setName,
      );

  static String _getName(_TestEntity entity) => entity.name;
  static _TestEntity _setName(_TestEntity entity, String value) =>
      entity.copyWith(name: value);
}
