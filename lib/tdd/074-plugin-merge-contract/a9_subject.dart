// IMPLEMENTED (074 phase 2, issue #962): AC-9 — a machine-readable
// verdict reports routes/DI/feature-suite each passing, the outcome is
// `landed`, and the JSON parses back into the same verdict.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/verifier/conformance_gate.dart';
import 'package:zuraffa/src/plugins/slice/verifier/di_graph_check.dart';

import 'merge_fixture.dart';

void subject_a9() {
  final barrel = RouteBarrel.regenerate(
    barrelSource: hostBarrel,
    module: 'login',
    incoming: featureRoutes,
  ).barrel;
  final verdict = MergeVerdict(
    feature: 'login',
    routes: ConformanceGate.routes(barrel: barrel, declared: featureRoutes),
    di: ConformanceGate.di(
      bindings: const [
        DiBindingDecl(token: 'dependencies/auth', flavors: ['mock', 'real']),
      ],
      resolves: (token, flavor) => true,
    ),
    views: ConformanceGate.views(
      viewSources: const {
        'lib/src/presentation/pages/login/login_page.dart': conformingView,
      },
      shellConvention: 'AdaptiveShell',
    ),
    featureSuite: ConformanceGate.featureSuite(
      baselineFailures: const [],
      currentFailures: const [],
    ),
  );

  expect(verdict.passed, isTrue);
  expect(verdict.outcome(gateRan: true), equals('landed'));
  expect(verdict.rolledBack, isFalse);

  // The verdict JSON: machine-readable, parseable back, contract keys.
  final json = verdict.encode();
  expect(json, contains('"check": "slice-merge-conformance"'));
  expect(json, contains('"passed": true'));
  final parsed = MergeVerdict.decode(json);
  expect(parsed.passed, isTrue);
  expect(parsed.routes.pass, isTrue);
  expect(parsed.di.pass, isTrue);
  expect(parsed.featureSuite.pass, isTrue);

  // The summary line names every gate and the outcome.
  final summary = verdict.summaryLine(host: '/host', gateRan: true);
  expect(summary, contains('routes=pass'));
  expect(summary, contains('di=pass'));
  expect(summary, contains('feature-suite=pass'));
  expect(summary, contains('outcome=landed'));
}
