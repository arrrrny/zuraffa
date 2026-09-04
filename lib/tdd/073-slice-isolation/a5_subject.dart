// IMPLEMENTED (073 phase 2, issue #961): AC-5 — deterministic
// scaffolding: a second `slice cut` with unchanged inputs produces
// byte-for-byte identical generated wiring (manifests carry timestamps;
// the wiring must not).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'sandbox_fixture.dart';

Future<void> subject_a5() async {
  final hostA = writeHostProject();
  final hostB = writeHostProject();
  final cutA = await cutSandbox(hostA);
  final cutB = await cutSandbox(hostB);
  expect(cutA.success, isTrue, reason: cutA.message);
  expect(cutB.success, isTrue, reason: cutB.message);

  final sandboxA = sandboxDirOf(hostA);
  final sandboxB = sandboxDirOf(hostB);
  var compared = 0;
  for (final wiring in fixtureWiring) {
    final a = File(p.join(sandboxA, wiring));
    final b = File(p.join(sandboxB, wiring));
    expect(a.existsSync(), isTrue, reason: wiring);
    expect(b.existsSync(), isTrue, reason: wiring);
    expect(
      a.readAsStringSync(),
      equals(b.readAsStringSync()),
      reason: 'identical inputs must cut identical wiring: $wiring',
    );
    compared++;
  }
  expect(
    compared,
    greaterThanOrEqualTo(6),
    reason: 'the whole wiring set is compared',
  );
}
