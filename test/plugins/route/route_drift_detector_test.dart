// U2: DriftDetector returns one finding per overlapping path, naming both
// source files.

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/route/route_table.dart';
import 'package:zuraffa/src/plugins/route/route_drift_detector.dart';

void main() {
  group('RouteDriftDetector', () {
    test('U2.1: empty table yields no findings', () {
      final detector = const RouteDriftDetector();
      expect(
        detector.detect(const RouteTable(version: 1, routes: [])),
        isEmpty,
      );
    });

    test('U2.2: only CLI entries yields no drift (no overlap)', () {
      const table = RouteTable(version: 1, routes: [
        RouteEntry(
          path: '/products',
          name: 'productList',
          source: RouteSource.cli,
          file: 'product_routes.dart',
          line: 10,
        ),
      ]);
      final detector = const RouteDriftDetector();
      expect(detector.detect(table), isEmpty);
    });

    test('U2.3: overlapping path yields one finding naming both files', () {
      const table = RouteTable(version: 1, routes: [
        RouteEntry(
          path: '/products',
          name: 'productList',
          source: RouteSource.cli,
          file: 'product_routes.dart',
          line: 10,
        ),
        RouteEntry(
          path: '/products',
          name: 'ProductView',
          source: RouteSource.dda,
          file: 'product_view.dart',
          line: 4,
        ),
      ]);
      final detector = const RouteDriftDetector();
      final findings = detector.detect(table);
      expect(findings, hasLength(1));
      expect(findings.first.path, equals('/products'));
      expect(
        findings.first.sources.map((s) => s.file).toSet(),
        equals({'product_routes.dart', 'product_view.dart'}),
      );
    });

    test('U2.4: distinct paths produce zero findings', () {
      const table = RouteTable(version: 1, routes: [
        RouteEntry(
          path: '/products',
          name: 'products',
          source: RouteSource.cli,
          file: 'a.dart',
          line: 1,
        ),
        RouteEntry(
          path: '/orders',
          name: 'orders',
          source: RouteSource.dda,
          file: 'b.dart',
          line: 1,
        ),
      ]);
      expect(const RouteDriftDetector().detect(table), isEmpty);
    });
  });
}
