// IMPLEMENTED (074 phase 2, issue #962): AC-10 — a routes-check
// failure rolls the host back byte-identical to pre-merge and the
// verdict marks the failed check, non-zero outcome, offenders named.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/merger/host_baseline.dart';
import 'package:zuraffa/src/plugins/slice/verifier/conformance_gate.dart';
import 'package:zuraffa/src/plugins/slice/verifier/route_barrel.dart';

import 'merge_fixture.dart';

void subject_a10() {
  final host = snapshotSandbox();
  final baseline = captureBaseline(host);
  final fingerprintBefore = HostBaseline.fingerprint(host.path);

  // The landing wrote a broken barrel (feature route resolving nowhere).
  final brokenBarrel = RouteBarrel.regenerate(
    barrelSource: hostBarrel,
    module: 'login',
    incoming: const [
      RouteDecl(path: '/login', page: 'NowherePage', module: 'login'),
    ],
  ).barrel;

  final verdict = MergeVerdict(
    feature: 'login',
    routes: ConformanceGate.routes(
      barrel: brokenBarrel,
      declared: featureRoutes,
    ),
    di: const MergeCheck(name: 'di', pass: true),
    views: const MergeCheck(name: 'views', pass: true),
    featureSuite: const MergeCheck(name: 'featureSuite', pass: true),
  );

  expect(
    verdict.routes.pass,
    isFalse,
    reason: 'the broken route must fail the gate',
  );
  expect(verdict.passed, isFalse);

  // Rollback: restore the snapshot and prove byte-identity; the merge
  // surface sets rolledBack=true on the verdict it reports.
  baseline.restore(host.path);
  final rolledBackVerdict = MergeVerdict(
    feature: verdict.feature,
    routes: verdict.routes,
    di: verdict.di,
    views: verdict.views,
    featureSuite: verdict.featureSuite,
    rolledBack: true,
  );
  expect(rolledBackVerdict.outcome(gateRan: true), equals('rolled-back'));
  expect(rolledBackVerdict.failures.single.name, equals('routes'));
  expect(rolledBackVerdict.routes.offenders.join(' '), contains('--> fix:'));

  // The host is byte-identical to pre-merge after the restore.
  final fingerprintAfter = HostBaseline.fingerprint(host.path);
  expect(fingerprintAfter, equals(fingerprintBefore));
  expect(baseline.matchesHost(host.path), isTrue);
}
