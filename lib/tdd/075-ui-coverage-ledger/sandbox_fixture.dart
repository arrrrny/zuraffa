/// Shared fixture for 075 subjects.
library;

import 'package:zuraffa/src/tdd/services/ui_ledger_builder.dart';
export 'package:zuraffa/src/tdd/services/ui_ledger_builder.dart';
export 'package:zuraffa/src/tdd/services/coverage_gate.dart';
export 'package:zuraffa/src/tdd/services/xray_ledger_binding.dart';

const String fixtureFeature = 'login';

List<DeclaredSurface> fixtureSurfaces() => const [
  DeclaredSurface(
    surface: 'Login button text',
    kind: UiSurfaceKind.text,
    declaredProvers: ['A1'],
  ),
  DeclaredSurface(
    surface: '/login',
    kind: UiSurfaceKind.route,
    declaredProvers: ['A2'],
  ),
  DeclaredSurface(
    surface: 'submit form',
    kind: UiSurfaceKind.affordance,
    declaredProvers: ['A3'],
  ),
];

Set<String> fixtureGreen() => const {'A1', 'A2'};

List<UiSurfaceRow> fixtureLedger() => UiLedgerBuilder.derive(
  declared: fixtureSurfaces(),
  greenBehaviors: fixtureGreen(),
);
