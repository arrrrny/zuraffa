// IMPLEMENTED (073 phase 2, issue #961): self-containment — the
// verifier's self-containment check passes on a clean sandbox (imports
// resolve, zero host references) and fails naming the offending
// reference when a host path leaks in (FR-002).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/generators/sandbox_composition.dart';
import 'package:zuraffa/src/plugins/slice/verifier/slice_verifier.dart';

import 'sandbox_fixture.dart';

Object? subject_u2() {
  final host = writeHostProject();
  final sandbox = Directory(
    p.join(host.path, '.zuraffa', 'slices', fixtureFeature),
  )..createSync(recursive: true);
  SandboxComposition().compose(
    projectRoot: host.path,
    sandboxDir: sandbox.path,
    feature: fixtureFeature,
    routes: fixtureManifest(host).routes,
    dependencies: fixtureManifest(host).dependencies,
    generatedFiles: <String>[],
  );

  final verifier = SliceVerifier(
    suiteRunner: (_) => const SuiteOutcome(passed: true),
  );
  final verdict = verifier.verify(
    sandboxDir: sandbox.path,
    manifest: fixtureManifest(host),
    hostRoot: host.path,
  );
  expect(verdict.selfContainment.pass, isTrue,
      reason: verdict.selfContainment.offenders.join('\n'));

  // A leaked host reference fails self-containment, named.
  final shell = File(p.join(sandbox.path, 'lib', 'main.dart'));
  shell.writeAsStringSync(
    '${shell.readAsStringSync()}// TODO: revisit with the host at ${host.path}\n',
  );
  final leaked = verifier.verify(
    sandboxDir: sandbox.path,
    manifest: fixtureManifest(host),
    hostRoot: host.path,
  );
  expect(leaked.selfContainment.pass, isFalse);
  expect(leaked.selfContainment.offenders, isNotEmpty);
  expect(
    leaked.selfContainment.offenders.join(' '),
    contains('lib/main.dart'),
    reason: 'the offending file must be named',
  );
  return null;
}
