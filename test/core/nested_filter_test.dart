import 'package:zuraffa/zuraffa.dart';
import 'package:flutter_test/flutter_test.dart';

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

// Mock Zorphy generated fields
class UrlEndpointFields {
  static final id = Field<UrlEndpoint, String>('id', (e) => e.id);
  static final name = Field<UrlEndpoint, String>('name', (e) => e.name);
}

class UrlTemplateFields {
  static final id = Field<UrlTemplate, String>('id', (e) => e.id);
  static final endpoints = Field<UrlTemplate, List<UrlEndpoint>>(
    'endpoints',
    (e) => e.endpoints,
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

    test('Filter using Filter directly', () {
      final endpointFilter = UrlEndpointFields.name.eq('search');
      final templateFilter = UrlTemplateFields.endpoints.filter(endpointFilter);

      final results = templates
          .where((t) => templateFilter.matches(t))
          .toList();

      expect(results, contains(templateWithSearch));
      expect(results, isNot(contains(templateWithoutSearch)));
      expect(results.length, 1);
    });

    test('Filter using query() - User syntax', () {
      final query = UrlEndpointFields.name.eq('search').toQuery();
      final templateFilter = UrlTemplateFields.endpoints.query(query);

      final results = templates
          .where((t) => templateFilter.matches(t))
          .toList();

      expect(results, contains(templateWithSearch));
      expect(results.length, 1);
    });

    test('Filter using list() - User syntax', () {
      final query = UrlEndpointFields.name.eq('search').toListQuery(limit: 10);
      final templateFilter = UrlTemplateFields.endpoints.list(query);

      final results = templates
          .where((t) => templateFilter.matches(t))
          .toList();

      expect(results, contains(templateWithSearch));
      expect(results.length, 1);
    });

    test('Serialization to JSON', () {
      final query = UrlEndpointFields.name.eq('search').toQuery();
      final templateFilter = UrlTemplateFields.endpoints.query(query);

      final json = templateFilter.toJson();
      expect(json, {
        'endpoints': {'name': 'search'},
      });
    });
  });
}
