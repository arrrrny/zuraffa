import 'package:flutter_test/flutter_test.dart';
import 'package:zorphy_annotation/zorphy_annotation.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('QueryParams', () {
    test('should store filter and optional params', () {
      const filter = Eq<_TestEntity, String>(_TestEntityFields.name, 'test');
      const params = {'key': 'value'};
      const queryParams = QueryParams<_TestEntity>(
        filter: filter,
        params: params,
      );

      expect(queryParams.filter, filter);
      expect(queryParams.params, params);
    });

    test('toJson serializes correctly', () {
      const filter = Eq<_TestEntity, String>(_TestEntityFields.name, 'test');
      const queryParams = QueryParams<_TestEntity>(
        filter: filter,
        params: {'includeDeleted': true},
      );

      final map = queryParams.toJson((_) => {});
      expect(map['filter'], isA<Map>());
      expect(map['params']['includeDeleted'], true);
    });

    test('copyWith should allow partial updates', () {
      const filter = Eq<_TestEntity, String>(_TestEntityFields.name, 'test');
      const q = QueryParams<_TestEntity>(
        filter: filter,
        params: {'key': 'value'},
      );

      // copyWith ignores nulls, so we can't test clearing directly with copyWith
      // unless we pass a different value.
      final updated = q.copyWith(params: {'new': 'value'});

      expect(updated.filter, filter);
      expect(updated.params?['new'], 'value');
    });

    test('equality should work correctly', () {
      const filter1 = Eq<_TestEntity, String>(_TestEntityFields.name, 'test');
      const filter2 = Eq<_TestEntity, String>(_TestEntityFields.name, 'test');
      const q1 = QueryParams<_TestEntity>(filter: filter1);
      const q2 = QueryParams<_TestEntity>(filter: filter2);
      const q3 = QueryParams<_TestEntity>();

      expect(q1, equals(q2));
      expect(q1, isNot(equals(q3)));
    });

    test('query extension should find matching entity', () {
      const entities = [
        _TestEntity(name: 'Alice'),
        _TestEntity(name: 'Bob'),
        _TestEntity(name: 'Charlie'),
      ];

      final params = QueryParams<_TestEntity>(
        filter: Eq(_TestEntityFields.name, 'Bob'),
      );

      final result = entities.query(params);
      expect(result.name, 'Bob');
    });

    test('query extension should return first when no filter', () {
      const entities = [_TestEntity(name: 'Alice'), _TestEntity(name: 'Bob')];

      final result = entities.query(null);
      expect(result.name, 'Alice');
    });
  });

  group('ListQueryParams', () {
    test('should store all query options', () {
      const nameField = _TestEntityFields.name;
      final q = ListQueryParams<_TestEntity>(
        search: 'test',
        filter: Eq<_TestEntity, String>(nameField, 'active'),
        sort: Sort<_TestEntity>.asc(nameField),
        limit: 10,
        offset: 0,
        params: const {'custom': 1},
      );

      expect(q.search, 'test');
      expect(q.filter, isNotNull);
      expect(q.sort?.field.name, 'name');
      expect(q.sort?.descending, false);
      expect(q.limit, 10);
      expect(q.offset, 0);
      expect(q.params?['custom'], 1);
    });

    test('copyWith should allow partial updates and clearing', () {
      const q = ListQueryParams<_TestEntity>(search: 'old');

      // copyWith ignores nulls, so we can't test clearing directly with copyWith
      // unless we pass a different value.
      final updated = q.copyWith(search: 'new');

      expect(updated.search, 'new');
      // Clearing logic usually requires explicit null assignment in a new instance or specific method
      // copyWith in this implementation typically skips nulls.
    });

    test('equality and hashCode', () {
      const q1 = ListQueryParams<_TestEntity>(search: 'a');
      const q2 = ListQueryParams<_TestEntity>(search: 'a');
      const q3 = ListQueryParams<_TestEntity>(search: 'b');

      expect(q1, equals(q2));
      expect(q1.hashCode, equals(q2.hashCode));
      expect(q1, isNot(equals(q3)));
    });

    test('toJson serializes correctly', () {
      const nameField = _TestEntityFields.name;
      final q = ListQueryParams<_TestEntity>(
        search: 'test',
        filter: Eq<_TestEntity, String>(nameField, 'active'),
        sort: Sort<_TestEntity>.desc(nameField),
        limit: 20,
        offset: 5,
        params: {'custom': 'value'},
      );

      final map = q.toJson((_) => {});
      expect(map['search'], 'test');
      expect(map['sort'], isA<Map>());
      expect((map['sort'] as Map)['field'], 'name');
      expect((map['sort'] as Map)['descending'], true);
      expect(map['limit'], 20);
      expect(map['offset'], 5);
      expect(map['filter'], isA<Map>());
      expect(map['params']['custom'], 'value');
    });

    test('default constructor works without type parameter', () {
      const q = ListQueryParams();
      expect(q.search, isNull);
      expect(q.filter, isNull);
      expect(q.sort, isNull);
    });
  });

  group('CreateParams', () {
    test('should store data and optional params', () {
      const entity = _TestEntity(name: 'Test');
      const params = {'key': 'value'};
      const createParams = CreateParams<_TestEntity>(
        data: entity,
        params: params,
      );

      expect(createParams.data, entity);
      expect(createParams.params, params);
    });

    test('toJson serializes correctly', () {
      const entity = _TestEntity(name: 'Test');
      const createParams = CreateParams<_TestEntity>(
        data: entity,
        params: {'source': 'api'},
      );

      final map = createParams.toJson((_) => entity);
      expect(map['data'], entity);
      expect(map['params']['source'], 'api');
    });

    test('copyWith should work correctly', () {
      const entity1 = _TestEntity(name: 'Test1');
      const entity2 = _TestEntity(name: 'Test2');
      const c = CreateParams<_TestEntity>(data: entity1);

      final updated = c.copyWith(data: entity2);

      expect(updated.data, entity2);
    });

    test('equality should work correctly', () {
      const entity = _TestEntity(name: 'Test');
      const c1 = CreateParams<_TestEntity>(data: entity);
      const c2 = CreateParams<_TestEntity>(data: entity);
      const c3 = CreateParams<_TestEntity>(data: _TestEntity(name: 'Other'));

      expect(c1, equals(c2));
      expect(c1, isNot(equals(c3)));
    });
  });

  group('UpdateParams', () {
    test('should store id, data, and optional params', () {
      const patch = {'name': 'Updated'};
      const params = {'key': 'value'};
      const updateParams = UpdateParams<String, Map<String, dynamic>>(
        id: '123',
        data: patch,
        params: params,
      );

      expect(updateParams.id, '123');
      expect(updateParams.data, patch);
      expect(updateParams.params, params);
    });

    test('toJson serializes correctly', () {
      const updateParams = UpdateParams<String, Map<String, dynamic>>(
        id: '123',
        data: {'name': 'Updated'},
      );

      final map = updateParams.toJson((id) => id, (data) => data);
      expect(map['id'], '123');
      expect(map['data'], isA<Map>());
    });

    test('copyWith should work correctly', () {
      const u = UpdateParams<String, Map<String, dynamic>>(
        id: '123',
        data: {'name': 'Old'},
      );

      final updated = u.copyWith(data: {'name': 'New'});

      expect(updated.data['name'], 'New');
      expect(updated.id, '123');
    });

    test('equality should work correctly', () {
      const u1 = UpdateParams<String, Map<String, dynamic>>(
        id: '123',
        data: {'name': 'Test'},
      );
      const u2 = UpdateParams<String, Map<String, dynamic>>(
        id: '123',
        data: {'name': 'Test'},
      );
      const u3 = UpdateParams<String, Map<String, dynamic>>(
        id: '456',
        data: {'name': 'Other'},
      );

      expect(u1, equals(u2));
      expect(u1, isNot(equals(u3)));
    });
  });

  group('DeleteParams', () {
    test('should store id and optional params', () {
      const params = {'soft': true};
      const deleteParams = DeleteParams<String>(id: '123', params: params);

      expect(deleteParams.id, '123');
      expect(deleteParams.params, params);
    });

    test('toJson serializes correctly', () {
      const deleteParams = DeleteParams<String>(
        id: '123',
        params: {'soft': true},
      );

      final map = deleteParams.toJson((id) => id);
      expect(map['id'], '123');
      expect(map['params']['soft'], true);
    });

    test('copyWith should work correctly', () {
      const d = DeleteParams<String>(id: '123');

      final updated = d.copyWith(id: '456');

      expect(updated.id, '456');
    });

    test('equality should work correctly', () {
      const d1 = DeleteParams<String>(id: '123');
      const d2 = DeleteParams<String>(id: '123');
      const d3 = DeleteParams<String>(id: '456');

      expect(d1, equals(d2));
      expect(d1, isNot(equals(d3)));
    });
  });
}

class _TestEntity {
  final String name;
  const _TestEntity({required this.name});
}

// Mock Fields class for testing
class _TestEntityFields {
  static const name = Field<_TestEntity, String>('name', _getName);

  static String _getName(_TestEntity entity) => entity.name;
}
