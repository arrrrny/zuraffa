// IMPLEMENTED (073 phase 2, issue #961): AC-4 — a declared
// platform-channel dependency gets its certified channel fake installed
// in the sandbox's DI: the fake artifact exists, is bound, and carries
// the declared channel members.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/generators/sandbox_composition.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_depth.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_manifest.dart';
import 'package:zuraffa/src/plugins/slice/verifier/slice_verifier.dart';

import 'sandbox_fixture.dart';

void subject_a4() {
  final host = writeHostProject();
  final sandboxPath = p.join(
    host.path,
    '.zuraffa',
    'slices',
    fixtureFeature,
  );
  final manifest = SliceManifest(
    name: fixtureFeature,
    createdAt: DateTime.parse('2026-09-04T00:00:00.000Z'),
    depth: SliceDepth.parse('feature'),
    entries: const [],
    projectRoot: host.path,
    packageName: 'host_app',
    branch: 'sandbox-test',
    files: const [],
    boundaries: const [],
    routes: const [],
    dependencies: const [
      ManifestDependency(
        dependency: 'SecureStore',
        kind: 'platform-channel',
        contract: 'read(key) -> String',
        priority: 'P2',
        mockArtifact: 'test/mock/dependencies/secure_store_fake.dart',
      ),
    ],
  );
  SandboxComposition().compose(
    projectRoot: host.path,
    sandboxDir: sandboxPath,
    feature: fixtureFeature,
    routes: manifest.routes,
    dependencies: manifest.dependencies,
    generatedFiles: <String>[],
  );

  // The certified channel fake is installed in the sandbox DI.
  final di = File(p.join(sandboxPath, 'lib', 'di.dart')).readAsStringSync();
  expect(di, contains("sandbox.bind('dependencies/secure_store'"));
  expect(di, contains('platform-channel'));

  // The fake carries every declared member of the channel contract.
  final fake = File(
    p.join(sandboxPath, 'test/mock/dependencies/secure_store_fake.dart'),
  ).readAsStringSync();
  expect(fake, contains('read'));
  expect(fake, contains('class FakeSecureStore'));

  // And the mock-certification check certifies exactly that binding.
  final verdict = SliceVerifier(suiteRunner: (_) => const SuiteOutcome(passed: true))
      .verify(
    sandboxDir: sandboxPath,
    manifest: manifest,
    hostRoot: host.path,
  );
  expect(verdict.mockCertification.pass, isTrue,
      reason: verdict.mockCertification.offenders.join('\n'));
}
