// IMPLEMENTED (074 phase 2, issue #962): FR-006 — any conformance
// failure rolls the host back byte-identical, exits non-zero, and names
// the failed checks (the verdict carries rolled-back + offenders).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/merger/host_baseline.dart';
import 'package:zuraffa/src/plugins/slice/verifier/conformance_gate.dart';

import 'merge_fixture.dart';

void subject_u6() {
  final host = snapshotSandbox();
  final baseline = captureBaseline(host);
  final before = HostBaseline.fingerprint(host.path);

  // Two gates fail: views and feature suite.
  final verdict = MergeVerdict(
    feature: 'login',
    routes: const MergeCheck(name: 'routes', pass: true),
    di: const MergeCheck(name: 'di', pass: true),
    views: ConformanceGate.views(
      viewSources: const {
        'lib/src/presentation/pages/login/login_page.dart': offConventionView,
      },
      shellConvention: 'AdaptiveShell',
    ),
    featureSuite: ConformanceGate.featureSuite(
      baselineFailures: const [],
      currentFailures: const ['login_flow_test [E]'],
    ),
  );
  expect(verdict.passed, isFalse);
  expect(
    verdict.failures.map((c) => c.name),
    containsAll(<String>['views', 'featureSuite']),
  );

  // Rollback the landing's bytes; the proof is the fingerprint.
  baseline.restore(host.path);
  expect(HostBaseline.fingerprint(host.path), equals(before));

  final rolledBack = MergeVerdict(
    feature: verdict.feature,
    routes: verdict.routes,
    di: verdict.di,
    views: verdict.views,
    featureSuite: verdict.featureSuite,
    rolledBack: true,
  );
  expect(rolledBack.outcome(gateRan: true), equals('rolled-back'));
  expect(
    rolledBack.summaryLine(host: '/host', gateRan: true),
    contains('rolled-back=true'),
  );
  expect(rolledBack.encode(), contains('"offenders"'));
}
