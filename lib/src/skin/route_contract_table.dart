/// RouteContractTable — the route half of the runtime skin contract
/// (issue #1102).
///
/// The pilot's `SkinRouteContractObserver` validated every push
/// against a contract route table; the productized table is pure
/// data so the emitted observer, `zfa skin kit`, and `zfa skin
/// verify` all reconcile against the SAME source of truth.
///
/// Pilot lesson 3 is load-bearing: WidgetsApp ALWAYS pushes `/` on
/// cold start — without treating the navigator root as conforming by
/// construction, every app flags a phantom violation at launch. Null
/// and empty route names (shell bookkeeping pushes unnamed helper
/// routes) conform for the same reason: they are framework traffic,
/// not contract drift.
library;

import 'skin_violation.dart';

class RouteContractTable {
  /// Creates a table allowing exactly [allowedRoutes] (plus the
  /// navigator root, always — see [navigatorRootRoute]).
  const RouteContractTable({required Set<String> allowedRoutes})
    : _allowedRoutes = allowedRoutes;

  /// Creates a table from route names (deduplicated).
  factory RouteContractTable.fromRouteNames(Iterable<String> names) =>
      RouteContractTable(allowedRoutes: Set<String>.of(names));

  /// The navigator root route — conforms BY CONSTRUCTION (pilot
  /// lesson 3: WidgetsApp pushes it on every cold start).
  static const String navigatorRootRoute = '/';

  final Set<String> _allowedRoutes;

  /// The route names this contract declares (read-only view).
  Set<String> get allowedRoutes => Set.unmodifiable(_allowedRoutes);

  /// Whether [routeName] is declared (or conforming by construction).
  bool allows(String? routeName) {
    if (routeName == null || routeName.isEmpty) return true;
    if (routeName == navigatorRootRoute) return true;
    return _allowedRoutes.contains(routeName);
  }

  /// Validates one push. Returns the violation when the pushed route
  /// does not conform, null when it does.
  SkinViolation? validatePush(String? routeName) {
    if (allows(routeName)) return null;
    final name = routeName!;
    final sorted = _allowedRoutes.toList()..sort();
    return SkinViolation.route(
      rowId: 'route:$name',
      requirement: 'route $name is declared by the route contract',
      message:
          'push of undeclared route; allowed routes: '
          '${sorted.isEmpty ? '(none declared)' : sorted.join(', ')}',
      route: name,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteContractTable && _setEquals(other._allowedRoutes);

  @override
  int get hashCode => Object.hashAllUnordered(_allowedRoutes);

  bool _setEquals(Set<String> other) {
    if (_allowedRoutes.length != other.length) return false;
    return _allowedRoutes.every(other.contains);
  }

  @override
  String toString() => 'RouteContractTable(${_allowedRoutes.toList()..sort()})';
}
