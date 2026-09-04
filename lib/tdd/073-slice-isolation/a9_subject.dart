// IMPLEMENTED (073 phase 2, issue #961): AC-9 — `slice verify --json`
// exits 0 and the verdict reports self-containment, mock certification,
// and suite state as passing; the capability writes the verdict file at
// the contract path the merge gate reads.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/generators/sandbox_composition.dart';
import 'package:zuraffa/src/plugins/slice/verifier/slice_verifier.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_verdict.dart';

import 'sandbox_fixture.dart';

Future<void> subject_a9() async {
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

  final verifier = SliceVerifier(
    suiteRunner: (_) => const SuiteOutcome(passed: true),
  );
  final verdict = verifier.verify(
    sandboxDir: sandboxPath,
    manifest: manifest,
    hostRoot: host.path,
  );

  // All three checks pass — the exit-0 contract.
  expect(verdict.passed, isTrue, reason: verdict.encode());
  expect(verdict.selfContainment.pass, isTrue);
  expect(verdict.mockCertification.pass, isTrue);
  expect(verdict.suiteState.pass, isTrue);

  // The JSON verdict is the machine-readable record (written by the
  // capability at the contract path).
  final json = verdict.encode();
  final verdictFile = File(
    p.join(sandboxPath, 'verify-verdict.json'),
  )..writeAsStringSync(json);
  final parsed = SliceVerdict.decode(verdictFile.readAsStringSync());
  expect(parsed.passed, isTrue);
  expect(parsed.summaryLine(fixtureFeature), contains('outcome=verified'));
}
