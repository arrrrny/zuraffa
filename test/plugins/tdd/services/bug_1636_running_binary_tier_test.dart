// Issue #1636 — `StepRunner.resolveEntrypoint` ordered the PATH tier (the
// bug #690 system-binary lookup) BEFORE the running-executable tier. When
// the driving process IS a compiled (non-VM) binary that is not on PATH —
// the `scripts/zfa` compile-cache artifact
// `.dart_tool/zfa_cli_bin/zfa_exe` — the PATH tier short-circuits and every
// resolved child, including `zfaBuildCommand`'s build pass, executes the
// PATH install. That install may predate the driving build while carrying
// the same version string, which the #1472 version pin cannot distinguish
// (it only fires on a provably different version).
//
// Fix under test: when `Platform.resolvedExecutable` is a compiled (non-VM)
// executable, the RUNNING binary outranks the PATH tier — it is
// definitionally what the operator invoked (the no-JIT directive: "the
// driving built binary always"). VM drivers (`dart run`, `dart test`, a
// `dartaotruntime` snapshot launch) fail the non-VM check and keep the
// exact #690/#717 tier order — backward compatible.
//
// Driver shapes exercised (each named per the tier history):
//   B1 — the cache-exe driver, the #864 native-AOT shape
//        (`Platform.script` IS `Platform.resolvedExecutable`) with a zfa
//        on PATH: the running binary wins (the #1636 repro).
//   B2 — the cache-exe driver with an UNUSABLE script (the stale-dill
//        shape) and a zfa on PATH: the running binary still wins.
//   B3 — the `dart run` driver (resolvedExecutable is the VM): the PATH
//        tier keeps firing exactly as #690 ordered (backward compat).
//   B4 — the `dartaotruntime` snapshot driver: the PATH tier keeps firing
//        (backward compat).
//   B5 — the cache-exe driver with a NON-executable PATH candidate: the
//        running binary wins; the non-executable PATH candidate never
//        wins (the test pins the outcome, not the tier order).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/step_runner.dart';

void main() {
  /// A real executable file in a temp dir (the compiled binaries the tests
  /// stand in for — the same fixture shape the bug #690 suite uses).
  Future<File> executableFile(String dirName, String name) async {
    final dir = await Directory.systemTemp.createTemp(dirName);
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, name));
    await file.writeAsString('#!/bin/sh\nexit 0\n');
    await Process.run('chmod', ['+x', file.path]);
    return file;
  }

  Future<Uri?> noPackageUri(Uri packageUri) async => null;
  const staleScript = '/build/stale/zfa.dart.dill';

  group('bug #1636: the running compiled binary outranks the PATH tier', () {
    test('B1: the cache-exe driver with a zfa on PATH resolves the running '
        'binary, not the PATH install (#864 native-AOT shape)', () async {
      final pathInstall = await executableFile('zfa1636_path', 'zfa');
      final driving = await executableFile('zfa1636_cache', 'zfa_exe');

      final bin = await StepRunner.resolveEntrypoint(
        // Native AOT executable (bug #864): Platform.script IS
        // Platform.resolvedExecutable — the scripts/zfa cache-exe shape.
        script: Uri.file(driving.path),
        resolvedExecutable: driving.path,
        environment: {'PATH': p.dirname(pathInstall.path)},
        resolvePackageUri: noPackageUri,
      );

      expect(
        bin,
        driving.path,
        reason:
            'the driving binary is definitionally what the operator '
            'invoked; the PATH install (tier 5) must not short-circuit it',
      );
    });

    test('B2: the cache-exe driver with an unusable script and a zfa on '
        'PATH still resolves the running binary', () async {
      final pathInstall = await executableFile('zfa1636_path2', 'zfa');
      final driving = await executableFile('zfa1636_cache2', 'zfa_exe');

      final bin = await StepRunner.resolveEntrypoint(
        script: Uri.file(staleScript),
        resolvedExecutable: driving.path,
        environment: {'PATH': p.dirname(pathInstall.path)},
        resolvePackageUri: noPackageUri,
      );

      expect(bin, driving.path);
    });

    test('B3: the dart run driver (VM) keeps the #690 order — the PATH '
        'tier still fires (backward compatible)', () async {
      final pathInstall = await executableFile('zfa1636_vm', 'zfa');

      final bin = await StepRunner.resolveEntrypoint(
        script: Uri.file(staleScript),
        // `dart run`: the driving executable is the Dart VM, not a
        // compiled zfa — the running-binary tier must NOT fire.
        resolvedExecutable: '/usr/bin/dart',
        environment: {'PATH': p.dirname(pathInstall.path)},
        resolvePackageUri: noPackageUri,
      );

      expect(bin, pathInstall.path);
    });

    test('B4: the dartaotruntime snapshot driver keeps the #690 order — '
        'the PATH tier still fires (backward compatible)', () async {
      final pathInstall = await executableFile('zfa1636_aot', 'zfa');
      final snapshot = await executableFile('zfa1636_snap', 'zfa.aot');

      final bin = await StepRunner.resolveEntrypoint(
        script: Uri.file(snapshot.path),
        // A JIT/AOT snapshot launch drives through dartaotruntime — the
        // VM names keep the running-binary tier off.
        resolvedExecutable: '/usr/bin/dartaotruntime',
        environment: {'PATH': p.dirname(pathInstall.path)},
        resolvePackageUri: noPackageUri,
      );

      expect(bin, pathInstall.path);
    });

    test(
      'B5: the cache-exe driver with a non-executable PATH candidate '
      'resolves the running binary — the PATH candidate never wins',
      () async {
        final dir = await Directory.systemTemp.createTemp('zfa1636_nox');
        addTearDown(() => dir.delete(recursive: true));
        final notExecutable = File(p.join(dir.path, 'zfa'));
        await notExecutable.writeAsString('#!/bin/sh\nexit 0\n');
        final driving = await executableFile('zfa1636_cache3', 'zfa_exe');

        final bin = await StepRunner.resolveEntrypoint(
          script: Uri.file(staleScript),
          resolvedExecutable: driving.path,
          environment: {'PATH': dir.path},
          resolvePackageUri: noPackageUri,
        );

        expect(
          bin,
          driving.path,
          reason:
              'the non-executable PATH candidate never wins; this test '
              'pins the outcome, not the tier order',
        );
      },
    );
  });
}
