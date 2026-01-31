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

    test('equality should work correctly', () {
      const q1 = QueryParams<String>('id1', Params({'a': 1}));
      const q2 = QueryParams<String>('id1', Params({'a': 1}));
      const q3 = QueryParams<String>('id2');

      expect(q1, equals(q2));
      expect(q1, isNot(equals(q3)));
    });
  });

  group('ListQueryParams', () {
    test('should store all query options', () {
      const q = ListQueryParams(
        search: 'test',
        filters: {'active': true},
        sortBy: 'name',
        descending: false,
        limit: 10,
        offset: 0,
        params: Params({'custom': 1}),
      );

      expect(q.search, 'test');
      expect(q.filters?['active'], true);
      expect(q.sortBy, 'name');
      expect(q.descending, false);
      expect(q.limit, 10);
      expect(q.offset, 0);
      expect(q.params?.params?['custom'], 1);
    });

    test('copyWith should allow partial updates and clearing', () {
      const q = ListQueryParams(search: 'old', sortBy: 'old');
      
      final updated = q.copyWith(
        search: 'new',
        clearSort: true,
      );

      expect(updated.search, 'new');
      expect(updated.sortBy, isNull);
    });

    test('equality and hashCode', () {
      const q1 = ListQueryParams(search: 'a');
      const q2 = ListQueryParams(search: 'a');
      const q3 = ListQueryParams(search: 'b');

      expect(q1, equals(q2));
      expect(q1.hashCode, equals(q2.hashCode));
      expect(q1, isNot(equals(q3)));
    });
  });

  group('UpdateParams', () {
    test('should store id and data map', () {
      const params = UpdateParams<Partial<String>>(
        id: '123',
        data: {'name': 'New Name'},
      );

      expect(params.id, '123');
      expect(params.data['name'], 'New Name');
      expect(params.data, isA<Partial<String>>());
    });

    test('validate should throw for invalid fields', () {
      const params = UpdateParams<Partial<String>>(
        id: '123',
        data: {'invalid': 'value'},
      );

      expect(
        () => params.validate(['name', 'email']),
        throwsArgumentError,
      );
    });

    test('validate should succeed for valid fields', () {
      const params = UpdateParams<Partial<String>>(
        id: '123',
        data: {'name': 'Value'},
      );

      expect(
        () => params.validate(['name', 'email']),
        returnsNormally,
      );
    });
  });

  group('DeleteParams', () {
    test('should store id and optional params', () {
      const params = DeleteParams<int>(123, Params({'soft': true}));

      expect(params.id, 123);
      expect(params.params?.params?['soft'], true);
    });

    test('equality', () {
      const d1 = DeleteParams<int>(1);
      const d2 = DeleteParams<int>(1);
      const d3 = DeleteParams<int>(2);

      expect(d1, equals(d2));
      expect(d1, isNot(equals(d3)));
    });
  });
}
