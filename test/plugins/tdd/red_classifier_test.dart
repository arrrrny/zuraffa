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
    bool timedOut = false,
  }) => RunRecord(
    command: command,
    exitCode: exitCode,
    output: output,
    startedProcess: startedProcess,
    testCount: testCount,
    timedOut: timedOut,
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

  group('issue #831 — channel-timeout vs assertion failures', () {
    // Captured grammar: a platform-channel call that never resolves. The
    // fake is missing, misconfigured, or the channel never answers — a
    // harness/config failure the TDD loop must NAME, not lump into
    // runner-error (issue #831 requirement 4).
    const missingPluginOutput = '''
00:01 +0: loading test/tdd/013-fixture/t1_test.dart
00:01 +0 -1: T1 — scans a barcode [E]
  MissingPluginException(No implementation found for method available on channel dev.zuraffa/barcode)

00:01 +0 -1: Some tests failed.
''';

    const channelTimeoutOutput = '''
00:01 +0: loading test/tdd/072-fixture/t2_test.dart
00:01 +0 -1: T2 — resolves location within the timeout [E]
  TimeoutException: channel dev.zuraffa/location method getLocation never resolved after 0:00:10.000000

00:01 +0 -1: Some tests failed.
''';

    const channelErrorOutput = '''
00:01 +0: loading test/tdd/077-fixture/t3_test.dart
00:01 +0 -1: T3 — captures a photo [E]
  PlatformException(channel-error, Failed to send message to channel dev.zuraffa/camera, null, null)

00:01 +0 -1: Some tests failed.
''';

    test('MissingPluginException -> channel-timeout', () {
      final result = classify(
        record(missingPluginOutput, exitCode: 1, testCount: 1),
      );
      expect(result, RedClassification.channelTimeout);
    });

    test('channel-scoped TimeoutException -> channel-timeout', () {
      final result = classify(
        record(channelTimeoutOutput, exitCode: 1, testCount: 1),
      );
      expect(result, RedClassification.channelTimeout);
    });

    test('PlatformException(channel-error) -> channel-timeout', () {
      final result = classify(
        record(channelErrorOutput, exitCode: 1, testCount: 1),
      );
      expect(result, RedClassification.channelTimeout);
    });

    test(
      'a bare TimeoutException with no channel context stays runner-error',
      () {
        // pumpAndSettle / arbitrary future timeouts are NOT channel
        // failures — the widget taxonomy (issue #830) keeps them.
        final result = classify(
          record(timeoutOutput, exitCode: 1, testCount: 1),
        );
        expect(result, RedClassification.runnerError);
      },
    );

    test(
      'an assertion signature beats channel text (assertion stays king)',
      () {
        // flutter_test wraps every failure — an expect() mismatch that
        // QUOTES a MissingPluginException in its Expected/Actual block is
        // an honest red, not a harness failure.
        const mixed = '''
00:01 +0 -1: T1 — rejects the unscripted method [E]
  Expected: PlatformException:code<unscripted>
    Actual: MissingPluginException(No implementation found for method available on channel dev.zuraffa/barcode)

00:01 +0 -1: Some tests failed.
''';
        final result = classify(record(mixed, exitCode: 1, testCount: 1));
        expect(result, RedClassification.assertion);
      },
    );

    test('a PROCESS-level timeout (SIGKILL) stays runner-error even with '
        'channel text (bug #742 precedence)', () {
      final result = classify(
        record(missingPluginOutput, exitCode: 1, testCount: 1, timedOut: true),
      );
      expect(result, RedClassification.runnerError);
    });

    test('channel signature does not fire on green runs', () {
      // Green with channel chatter in the transcript is still
      // unexpected-green — the classification is red-side only.
      final result = classify(
        record(missingPluginOutput, exitCode: 0, testCount: 1),
      );
      expect(result, RedClassification.unexpectedGreen);
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
    test('exposes exactly the eight spec classes with kebab labels', () {
      // The eighth class (kind-mismatch, issue #964): the observed red
      // came from a finder whose kind does not match the scenario verb.
      expect(RedClassification.values.map((c) => c.label), [
        'assertion',
        'compile-error',
        'load-error',
        'skipped',
        'unexpected-green',
        'runner-error',
        'channel-timeout',
        'kind-mismatch',
      ]);
    });

    test('channel-timeout carries a non-empty remediation hint', () {
      final channelTimeout = RedClassification.channelTimeout;
      expect(channelTimeout.remediationHint, isNotEmpty);
      expect(channelTimeout.label, 'channel-timeout');
    });

    test('every class carries a non-empty remediation hint', () {
      for (final c in RedClassification.values) {
        expect(c.remediationHint, isNotEmpty, reason: c.name);
      }
    });
  });

  // ------------------------------------------------------------------
  // issue #959 — failingAssertionOf: name the failing authored assertion
  // (U3): a certified red must identify WHICH authored assertion failed,
  // extracted from the same reporter grammar classify() parses.
  // ------------------------------------------------------------------
  group('failingAssertionOf — names the failing authored assertion (U3)', () {
    test('finder-failure transcript yields the failing test description', () {
      expect(
        failingAssertionOf(assertionOutput),
        'returns 42 when invoked with no args',
      );
    });

    test('flutter assertion shape yields the test description', () {
      expect(
        failingAssertionOf(flutterAssertionOutput),
        'returns 42 when invoked with no args',
      );
    });

    test('blended transcript yields the LAST failing assertion', () {
      expect(
        failingAssertionOf(blendedOutput),
        'returns 41 when invoked with no args',
      );
    });

    test('loading [E] lines are never mistaken for an authored assertion', () {
      // Load failures route to load-error, never assertion — the
      // extractor must not hand back a "loading ..." identity.
      expect(failingAssertionOf(loadErrorMissingFileOutput), isNull);
      expect(failingAssertionOf(compileErrorOutput), isNull);
    });

    test('runner-crash transcript without an [E] line yields null', () {
      const crash = '''
00:01 +0: loading test/tdd/a1_test.dart
══╡ EXCEPTION CAUGHT BY WIDGETS LIBRARY ╞═════════════════════════════
The following StateError was thrown building Dashboard(dirty):
  Bad state: no theme

00:01 +0 -1: Some tests failed.
''';
      expect(failingAssertionOf(crash), isNull);
    });

    test('empty and unparseable transcripts yield null', () {
      expect(failingAssertionOf(''), isNull);
      expect(failingAssertionOf('gibberish'), isNull);
    });

    test('the identity is single-line even when the name has em-dashes', () {
      const named = '''
00:00 +0: loading test/b_001_test.dart
00:00 +0 -1: B-001 \u2014 renders the 'Home' label [E]
  Expected: exactly one matching node in the widget tree
    Actual: _TextWidgetFinder:<zero widgets with text "Home">

00:00 +0 -1: Some tests failed.
''';
      expect(failingAssertionOf(named), "B-001 \u2014 renders the 'Home' label");
    });
  });
}
