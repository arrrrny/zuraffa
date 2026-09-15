/// Issue #1664 — the child binary resolution seam paid a one-time ~85s
/// `dart compile exe` of the zfa CLI on the first refactor after every
/// master bump, even when the driving process ran from a CURRENT installed
/// binary (`~/.local/bin/zfa` whose `zfa.build_commit` equals the checkout
/// HEAD). `scripts/rebuild.sh` wipes `<checkout>/.dart_tool` on every
/// install, so the compile cache starts empty and the first
/// `ZfaExecutable.ensureCompiled(<checkout>/bin/zfa.dart)` that reaches the
/// compile path pays the full AOT build inside the first refactor's wall
/// clock (124.6s measured vs the ~40s expectation; steady state 0.4–0.6s).
///
/// Fix under test: an injectable reuse probe —
/// `ZfaExecutable.currentInstalledBinary` — wired into `_compileCached`
/// AFTER the fresh-cache check and BEFORE the build lock. When
///   (a) the candidate is the canonical package entrypoint
///       (`bin/zfa.dart` / `bin/zuraffa.dart` of its source root),
///   (b) the running process is a compiled (non-Dart-VM) executable,
///   (c) `<install-dir>/zfa.build_commit` exists and equals the candidate
///       source root's `git rev-parse HEAD`,
/// the probe returns the running binary and the compile never happens
/// (acceptance criteria 1–2). Every other shape returns null and the
/// existing compile path proceeds unchanged — in particular a marker that
/// DISAGREES with the checkout HEAD proves the installed binary stale and
/// forbids the reuse (acceptance criterion 3). The wiring keeps the fresh
/// cache verdict FIRST, so the warm-cache steady state is byte-for-byte
/// unchanged (acceptance criterion 4 — pinned by the pre-existing U3).
///
/// The probe is the #1643/#1645 running-binary idea extended to the compile
/// seam itself: those tiers fix WHICH candidate the resolution chains pick
/// when the driver is compiled; this guard intercepts the would-compile
/// moment no matter which tier produced a source candidate.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/binary_staleness.dart';
import 'package:zuraffa/src/cli/zfa_executable.dart';

