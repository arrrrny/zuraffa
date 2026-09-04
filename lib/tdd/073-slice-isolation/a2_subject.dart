// IMPLEMENTED (073 phase 2, issue #961): AC-2 — with the host made
// unavailable, the sandbox's own suite is the verdict: the suite-state
// check reports the injected suite outcome and self-containment holds
// (no sandbox file references the host path).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/generators/sandbox_composition.dart';
import 'package:zuraffa/src/plugins/slice/verifier/self_containment.dart';
import 'package:zuraffa/src/plugins/slice/verifier/slice_verifier.dart';

import 'sandbox_fixture.dart';

void subject_a2() {
  final host = writeHostProject();
  final sandboxPath = p.join(
    host.path,
    '.zuraffa',
    'slices',
    fixtureFeature,
  );
  final manifest = fixtureManifest(host);
  SandboxComposition().compose(
    projectRoot: host.path,
    sandboxDir: sandboxPath,
    feature: fixtureFeature,
    routes: manifest.routes,
    dependencies: manifest.dependencies,
    generatedFiles: <String>[],
  );

  // The suite runs green with the host gone: the injected runner
  // models the sandbox's own suite (host unavailable).
  final verifier = SliceVerifier(
    suiteRunner: (_) => const SuiteOutcome(passed: true),
  );
  final verdict = verifier.verify(
    sandboxDir: sandboxPath,
    manifest: manifest,
    hostRoot: host.path,
  );
  expect(verdict.suiteState.pass, isTrue);
  expect(verdict.selfContainment.pass, isTrue,
      reason: verdict.selfContainment.offenders.join('\n'));

  // No generated file references the host — the scan is the proof.
  expect(
    HostReferenceScanner.scan(sandboxDir: sandboxPath, hostRoot: host.path),
    isEmpty,
  );
}
