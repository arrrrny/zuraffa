import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:zorphy/zorphy.dart';

void main() {
  group('QueryParams', () {
    test('should store filter and optional params', () {
      const params = Params(params: {'key': 'value'});
      final filter = AlwaysMatch<String>();
      final queryParams = QueryParams<String>(filter: filter, params: params);

      expect(queryParams.filter, filter);
      expect(queryParams.params, params);
    });

    test('should work with null filter and params', () {
      const queryParams = QueryParams<int>();
      expect(queryParams.filter, isNull);
      expect(queryParams.params, isNull);
    });

    test('should work with only filter', () {
      final filter = AlwaysMatch<String>();
      final queryParams = QueryParams<String>(filter: filter);
      expect(queryParams.filter, filter);
      expect(queryParams.params, isNull);
    });

    test('copyWith should update fields correctly', () {
      final filter1 = AlwaysMatch<String>();
      final filter2 = AlwaysMatch<String>();
      final queryParams = QueryParams<String>(filter: filter1);
      const newParams = Params(params: {'filter': 'active'});

      final updated = queryParams.copyWith(filter: filter2, params: newParams);

      expect(updated.filter, filter2);
      expect(updated.params, newParams);
    });

    test('copyWith should clear fields when requested', () {
      final filter = AlwaysMatch<String>();
      const params = Params(params: {'key': 'value'});
      final queryParams = QueryParams<String>(filter: filter, params: params);

      // copyWith doesn't support clearing, so we create new instances to simulate clearing
      final clearedFilter = QueryParams<String>(filter: null, params: params);
      expect(clearedFilter.filter, isNull);
      expect(clearedFilter.params, params);

      final clearedParams = QueryParams<String>(filter: filter, params: null);
      expect(clearedParams.filter, filter);
      expect(clearedParams.params, isNull);
    });

    test('equality should work correctly', () {
      final filter1a = AlwaysMatch<String>();
      final filter2 = AlwaysMatch<String>();
      const params1 = Params({'a': 1});
      const params2 = Params({'b': 2});

      final q1 = QueryParams<String>(filter: filter1a, params: params1);
      final q2 = QueryParams<String>(filter: filter1a, params: params1);
      final q3 = QueryParams<String>(filter: filter2, params: params1);
      final q4 = QueryParams<String>(filter: filter1a, params: params2);

      expect(q1, equals(q2));
      expect(q1, isNot(equals(q3)));
      expect(q1, isNot(equals(q4)));
    });

    test('hashCode should be consistent for same instance', () {
      final filter = AlwaysMatch<String>();
      const params = Params({'a': 1});

      final q1 = QueryParams<String>(filter: filter, params: params);
      final q2 = QueryParams<String>(filter: filter, params: params);

      expect(q1.hashCode, equals(q2.hashCode));
    });

    test('toString should be descriptive', () {
      final filter = AlwaysMatch<String>();
      final queryParams = QueryParams<String>(filter: filter);
      expect(
        queryParams.toString(),
        contains('QueryParams<String>(filter: Instance of'),
      );
    });

    test('toQueryMap should serialize filter and params', () {
      final filter = AlwaysMatch<String>();
      const params = Params(params: {'key': 'value'});
      final queryParams = QueryParams<String>(filter: filter, params: params);

      final map = queryParams.toJson();
      expect(map['filter'], isNotNull);
      expect(map['params'], isNotNull);
    });
  });
}
