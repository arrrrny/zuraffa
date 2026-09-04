// IMPLEMENTED (073 phase 2, issue #961): the machine-readable verdict —
// `slice verify` composes the three named checks into a JSON document
// with a stable shape (contract verify-verdict.md), reports pass only
// when all three pass, and names the failing check with its offenders
// on failure (FR-004).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/capabilities/verify_slice_capability.dart';
import 'package:zuraffa/src/plugins/slice/generators/sandbox_composition.dart';
import 'package:zuraffa/src/plugins/slice/verifier/slice_verifier.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_verdict.dart';

import 'sandbox_fixture.dart';

Object? subject_u4() {
  final host = writeHostProject();
  final sandboxPath = p.join(
    host.path,
    '.zuraffa',
    'slices',
    fixtureFeature,
  );
  Directory(sandboxPath).createSync(recursive: true);
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

  // The verdict serializes to the contract shape: three named checks
  // plus the outcome, machine-parseable back into the same verdict.
  final json = verdict.encode();
  expect(json, contains('"check": "slice-verify"'));
  expect(json, contains('"selfContainment"'));
  expect(json, contains('"mockCertification"'));
  expect(json, contains('"suiteState"'));
  expect(json, contains('"passed": true'));
  final parsed = SliceVerdict.decode(json);
  expect(parsed.passed, isTrue);
  expect(parsed.selfContainment.pass, isTrue);
  expect(parsed.mockCertification.pass, isTrue);
  expect(parsed.suiteState.pass, isTrue);

  // The verdict file lives at the contract path the merge gate reads.
  expect(
    VerifySliceCapability.verdictPathFor(sandboxPath),
    endsWith('verify-verdict.json'),
  );

  // The summary line names every check and the outcome.
  expect(
    verdict.summaryLine(fixtureFeature),
    contains('self-containment=pass mock-certification=pass suite=pass'),
  );
  expect(verdict.summaryLine(fixtureFeature), contains('outcome=verified'));

  // A failing check encodes its offenders — never a bare boolean.
  // Verified by JSON roundtrip (the encode output is pretty-printed
  // JSON; exact formatting is not part of the contract — the decoded
  // values are).
  final failing = SliceVerdict(
    selfContainment: const SliceCheck(name: 'selfContainment', pass: false, offenders: ['lib/x.dart:3: "/host"']),
    mockCertification: const SliceCheck(name: 'mockCertification', pass: true),
    suiteState: const SliceCheck(name: 'suiteState', pass: true),
  );
  final decodedFailing = SliceVerdict.decode(failing.encode());
  expect(decodedFailing.passed, isFalse);
  expect(
    decodedFailing.selfContainment.offenders,
    contains('lib/x.dart:3: "/host"'),
    reason: 'offender text must roundtrip exactly (issue #961 verdict)',
  );
  expect(File(VerifySliceCapability.verdictPathFor(sandboxPath)).existsSync(), isFalse,
      reason: 'only the verify capability writes the verdict file');
  return null;
}
