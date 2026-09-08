// Fast tier — issue #1323: the `_argN()` hand-delta seam vocabulary.
//
// The generated `_argN()` placeholder helper is a GENERATED, named marker
// (spec 991 FR-001): the helper's throw message carries the target, the
// parameter index, and the declared type, and the same message reaches
// the failing transcript when the placeholder is the red's cause. The
// detection is TWO-SIGNAL — the test-file marker AND the transcript
// token must agree — so a make whose target test fails for an unrelated
// reason is never mis-diagnosed as a hand-delta.
//
// Test map (spec 991):
//   U1 — marker + transcript token -> hit (index, target, declared type).
//   U2 — marker without the transcript token -> null (two-signal rule).
//   U3 — transcript token without the marker -> null.
//   U4 — a second parameter (`_arg1`) parses its own index/type.
//   U5 — the remedy names the EXACT edit: placeholder, test path,
//        declared type, re-run command (FR-002).
//   U6 — the content-only probe (driver-side signal) parses the hit
//        without a transcript.
//   U7 — the hand-step violation carries the #1308 hand-step contract
//        vocabulary (what to write, where, re-run).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/arg_placeholder.dart';

/// The exact helper shape the behavior test writer emits for a
/// non-scalar declared param (`_captureInvocation`).
String testWithHelper({
  String helper =
      "Object _arg0() => throw UnimplementedError('provide a "
      "representative argument for subject_u6 (declared param 0: Object)');",
  String invocation = 'return subject.reason(_arg0());',
}) {
  return '''
import 'package:test/test.dart';
import '../lib/u6_subject.dart' as subject;

void main() {
  group('U6 (FR-1)', () {
    test('U6 — reason reports the error class', () {
      $helper
      final result = (() {
        try {
          $invocation
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isA<String>());
    });
  });
}
''';
}

/// The failing transcript (the probe-verified shape): the placeholder's
/// message surfaces in the matcher's Actual line.
const transcriptWithToken = '''
00:00 +0 -1: U6 (FR-1) U6 — reason reports the error class [E]
  Expected: <Instance of 'String'>
    Actual: UnimplementedError:<UnimplementedError: provide a representative argument for subject_u6 (declared param 0: Object)>
     Which: is not an instance of 'String'
00:00 +0 -1: Some tests failed.
''';

void main() {
  group('argPlaceholderHitOf — two-signal detection (spec 991 FR-001)', () {
    test('U1: marker + transcript token -> the hit names index, target, '
        'declared type', () {
      final hit = argPlaceholderHitOf(
        testContent: testWithHelper(),
        runOutput: transcriptWithToken,
      );
      expect(hit, isNotNull, reason: 'both signals agree — the seam fires');
      expect(hit!.index, 0);
      expect(hit.target, 'subject_u6');
      expect(hit.declaredType, 'Object');
    });

    test('U2: marker without the transcript token -> null — the red is '
        'NOT attributed to the placeholder', () {
      final hit = argPlaceholderHitOf(
        testContent: testWithHelper(),
        runOutput: "Expected: <2>\n  Actual: <1>\nSome tests failed.",
      );
      expect(hit, isNull, reason: 'the transcript never named the marker');
    });

    test('U3: transcript token without the marker -> null — a stale '
        'transcript never fabricates a seam', () {
      final hit = argPlaceholderHitOf(
        testContent: testWithHelper(
          helper: '',
          invocation: "return subject.reason('boom');",
        ),
        runOutput: transcriptWithToken,
      );
      expect(hit, isNull, reason: 'the test file carries no _argN helper');
    });

    test('U4: a second parameter parses its own index and declared type', () {
      final hit = argPlaceholderHitOf(
        testContent: testWithHelper(
          helper:
              "AuthRequest _arg1() => throw UnimplementedError('provide "
              "a representative argument for subject_u7 (declared param 1: "
              "AuthRequest)');",
          invocation: 'return subject.submit(_arg1());',
        ),
        runOutput:
            'provide a representative argument for subject_u7 '
            '(declared param 1: AuthRequest)',
      );
      expect(hit, isNotNull);
      expect(hit!.index, 1);
      expect(hit.declaredType, 'AuthRequest');
    });

    test('U4b: the lowest index wins when several placeholders remain', () {
      final hit = argPlaceholderHitOf(
        testContent: testWithHelper(
          helper:
              "Object _arg1() => throw UnimplementedError('provide a "
              "representative argument for subject_u8 (declared param 1: "
              "Object)');\n      "
              "AuthRequest _arg2() => throw UnimplementedError('provide a "
              "representative argument for subject_u8 (declared param 2: "
              "AuthRequest)');",
          invocation: 'return subject.submit(_arg1(), _arg2());',
        ),
        runOutput: 'provide a representative argument for subject_u8',
      );
      expect(hit, isNotNull);
      expect(hit!.index, 1, reason: 'the first placeholder is the exact edit');
    });
  });

  group('argPlaceholderRemedy — the exact edit (spec 991 FR-002)', () {
    test('U5: the remedy names the placeholder, the test path, the '
        'declared type, and the re-run command', () {
      final remedy = argPlaceholderRemedy(
        index: 0,
        testPath: 'test/tdd/1323-hand-delta/u6_test.dart',
        declaredType: 'Object',
        behaviorId: 'U6',
      );
      expect(remedy, contains('replace _arg0()'));
      expect(remedy, contains('test/tdd/1323-hand-delta/u6_test.dart'));
      expect(remedy, contains('representative Object'));
      expect(remedy, contains('then re-run zfa tdd make U6'));
    });
  });

  group('argPlaceholderHitInContent — the driver-side content probe', () {
    test('U6: parses the hit from the test content alone', () {
      final hit = argPlaceholderHitInContent(testWithHelper());
      expect(hit, isNotNull);
      expect(hit!.index, 0);
      expect(hit.declaredType, 'Object');
    });

    test('U6b: a hand-edited test (placeholder replaced) parses no hit', () {
      final hit = argPlaceholderHitInContent(
        testWithHelper(
          helper: '',
          invocation: "return subject.reason(StateError('boom'));",
        ),
      );
      expect(
        hit,
        isNull,
        reason: 'the hand-edit removed the marker — no seam to surface',
      );
    });
  });

  group('argPlaceholderHandStepViolation — the named hand step', () {
    test('U7: the violation names the hand step, the exact edit, and the '
        'file', () {
      final violation = argPlaceholderHandStepViolation(
        behaviorId: 'U6',
        testPath: 'test/tdd/1323-hand-delta/u6_test.dart',
        declaredType: 'Object',
      );
      expect(violation, contains('hand-step=U6:hand'));
      expect(violation, contains('_arg0()'));
      expect(violation, contains('test/tdd/1323-hand-delta/u6_test.dart'));
      expect(violation, contains('representative Object'));
      expect(violation, contains('then re-run zfa tdd make U6'));
    });
  });
}
