@Tags(['regression'])
// Bug #1507 — `zfa tdd` leaks `$TMPDIR/dart_test.kernel.*` directories
// without bound (51 GB / 869 dill files in ~80 minutes on the reporter's
// machine; Docker Desktop died of ENOSPC). The built-in cleanup
// `_clearDartTestKernelCache` matched `entity is File` while the leaked
// entries are DIRECTORIES (`dart_test.kernel.VSoGgt/` full of .dill
// files) — the branch was dead code — and its only call site was the
// ReproofFailureClass.infraRunner retry path, so a healthy cycle (the one
// that actually leaks) never cleared anything. `run_command.dart` had no
// kernel handling at all.
//
// Contract pinned here (issue #1507):
//   C1 — the sweep matches BOTH files and directories and deletes
//        directories recursively;
//   C2 — the sweep runs at the START of every TDD cycle in BOTH the
//        refactor and the run command. Proven with a HEALTHY green cycle:
//        the counter shows preflight + re-proof only (2), so the retry
//        machinery never fired and the only sweep that can have deleted
//        the seeded entries is the cycle-start one;
//   C3 — the sweep logs what it reclaimed:
//        `cleared N stale kernel dir(s), freed X MB`;
//   C4 — entries created or updated after the command start may belong to
//        a concurrent runner and survive — the commandStartedAt guard is
//        preserved.
//
// Fixture discipline (bug #922/#1333 pattern): the suite template is a
// counting shell script that never fails; the stale kernel entries are
// pre-seeded markers (a directory full of dill-sized files, a bare file,
// and the project's `.dart_tool/test/`) whose mtimes are backdated one
// hour so they are unambiguously stale relative to any commandStartedAt
// this suite can produce.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

/// The reclaim log line the sweep must emit (issue #1507): the cleared
/// entry count and the freed size in MB.
final RegExp reclaimLine = RegExp(
  r'cleared (\d+) stale kernel dir\(s\), freed ([\d.]+) MB',
);

/// The same TMPDIR resolution chain the sweep itself uses
/// (refactor_command.dart).
String get tmpRoot =>
    Platform.environment['TMPDIR'] ??
    Platform.environment['TEMP'] ??
    Platform.environment['TMP'] ??
    Directory.systemTemp.path;

