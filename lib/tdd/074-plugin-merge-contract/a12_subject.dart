// IMPLEMENTED (074 phase 2, issue #962): AC-12 — rollback is
// byte-identical: after a restore, every snapshotted file's bytes (and
// the tree fingerprint) match the pre-merge capture exactly.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/merger/host_baseline.dart';

import 'merge_fixture.dart';

void subject_a12() {
  final host = snapshotSandbox();
  final before = HostBaseline.fingerprint(host.path);
  final baseline = captureBaseline(host);

  // The merge mutates the host (regenerated barrel + a created file).
  File(p.join(host.path, 'lib', 'router.dart')).writeAsStringSync(
    '$hostBarrel\nroute(\'/login\', page: LoginPage(), // module: login)',
  );
  File(
    p.join(host.path, 'lib', 'new_barrel.dart'),
  ).writeAsStringSync('// created by merge\n');

  final during = HostBaseline.fingerprint(host.path);
  expect(during, isNot(equals(before)), reason: 'the merge changed bytes');

  // Rollback restores EXACTLY the pre-merge bytes.
  final restored = baseline.restore(host.path);
  expect(
    restored,
    containsAll(<String>['lib/router.dart', 'lib/new_barrel.dart']),
  );
  expect(HostBaseline.fingerprint(host.path), equals(before));
  expect(
    File(p.join(host.path, 'lib', 'router.dart')).readAsStringSync(),
    equals(hostBarrel),
  );
  expect(
    File(p.join(host.path, 'lib', 'new_barrel.dart')).existsSync(),
    isFalse,
    reason: 'merge-created files are removed on rollback',
  );
}