void main() {
  /// A source root shaped like the zuraffa checkout: a package whose
  /// canonical `bin/zfa.dart` exists (the candidate every child seam
  /// resolves in the reported scenario).
  Future<Directory> sourceRoot(String tag) async {
    final dir = await Directory.systemTemp.createTemp('zfa1664_root_$tag');
    addTearDown(() => dir.deleteSync(recursive: true));
    await File(
      p.join(dir.path, 'bin', 'zfa.dart'),
    ).create(recursive: true).then((f) => f.writeAsString('void main() {}\n'));
    await File(
      p.join(dir.path, 'pubspec.yaml'),
    ).writeAsString('name: fixture\n');
    return dir;
  }

  /// A fake "installed binary" dir: the running executable plus the
  /// `zfa.build_commit` marker `scripts/rebuild.sh` writes next to it
  /// (trailing newline included — `printf '%s\n'`).
  Future<Directory> installDir(
    String tag, {
    required String exeName,
    String? markerCommit,
  }) async {
    final dir = await Directory.systemTemp.createTemp('zfa1664_bin_$tag');
    addTearDown(() => dir.deleteSync(recursive: true));
    final exe = File(p.join(dir.path, exeName));
    await exe.writeAsString('#!/bin/sh\nexit 0\n');
    await Process.run('chmod', ['+x', exe.path]);
    if (markerCommit != null) {
      await File(
        p.join(dir.path, zfaBuildCommitMarker),
      ).writeAsString('$markerCommit\n');
    }
    return dir;
  }

  /// A git probe fake: answers `git rev-parse HEAD` with [head] and records
  /// every argv so the probe's probe-contract is pinned (argv shape, cwd).
  (
    Future<ProcessResult> Function(List<String>, String),
    List<List<String>>,
    List<String>,
  )
  gitProbe(String head, {int exitCode = 0}) {
    final calls = <List<String>>[];
    final cwds = <String>[];
    Future<ProcessResult> call(
      List<String> argv,
      String workingDirectory,
    ) async {
      calls.add(argv);
      cwds.add(workingDirectory);
      return ProcessResult(1, exitCode, '$head\n', '');
    }

    return (call, calls, cwds);
  }

  const headSha = 'c5ed519f00000000000000000000000000000000';
  const oldSha = 'a111111111111111111111111111111111111111';

  group('bug #1664: currentInstalledBinary reuse probe', () {
    test('U-1664-b1: a current installed binary (marker == checkout HEAD) is '
        'returned for the canonical entrypoint — the compile never happens '
        '(the issue\'s bug)', () async {
      final root = await sourceRoot('reuse');
      final bin = await installDir(
        'reuse',
        exeName: 'zfa',
        markerCommit: headSha,
      );
      final (probe, calls, cwds) = gitProbe(headSha);

      final result = await ZfaExecutable.currentInstalledBinary(
        candidate: p.join(root.path, 'bin', 'zfa.dart'),
        sourceRoot: root.path,
        runningExecutable: p.join(bin.path, 'zfa'),
        runner: probe,
      );

      expect(
        result,
        p.join(bin.path, 'zfa'),
        reason: 'the running binary is proven current — reuse it',
      );
      expect(calls, hasLength(1), reason: 'exactly one git probe');
      expect(calls.single, ['git', 'rev-parse', 'HEAD']);
      expect(
        cwds.single,
        root.path,
        reason: 'HEAD is probed in the CANDIDATE source root',
      );
    });

    test(
      'U-1664-b2: a marker that disagrees with the checkout HEAD forbids '
      'the reuse (the stale-install guard, acceptance criterion 3)',
      () async {
        final root = await sourceRoot('stale');
        final bin = await installDir(
          'stale',
          exeName: 'zfa',
          markerCommit: oldSha,
        );
        final (probe, calls, _) = gitProbe(headSha);

        final result = await ZfaExecutable.currentInstalledBinary(
          candidate: p.join(root.path, 'bin', 'zfa.dart'),
          sourceRoot: root.path,
          runningExecutable: p.join(bin.path, 'zfa'),
          runner: probe,
        );

        expect(
          result,
          isNull,
          reason: 'an old install against a bumped checkout must compile',
        );
        expect(calls, hasLength(1));
      },
    );

    test('U-1664-b3: a Dart-VM running executable never reuses (source/test '
        'drivers keep the compile-cache contract)', () async {
      final root = await sourceRoot('vm');
      final bin = await installDir('vm', exeName: 'dartaotruntime');
      final (probe, calls, _) = gitProbe(headSha);

      final result = await ZfaExecutable.currentInstalledBinary(
        candidate: p.join(root.path, 'bin', 'zfa.dart'),
        sourceRoot: root.path,
        runningExecutable: p.join(bin.path, 'dartaotruntime'),
        runner: probe,
      );

      expect(result, isNull, reason: 'the VM is never a zfa binary');
      expect(
        calls,
        isEmpty,
        reason: 'the VM shape is rejected before any git probe',
      );
    });

    test('U-1664-b4: no build-commit marker — reuse is unprovable', () async {
      final root = await sourceRoot('nomarker');
      final bin = await installDir('nomarker', exeName: 'zfa');
      final (probe, calls, _) = gitProbe(headSha);

      final result = await ZfaExecutable.currentInstalledBinary(
        candidate: p.join(root.path, 'bin', 'zfa.dart'),
        sourceRoot: root.path,
        runningExecutable: p.join(bin.path, 'zfa'),
        runner: probe,
      );

      expect(result, isNull, reason: 'no marker, no proof — compile as today');
      expect(calls, isEmpty);
    });

    test('U-1664-b5: an empty marker — reuse is unprovable', () async {
      final root = await sourceRoot('emptymarker');
      final bin = await installDir(
        'emptymarker',
        exeName: 'zfa',
        markerCommit: '   ',
      );
      final (probe, calls, _) = gitProbe(headSha);

      final result = await ZfaExecutable.currentInstalledBinary(
        candidate: p.join(root.path, 'bin', 'zfa.dart'),
        sourceRoot: root.path,
        runningExecutable: p.join(bin.path, 'zfa'),
        runner: probe,
      );

      expect(result, isNull);
      expect(calls, isEmpty);
    });

    test('U-1664-b6: a failed git probe (not a repo) falls through to the '
        'compile path', () async {
      final root = await sourceRoot('norepo');
      final bin = await installDir(
        'norepo',
        exeName: 'zfa',
        markerCommit: headSha,
      );
      final (probe, calls, _) = gitProbe('', exitCode: 128);

      final result = await ZfaExecutable.currentInstalledBinary(
        candidate: p.join(root.path, 'bin', 'zfa.dart'),
        sourceRoot: root.path,
        runningExecutable: p.join(bin.path, 'zfa'),
        runner: probe,
      );

      expect(result, isNull, reason: 'unresolvable HEAD — fail open');
      expect(calls, hasLength(1));
    });

    test('U-1664-b7: a non-canonical candidate (a custom --zfa-bin fixture) '
        'never reuses the zfa binary', () async {
      final root = await sourceRoot('fixture');
      await File(
        p.join(root.path, 'tool', 'fixture.dart'),
      ).create(recursive: true).then((f) => f.writeAsString('void m() {}\n'));
      final bin = await installDir(
        'fixture',
        exeName: 'zfa',
        markerCommit: headSha,
      );
      final (probe, calls, _) = gitProbe(headSha);

      final result = await ZfaExecutable.currentInstalledBinary(
        candidate: p.join(root.path, 'tool', 'fixture.dart'),
        sourceRoot: root.path,
        runningExecutable: p.join(bin.path, 'zfa'),
        runner: probe,
      );

      expect(
        result,
        isNull,
        reason: 'a scripted fixture must keep its own artifact',
      );
      expect(calls, isEmpty, reason: 'rejected before any git probe');
    });

    test('U-1664-b8: a missing running executable never reuses', () async {
      final root = await sourceRoot('missing');
      final bin = await installDir(
        'missing',
        exeName: 'zfa',
        markerCommit: headSha,
      );
      final (probe, calls, _) = gitProbe(headSha);

      final result = await ZfaExecutable.currentInstalledBinary(
        candidate: p.join(root.path, 'bin', 'zfa.dart'),
        sourceRoot: root.path,
        runningExecutable: p.join(bin.path, 'gone'),
        runner: probe,
      );

      expect(result, isNull);
      expect(calls, isEmpty);
    });
  });

  group('bug #1664: ensureCompiled wiring keeps the existing contract', () {
    test(
      'U-1664-b9: a VM-driven cache miss still compiles through the '
      'injected runner, and the compiler fake never sees a git argv',
      () async {
        final root = await Directory.systemTemp.createTemp('zfa1664_wire_');
        addTearDown(() => root.deleteSync(recursive: true));
        await File(p.join(root.path, 'bin', 'zfa.dart'))
            .create(recursive: true)
            .then((f) => f.writeAsString('void main() {}\n'));
        await File(
          p.join(root.path, 'lib', 'x.dart'),
        ).create(recursive: true).then((f) => f.writeAsString('// x\n'));
        await File(
          p.join(root.path, 'pubspec.yaml'),
        ).writeAsString('name: fixture\n');

        final compileCalls = <List<String>>[];
        Future<ProcessResult> compile(List<String> argv, String cwd) async {
          compileCalls.add(argv);
          final out = argv[argv.indexOf('--output') + 1];
          await File(out).writeAsString('compiled');
          return ProcessResult(1, 0, '', '');
        }

        // The test process runs under the Dart VM, so the reuse probe
        // rejects the driver before any git probe and the compile path
        // proceeds exactly as the pre-#1664 U2 contract pins.
        final result = await ZfaExecutable.ensureCompiled(
          p.join(root.path, 'bin', 'zfa.dart'),
          sourceRoot: root.path,
          runner: compile,
        );

        expect(
          result,
          p.join(root.path, p.joinAll(kZfaBinaryCacheDir), kZfaBinaryName),
        );
        expect(compileCalls, hasLength(1));
        expect(compileCalls.single.take(3), [
          'dart',
          'compile',
          'exe',
        ], reason: 'the compile argv is untouched by the reuse probe');
        expect(
          compileCalls.single.any((token) => token == 'git'),
          isFalse,
          reason: 'the git probe never rides the compile runner',
        );
      },
    );
  });
}