void main() {
  late TddFixture fx;
  late String fakeZfa;
  late File counter;
  final tmpEntries = <FileSystemEntity>[];

  /// Seed a stale `dart_test.kernel.bug1507-<unique>` DIRECTORY holding
  /// [files] dill-sized files (each exactly 512 KiB) — the leaked shape
  /// from the issue report. The directory mtime is backdated one hour
  /// AFTER the files are written (adding entries refreshes it) so the
  /// directory itself is unambiguously stale.
  Directory seedStaleKernelDir(String unique, {int files = 3}) {
    final dir = Directory(p.join(tmpRoot, 'dart_test.kernel.bug1507-$unique'))
      ..createSync(recursive: true);
    final chunk = List.filled(512 * 1024, 120);
    for (var i = 0; i < files; i++) {
      File(p.join(dir.path, 'probe_$i.dart.dill')).writeAsBytesSync(chunk);
    }
    final staleEpochSeconds =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600;
    Process.runSync('touch', ['-d', '@$staleEpochSeconds', dir.path]);
    tmpEntries.add(dir);
    return dir;
  }

  /// Seed a stale `dart_test.kernel.bug1507-<unique>` FILE of [kib]
  /// KiB, mtime backdated one hour.
  File seedStaleKernelFile(String unique, {int kib = 512}) {
    final file = File(p.join(tmpRoot, 'dart_test.kernel.bug1507-$unique'))
      ..writeAsBytesSync(List.filled(kib * 1024, 120));
    file.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 1)));
    tmpEntries.add(file);
    return file;
  }

  /// Seed a `dart_test.kernel.bug1507-<unique>` FILE whose mtime is one
  /// hour in the FUTURE — it simulates a concurrent runner's live kernel:
  /// created before the command starts, but updated after commandStartedAt.
  File seedLiveKernelFile(String unique) {
    final file = File(p.join(tmpRoot, 'dart_test.kernel.bug1507-$unique'))
      ..writeAsStringSync('live kernel bytes');
    file.setLastModifiedSync(DateTime.now().add(const Duration(hours: 1)));
    tmpEntries.add(file);
    return file;
  }

  /// Write a counting suite script that NEVER fails ([when] can never
  /// hold) — the preflight and the re-proof both run it green, so the
  /// cycle is healthy and the retry machinery never fires. The counter
  /// proves the invocation count afterwards.
  Future<String> writeNeverFailingSuite(String name) async {
    await Directory(fx.spyDir).create(recursive: true);
    final scriptPath = p.join(fx.spyDir, name);
    const template = '''
#!/bin/sh
C=__COUNTER__
N=0
if test -f "\$C"; then
  read -r N < "\$C"
fi
N=\$((N+1))
echo \$N > "\$C"
exit 0
''';
    await File(
      scriptPath,
    ).writeAsString(template.replaceAll('__COUNTER__', counter.path));
    Process.runSync('chmod', ['+x', scriptPath]);
    return scriptPath;
  }

  Future<String> runRefactor() async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'tdd',
      'refactor',
      '--project',
      fx.root.path,
      '--feature',
      '090-tdd-fixture',
      '--zfa-bin',
      fakeZfa,
    ]);
  }

  /// The reclaim line's parsed numbers ([count], [mb]) — null when the
  /// command never logged a reclaim (the pre-fix behavior).
  Match? reclaimIn(String out) => reclaimLine.firstMatch(out);

  setUp(() async {
    fx = await TddFixture.create(featureName: '090-tdd-fixture');
    fakeZfa = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);
    counter = File(p.join(fx.root.path, '.zfa_suite_count'));
    counter.writeAsStringSync('0');
    exitCode = 0;
  });

  tearDown(() {
    for (final entry in tmpEntries) {
      if (entry.existsSync()) {
        entry.deleteSync(recursive: true);
      }
    }
    tmpEntries.clear();
    fx.dispose();
    exitCode = 0;
  });

  group('bug #1507: the kernel sweep is a start-of-cycle obligation', () {
    test('C1+C2+C3 (refactor): a HEALTHY green cycle deletes stale kernel '
        'directories AND files and logs the reclaimed size', () async {
      final staleDir = seedStaleKernelDir('dir', files: 3); // 1.5 MiB
      final staleFile = seedStaleKernelFile('file'); // 0.5 MiB
      final probe =
          File(p.join(fx.root.path, '.dart_tool', 'test', 'probe.kernel'))
            ..parent.createSync(recursive: true)
            ..writeAsStringSync('');
      final suite = await writeNeverFailingSuite('green-suite');
      await fx.rewriteProfile(
        singleTemplate: TddFixture.defaultSingleTemplate,
        suiteTemplate: suite,
      );
      await fx.seedAlreadyCleanLib();

      final out = await runRefactor();

      expect(exitCode, 0, reason: out);
      expect(
        counter.readAsStringSync().trim(),
        '2',
        reason:
            'preflight + re-proof — the retry machinery never fired, '
            'so the only sweep that can have deleted the seeded entries '
            'is the cycle-start one (C2)',
      );
      expect(
        staleDir.existsSync(),
        isFalse,
        reason:
            r'the leaked $TMPDIR/dart_test.kernel.* entries are '
            'DIRECTORIES — the sweep must match and delete them '
            'recursively (C1)',
      );
      expect(staleFile.existsSync(), isFalse, reason: 'C1: files too');
      expect(
        probe.existsSync(),
        isFalse,
        reason: '.dart_tool/test/ is cleared by the same sweep',
      );
      final match = reclaimIn(out);
      expect(
        match,
        isNotNull,
        reason: 'the sweep must log what it reclaimed (C3) — out:\n$out',
      );
      expect(
        int.parse(match!.group(1)!),
        greaterThanOrEqualTo(3),
        reason:
            'at least the three seeded stale entries '
            '(stale dir + stale file + the project kernel cache) — '
            'out:\n$out',
      );
      expect(
        double.parse(match.group(2)!),
        greaterThanOrEqualTo(2.0),
        reason:
            'stale dir (3 x 512 KiB) + stale file (512 KiB) is at '
            'least 2 MiB — out:\n$out',
      );
    });

    test('C4 (refactor): a kernel entry younger than the command start '
        'survives the sweep (concurrent-runner guard preserved)', () async {
      final staleDir = seedStaleKernelDir('stale-guard', files: 1);
      final liveFile = seedLiveKernelFile('live-guard');
      final suite = await writeNeverFailingSuite('guard-suite');
      await fx.rewriteProfile(
        singleTemplate: TddFixture.defaultSingleTemplate,
        suiteTemplate: suite,
      );
      await fx.seedAlreadyCleanLib();

      final out = await runRefactor();

      expect(exitCode, 0, reason: out);
      expect(
        staleDir.existsSync(),
        isFalse,
        reason: 'the stale kernel directory is swept (C1)',
      );
      expect(
        liveFile.existsSync(),
        isTrue,
        reason:
            'an entry created-or-updated after commandStartedAt may '
            'belong to a concurrent runner and must be left untouched '
            '(C4) — out:\n$out',
      );
    });

    test('C2 (run): zfa tdd run sweeps stale kernel entries at cycle start — '
        'run_command had NO kernel handling at all before the fix', () async {
      final staleDir = seedStaleKernelDir('run-dir', files: 1); // 0.5 MiB
      final staleFile = seedStaleKernelFile('run-file'); // 0.5 MiB
      await fx.seedTestList([
        (
          id: 'B-001',
          description: 'first behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
        (
          id: 'B-002',
          description: 'second behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
        (
          id: 'B-003',
          description: 'third behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await fx.writeFakeZfa();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'run',
        '090-tdd-fixture',
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);

      expect(exitCode, 0, reason: out);
      expect(
        staleDir.existsSync(),
        isFalse,
        reason:
            r'zfa tdd run must sweep $TMPDIR/dart_test.kernel.* '
            'directories at cycle start (C1+C2) — out:\n$out',
      );
      expect(
        staleFile.existsSync(),
        isFalse,
        reason: 'kernel files too (C1) — out:\n$out',
      );
      final match = reclaimIn(out);
      expect(
        match,
        isNotNull,
        reason: 'the run sweep logs what it reclaimed (C3) — out:\n$out',
      );
      expect(
        double.parse(match!.group(2)!),
        greaterThanOrEqualTo(1.0),
        reason:
            'the two seeded stale entries hold at least 1 MiB — '
            'out:\n$out',
      );
    });
    test('C5 (refactor): a kernel dir referenced by a LIVE process argv '
        'survives the sweep — liveness guard, then swept once the holder '
        'exits', () async {
      final heldDir = seedStaleKernelDir('held', files: 1);
      final freeDir = seedStaleKernelDir('free', files: 1);
      // A fake frontend-server child: alive for the whole command, its
      // argv references the held kernel dir exactly like the real dart
      // test runner's compiler child does
      // (--output-dill=<dir>/output.dill). A script FILE (not `sh -c`)
      // keeps the reference in the interpreter's own argv — the shell
      // exec-optimizes a `-c` body away.
      final holderScript = File(p.join(fx.spyDir, 'kernel-holder.sh'));
      await holderScript.parent.create(recursive: true);
      await holderScript.writeAsString('#!/bin/sh\nsleep 30\n');
      Process.runSync('chmod', ['+x', holderScript.path]);
      final child = await Process.start(holderScript.path, [
        '--output-dill=${heldDir.path}/output.dill',
      ]);
      var firstRunRan = false;
      try {
        final suite = await writeNeverFailingSuite('liveness-suite');
        await fx.rewriteProfile(
          singleTemplate: TddFixture.defaultSingleTemplate,
          suiteTemplate: suite,
        );
        await fx.seedAlreadyCleanLib();

        final out = await runRefactor();
        firstRunRan = true;

        expect(exitCode, 0, reason: out);
        expect(
          heldDir.existsSync(),
          isTrue,
          reason:
              'a kernel dir a live dart test runner still references '
              '(its frontend-server child argv) must survive the sweep — '
              'deleting it crashes that runner at close — out:\n$out',
        );
        expect(
          freeDir.existsSync(),
          isFalse,
          reason: 'an unreferenced stale kernel dir is swept — out:\n$out',
        );
      } finally {
        child.kill();
        await child.exitCode;
      }
      expect(firstRunRan, isTrue);

      // Once the holder exited, the dir is plain stale garbage — the
      // NEXT cycle's start-of-cycle sweep reclaims it.
      final out2 = await runRefactor();
      expect(exitCode, 0, reason: out2);
      expect(
        heldDir.existsSync(),
        isFalse,
        reason:
            'the kernel dir is reclaimed by the next cycle once its '
            'holder is gone — out:\n$out2',
      );
    });
  }, timeout: const Timeout(Duration(minutes: 4)));
}
