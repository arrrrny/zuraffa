import 'package:zuraffa/zuraffa.dart';
import 'package:test/test.dart';

class UrlEndpoint {
  final String id;
  final String name;

  UrlEndpoint({required this.id, required this.name});

  @override
  String toString() => 'UrlEndpoint(id: $id, name: $name)';
}

class UrlTemplate {
  final String id;
  final List<UrlEndpoint> endpoints;

  UrlTemplate({required this.id, required this.endpoints});

  @override
  String toString() => 'UrlTemplate(id: $id, endpoints: $endpoints)';
}

// Hand-built v3 field descriptors: the shape the zorphy generator emits on
// `<Entity>Fields` (name, wire key, JSON pointer, get/set pair).
class UrlEndpointFields {
  static final id = ZorphyField<UrlEndpoint, String>(
    name: 'id',
    jsonKey: 'id',
    pointer: '/id',
    get: (e) => e.id,
    set: (e, value) => UrlEndpoint(id: value, name: e.name),
  );
  static final name = ZorphyField<UrlEndpoint, String>(
    name: 'name',
    jsonKey: 'name',
    pointer: '/name',
    get: (e) => e.name,
    set: (e, value) => UrlEndpoint(id: e.id, name: value),
  );
}

class UrlTemplateFields {
  static final endpoints = ZorphyField<UrlTemplate, List<UrlEndpoint>>(
    name: 'endpoints',
    jsonKey: 'endpoints',
    pointer: '/endpoints',
    get: (e) => e.endpoints,
    set: (e, value) => UrlTemplate(id: e.id, endpoints: value),
  );
}

void main() {
  group('Nested Filter Verification', () {
    final searchEndpoint = UrlEndpoint(id: '1', name: 'search');
    final otherEndpoint = UrlEndpoint(id: '2', name: 'other');

    final templateWithSearch = UrlTemplate(
      id: 't1',
      endpoints: [searchEndpoint, otherEndpoint],
    );
    final templateWithoutSearch = UrlTemplate(
      id: 't2',
      endpoints: [otherEndpoint],
    );

    final templates = [templateWithSearch, templateWithoutSearch];

    test('Filter using ZorphyField.nested directly', () {
      final endpointFilter = UrlEndpointFields.name.equals('search');
      final templateFilter = UrlTemplateFields.endpoints.nested(endpointFilter);

      final results = templates
          .where((t) => templateFilter.matches(t))
          .toList();

      expect(results, contains(templateWithSearch));
      expect(results, isNot(contains(templateWithoutSearch)));
      expect(results.length, 1);
    });

    test('Filter using query() - User syntax', () {
      final query = UrlEndpointFields.name.equals('search').toQuery();
      final templateFilter = UrlTemplateFields.endpoints.query(query);

      final results = templates
          .where((t) => templateFilter.matches(t))
          .toList();

      expect(results, contains(templateWithSearch));
      expect(results.length, 1);
    });

    test('Filter using list() - User syntax', () {
      final query = UrlEndpointFields.name
          .equals('search')
          .toListQuery(limit: 10);
      final templateFilter = UrlTemplateFields.endpoints.list(query);

      final results = templates
          .where((t) => templateFilter.matches(t))
          .toList();

      expect(results, contains(templateWithSearch));
      expect(results.length, 1);
    });

    test('Serialization to v3 wire', () {
      final query = UrlEndpointFields.name.equals('search').toQuery();
      final templateFilter = UrlTemplateFields.endpoints.query(query);

      expect(templateFilter.toWire(), {
        'field': '/endpoints',
        'op': 'nested',
        'filter': {'field': '/name', 'op': 'eq', 'value': 'search'},
      });
    });
  });
}
