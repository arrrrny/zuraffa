// IMPLEMENTED (073 phase 2, issue #961): AC-6 — the loop completes its
// cycle over the sandbox's own behaviors with no reference to the
// host: the verifier drives the three checks over the sandbox tree
// alone and the full verdict passes.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/generators/sandbox_composition.dart';
import 'package:zuraffa/src/plugins/slice/verifier/slice_verifier.dart';

import 'sandbox_fixture.dart';

void subject_a6() {
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

  // The verifier consumes only the sandbox tree + declared facts: reds
  // certified and greens landed are modeled by the injected suite
  // outcome; no host cooperation is available or needed.
  final verifier = SliceVerifier(
    suiteRunner: (dir) {
      expect(
        dir,
        equals(sandboxPath),
        reason: 'the suite must run against the sandbox, not the host',
      );
      return const SuiteOutcome(passed: true);
    },
  );
  final verdict = verifier.verify(
    sandboxDir: sandboxPath,
    manifest: manifest,
    hostRoot: host.path,
  );
  expect(verdict.passed, isTrue, reason: verdict.encode());
}
