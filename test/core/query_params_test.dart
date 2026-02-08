import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('QueryParams', () {
    test('should store query value and optional params', () {
      const params = Params({'key': 'value'});
      const queryParams = QueryParams<String>('id123', params);

      expect(queryParams.query, 'id123');
      expect(queryParams.params, params);
    });

    test('should work with different types as query', () {
      const queryParamsInt = QueryParams<int>(42);
      expect(queryParamsInt.query, 42);

      const queryParamsString = QueryParams<String>('slug-name');
      expect(queryParamsString.query, 'slug-name');
    });

    test('copyWith should update fields correctly', () {
      const queryParams = QueryParams<String>('id123');
      const newParams = Params({'filter': 'active'});

      final updated = queryParams.copyWith(query: 'id456', params: newParams);

      expect(updated.query, 'id456');
      expect(updated.params, newParams);
    });

    test('equality should work correctly', () {
      const q1 = QueryParams<String>('id1', Params({'a': 1}));
      const q2 = QueryParams<String>('id1', Params({'a': 1}));
      const q3 = QueryParams<String>('id2', Params({'a': 1}));
      const q4 = QueryParams<String>('id1', Params({'b': 2}));

      expect(q1, equals(q2));
      expect(q1, isNot(equals(q3)));
      expect(q1, isNot(equals(q4)));
    });

    test('hashCode should be consistent', () {
      const q1 = QueryParams<String>('id1', Params({'a': 1}));
      const q2 = QueryParams<String>('id1', Params({'a': 1}));

      expect(q1.hashCode, equals(q2.hashCode));
    });

    test('toString should be descriptive', () {
      const queryParams = QueryParams<String>('id123');
      expect(
        queryParams.toString(),
        contains('QueryParams<String>(query: id123, params: null)'),
      );
    });
  });
}
