@TestOn('linux || mac-os')
@Tags(['regression'])
// Spec 1520 — the refactor command's per-run scratch TMPDIR (issue #1520).
//
// `tdd refactor` is a driving command (kernel_cache.dart's own header names
// it alongside `tdd run`), so its suite children leaked
// `$TMPDIR/dart_test.kernel.<random>/` into the SHARED user TMPDIR exactly
// like the run command's step children did — in the command whose loops
// historically ran longest (#1507: 51 GB in ~80 minutes). This suite pins
// the wiring:
//
//   B15 — every suite child of ONE refactor invocation observes the SAME
//         fresh `zfa-<feature>-<random>` TMPDIR, and that scratch does not
//         exist after the invocation completes (FR-1/FR-3).
//
// The preflight/re-proof suite template is a spy script (no real `dart
// test`), while the pass registry runs for real against the fixture — the
// same subprocess contract the existing refactor suite exercises.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  late Directory spyDir;
  late File tmpdirReceipt;
  late String fakeZfa;

  setUp(() async {
    spyDir = await Directory.systemTemp.createTemp('zfa1520-refactor-spy-');
    tmpdirReceipt = File(p.join(spyDir.path, 'tmpdir-receipt.log'))
      ..writeAsStringSync('');
    // A stand-in suite runner: records the TMPDIR it observes, then exits
    // green so the refactor proceeds through its pass registry + re-proof.
    final spy = File(p.join(spyDir.path, 'suite-spy.sh'))
      ..writeAsStringSync(
        '#!/bin/sh\n'
        'printf \'TMPDIR=%s\\n\' "\$TMPDIR" >> "${tmpdirReceipt.path}"\n'
        'exit 0\n',
      );
    Process.runSync('chmod', ['+x', spy.path]);

    fx = await TddFixture.create(suiteTemplate: spy.path);
    await fx.seedAlreadyCleanLib();
    fakeZfa = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);
  });

  tearDown(() {
    fx.dispose();
    if (spyDir.existsSync()) spyDir.deleteSync(recursive: true);
    exitCode = 0;
  });

  group('bug #1520: the refactor command drives its suite children inside a '
      'per-run scratch TMPDIR', () {
    test('B15: the preflight and re-proof observe the same fresh '
        'zfa-<feature>-* scratch, deleted at invocation end', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'refactor',
        '--project',
        fx.root.path,
        '--feature',
        fx.featureName,
        '--zfa-bin',
        fakeZfa,
      ]);

      expect(exitCode, 0, reason: out);

      final lines = tmpdirReceipt
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      expect(
        lines,
        isNotEmpty,
        reason:
            'the refactor must run its preflight and re-proof suites — '
            'out:\n$out',
      );

      final observed = lines.map((l) => l.substring('TMPDIR='.length)).toSet();
      expect(
        observed.length,
        1,
        reason:
            'one scratch dir per invocation — the preflight and every '
            're-proof of the cycle observe the SAME TMPDIR',
      );

      final scratch = observed.first;
      expect(
        p.basename(scratch),
        startsWith('zfa-${fx.featureName}-'),
        reason:
            'the scratch is a fresh per-run dir named zfa-<feature>-<rand>; '
            'pre-fix the suite children observed the shared user TMPDIR '
            '(${Directory.systemTemp.path})',
      );
      expect(
        Directory(scratch).existsSync(),
        isFalse,
        reason:
            'the refactor deleted its own scratch at invocation end '
            '(spec 1520 FR-3)',
      );
    });
  }, timeout: const Timeout(Duration(minutes: 4)));
}
