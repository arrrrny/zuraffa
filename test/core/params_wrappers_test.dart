import 'package:flutter_test/flutter_test.dart';
import 'package:zorphy_annotation/zorphy_annotation.dart';
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
      const nameField = Field<_TestEntity, String>('name');
      final q = ListQueryParams<_TestEntity>(
        search: 'test',
        filter: Eq<_TestEntity, String>(nameField, 'active'),
        sort: Sort<_TestEntity>.asc(nameField),
        limit: 10,
        offset: 0,
        params: const Params({'custom': 1}),
        extra: const {'active': true},
      );

      expect(q.search, 'test');
      expect(q.filter, isNotNull);
      expect(q.sort?.field.name, 'name');
      expect(q.sort?.descending, false);
      expect(q.limit, 10);
      expect(q.offset, 0);
      expect(q.params?.params?['custom'], 1);
      expect(q.extra?['active'], true);
    });

    test('copyWith should allow partial updates and clearing', () {
      const q = ListQueryParams<_TestEntity>(search: 'old');

      final updated = q.copyWith(search: 'new', clearSort: true);

      expect(updated.search, 'new');
      expect(updated.sort, isNull);
    });

    test('equality and hashCode', () {
      const q1 = ListQueryParams<_TestEntity>(search: 'a');
      const q2 = ListQueryParams<_TestEntity>(search: 'a');
      const q3 = ListQueryParams<_TestEntity>(search: 'b');

      expect(q1, equals(q2));
      expect(q1.hashCode, equals(q2.hashCode));
      expect(q1, isNot(equals(q3)));
    });

    test('toQueryMap serializes correctly', () {
      const nameField = Field<_TestEntity, String>('name');
      final q = ListQueryParams<_TestEntity>(
        search: 'test',
        filter: Eq<_TestEntity, String>(nameField, 'active'),
        sort: Sort<_TestEntity>.desc(nameField),
        limit: 20,
        offset: 5,
        extra: const {'custom': 'value'},
      );

      final map = q.toQueryMap();
      expect(map['search'], 'test');
      expect(map['sort'], isA<Map>());
      expect((map['sort'] as Map)['field'], 'name');
      expect((map['sort'] as Map)['descending'], true);
      expect(map['limit'], 20);
      expect(map['offset'], 5);
      expect(map['filter'], isA<Map>());
      expect(map['custom'], 'value');
    });

    test('default constructor works without type parameter', () {
      const q = ListQueryParams();
      expect(q.search, isNull);
      expect(q.filter, isNull);
      expect(q.sort, isNull);
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

      expect(() => params.validate(['name', 'email']), throwsArgumentError);
    });

    test('validate should succeed for valid fields', () {
      const params = UpdateParams<Partial<String>>(
        id: '123',
        data: {'name': 'Value'},
      );

      expect(() => params.validate(['name', 'email']), returnsNormally);
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

class _TestEntity {
  final String name;
  const _TestEntity({required this.name});
}
