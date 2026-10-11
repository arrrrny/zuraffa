// Bug #1159: the TDD pipeline's `--timeout` override must be ONE uniform
// deadline (bug #742 contract). The driver dropped it for the run-level
// suite baseline, the spawned step children, and make's fallback live
// baseline — so on repos whose fast suite outlives the hardcoded 10-minute
// defaultSuite, the baseline child was SIGKILLed, no run-baseline.json was
// written, and every `tdd make` refused with runner-error.
//
// These tests pin the two plumbing surfaces the fix touches:
//   1. StepRunner forwards the driver's deadline to spawned step children
//      via `--timeout` (absent when the default applies — no behavior
//      change for small repos).
//   2. SingleTestRunner.runSuite honors the passed deadline (fractional
//      minutes are accepted and enforced, per parseTddTimeoutMinutes).
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/step_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/tdd_timeout.dart';

void main() {
  group('bug #1159: step children inherit the driver deadline', () {
    (StepRunner, List<List<String>>) runnerWith({Duration? timeout}) {
      final commands = <List<String>>[];
      Future<ProcessResult> spawner(
        List<String> command,
        String workingDirectory,
      ) {
        commands.add(command);
        return Future.value(ProcessResult(0, 0, 'outcome=green\n', ''));
      }

      final runner = StepRunner(
        zfaBin: '/fake/bin/zfa',
        spawner: spawner,
        timeout: timeout,
      );
      return (runner, commands);
    }

    test(
      'U3: a non-default deadline is forwarded as --timeout on make steps',
      () async {
        final (runner, commands) = runnerWith(
          timeout: const Duration(minutes: 30),
        );

        await runner.run(
          step: 'make',
          behaviorId: 'A1',
          feature: 'bug-tdd-run-baseline-timeout',
          projectRoot: '/tmp/proj',
        );

        final argv = commands.single;
        final timeoutIndex = argv.indexOf('--timeout');
        expect(timeoutIndex, greaterThanOrEqualTo(0), reason: '$argv');
        expect(double.parse(argv[timeoutIndex + 1]), closeTo(30, 0.0001));
      },
    );

    test('U3/U4: the default deadline is NOT forwarded (small-repo behavior '
        'unchanged)', () async {
      final (runner, commands) = runnerWith();

      await runner.run(
        step: 'make',
        behaviorId: 'A1',
        feature: 'bug-tdd-run-baseline-timeout',
        projectRoot: '/tmp/proj',
      );

      expect(commands.single, isNot(contains('--timeout')));
    });

    test('U3: refactor steps inherit the deadline too', () async {
      final (runner, commands) = runnerWith(
        timeout: const Duration(minutes: 12, seconds: 30),
      );

      await runner.run(
        step: 'refactor',
        behaviorId: 'A1',
        feature: 'bug-tdd-run-baseline-timeout',
        projectRoot: '/tmp/proj',
      );

      final argv = commands.single;
      final timeoutIndex = argv.indexOf('--timeout');
      expect(timeoutIndex, greaterThanOrEqualTo(0), reason: '$argv');
      expect(double.parse(argv[timeoutIndex + 1]), closeTo(12.5, 0.0001));
    });
  });

  group('bug #1159: runSuite honors the passed deadline', () {
    test('U1/U2: a suite that outlives defaultSuite-class deadlines completes '
        'when the override allows it and is killed when it does not', () async {
      final runner = const SingleTestRunner();

      // `sleep 2` outlives a 0.5-second deadline but fits a 30-second
      // one — the same shape as a >10-minute suite under --timeout 25.
      final slow = await runner.runSuite(
        suiteTemplate: 'sleep 2',
        workingDirectory: Directory.systemTemp.path,
        timeout: const Duration(milliseconds: 500),
      );
      expect(slow.timedOut, isTrue, reason: slow.output);
      expect(slow.exitCode, -1);

      final allowed = await runner.runSuite(
        suiteTemplate: 'sleep 2',
        workingDirectory: Directory.systemTemp.path,
        timeout: const Duration(seconds: 30),
      );
      expect(allowed.timedOut, isFalse, reason: allowed.output);
      expect(allowed.exitCode, 0);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('U4: parseTddTimeoutMinutes keeps the 10-minute default shape', () {
      expect(parseTddTimeoutMinutes('10'), TddTimeouts.defaultSuite);
      expect(parseTddTimeoutMinutes('0.5'), const Duration(seconds: 30));
      expect(parseTddTimeoutMinutes(null), isNull);
    });
  });
}
