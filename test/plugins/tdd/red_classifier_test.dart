// Tests for the RedClassification model and the pure `classify` function
// plus `parseExecutedTestCount` (spec 046-tdd-verify-red, U1-U10 / T003,
// T004, T006, T011).
//
// The canned outputs below are captured from real `dart test` runs
// (assertion, skip, green, blended, compile-error, load-error, timeout,
// uncaught error) so the classifier is graded against the runner's actual
// grammar, not a paraphrase of it.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/red_classification.dart';
import 'package:zuraffa/src/plugins/tdd/services/red_classifier.dart';

void main() {
  // ------------------------------------------------------------------
  // Captured runner outputs (dart test, 3.13).
  // ------------------------------------------------------------------

  const assertionOutput = '''
00:00 +0: loading b_001_test.dart
00:00 +0: returns 42 when invoked with no args
00:00 +0 -1: returns 42 when invoked with no args [E]
  Expected: <2>
    Actual: <1>

  package:matcher           expect
  b_001_test.dart 3:23      main.<fn>

00:00 +0 -1: Some tests failed.

Failing tests:
  b_001_test.dart: returns 42 when invoked with no args
''';

  // package:test's reporter grammar is shared by `flutter test`.
  const flutterAssertionOutput = '''
00:01 +0: loading test/b_001_test.dart
00:01 +0 -1: returns 42 when invoked with no args [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: not implemented>

00:01 +0 -1: Some tests failed.
''';

  const greenOutput = '''
00:00 +0: loading b_001_test.dart
00:00 +0: returns 42 when invoked with no args
00:00 +1: All tests passed!
''';

  const skippedOutput = '''
00:00 +0: loading b_001_test.dart
00:00 +0: returns 42 when invoked with no args
  Skip: not ready
00:00 +0 ~1: All tests skipped.
''';

  const loadErrorMissingFileOutput = '''
00:00 +0: loading b_001_test.dart
00:00 +0 -1: loading b_001_test.dart [E]
  Failed to load "b_001_test.dart": Does not exist.
00:00 +0 -1: Some tests failed.

Failing tests:
  b_001_test.dart: loading b_001_test.dart
''';

  const loadErrorMissingImportOutput = '''
00:00 +0: loading b_001_test.dart
00:00 +0 -1: loading b_001_test.dart [E]
  Failed to load "b_001_test.dart":
  b_001_test.dart:2:8: Error: Error when reading 'missing_subject.dart': No such file or directory
  import 'missing_subject.dart';
         ^
00:00 +0 -1: Some tests failed.
''';

  const compileErrorOutput = '''
00:00 +0: loading b_001_test.dart
00:00 +0 -1: loading b_001_test.dart [E]
  Failed to load "b_001_test.dart":
  b_001_test.dart:3:23: Error: Method not found: 'undefinedFunctionHere'.
    test('returns 42 when invoked with no args', () { undefinedFunctionHere(); });
                        ^^^^^^^^^^^^^^^^^^^^^
00:00 +0 -1: Some tests failed.

Failing tests:
  b_001_test.dart: loading b_001_test.dart
''';

  // Flutter-shaped compile diagnostics: CFE output without the
  // "Failed to load" wrapper.
  const bareCompileOutput = '''
Error: Couldn't resolve the package 'test' into a compilation unit.
b_001_test.dart:1:14: Error: Undefined name 'undefinedThing'.
Compilation failed.
''';

  const blendedOutput = '''
00:00 +0: loading b_001_test.dart
00:00 +0: returns 42 when invoked with no args
00:00 +0 -1: returns 42 when invoked with no args [E]
  Expected: <2>
    Actual: <1>

00:00 +0 -1: returns 41 when invoked with no args
00:00 +0 -2: returns 41 when invoked with no args [E]
  Expected: <2>
    Actual: <1>

00:00 +0 -2: Some tests failed.

Failing tests:
  b_001_test.dart: returns 42 when invoked with no args
  b_001_test.dart: returns 41 when invoked with no args
''';

  const uncaughtErrorOutput = '''
00:00 +0: loading b_001_test.dart
00:00 +0: returns 42 when invoked with no args
00:00 +0 -1: returns 42 when invoked with no args [E]
  Bad state: boom
  b_001_test.dart 3:23  main.<fn>

00:00 +0 -1: Some tests failed.
''';

  const timeoutOutput = '''
00:00 +0: loading b_001_test.dart
00:00 +0: returns 42 when invoked with no args
00:01 +0 -1: returns 42 when invoked with no args [E]
  TimeoutException after 0:00:01.000000: Test timed out after 1 seconds.
  dart:isolate  _RawReceivePort._handleMessage

00:01 +0 -1: Some tests failed.
''';

  RunRecord record(
    String output, {
    required int exitCode,
    bool startedProcess = true,
    int? testCount,
    String command = 'dart test <file> --plain-name "<name>"',
  }) => RunRecord(
    command: command,
    exitCode: exitCode,
    output: output,
    startedProcess: startedProcess,
    testCount: testCount,
  );

  group('U1 — assertion signature classifies assertion', () {
    test('dart shape: non-zero exit, Expected/Actual pair, one test', () {
      final result = classify(
        record(assertionOutput, exitCode: 1, testCount: 1),
      );
      expect(result, RedClassification.assertion);
    });

    test(
      'flutter shape: Expected: not <...> with UnimplementedError actual',
      () {
        final result = classify(
          record(flutterAssertionOutput, exitCode: 1, testCount: 1),
        );
        expect(result, RedClassification.assertion);
      },
    );
  });

  group('U2 — exit 0 with no skip markers classifies unexpected-green', () {
    test('single passing test', () {
      final result = classify(record(greenOutput, exitCode: 0, testCount: 1));
      expect(result, RedClassification.unexpectedGreen);
    });
  });

  group('U3 — exit 0 with all tests skipped classifies skipped', () {
    test('single skipped test', () {
      final result = classify(record(skippedOutput, exitCode: 0, testCount: 1));
      expect(result, RedClassification.skipped);
    });
  });

  group('U4 — load signatures classify load-error', () {
    test('missing test file: Failed to load / Does not exist', () {
      final result = classify(
        record(loadErrorMissingFileOutput, exitCode: 1, testCount: 1),
      );
      expect(result, RedClassification.loadError);
    });

    test('missing import: Failed to load / Error when reading', () {
      final result = classify(
        record(loadErrorMissingImportOutput, exitCode: 1, testCount: 1),
      );
      expect(result, RedClassification.loadError);
    });
  });

  group('U5 — CFE diagnostics classify compile-error', () {
    test('compile error wrapped in Failed to load', () {
      final result = classify(
        record(compileErrorOutput, exitCode: 1, testCount: 1),
      );
      expect(result, RedClassification.compileError);
    });

    test('bare CFE diagnostics without the load wrapper (flutter shape)', () {
      final result = classify(
        record(bareCompileOutput, exitCode: 1, testCount: 1),
      );
      expect(result, RedClassification.compileError);
    });
  });

  group('U6 — process failed to start classifies runner-error', () {
    test('startedProcess=false dominates everything else', () {
      final result = classify(
        record('anything at all', exitCode: -1, startedProcess: false),
      );
      expect(result, RedClassification.runnerError);
    });
  });

  group('U7 — testCount != 1 classifies runner-error (blended run)', () {
    test('two tests executed even with assertion signatures', () {
      final result = classify(record(blendedOutput, exitCode: 1, testCount: 2));
      expect(result, RedClassification.runnerError);
    });

    test('zero tests executed (filter matched nothing)', () {
      final result = classify(
        record(
          '00:00 +0: loading b_001_test.dart\nNo tests ran.\n'
          'No tests match "nope".\n',
          exitCode: 79,
          testCount: 0,
        ),
      );
      expect(result, RedClassification.runnerError);
    });

    test('unparseable count is not honest evidence of a single run', () {
      final result = classify(record('gibberish', exitCode: 1));
      expect(result, RedClassification.runnerError);
    });
  });

  group('U8 — load/compile signature beats the count guard', () {
    test('load signature with count 2 still classifies load-error', () {
      final result = classify(
        record(loadErrorMissingFileOutput, exitCode: 1, testCount: 2),
      );
      expect(result, RedClassification.loadError);
    });

    test('compile signature with count 2 still classifies compile-error', () {
      final result = classify(
        record(compileErrorOutput, exitCode: 1, testCount: 2),
      );
      expect(result, RedClassification.compileError);
    });
  });

  group('U9 — unexplained red is not honest red', () {
    test('uncaught StateError without assertion signature -> runner-error', () {
      final result = classify(
        record(uncaughtErrorOutput, exitCode: 1, testCount: 1),
      );
      expect(result, RedClassification.runnerError);
    });

    test('timeout failure -> runner-error', () {
      final result = classify(record(timeoutOutput, exitCode: 1, testCount: 1));
      expect(result, RedClassification.runnerError);
    });
  });

  group('U10 — fixed precedence when signatures co-occur', () {
    test('runner-start beats every output signature', () {
      final result = classify(
        record(loadErrorMissingFileOutput, exitCode: 1, startedProcess: false),
      );
      expect(result, RedClassification.runnerError);
    });

    test('load beats compile when both markers appear', () {
      // A read failure plus a CFE diagnostic: the file could not even be
      // read, so the failure is a load failure.
      const mixed =
          'Failed to load "x": x.dart:2:8: Error: Error when '
          "reading 'missing.dart': No such file or directory\n"
          'x.dart:3:1: Error: Method not found.\n';
      final result = classify(record(mixed, exitCode: 1, testCount: 2));
      expect(result, RedClassification.loadError);
    });

    test('compile beats green markers when both appear', () {
      const mixed = '$compileErrorOutput\nAll tests passed!\n';
      final result = classify(record(mixed, exitCode: 1, testCount: 1));
      expect(result, RedClassification.compileError);
    });

    test('skip beats green on exit 0 when skip markers appear', () {
      const mixed = '$skippedOutput\n00:00 +1: All tests passed!\n';
      final result = classify(record(mixed, exitCode: 0, testCount: 1));
      expect(result, RedClassification.skipped);
    });

    test('classification is deterministic for identical inputs', () {
      final r = record(assertionOutput, exitCode: 1, testCount: 1);
      expect(
        classify(r),
        classify(record(assertionOutput, exitCode: 1, testCount: 1)),
      );
    });
  });

  group('parseExecutedTestCount — runner grammar (helper for U7)', () {
    test('single failing test counts one', () {
      expect(parseExecutedTestCount(assertionOutput), 1);
    });

    test('single passing test counts one', () {
      expect(parseExecutedTestCount(greenOutput), 1);
    });

    test('single skipped test counts one', () {
      expect(parseExecutedTestCount(skippedOutput), 1);
    });

    test('two failing tests count two', () {
      expect(parseExecutedTestCount(blendedOutput), 2);
    });

    test('pass plus skip counts two', () {
      expect(
        parseExecutedTestCount(
          '00:00 +0: loading t\n00:00 +1 ~1: All tests passed!\n',
        ),
        2,
      );
    });

    test('No tests ran counts zero', () {
      expect(
        parseExecutedTestCount(
          '00:00 +0: loading t\nNo tests ran.\nNo tests match "x".\n',
        ),
        0,
      );
    });

    test('unparseable output returns null', () {
      expect(parseExecutedTestCount('not a runner transcript'), isNull);
    });
  });

  group('RedClassification model (T003)', () {
    test('exposes exactly the six spec classes with kebab labels', () {
      expect(RedClassification.values.map((c) => c.label), [
        'assertion',
        'compile-error',
        'load-error',
        'skipped',
        'unexpected-green',
        'runner-error',
      ]);
    });

    test('every class carries a non-empty remediation hint', () {
      for (final c in RedClassification.values) {
        expect(c.remediationHint, isNotEmpty, reason: c.name);
      }
    });
  });
}
