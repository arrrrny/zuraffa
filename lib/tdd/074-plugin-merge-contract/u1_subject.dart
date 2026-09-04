// IMPLEMENTED (074 phase 2, issue #962): FR-001 — merge regenerates
// the host's route barrel (never hand-edited): the regeneration is the
// seam, and a re-merge regenerates an identical barrel (byte no-op).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/verifier/route_barrel.dart';

import 'merge_fixture.dart';

void subject_u1() {
  final once = RouteBarrel.regenerate(
    barrelSource: hostBarrel,
    module: 'login',
    incoming: featureRoutes,
  );
  expect(once.passed, isTrue);

  // Re-merge: identical inputs regenerate a byte-identical barrel.
  final twice = RouteBarrel.regenerate(
    barrelSource: once.barrel,
    module: 'login',
    incoming: featureRoutes,
  );
  expect(twice.passed, isTrue);
  expect(
    twice.barrel,
    equals(once.barrel),
    reason: 'regeneration is deterministic: re-merge is a byte no-op',
  );

  // Existing host entries are preserved verbatim — no hand-editing of
  // host routing ever happens.
  for (final line in hostBarrel.trim().split('\n')) {
    expect(once.barrel, contains(line.trim()));
  }
}
