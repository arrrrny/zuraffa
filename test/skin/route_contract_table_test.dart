// Issue #1102 — RouteContractTable: the route half of the runtime skin
// contract, validated on every push (lesson 3: '/' conforms by
// construction).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/skin/route_contract_table.dart';

void main() {
  group('issue #1102 — RouteContractTable', () {
    test('the navigator root / conforms by construction (lesson 3)', () {
      // WidgetsApp ALWAYS pushes / on cold start. Without this, every
      // app flags a phantom violation at launch — the pilot's finding.
      final table = RouteContractTable.fromRouteNames(const {'deal_list'});
      expect(table.validatePush('/'), isNull);
    });

    test('null and empty route names conform by construction', () {
      final table = RouteContractTable.fromRouteNames(const {'deal_list'});
      // Shell bookkeeping pushes unnamed helper routes; a null
      // settings.name is not a contract breach.
      expect(table.validatePush(null), isNull);
      expect(table.validatePush(''), isNull);
    });

    test('an allowed route push conforms', () {
      final table = RouteContractTable.fromRouteNames({'deal_list', 'login'});
      expect(table.validatePush('deal_list'), isNull);
      expect(table.validatePush('login'), isNull);
    });

    test('an undeclared push is a route violation', () {
      final table = RouteContractTable.fromRouteNames(const {'deal_list'});
      final violation = table.validatePush('debug-thing');
      expect(violation, isNotNull);
      expect(violation!.kind.label, 'route');
      expect(violation.rowId, 'route:debug-thing');
      expect(violation.route, 'debug-thing');
      expect(violation.requirement, contains('debug-thing'));
      expect(violation.message, contains('deal_list'));
    });

    test('the violation message names the allowed routes (actionable)', () {
      final table = RouteContractTable.fromRouteNames({'login', 'deal_list'});
      final violation = table.validatePush('chaos');
      expect(violation!.message, contains('login'));
      expect(violation.message, contains('deal_list'));
    });

    test('an empty table still lets the root through but flags others', () {
      final table = RouteContractTable.fromRouteNames(const {});
      expect(table.validatePush('/'), isNull);
      expect(table.validatePush('anything'), isNotNull);
    });

    test('root route is a documented constant', () {
      expect(RouteContractTable.navigatorRootRoute, '/');
    });

    test('fromRouteNames deduplicates and exposes the allowed set', () {
      final table = RouteContractTable.fromRouteNames(const [
        'deal_list',
        'deal_list',
        'login',
      ]);
      expect(table.allowedRoutes, {'deal_list', 'login'});
    });

    test('validatePush with a path-style route name still string-matches', () {
      // Route names may be paths ('/deal') when apps declare them so;
      // the table is name-set based, no path normalization magic.
      final table = RouteContractTable.fromRouteNames(const {'/deal'});
      expect(table.validatePush('/deal'), isNull);
      expect(table.validatePush('deal'), isNotNull);
    });
  });
}
