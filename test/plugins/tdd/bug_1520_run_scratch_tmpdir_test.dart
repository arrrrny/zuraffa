@TestOn('linux || mac-os')
@Tags(['regression'])
// Spec 1520 — the run command's per-run scratch TMPDIR, end to end
// (issue #1520).
//
// `zfa tdd run` drives every behavior through `StepRunner`-spawned step
// children. Before spec 1520 every child inherited `Platform.environment`,
// so every `dart test` grandchild leaked its
// `$TMPDIR/dart_test.kernel.<random>/` kernel dir into the SHARED user
// TMPDIR — where any agent's janitor sweep could delete another agent's
// actively-compiling kernel (#1507's hazard, by construction impossible to
// guard perfectly).
//
// Contract pinned here (spec 1520 SC-1/SC-2, FR-1/FR-3/FR-6):
//   B8 — every step child of ONE run observes the SAME fresh
//        `zfa-<feature>-<random>` TMPDIR (one scratch per invocation), and
//        that scratch does not exist after the run completes (best-effort
//        run-end cleanup in a finally).
//   B9 — with `.zfa.json` `tdd.tmpDir` naming a scratch root, the run's
//        scratch is created INSIDE that root and is cleaned at run end.
//
// Fixture discipline (the bug #922/#1507 pattern): the fixture's fake zfa
// drives a healthy green cycle; a thin wrapper around it records the
// child-observed TMPDIR per invocation so the scratch contract is provable
// without touching the real user TMPDIR.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  late File tmpdirReceipt;

  /// Wrap the fixture's fake zfa so every step child ALSO records the
  /// TMPDIR it observed, then execs the real fake (the green-cycle
  /// contract stays byte-identical to the #1507 suite's).
  Future<void> wrapFakeZfaWithEnvSpy() async {
    await Directory(fx.spyDir).create(recursive: true);
    final original = File(fx.fakeZfaBin);
    final real = File('${fx.fakeZfaBin}.real');
    real.writeAsStringSync(original.readAsStringSync());
    Process.runSync('chmod', ['+x', real.path]);
    final wrapper = File(fx.fakeZfaBin)
      ..writeAsStringSync(
        '#!/bin/sh\n'
        'printf \'TMPDIR=%s\\n\' "\$TMPDIR" >> "${tmpdirReceipt.path}"\n'
        'exec "${real.path}" "\$@"\n',
      );
    Process.runSync('chmod', ['+x', wrapper.path]);
  }

  Future<int> runFeature() async {
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
    return exitCode;
  }

  setUp(() async {
    fx = await TddFixture.create(featureName: '090-tdd-fixture');
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
    await fx.seedAlreadyCleanLib();
    await fx.writeFakeZfa();
    await Directory(fx.spyDir).create(recursive: true);
    tmpdirReceipt = File(p.join(fx.spyDir, 'tmpdir-receipt.log'))
      ..writeAsStringSync('');
    await wrapFakeZfaWithEnvSpy();
    exitCode = 0;
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('bug #1520: the run command drives its children inside a per-run '
      'scratch TMPDIR', () {
    test('B8: every step child observes the same fresh zfa-<feature>-* '
        'scratch and the scratch is deleted at run end', () async {
      await runFeature();

      final lines = tmpdirReceipt
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      expect(lines, isNotEmpty,
          reason: 'the run must spawn step children (gen/verify-red/make/'
              'refactor per behavior) — out receipt:\n${lines.join('\n')}');

      final observed = lines.map((l) => l.substring('TMPDIR='.length)).toSet();
      expect(observed.length, 1,
          reason: 'one scratch dir per invocation — every child of the run '
              'observes the SAME TMPDIR');

      final scratch = observed.first;
      expect(
        p.basename(scratch),
        startsWith('zfa-090-tdd-fixture-'),
        reason:
            'the scratch is a fresh per-run dir named zfa-<feature>-<rand>; '
            'pre-fix the children observed the shared user TMPDIR '
            '(${Directory.systemTemp.path}) — receipt:\n${lines.join('\n')}',
      );
      expect(Directory(scratch).existsSync(), isFalse,
          reason: 'the run deleted its own scratch at run end (FR-3)');
    });

    test('B9: .zfa.json tdd.tmpDir names the scratch root and the scratch '
        'is still cleaned at run end', () async {
      final cfgRoot =
          Directory.systemTemp.createTempSync('zfa1520-cfg-root-');
      addTearDown(() {
        if (cfgRoot.existsSync()) cfgRoot.deleteSync(recursive: true);
      });
      File(p.join(fx.root.path, '.zfa.json')).writeAsStringSync(
        '{"tdd": {"tmpDir": "${cfgRoot.path}"}}',
      );

      await runFeature();

      final lines = tmpdirReceipt
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      expect(lines, isNotEmpty);

      final scratch = lines.first.substring('TMPDIR='.length);
      expect(p.dirname(scratch), cfgRoot.path,
          reason:
              'the configured scratch root (.zfa.json tdd.tmpDir) holds the '
              'per-run scratch (FR-6 / SC-2)');
      expect(p.basename(scratch), startsWith('zfa-090-tdd-fixture-'));
      expect(Directory(scratch).existsSync(), isFalse,
          reason: 'the scratch is deleted at run end even under a '
              'configured root (FR-3)');
    });
  }, timeout: const Timeout(Duration(minutes: 4)));
}
