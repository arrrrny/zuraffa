// U1: RouteTable DTO has union-of-routes semantics and stable JSON encoding.
//
// Pure-Dart, no I/O. Mirrors `test/plugins/benchmark/`'s unit-test style
// (scenario tests live under `test/plugins/route/scenarios/`).

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/route/route_table.dart';

void main() {
  group('RouteTable', () {
    test('U1.1: empty table encodes to {"routes": []} with version 1', () {
      final table = const RouteTable(version: 1, routes: []);
      final json = jsonDecode(table.toJsonString()) as Map<String, Object?>;
      expect(json['version'], equals(1));
      expect(json['routes'], isA<List>());
      expect((json['routes']! as List), isEmpty);
    });

    test('U1.2: fromSources of CLI and DDA entries preserves every input', () {
      const cli = [
        RouteEntry(
          path: '/products',
          name: 'productList',
          source: RouteSource.cli,
          file: 'lib/src/routes/product_routes.dart',
          line: 12,
        ),
      ];
      const dda = [
        RouteEntry(
          path: '/products',
          name: 'ProductView',
          source: RouteSource.dda,
          file: 'lib/src/views/product_view.dart',
          line: 4,
        ),
      ];
      final table = RouteTable.fromSources(cli: cli, dda: dda);
      expect(table.routes, hasLength(2));
      expect(
        table.routes.map((r) => r.source).toSet(),
        equals({RouteSource.cli, RouteSource.dda}),
      );
    });

    test('U1.3: JSON encoding uses the canonical total ordering', () {
      const entries = [
        RouteEntry(
          path: '/b',
          name: 'B',
          source: RouteSource.dda,
          file: 'b.dart',
          line: 1,
        ),
        RouteEntry(
          path: '/a',
          name: 'Z',
          source: RouteSource.cli,
          file: 'z.dart',
          line: 2,
        ),
        RouteEntry(
          path: '/a',
          name: 'B',
          source: RouteSource.cli,
          file: 'a.dart',
          line: 2,
        ),
        RouteEntry(
          path: '/a',
          name: 'A',
          source: RouteSource.cli,
          file: 'a.dart',
          line: 2,
        ),
        RouteEntry(
          path: '/a',
          name: 'Earlier',
          source: RouteSource.cli,
          file: 'a.dart',
          line: 1,
        ),
        RouteEntry(
          path: '/a',
          name: 'A-dda',
          source: RouteSource.dda,
          file: 'a_view.dart',
          line: 1,
        ),
      ];
      final a = const RouteTable(version: 1, routes: entries).toJsonString();
      final b = const RouteTable(version: 1, routes: entries).toJsonString();
      expect(a, equals(b), reason: 'encoding must be deterministic');

      final decoded = jsonDecode(a) as Map<String, Object?>;
      final routes = (decoded['routes']! as List).cast<Map>();
      expect(routes[0]['name'], equals('Earlier'));
      expect(routes[0]['source'], equals('cli'));
      expect(routes[1]['name'], equals('A'));
      expect(routes[2]['name'], equals('B'));
      expect(routes[3]['name'], equals('Z'));
      expect(routes[4]['source'], equals('dda'));
      expect(routes[5]['path'], equals('/b'));
    });
  });
}
