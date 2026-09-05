/// skin-contract runtime binding (issue #1165, stage 2/4 of #1111 —
/// engine half, pure Dart).
///
/// Turns a parsed [SkinContract] into the runtime kit's inputs in one
/// call: the route table the route observer validates pushes against,
/// per-view state bindings (toaster/inline/none + empty), and audit-row
/// descriptors. The Flutter shell (`zuraffa_flutter`) mounts this
/// binding across the package boundary — zero hand-written contract
/// wiring at call sites.
///
/// Engine lane: no UI-framework dependency; the shell maps the pure
/// [StateErrorKind] / empty declarations onto real widgets.
library;

import 'route_contract_table.dart';
import 'contract/skin_contract.dart';

/// How a view's error state surfaces (v1 vocabulary: none | toaster |
/// inline).
enum StateErrorKind { none, toaster, inline }

/// One view's declared state handling, from `contract.states`.
class StateBinding {
  final String view;
  final StateErrorKind error;
  final bool empty;

  const StateBinding({
    required this.view,
    required this.error,
    required this.empty,
  });
}

/// The runtime binding the Flutter shell mounts whole.
class SkinContractRuntimeBinding {
  final String name;
  final RouteContractTable routeTable;

  /// The declared (path → view) pairs in contract order — what the
  /// shell needs to populate its route table.
  final List<ContractRoute> declaredRoutes;
  final Map<String, StateBinding> stateBindings;
  final List<ContractStateRow> auditRows;

  const SkinContractRuntimeBinding({
    required this.name,
    required this.routeTable,
    required this.declaredRoutes,
    required this.stateBindings,
    required this.auditRows,
  });

  /// Builds the binding from a parsed contract in one call.
  factory SkinContractRuntimeBinding.fromContract({
    required String name,
    required SkinContract contract,
  }) {
    return SkinContractRuntimeBinding(
      name: name,
      routeTable: RouteContractTable.fromRouteNames(
        contract.routes.map((r) => r.path),
      ),
      declaredRoutes: List.of(contract.routes),
      stateBindings: {
        for (final state in contract.states)
          state.view: StateBinding(
            view: state.view,
            error: StateErrorKind.values.firstWhere(
              (k) => k.name == state.error,
            ),
            empty: state.empty,
          ),
      },
      auditRows: List.of(contract.stateRows),
    );
  }

  /// The state binding for [view], or a neutral (none, no empty)
  /// binding when the view declares none — an undeclared view is not a
  /// violation, it simply binds nothing.
  StateBinding stateBindingFor(String view) =>
      stateBindings[view] ??
      StateBinding(view: view, error: StateErrorKind.none, empty: false);
}
