// IMPLEMENTED (073 phase 2, issue #961): AC-8 — an operator whose only
// input is the spec drives every step without host knowledge: the
// verifier runs with no host root at all (imports-only
// self-containment) and the declared facts alone drive composition.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/generators/sandbox_composition.dart';
import 'package:zuraffa/src/plugins/slice/verifier/slice_verifier.dart';

import 'sandbox_fixture.dart';

void subject_a8() {
  final host = writeHostProject();
  final sandboxPath = p.join(
    host.path,
    '.zuraffa',
    'slices',
    fixtureFeature,
  );
  final manifest = fixtureManifest(host);
  Directory(sandboxPath).createSync(recursive: true);
  // The sandbox carries its own pubspec (the cut's filtered output):
  // verify reads it to resolve package imports without host knowledge.
  File(p.join(sandboxPath, 'pubspec.yaml')).writeAsStringSync(
    'name: host_app\n'
    'environment:\n  sdk: ^3.11.0\n'
    'dependencies:\n  flutter:\n    sdk: flutter\n',
  );
  SandboxComposition().compose(
    projectRoot: host.path,
    sandboxDir: sandboxPath,
    feature: fixtureFeature,
    routes: manifest.routes,
    dependencies: manifest.dependencies,
    generatedFiles: <String>[],
  );

  // Every step succeeds with no host knowledge: verify runs with
  // hostRoot ABSENT — the sandbox is judged on itself alone.
  final verifier = SliceVerifier(
    suiteRunner: (_) => const SuiteOutcome(passed: true),
  );
  final verdict = verifier.verify(
    sandboxDir: sandboxPath,
    manifest: manifest,
  );
  expect(verdict.selfContainment.pass, isTrue,
      reason: verdict.selfContainment.offenders.join('\n'));
  expect(verdict.mockCertification.pass, isTrue,
      reason: verdict.mockCertification.offenders.join('\n'));
  expect(verdict.suiteState.pass, isTrue);
  expect(verdict.passed, isTrue, reason: verdict.encode());
}
