// Issue #1645 — `PipelineRunner._resolveEntrypoint` (the #665 chain behind
// `tdd make`/`gen` spawns) ordered the PATH tier BEFORE any running-binary
// tier. When the driving process IS a compiled (non-VM) binary whose
// `Platform.script` basename is not `zfa.dart`/`zuraffa.dart` — the
// `scripts/zfa` compile-cache artifact `.dart_tool/zfa_cli_bin/zfa_exe` —
// tier 2 falls through and the PATH tier short-circuits: every spawned
// child executes the PATH install. That install may predate the driving
// build while carrying the same version string, which the #1472 version
// pin cannot distinguish (it only fires on a provably different version).
//
// Fix under test (the #1643 mirror): when `Platform.resolvedExecutable`
// is a compiled (non-VM) executable, the RUNNING binary outranks the PATH
// tier — it is definitionally what the operator invoked (the no-JIT
// directive: "the driving built binary always"). VM drivers (`dart run`,
// `dart test`, a `dartaotruntime` snapshot launch) fail the non-VM check
// and keep the exact #665/#690 tier order — backward compatible.
//
// Driver shapes exercised (each named per the tier history; the same
// shapes the #1636 step-runner suite pins, driven through `runPlan` so
// the RESOLVED AND SPAWNED entrypoint is observable via
// `PipelineResult.entrypoint`):
//   A1 — B1: the cache-exe driver, the #864 native-AOT shape
//        (`Platform.script` IS `Platform.resolvedExecutable`) with a zfa
//        on PATH: the running binary wins (the #1645 repro).
//   A2 — B2: the cache-exe driver with an UNUSABLE script (the stale-dill
//        shape) and a zfa on PATH: the running binary still wins.
//   U2 — B3: the `dart run` driver (resolvedExecutable is the VM): the
//        PATH tier keeps firing exactly as #665/#690 ordered.
//   U3 — B4: the `dartaotruntime` snapshot driver: the PATH tier keeps
//        firing (backward compat).
//   U1 — B5: the cache-exe driver with a NON-executable PATH candidate:
//        the running binary wins; the non-executable PATH candidate never
//        wins (the test pins the outcome, not the tier order).
//   U11 — B6 (verify remediation, kills M2): a non-VM-named executable
//        MISSING from disk + a zfa on PATH: the PATH install wins — the
//        promoted tier must not fire on a missing file (the existence
//        check is load-bearing).
//   U12 — B7 (verify remediation, kills M4): a `.dart`-suffixed
//        resolvedExecutable (non-VM basename) routes through the
//        `ensureCompiled` seam — the entrypoint is the returned artifact,
//        never the raw source (the no-JIT seam is load-bearing).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/generation_plan.dart';
import 'package:zuraffa/src/cli/zfa_executable.dart';
import 'package:zuraffa/src/plugins/tdd/services/pipeline_runner.dart';

