import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('Initialization wire params', () {
    const values = <String, dynamic>{'clear': null, 'enabled': true};

    test('retains null and non-null entries in params and settings', () {
      final params = Settings.fromTrusted(params: values);
      final decodedParams = Settings.fromWire(params.toWire()).fold(
        (value) => value,
        (error) => throw StateError('${error.violations}'),
      );
      expect(decodedParams.params, values);

      final settings = Settings.fromTrusted(params: values);
      final decoded = Settings.fromWire(settings.toWire()).fold(
        (value) => value,
        (error) => throw StateError('${error.violations}'),
      );
      expect(decoded.params, values);
    });

    test(
      'retains null and non-null entries in initialization and its settings',
      () {
        final initialization = InitializationParams.fromTrusted(
          timeout: Duration(seconds: 5),
          params: values,
          credentials: Credentials.fromTrusted(params: values),
          settings: Settings.fromTrusted(params: values),
        );
        final decoded = InitializationParams.fromWire(initialization.toWire())
            .fold(
              (value) => value,
              (error) => throw StateError('${error.violations}'),
            );
        expect(decoded.params, values);
        expect(decoded.credentials?.params, values);
        expect(decoded.settings?.params, values);
      },
    );

    test('still rejects params maps with non-string keys', () {
      final paths =
          Settings.fromWire({
            'params': {1: null},
          }).fold(
            (_) => <String>[],
            (error) => [
              for (final violation in error.violations) violation.path,
            ],
          );
      expect(paths, ['/params']);
    });
  });

  group('v3 field registry', () {
    test('a predicate built through the erased `all` registry matches like '
        'the typed one (zorphy#301)', () {
      final field = _TestEntityFields.all.byPointer('/name');
      expect(field, isNotNull);
      final viaAll = field!.equals('Bob');
      final typed = _TestEntityFields.name.equals('Bob');
      const bob = _TestEntity(name: 'Bob');
      const alice = _TestEntity(name: 'Alice');
      expect(viaAll.matches(bob), isTrue);
      expect(viaAll.matches(alice), isFalse);
      expect(viaAll.toWire(), typed.toWire());
    });
  });

  group('QueryParams', () {
    test('should store filter and optional params', () {
      final filter = _TestEntityFields.name.equals('test');
      const params = {'key': 'value'};
      final queryParams = QueryParams<_TestEntity>.fromTrusted(
        filter: filter,
        params: params,
      );

      expect(queryParams.filter, filter);
      expect(queryParams.params, params);
    });

    test('toJson serializes correctly', () {
      final filter = _TestEntityFields.name.equals('test');
      final queryParams = QueryParams<_TestEntity>.fromTrusted(
        filter: filter,
        params: {'includeDeleted': true},
      );

      // The JSON wire shape goes through the hand-written converter.
      final map = queryParamsToWire(queryParams);
      expect(map['filter'], isA<Map>());
      expect((map['params'] as Map)['includeDeleted'], true);
      // The generated codec keeps the Filter object (it cannot know the
      // converter) — it round-trips the object, not its JSON.
      final generated = queryParams.toWire((_) => {});
      expect(generated['filter'], same(filter));
    });

    test('copyWith should allow partial updates', () {
      final filter = _TestEntityFields.name.equals('test');
      final q = QueryParams<_TestEntity>.fromTrusted(
        filter: filter,
        params: {'key': 'value'},
      );

      // copyWith ignores nulls, so we can't test clearing directly with copyWith
      // unless we pass a different value.
      final updated = q.copyWith(params: {'new': 'value'});

      expect(updated.filter, filter);
      expect(updated.params?['new'], 'value');
    });

    test('equality: same predicate instance, and params compared by value', () {
      // v3 predicates carry no value equality (neither did v2 — two `const Eq`
      // compared equal only through const canonicalization), so QueryParams
      // equality is by the SAME predicate instance, never by an equal-valued
      // one built twice.
      final filter = _TestEntityFields.name.equals('test');
      final q1 = QueryParams<_TestEntity>.fromTrusted(filter: filter);
      final q2 = QueryParams<_TestEntity>.fromTrusted(filter: filter);
      final sameValue = QueryParams<_TestEntity>.fromTrusted(
        filter: _TestEntityFields.name.equals('test'),
      );
      final q3 = QueryParams<_TestEntity>.fromTrusted();

      expect(q1, equals(q2));
      expect(q1, isNot(equals(sameValue)));
      expect(q1, isNot(equals(q3)));
    });

    test('query extension should find matching entity', () {
      const entities = [
        _TestEntity(name: 'Alice'),
        _TestEntity(name: 'Bob'),
        _TestEntity(name: 'Charlie'),
      ];

      final params = QueryParams<_TestEntity>.fromTrusted(
        filter: _TestEntityFields.name.equals('Bob'),
      );

      final result = entities.query(params);
      expect(result.name, 'Bob');
    });

    test('query extension should return first when no filter', () {
      const entities = [_TestEntity(name: 'Alice'), _TestEntity(name: 'Bob')];

      final result = entities.query(null);
      expect(result.name, 'Alice');
    });

    test('query extension throws NotFoundFailure on empty iterable', () {
      const entities = <_TestEntity>[];

      expect(
        () => entities.query(
          QueryParams<_TestEntity>.fromTrusted(params: {'id': 'entity_1'}),
        ),
        throwsA(isA<NotFoundFailure>()),
      );
      expect(() => entities.query(null), throwsA(isA<NotFoundFailure>()));
    });

    test('query extension never returns a non-matching element for a '
        'params-only query', () {
      final entities = [
        _JsonEntity(id: 'entity_1', name: 'Alice'),
        _JsonEntity(id: 'entity_2', name: 'Bob'),
      ];

      expect(
        () => entities.query(
          QueryParams<_JsonEntity>.fromTrusted(params: {'id': 'entity_3'}),
        ),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('query extension matches params against the entity JSON view', () {
      final entities = [
        _JsonEntity(id: 'entity_1', name: 'Alice'),
        _JsonEntity(id: 'entity_2', name: 'Bob'),
      ];

      final result = entities.query(
        QueryParams<_JsonEntity>.fromTrusted(params: {'id': 'entity_2'}),
      );

      expect(result.name, 'Bob');
    });

    test('query extension throws NotFoundFailure when the filter matches '
        'nothing', () {
      const entities = [_TestEntity(name: 'Alice')];

      final params = QueryParams<_TestEntity>.fromTrusted(
        filter: _TestEntityFields.name.equals('Zoe'),
      );

      expect(() => entities.query(params), throwsA(isA<NotFoundFailure>()));
    });

    test('query extension returns the first element for an empty params map '
        'or absent params', () {
      const entities = [_TestEntity(name: 'Alice'), _TestEntity(name: 'Bob')];

      expect(
        entities.query(QueryParams<_TestEntity>.fromTrusted(params: {})).name,
        'Alice',
      );
      expect(
        entities.query(QueryParams<_TestEntity>.fromTrusted()).name,
        'Alice',
      );
    });

    test('query extension returns the first of several filter matches', () {
      const entities = [
        _TestEntity(name: 'Alice', tag: 'first'),
        _TestEntity(name: 'Alice', tag: 'second'),
      ];

      final result = entities.query(
        QueryParams<_TestEntity>.fromTrusted(
          filter: _TestEntityFields.name.equals('Alice'),
        ),
      );

      expect(result.tag, 'first');
    });

    test('query extension matches params against a Zorphy toJsonLean view', () {
      const entities = [_LeanEntity(id: 'id 1'), _LeanEntity(id: 'id 2')];

      final result = entities.query(
        QueryParams<_LeanEntity>.fromTrusted(params: {'id': 'id 1'}),
      );

      expect(result.id, 'id 1');
    });
  });

  group('ListQueryParams', () {
    test('should store all query options', () {
      const nameField = _TestEntityFields.name;
      final q = ListQueryParams<_TestEntity>.fromTrusted(
        search: 'test',
        filter: nameField.equals('active'),
        sort: nameField.asc(),
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
      final q = ListQueryParams<_TestEntity>.fromTrusted(search: 'old');

      // copyWith ignores nulls, so we can't test clearing directly with copyWith
      // unless we pass a different value.
      final updated = q.copyWith(search: 'new');

      expect(updated.search, 'new');
      // Clearing logic usually requires explicit null assignment in a new instance or specific method
      // copyWith in this implementation typically skips nulls.
    });

    test('equality and hashCode', () {
      final q1 = ListQueryParams<_TestEntity>.fromTrusted(search: 'a');
      final q2 = ListQueryParams<_TestEntity>.fromTrusted(search: 'a');
      final q3 = ListQueryParams<_TestEntity>.fromTrusted(search: 'b');

      expect(q1, equals(q2));
      expect(q1.hashCode, equals(q2.hashCode));
      expect(q1, isNot(equals(q3)));
    });

    test('toJson serializes correctly', () {
      const nameField = _TestEntityFields.name;
      final q = ListQueryParams<_TestEntity>.fromTrusted(
        search: 'test',
        filter: nameField.equals('active'),
        sort: nameField.desc(),
        limit: 20,
        offset: 5,
        params: {'custom': 'value'},
      );

      final map = listQueryParamsToWire(q);
      expect(map['search'], 'test');
      expect(map['sort'], isA<Map>());
      // v3 wire contract: a sort names its field by JSON Pointer
      // (ZorphySort.toWire), which ZorphySort.fromWire resolves through
      // `<E>Fields.all.byPointer`. (v2 emitted the bare field name.)
      expect((map['sort'] as Map)['field'], '/name');
      expect((map['sort'] as Map)['descending'], true);
      expect(map['limit'], 20);
      expect(map['offset'], 5);
      expect(map['filter'], isA<Map>());
      expect((map['params'] as Map)['custom'], 'value');
    });

    test('default constructor works without type parameter', () {
      final q = ListQueryParams.fromTrusted();
      expect(q.search, isNull);
      expect(q.filter, isNull);
      expect(q.sort, isNull);
    });
  });

  group('CreateParams', () {
    test('should store data and optional params', () {
      const entity = _TestEntity(name: 'Test');
      const params = {'key': 'value'};
      final createParams = CreateParams<_TestEntity>.fromTrusted(
        data: entity,
        params: params,
      );

      expect(createParams.data, entity);
      expect(createParams.params, params);
    });

    test('toJson serializes correctly', () {
      const entity = _TestEntity(name: 'Test');
      final createParams = CreateParams<_TestEntity>.fromTrusted(
        data: entity,
        params: {'source': 'api'},
      );

      // The generated codec routes `T` through the encoder, which yields the
      // entity's wire MAP (the v3 contract: a type parameter is a wire object).
      final map = createParamsToWire(
        createParams,
        toElement: (e) => {'name': e.name},
      );
      expect(map['data'], {'name': 'Test'});
      expect((map['params'] as Map)['source'], 'api');
    });

    test('copyWith should work correctly', () {
      const entity1 = _TestEntity(name: 'Test1');
      const entity2 = _TestEntity(name: 'Test2');
      final c = CreateParams<_TestEntity>.fromTrusted(data: entity1);

      final updated = c.copyWith(data: entity2);

      expect(updated.data, entity2);
    });

    test('equality should work correctly', () {
      const entity = _TestEntity(name: 'Test');
      final c1 = CreateParams<_TestEntity>.fromTrusted(data: entity);
      final c2 = CreateParams<_TestEntity>.fromTrusted(data: entity);
      final c3 = CreateParams<_TestEntity>.fromTrusted(
        data: _TestEntity(name: 'Other'),
      );

      expect(c1, equals(c2));
      expect(c1, isNot(equals(c3)));
    });
  });

  group('UpdateParams', () {
    test('should store id, data, and optional params', () {
      const patch = {'name': 'Updated'};
      const params = {'key': 'value'};
      final updateParams =
          UpdateParams<String, Map<String, dynamic>>.fromTrusted(
            id: '123',
            data: patch,
            params: params,
          );

      expect(updateParams.id, '123');
      expect(updateParams.data, patch);
      expect(updateParams.params, params);
    });

    test('toJson serializes correctly', () {
      final updateParams =
          UpdateParams<String, Map<String, dynamic>>.fromTrusted(
            id: '123',
            data: {'name': 'Updated'},
          );

      final map = updateParamsToWire(
        updateParams,
        toI: (id) => id,
        toP: (data) => data,
      );
      expect(map['id'], '123');
      expect(map['data'], isA<Map>());
    });

    test('copyWith should work correctly', () {
      final u = UpdateParams<String, Map<String, dynamic>>.fromTrusted(
        id: '123',
        data: {'name': 'Old'},
      );

      final updated = u.copyWith(data: {'name': 'New'});

      expect(updated.data['name'], 'New');
      expect(updated.id, '123');
    });

    test('equality should work correctly', () {
      final u1 = UpdateParams<String, Map<String, dynamic>>.fromTrusted(
        id: '123',
        data: {'name': 'Test'},
      );
      final u2 = UpdateParams<String, Map<String, dynamic>>.fromTrusted(
        id: '123',
        data: {'name': 'Test'},
      );
      final u3 = UpdateParams<String, Map<String, dynamic>>.fromTrusted(
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
      final deleteParams = DeleteParams<String>.fromTrusted(
        id: '123',
        params: params,
      );

      expect(deleteParams.id, '123');
      expect(deleteParams.params, params);
    });

    test('toJson serializes correctly', () {
      final deleteParams = DeleteParams<String>.fromTrusted(
        id: '123',
        params: {'soft': true},
      );

      final map = deleteParamsToWire(deleteParams, toI: (id) => id);
      expect(map['id'], '123');
      expect((map['params'] as Map)['soft'], true);
    });

    test('copyWith should work correctly', () {
      final d = DeleteParams<String>.fromTrusted(id: '123');

      final updated = d.copyWith(id: '456');

      expect(updated.id, '456');
    });

    test('equality should work correctly', () {
      final d1 = DeleteParams<String>.fromTrusted(id: '123');
      final d2 = DeleteParams<String>.fromTrusted(id: '123');
      final d3 = DeleteParams<String>.fromTrusted(id: '456');

      expect(d1, equals(d2));
      expect(d1, isNot(equals(d3)));
    });
  });
}

class _TestEntity {
  final String name;
  final String tag;

  const _TestEntity({required this.name, this.tag = ''});

  _TestEntity copyWith({String? name, String? tag}) =>
      _TestEntity(name: name ?? this.name, tag: tag ?? this.tag);
}

class _JsonEntity {
  final String id;
  final String name;

  const _JsonEntity({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

/// Mirrors a Zorphy entity: `toJsonLean()` is an instance method, `toJson()`
/// is a generated extension (so unreachable through `dynamic`).
class _LeanEntity {
  final String id;

  const _LeanEntity({required this.id});

  Map<String, dynamic> toJsonLean() => {'id': id};
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
  static final List<ZorphyField<_TestEntity, Object?>> all = [name.asObject];

  static String _getName(_TestEntity entity) => entity.name;
  static _TestEntity _setName(_TestEntity entity, String value) =>
      entity.copyWith(name: value);
}
