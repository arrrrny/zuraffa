// IMPLEMENTED (073 phase 2, issue #961): AC-10 — a sandbox carrying a
// host reference fails verification: the verdict marks
// self-containment failed and NAMES the offending reference.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/generators/sandbox_composition.dart';
import 'package:zuraffa/src/plugins/slice/verifier/slice_verifier.dart';

import 'sandbox_fixture.dart';

void subject_a10() {
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

  // A host reference escapes into a sandbox file (an agent pasted the
  // host path into the router while developing).
  final router = File(p.join(sandboxPath, 'lib', 'router.dart'));
  router.writeAsStringSync(
    '${router.readAsStringSync()}\n// cut from ${p.join(host.path, "lib")}\n',
  );

  final verdict = SliceVerifier(
    suiteRunner: (_) => const SuiteOutcome(passed: true),
  ).verify(sandboxDir: sandboxPath, manifest: manifest, hostRoot: host.path);

  expect(verdict.passed, isFalse, reason: 'a leaked host reference fails');
  expect(verdict.selfContainment.pass, isFalse);
  final offenders = verdict.selfContainment.offenders.join('\n');
  expect(
    offenders,
    contains('lib/router.dart'),
    reason: 'the offending reference is named',
  );
  expect(offenders, contains('--> fix:'));
  expect(verdict.mockCertification.pass, isTrue);
  expect(verdict.suiteState.pass, isTrue);
}
