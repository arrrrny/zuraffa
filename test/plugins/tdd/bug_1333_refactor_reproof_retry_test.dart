@Tags(['slow', 'regression'])
// Spec 1333 — the refactor re-proof must classify transient dart test
// runner failures (the incremental kernel-cache race: exit 255, "Cannot
// retrieve length of file", dart_test.kernel ENOENT) as INFRA, retry the
// re-proof with a kernel-cache clear, and record the verdict + transcript
// tail in cycle-log.md on EVERY verdict — instead of reporting a false
// regression with zero diagnostics.
//
// Fixture discipline (bug #922 two-phase pattern): the suite template is a
// counting shell script — preflight green, re-proof scripted per scenario.
// Invocation counts are read from the counter file; kernel-cache clear is
// proven via pre-seeded markers that only the retry may delete.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  late String fakeZfa;
  late File counter;
  late List<File> tmpKernelMarkers;

  /// Write a counting suite script. [when] is the `test` operator applied
  /// to the invocation number (the preflight is always invocation 1);
  /// [failBranch] is the `sh` body that runs when the condition holds.
  Future<String> writeCountingSuite(
    String name, {
    required String when,
    required String failBranch,
  }) async {
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
if test \$N __WHEN__; then
__FAILBRANCH__
fi
exit 0
''';
    await File(scriptPath).writeAsString(
      template
          .replaceAll('__COUNTER__', counter.path)
          .replaceAll('__WHEN__', when)
          .replaceAll('__FAILBRANCH__', failBranch),
    );
    Process.runSync('chmod', ['+x', scriptPath]);
    return scriptPath;
  }

  /// Pre-seed the two kernel-cache markers the retry's cache clear must
  /// remove: `<project>/.dart_tool/test/probe.kernel` and a
  /// `$TMPDIR/dart_test.kernel.<unique>` file.
  File tmpKernelMarker(String unique) {
    final tmpRoot =
        Platform.environment['TMPDIR'] ??
        Platform.environment['TEMP'] ??
        Platform.environment['TMP'] ??
        Directory.systemTemp.path;
    final marker = File(p.join(tmpRoot, 'dart_test.kernel.bug1333-$unique'));
    if (!tmpKernelMarkers.any((candidate) => candidate.path == marker.path)) {
      tmpKernelMarkers.add(marker);
    }
    return marker;
  }

  Future<void> seedKernelMarkers(String unique) async {
    await Directory(
      p.join(fx.root.path, '.dart_tool', 'test'),
    ).create(recursive: true);
    File(
      p.join(fx.root.path, '.dart_tool', 'test', 'probe.kernel'),
    ).writeAsStringSync('stale kernel bytes');
    final marker = tmpKernelMarker(unique)
      ..writeAsStringSync('stale tmp kernel bytes');
    // Spec 1520: the janitor's age floor never sweeps a
    // `$TMPDIR/dart_test.kernel.*` entry younger than ~1 hour (it may
    // belong to a concurrent runner, or to a crashed run about to be
    // re-read). The markers model HISTORICAL leaks, so their mtime is
    // backdated past the floor — the same fixture discipline the #1507
    // suite's backdated seeders use.
    marker.setLastModifiedSync(
      DateTime.now().subtract(const Duration(hours: 1, minutes: 1)),
    );
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

  setUp(() async {
    fx = await TddFixture.create(featureName: '090-tdd-fixture');
    fakeZfa = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);
    counter = File(p.join(fx.root.path, '.zfa_suite_count'));
    counter.writeAsStringSync('0');
    tmpKernelMarkers = [];
    exitCode = 0;
  });

  tearDown(() {
    for (final marker in tmpKernelMarkers) {
      if (marker.existsSync()) marker.deleteSync();
    }
    fx.dispose();
    exitCode = 0;
  });

  group('infra re-proof failure is retried, not a regression (spec 1333)', () {
    test('B3: one infra failure (exit 255 + kernel signature) is retried '
        'with a kernel-cache clear and the run completes green', () async {
      await seedKernelMarkers('retry');
      final concurrentMarker = tmpKernelMarker('concurrent');
      final kernelRace =
          '''
echo Cannot retrieve length of file: /tmp/dart_test.kernel./probe_test.dart_.dill errno 2 >&2
echo active kernel bytes > '${concurrentMarker.path}'
exit 255
''';
      final suite = await writeCountingSuite(
        'flaky-suite',
        when: '-eq 2',
        failBranch: kernelRace,
      );
      await fx.rewriteProfile(
        singleTemplate: TddFixture.defaultSingleTemplate,
        suiteTemplate: suite,
      );
      await fx.seedAlreadyCleanLib();

      final out = await runRefactor();

      // The retry recovered: green outcome, exit 0.
      expect(out, contains(RegExp(r'outcome=(clean|refactored)')), reason: out);
      expect(
        counter.readAsStringSync().trim(),
        '3',
        reason: 'preflight + re-proof + ONE retry, saw: $out',
      );
      expect(
        exitCode,
        0,
        reason: 'a transient infra failure must not fail the refactor',
      );
      // The cache clear fired before the retry: both markers are gone.
      expect(
        File(
          p.join(fx.root.path, '.dart_tool', 'test', 'probe.kernel'),
        ).existsSync(),
        isFalse,
        reason: '.dart_tool/test/ must be cleared before the retry',
      );
      expect(
        tmpKernelMarker('retry').existsSync(),
        isFalse,
        reason: r'$TMPDIR/dart_test.kernel.* must be cleared',
      );
      expect(
        concurrentMarker.existsSync(),
        isTrue,
        reason: 'a kernel file created during this command may be in use',
      );
      final log = await File(fx.cycleLogPath).readAsString();
      expect(log, contains('re-proof verdict: green (exit 0)'));
      expect(log, contains('re-proof retries: 1'));
    });

    test('B4: infra failures exhausting the retries yield runner-error, '
        'never regression, with a full diagnostic record', () async {
      await seedKernelMarkers('exhaust');
      const kernelRaceEveryTime = '''
echo Cannot retrieve length of file: /tmp/dart_test.kernel./probe_test.dart_.dill errno 2 >&2
exit 255
''';
      final suite = await writeCountingSuite(
        'infra-suite',
        when: '-ge 2',
        failBranch: kernelRaceEveryTime,
      );
      await fx.rewriteProfile(
        singleTemplate: TddFixture.defaultSingleTemplate,
        suiteTemplate: suite,
      );
      await fx.seedAlreadyCleanLib();

      final out = await runRefactor();

      expect(out, contains('outcome=runner-error'), reason: out);
      expect(out, isNot(contains('outcome=regression')), reason: out);
      expect(exitCode, isNot(0), reason: 'exhausted retries still fail');
      expect(
        counter.readAsStringSync().trim(),
        '4',
        reason: 'preflight + initial re-proof + 2 retries',
      );
      final log = await File(fx.cycleLogPath).readAsString();
      // NOT a regression — the outcome tier is runner-error.
      expect(log, contains('re-proof verdict: infra-runner-error (exit 255)'));
      expect(log, contains('re-proof retries: 2'));
      // The transcript tail makes the failure auditable.
      expect(log, contains('re-proof output tail (stdout+stderr, truncated):'));
      expect(log, contains('Cannot retrieve length of file'));
    });

    test('B5: a genuine assertion failure regresses IMMEDIATELY — no retry, '
        'and the cycle log records the diagnostic (exit 1 + tail)', () async {
      await seedKernelMarkers('assert');
      const assertionRed = '''
echo 00:00 +0 -1: probe behavior broke [E]
echo Expected: true
echo Actual: false
echo 00:00 +0 -1: Some tests failed.
exit 1
''';
      final suite = await writeCountingSuite(
        'assert-suite',
        when: '-eq 2',
        failBranch: assertionRed,
      );
      await fx.rewriteProfile(
        singleTemplate: TddFixture.defaultSingleTemplate,
        suiteTemplate: suite,
      );
      await fx.seedAlreadyCleanLib();

      final out = await runRefactor();

      expect(out, contains('outcome=regression'), reason: out);
      expect(exitCode, isNot(0));
      expect(
        counter.readAsStringSync().trim(),
        '2',
        reason: 'genuine regression: NO retry (preflight + re-proof)',
      );
      // The failure path now records diagnostics (issue #1333: the failed
      // re-proof cycle was never appended to cycle-log.md).
      final log = await File(fx.cycleLogPath).readAsString();
      expect(log, contains('re-proof verdict: regression (exit 1)'));
      expect(log, contains('re-proof retries: 0'));
      expect(log, contains('re-proof output tail (stdout+stderr, truncated):'));
      expect(log, contains('probe behavior broke'));
      // Issue #1507: the cycle-start kernel sweep now clears stale kernel
      // entries on EVERY path — including the regression path — so the
      // seeded markers are gone by the time the regression verdict lands.
      // The regression contract itself is unchanged: no RETRY machinery
      // fired (counter == 2 above); the sweep is housekeeping, not retry.
      expect(
        File(
          p.join(fx.root.path, '.dart_tool', 'test', 'probe.kernel'),
        ).existsSync(),
        isFalse,
      );
      expect(tmpKernelMarker('assert').existsSync(), isFalse);
    });

    test('B6: a clean green no-op records the re-proof verdict line and '
        'tail in the evidence entry', () async {
      await fx.seedAlreadyCleanLib();
      // Default suite template (real `dart test` on the fixture's single
      // green test) — the plain A9 scenario.

      await runRefactor();

      expect(exitCode, 0);
      final log = await File(fx.cycleLogPath).readAsString();
      expect(log, contains('- no-op: true'));
      expect(log, contains('re-proof verdict: green (exit 0)'));
      expect(log, contains('re-proof retries: 0'));
      expect(log, contains('re-proof output tail (stdout+stderr, truncated):'));
    });
  }, timeout: const Timeout(Duration(minutes: 8)));
}