void main() {
  /// A real executable file in a temp dir (the compiled binaries the tests
  /// stand in for — the same fixture shape the bug #1636 suite uses).
  Future<File> executableFile(String dirName, String name) async {
    final dir = await Directory.systemTemp.createTemp(dirName);
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, name));
    await file.writeAsString('#!/bin/sh\nexit 0\n');
    await Process.run('chmod', ['+x', file.path]);
    return file;
  }

  /// A throwaway working directory for `runPlan` — the single step spawns
  /// the resolved entrypoint with `make Todo` and the fake exits 0.
  Future<Directory> workingDir() =>
      Directory.systemTemp.createTemp('zfa1645_wd');

  final staleScript = '/build/stale/zfa.dart.dill';

  Future<PipelineResult> runSingleStepPlan({
    required String scriptPath,
    required String resolvedExecutable,
    required String pathEnv,
    ZfaEnsureCompiled? ensureCompiled,
  }) async {
    final wd = await workingDir();
    addTearDown(() => wd.delete(recursive: true));
    const runner = PipelineRunner();
    return runner.runPlan(
      plan: GenerationPlan(
        behaviorId: 'B-001',
        feature: 'bug_1645',
        sourceCriterion: 'FR-001',
        steps: [
          GenerationStepSpec(args: ['make', 'Todo'], purpose: 'p1'),
        ],
      ),
      workingDirectory: wd.path,
      scriptPathOverride: scriptPath,
      resolvedExecutableOverride: resolvedExecutable,
      pathEnvOverride: pathEnv,
      ensureCompiled: ensureCompiled,
    );
  }

  group('bug #1645: the running compiled binary outranks the PATH tier', () {
    test(
      'A1: the cache-exe driver with a zfa on PATH resolves and spawns '
      'the running binary, not the PATH install (#864 native-AOT shape)',
      () async {
        final pathInstall = await executableFile('zfa1645_path', 'zfa');
        final driving = await executableFile('zfa1645_cache', 'zfa_exe');

        final result = await runSingleStepPlan(
          // Native AOT executable (bug #864): Platform.script IS
          // Platform.resolvedExecutable — the scripts/zfa cache-exe shape.
          scriptPath: driving.path,
          resolvedExecutable: driving.path,
          pathEnv: p.dirname(pathInstall.path),
        );

        expect(result.completed, isTrue);
        expect(
          result.entrypoint,
          driving.path,
          reason:
              'the driving binary is definitionally what the operator '
              'invoked; the PATH install (tier 4) must not short-circuit it '
              '— the same-version/different-code hazard the #1472 pin '
              'cannot see',
        );
      },
    );

    test('A2: the cache-exe driver with an unusable script and a zfa on '
        'PATH still resolves the running binary', () async {
      final pathInstall = await executableFile('zfa1645_path2', 'zfa');
      final driving = await executableFile('zfa1645_cache2', 'zfa_exe');

      final result = await runSingleStepPlan(
        scriptPath: staleScript,
        resolvedExecutable: driving.path,
        pathEnv: p.dirname(pathInstall.path),
      );

      expect(result.completed, isTrue);
      expect(result.entrypoint, driving.path);
    });

    test('U2 (B3): the dart run driver (VM) keeps the #665/#690 order — '
        'the PATH tier still fires (backward compatible)', () async {
      final pathInstall = await executableFile('zfa1645_vm', 'zfa');
      // A REAL VM name AND a real existing file (verify remediation R3):
      // the stand-in must exist so the running-binary tier's existence
      // check alone never masks a broken VM-name set.
      final vm = await executableFile('zfa1645_vmbin', 'dart');

      final result = await runSingleStepPlan(
        scriptPath: staleScript,
        // `dart run`: the driving executable is the Dart VM, not a
        // compiled zfa — the running-binary tier must NOT fire.
        resolvedExecutable: vm.path,
        pathEnv: p.dirname(pathInstall.path),
      );

      expect(result.completed, isTrue);
      expect(result.entrypoint, pathInstall.path);
    });

    test('U3 (B4): the dartaotruntime snapshot driver keeps the #665/#690 '
        'order — the PATH tier still fires (backward compatible)', () async {
      final pathInstall = await executableFile('zfa1645_aot', 'zfa');
      final snapshot = await executableFile('zfa1645_snap', 'zfa.aot');
      // A REAL VM name AND a real existing file (verify remediation R3).
      final vm = await executableFile('zfa1645_aotbin', 'dartaotruntime');

      final result = await runSingleStepPlan(
        scriptPath: snapshot.path,
        // A JIT/AOT snapshot launch drives through dartaotruntime — the
        // VM names keep the running-binary tier off.
        resolvedExecutable: vm.path,
        pathEnv: p.dirname(pathInstall.path),
      );

      expect(result.completed, isTrue);
      expect(result.entrypoint, pathInstall.path);
    });

    test(
      'U1 (B5): the cache-exe driver with a non-executable PATH candidate '
      'resolves the running binary — the PATH candidate never wins',
      () async {
        final dir = await Directory.systemTemp.createTemp('zfa1645_nox');
        addTearDown(() => dir.delete(recursive: true));
        final notExecutable = File(p.join(dir.path, 'zfa'));
        await notExecutable.writeAsString('#!/bin/sh\nexit 0\n');
        final driving = await executableFile('zfa1645_cache3', 'zfa_exe');

        final result = await runSingleStepPlan(
          scriptPath: driving.path,
          resolvedExecutable: driving.path,
          pathEnv: dir.path,
        );

        expect(result.completed, isTrue);
        expect(
          result.entrypoint,
          driving.path,
          reason:
              'the non-executable PATH candidate never wins; this test '
              'pins the outcome, not the tier order',
        );
      },
    );

    test('U11 (B6): a non-VM-named executable MISSING from disk falls through '
        'to PATH — the promoted tier never fires on a missing file', () async {
      final pathInstall = await executableFile('zfa1645_path3', 'zfa');
      final ghostDir = await Directory.systemTemp.createTemp('zfa1645_ghost');
      addTearDown(() => ghostDir.delete(recursive: true));
      // A non-VM basename whose file does NOT exist: the existence
      // check must refuse the promotion and let the PATH tier resolve
      // (the spec's nonexistent-executable edge case).
      final missing = p.join(ghostDir.path, 'missing_bin', 'zfa_exe');

      final result = await runSingleStepPlan(
        scriptPath: staleScript,
        resolvedExecutable: missing,
        pathEnv: p.dirname(pathInstall.path),
      );

      expect(result.completed, isTrue);
      expect(
        result.entrypoint,
        pathInstall.path,
        reason:
            'a missing candidate must not be promoted; falling through '
            'to PATH is the honest resolution',
      );
    });

    test('U12 (B7): a .dart-suffixed resolvedExecutable routes through the '
        'compile seam — the artifact runs, never the raw source', () async {
      final pathInstall = await executableFile('zfa1645_path4', 'zfa');
      final source = await executableFile('zfa1645_src', 'tool_main.dart');
      final artifact = await executableFile('zfa1645_art', 'zfa-compiled');
      final compiledFrom = <String>[];

      final result = await runSingleStepPlan(
        scriptPath: staleScript,
        // Non-VM basename, exists — the promoted tier fires, and a
        // SOURCE candidate must be compiled before it is returned
        // (the no-JIT seam, FR-005, now pinned on the new tier).
        resolvedExecutable: source.path,
        pathEnv: p.dirname(pathInstall.path),
        ensureCompiled: (candidate, {sourceRoot, runner, environment}) async {
          compiledFrom.add(candidate);
          return artifact.path;
        },
      );

      expect(result.completed, isTrue);
      expect(compiledFrom, [source.path]);
      expect(
        result.entrypoint,
        artifact.path,
        reason:
            'the promoted tier resolves through the compile seam: the '
            'entrypoint is the compiled artifact, never the raw source',
      );
    });
  });
}
