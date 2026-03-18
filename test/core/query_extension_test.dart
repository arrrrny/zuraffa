import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('Query Extension Test', () {
    test('Filter.toQuery() extension', () {
      final filter = AlwaysMatch<_TestEntity>();
      final queryParams = filter.toQuery();
      expect(queryParams.filter, equals(filter));
    });

    test('Iterable<Filter>.toFilter() extension', () {
      final filter1 = Eq<_TestEntity, String>(_TestEntityFields.name, 'test1');
      final filter2 = Eq<_TestEntity, String>(_TestEntityFields.name, 'test2');
      final filters = [filter1, filter2];

      final combinedFilter = filters.toFilter();
      expect(combinedFilter, isA<And<_TestEntity>>());
      expect((combinedFilter as And<_TestEntity>).filters, equals(filters));
    });

    test('Iterable<Filter>.toQuery() extension', () {
      final filter1 = Eq<_TestEntity, String>(_TestEntityFields.name, 'test1');
      final filter2 = Eq<_TestEntity, String>(_TestEntityFields.name, 'test2');
      final filters = [filter1, filter2];

      final queryParams = filters.toQuery();
      expect(queryParams.filter, isA<And<_TestEntity>>());
      expect((queryParams.filter as And<_TestEntity>).filters, equals(filters));
    });

    test('List<T>.query(Filter<T>) extension', () {
      final item1 = _TestEntity(name: 'A');
      final item2 = _TestEntity(name: 'B');
      final list = [item1, item2];

      final filter = Eq<_TestEntity, String>(_TestEntityFields.name, 'B');
      final result = list.query(filter.toQuery());
      expect(result, equals(item2));
    });

    test('toQuery with custom params', () {
      final filter = AlwaysMatch<_TestEntity>();
      final queryParams = filter.toQuery(params: {'includeDeleted': true});
      expect(queryParams.filter, equals(filter));
      expect(queryParams.params, equals({'includeDeleted': true}));
    });

    test('Filter.toListQuery() extension', () {
      final filter = AlwaysMatch<_TestEntity>();
      final listQuery = filter.toListQuery(limit: 10, offset: 5);
      expect(listQuery.filter, equals(filter));
      expect(listQuery.limit, equals(10));
      expect(listQuery.offset, equals(5));
    });

    test('Iterable<Filter>.toListQuery() extension', () {
      final filter1 = Eq<_TestEntity, String>(_TestEntityFields.name, 'test1');
      final filter2 = Eq<_TestEntity, String>(_TestEntityFields.name, 'test2');
      final filters = [filter1, filter2];

      final listQuery = filters.toListQuery(search: 'query');
      expect(listQuery.filter, isA<And<_TestEntity>>());
      expect(listQuery.search, equals('query'));
    });
  });
}

class _TestEntity {
  final String name;
  _TestEntity({required this.name});
}

class _TestEntityFields {
  static const name = Field<_TestEntity, String>('name', _getName);
  static String _getName(_TestEntity entity) => entity.name;
}
