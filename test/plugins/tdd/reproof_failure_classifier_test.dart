// Spec 1333 — pure re-proof failure classifier unit contract.
//
// The refactor re-proof (issue #1333) must classify a FAILED re-proof
// attempt into exactly one of: infra-level runner failure (transient dart
// test kernel-cache race: exit 255, "Cannot retrieve length of file",
// dart_test.kernel ENOENT; process never started; per-command timeout) or
// regression (genuine assertion failure / unparseable non-infra red).
// Infra failures are retried with a kernel-cache clear; regressions are
// immediate. Pure function — no I/O, no subprocesses.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/reproof_failure_classifier.dart';

void main() {
  group('classifyReproofFailure — infra tier (FR-1 / AS-5)', () {
    test('exit 255 with no other signature is infra (runner crash)', () {
      final cls = classifyReproofFailure(
        exitCode: 255,
        output: 'Unhandled exception: kernel binary corrupt',
        startedProcess: true,
      );
      expect(cls, ReproofFailureClass.infraRunner);
    });

    test('the issue #1333 signature: "Cannot retrieve length of file" + '
        'dart_test.kernel .dill errno 2', () {
      const transcript = '''
00:00 +0: loading test/probe_test.dart
Failed to load "test/probe_test.dart":
Cannot retrieve length of file: /tmp/dart_test.kernel./probe_test.dart_.dill (errno 2)
''';
      final cls = classifyReproofFailure(
        exitCode: 255,
        output: transcript,
        startedProcess: true,
      );
      expect(cls, ReproofFailureClass.infraRunner);
    });

    test('kernel-cache ENOENT alone (any exit) is infra', () {
      final cls = classifyReproofFailure(
        exitCode: 1,
        output:
            'Cannot retrieve length of file: /tmp/dart_test.kernel.x.dill '
            '(errno 2 — No such file)',
        startedProcess: true,
      );
      expect(cls, ReproofFailureClass.infraRunner);
    });

    test('.dill + ENOENT without the canonical sentence is infra', () {
      final cls = classifyReproofFailure(
        exitCode: 253,
        output: 'error opening /tmp/dart_test.kernel/main.dill: ENOENT',
        startedProcess: true,
      );
      expect(cls, ReproofFailureClass.infraRunner);
    });

    test('dart_test.kernel requires crash evidence on the same line', () {
      expect(
        hasKernelCacheSignature(
          'test name mentions dart_test.kernel\nNo such file on a later line',
        ),
        isFalse,
      );
      expect(
        hasKernelCacheSignature('Failed to open dart_test.kernel.worker'),
        isTrue,
      );
    });

    test('process never started is infra (runner cannot launch)', () {
      final cls = classifyReproofFailure(
        exitCode: -1,
        output: 'Failed to start "definitely_not_a_real_binary": ...',
        startedProcess: false,
      );
      expect(cls, ReproofFailureClass.infraRunner);
    });

    test('per-command timeout is infra (bug #742 tier)', () {
      final cls = classifyReproofFailure(
        exitCode: -1,
        output: 'ProcessTimeoutException: suite exceeded 10m',
        startedProcess: true,
        timedOut: true,
      );
      expect(cls, ReproofFailureClass.infraRunner);
    });
  });

  group('classifyReproofFailure — regression tier (FR-4 / AS-5)', () {
    test(
      'exit 1 with parseable failing-test names is a genuine regression',
      () {
        const transcript = '''
00:00 +0 -1: probe behavior broke [E]
Expected: true
  Actual: false
00:00 +0 -1: Some tests failed.
''';
        final cls = classifyReproofFailure(
          exitCode: 1,
          output: transcript,
          startedProcess: true,
        );
        expect(cls, ReproofFailureClass.regression);
      },
    );

    test('exit 1 with an unparseable transcript stays a regression '
        '(bug #922 mutation M2 guard)', () {
      final cls = classifyReproofFailure(
        exitCode: 1,
        output: 'boom — re-proof transcript is unparseable',
        startedProcess: true,
      );
      expect(cls, ReproofFailureClass.regression);
    });

    test(
      'any other non-zero exit without an infra signature is a regression',
      () {
        final cls = classifyReproofFailure(
          exitCode: 79,
          output: 'No tests match regular expression.',
          startedProcess: true,
        );
        expect(cls, ReproofFailureClass.regression);
      },
    );
  });

  group('classifyReproofFailure — poison test-name progress line (bug #1524)', () {
    // The progress line `dart test` prints for the classifier's OWN passing
    // test above (the group + test name quote the issue #1333 signature).
    // Every full-suite re-proof transcript contains it — it must never be
    // crash evidence for a genuinely red re-proof.
    const poisonProgressLine =
        '10:22 +2918 ~1: test/plugins/tdd/reproof_failure_classifier_test.dart: '
        'classifyReproofFailure — infra tier (FR-1 / AS-5) the issue #1333 '
        'signature: "Cannot retrieve length of file" + dart_test.kernel .dill '
        'errno 2';

    test('hasKernelCacheSignature ignores a reporter progress line', () {
      expect(hasKernelCacheSignature(poisonProgressLine), isFalse);
    });

    test('a genuine red re-proof with the poison line stays a regression', () {
      const transcript =
          '''
$poisonProgressLine
00:01 +2918 -1: test/some_test.dart: a real regression [E]
  Expected: 2
    Actual: 1
00:01 +2918 -1: Some tests failed.
''';
      final cls = classifyReproofFailure(
        exitCode: 1,
        output: transcript,
        startedProcess: true,
      );
      expect(cls, ReproofFailureClass.regression);
    });

    test('kernelCacheSignatureLine finds no signature in a poisoned red', () {
      const transcript =
          '''
$poisonProgressLine
00:01 +2918 -1: test/some_test.dart: a real regression [E]
  Expected: 2
    Actual: 1
00:01 +2918 -1: Some tests failed.
''';
      expect(kernelCacheSignatureLine(transcript), isNull);
    });

    test('the canonical crash line is still infra next to the poison line', () {
      // Progress-line skipping must not swallow genuine crash evidence.
      const transcript =
          '''
00:00 +2918: loading test/probe_test.dart
Failed to load "test/probe_test.dart":
Cannot retrieve length of file: /tmp/dart_test.kernel./probe_test.dart_.dill (errno 2)
$poisonProgressLine
''';
      final cls = classifyReproofFailure(
        exitCode: 255,
        output: transcript,
        startedProcess: true,
      );
      expect(cls, ReproofFailureClass.infraRunner);
    });

    test(
      'bare phrase without crash evidence on the same line is not infra',
      () {
        expect(
          hasKernelCacheSignature(
            'a quoted log says: cannot retrieve length of file — nothing else',
          ),
          isFalse,
        );
      },
    );
  });

  group('parseFailingTestNames', () {
    test('extracts sorted de-duped names from [E] lines', () {
      const transcript = '''
00:00 +0 -1: zeta behavior [E]
00:00 +0 -2: alpha behavior [E]
00:00 +0 -2: zeta behavior [E]
''';
      expect(parseFailingTestNames(transcript), [
        'alpha behavior',
        'zeta behavior',
      ]);
    });

    test('returns empty for transcripts without [E] lines', () {
      expect(parseFailingTestNames('boom — nothing parseable'), isEmpty);
    });
  });

  group('reproofOutputTail (FR-3)', () {
    test('short transcripts pass through trimmed', () {
      expect(reproofOutputTail('  line1\nline2  '), 'line1\nline2');
    });

    test('long transcripts truncate to whole lines with a marker', () {
      final long = List.generate(50, (i) => 'line $i ${'x' * 80}').join('\n');
      final tail = reproofOutputTail(long, maxChars: 500);
      expect(tail.startsWith('...(truncated)'), isTrue, reason: tail);
      expect(tail.length, lessThanOrEqualTo(600));
      // Whole lines only: no cut in the middle of a line.
      final body = tail.split('\n').skip(1).join('\n');
      expect(body.startsWith('line '), isTrue, reason: tail);
      expect(body.endsWith('line 49 ${'x' * 80}'), isTrue, reason: tail);
    });
  });
}
