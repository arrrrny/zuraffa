// IMPLEMENTED (074 phase 2, issue #962): FR-008 — merge is idempotent:
// re-merging a merged feature changes nothing (byte no-op barrel) and
// re-runs the gates (the gates consume regenerated facts, still green).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/verifier/conformance_gate.dart';
import 'package:zuraffa/src/plugins/slice/verifier/route_barrel.dart';

import 'merge_fixture.dart';

void subject_u8() {
  // First merge: regenerate + gate.
  final first = RouteBarrel.regenerate(
    barrelSource: hostBarrel,
    module: 'login',
    incoming: featureRoutes,
  );
  final firstGate = ConformanceGate.routes(
    barrel: first.barrel,
    declared: featureRoutes,
  );
  expect(firstGate.pass, isTrue);

  // Re-merge: the regeneration is a byte no-op, gates re-run green.
  final second = RouteBarrel.regenerate(
    barrelSource: first.barrel,
    module: 'login',
    incoming: featureRoutes,
  );
  expect(second.barrel, equals(first.barrel),
      reason: 're-merge changes nothing');
  final secondGate = ConformanceGate.routes(
    barrel: second.barrel,
    declared: featureRoutes,
  );
  expect(secondGate.pass, isTrue);
  expect(secondGate.evidence, equals(firstGate.evidence));
}
