// IMPLEMENTED (073 phase 2, issue #961): AC-11 — an unbound declared
// dependency fails mock certification naming the unbound dependency.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/generators/sandbox_composition.dart';
import 'package:zuraffa/src/plugins/slice/verifier/slice_verifier.dart';

import 'sandbox_fixture.dart';

void subject_a11() {
  final host = writeHostProject();
  final sandboxPath = p.join(host.path, '.zuraffa', 'slices', fixtureFeature);
  final manifest = fixtureManifest(host);
  SandboxComposition().compose(
    projectRoot: host.path,
    sandboxDir: sandboxPath,
    feature: fixtureFeature,
    routes: manifest.routes,
    dependencies: manifest.dependencies,
    generatedFiles: <String>[],
  );

  // The developer's sandbox edit drops the GoRouterHost binding.
  final di = File(p.join(sandboxPath, 'lib', 'di.dart'));
  di.writeAsStringSync(
    di.readAsStringSync().replaceAll(
      RegExp(r"  sandbox\.bind\('dependencies/go_router_host'.*\n"),
      '',
    ),
  );

  final verdict = SliceVerifier(
    suiteRunner: (_) => const SuiteOutcome(passed: true),
  ).verify(sandboxDir: sandboxPath, manifest: manifest, hostRoot: host.path);

  expect(verdict.passed, isFalse);
  expect(verdict.mockCertification.pass, isFalse);
  final offenders = verdict.mockCertification.offenders.join('\n');
  expect(
    offenders,
    contains('GoRouterHost'),
    reason: 'the unbound dependency is named',
  );
  expect(offenders, contains('--> fix:'));
  // The OTHER bindings still certify — the failure is precise.
  expect(offenders, isNot(contains('FirebaseAuth --')));
}
