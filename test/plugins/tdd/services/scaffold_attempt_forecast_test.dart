// Issue #1689 — the scenario × zero-scaffold pre-flight forecast (unit).
//
// The single-sourced predicate behind make's `would-never-pass` fast
// stop: when the plan's func pass will scaffold the #1517 zero-value
// dummy for the declared return (`return 0;`-class body) and the paired
// test asserts a DIFFERENT concrete outcome (`equals(5)` — the #1679
// scenario-derived shape), the make attempt is provably guaranteed-
// failing work and must be skipped in favor of the hand-step remedy.
//
// The truth table pins BOTH directions:
//   - fires for the literal-dummy vocabulary × a differing literal
//     (int→0, double→0.0, bool→true, String→the function's own name);
//   - stays silent for every shape the attempt must keep running:
//     zero-matching literals (Dart num equality: 0 == 0.0), nullable /
//     void / num / entity returns (the still-red UnimplementedError
//     scaffold, not a zero value), marker-less hand-authored subjects,
//     the legacy no-arg stub (a different, description-derived
//     scaffold), non-stub bodies (funcRewritableStubPattern misses),
//     guard-only / type-only tests (no value assertion — the
//     non-scenaried class the gate must never skip), and unparseable
//     matcher arguments (fail-open: never refuse on absence of
//     evidence).
library;

import 'package:zuraffa/src/plugins/tdd/services/scaffold_attempt_forecast.dart';
import 'package:zuraffa/src/plugins/tdd/services/subject_provenance.dart';
import 'package:test/test.dart';

/// gen's provenance-marked parametrized scalar stub — the exact shape
/// func rewrites ([SubjectProvenance.funcRewritableStubPattern]) and the
/// shape the zcalc3 probe's U1 subject carried at make time.
String genStub(String returnType, String params, {String? name}) {
  final fn = name ?? 'subject_u1';
  return '''
// GENERATED STUB — `zfa tdd gen U1` (spec 044-test-tdd-generation + issue #1259 contract derivation).
library;

/// Throws [UnimplementedError] until the real implementation lands.
$returnType $fn($params) => throw UnimplementedError('$fn not implemented: add($params) -> $returnType');
''';
}

/// The #1679 scenario-derived test shape (the zcalc3 U1 generated form):
/// the capture catches the stub's throw, the assertion pins the
/// scenario's concrete outcome.
String scenarioTest(String expected) =>
    '''
import 'package:test/test.dart';

import '../lib/u1_subject.dart' as subject;

void main() {
  test('U1 — the engine adds two integers', () {
    final result = (() {
      try {
        return subject.subject_u1(2, 3);
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    expect(result, equals($expected));
  });
}
''';

/// The non-scenaried shapes: the #1259 guard-only test and the
/// post-#1259 type-only + marker fallback — no value assertion.
const guardOnlyTest = '''
import 'package:test/test.dart';

import '../lib/u1_subject.dart' as subject;

void main() {
  test('U1 — the engine adds two integers', () {
    final result = subject.subject_u1(0, 0);
    expect(result, isNot(isA<UnimplementedError>()));
  });
}
''';

void main() {
  group('fires — literal dummy × a differing value assertion', () {
    test('U-1689-b1: int stub + equals(5) — the issue\'s exact shape', () {
      final forecast = forecastMakeAttempt(
        subjectSource: genStub('int', 'int a, int b'),
        testSource: scenarioTest('5'),
      );
      expect(forecast, isNotNull, reason: 'the attempt would never pass');
      expect(forecast!.returnType, 'int');
      expect(forecast.functionName, 'subject_u1');
      expect(forecast.dummyLiteral, '0');
      expect(forecast.expectedLiteral, '5');
    });

    test('U-1689-b2: double / String / bool vocabularies fire on a '
        'differing literal', () {
      expect(
        forecastMakeAttempt(
          subjectSource: genStub('double', 'int a, int b'),
          testSource: scenarioTest('2.0'),
        )?.dummyLiteral,
        '0.0',
      );
      final stringForecast = forecastMakeAttempt(
        subjectSource: genStub('String', 'String name', name: 'greet'),
        testSource: scenarioTest("'Hello Alice'"),
      );
      expect(stringForecast, isNotNull);
      expect(stringForecast!.dummyLiteral, "'greet'");
      expect(stringForecast.expectedLiteral, "'Hello Alice'");
      expect(
        forecastMakeAttempt(
          subjectSource: genStub('bool', 'int a'),
          testSource: scenarioTest('false'),
        )?.dummyLiteral,
        'true',
      );
    });

    test('U-1689-b10: mixed kinds discriminate and the first offending '
        'literal wins', () {
      // A string literal vs an int dummy: `0 == '5'` is false in Dart —
      // provably unsatisfiable.
      final mixed = forecastMakeAttempt(
        subjectSource: genStub('int', 'int a, int b'),
        testSource: scenarioTest("'5'"),
      );
      expect(mixed, isNotNull);
      expect(mixed!.expectedLiteral, "'5'");
      // Several equals() assertions in the file's assertion set: the
      // FIRST provably-unsatisfiable one is reported, verbatim — the
      // scan is file-level (the paired test artifact IS the assertion
      // set), so an unrelated failing equals discriminates too.
      final multi = forecastMakeAttempt(
        subjectSource: genStub('int', 'int a, int b'),
        testSource: '''
import 'package:test/test.dart';

void main() {
  test('multi', () {
    expect(1, equals(2));
    expect(subject.subject_u1(2, 3), equals(7));
  });
}
''',
      );
      expect(multi, isNotNull);
      expect(multi!.expectedLiteral, '2');
      // The subject's own first offending literal when it comes first.
      final subjectFirst = forecastMakeAttempt(
        subjectSource: genStub('int', 'int a, int b'),
        testSource: '''
import 'package:test/test.dart';

void main() {
  test('multi', () {
    final result = subject.subject_u1(2, 3);
    expect(result, equals(7));
    expect(result, equals(9));
  });
}
''',
      );
      expect(subjectFirst, isNotNull);
      expect(subjectFirst!.expectedLiteral, '7');
    });
  });

  group('stays silent — the attempt must keep running', () {
    test('U-1689-b3: zero-matching literals (the dummy may satisfy them)', () {
      expect(
        forecastMakeAttempt(
          subjectSource: genStub('int', 'int a, int b'),
          testSource: scenarioTest('0'),
        ),
        isNull,
        reason: 'equals(0) — the int dummy may pass',
      );
      expect(
        forecastMakeAttempt(
          subjectSource: genStub('int', 'int a, int b'),
          testSource: scenarioTest('0.0'),
        ),
        isNull,
        reason: 'Dart num equality: 0 == 0.0 — the int dummy may pass',
      );
      expect(
        forecastMakeAttempt(
          subjectSource: genStub('bool', 'int a'),
          testSource: scenarioTest('true'),
        ),
        isNull,
        reason: 'equals(true) — the bool dummy may pass',
      );
      expect(
        forecastMakeAttempt(
          subjectSource: genStub('String', 'String name', name: 'greet'),
          testSource: scenarioTest("'greet'"),
        ),
        isNull,
        reason: 'the String dummy returns the function\'s own name',
      );
    });

    test('U-1689-b4: non-literal scaffolds — void / num / nullable / '
        'entity returns keep the still-red branch', () {
      for (final returnType in const ['void', 'num', 'int?', 'double?']) {
        expect(
          forecastMakeAttempt(
            subjectSource: genStub(returnType, 'int a, int b'),
            testSource: scenarioTest('5'),
          ),
          isNull,
          reason: '$returnType does not scaffold a literal dummy',
        );
      }
      expect(
        forecastMakeAttempt(
          subjectSource: genStub('ScanSession', 'AuthRequest request'),
          testSource: scenarioTest('5'),
        ),
        isNull,
        reason: 'an entity return keeps the UnimplementedError scaffold',
      );
    });

    test('U-1689-b5: a marker-less (hand-authored) subject never fires', () {
      final handAuthored = '''
library;

int subject_u1(int a, int b) => throw UnimplementedError('todo');
''';
      expect(
        forecastMakeAttempt(
          subjectSource: handAuthored,
          testSource: scenarioTest('5'),
        ),
        isNull,
        reason: 'the gen provenance marker is part of the proof',
      );
    });

    test('U-1689-b6: the legacy no-arg stub never fires', () {
      final legacy = '''
// GENERATED STUB — `zfa tdd gen U1` (spec 044-test-tdd-generation + issue #1259 contract derivation).
library;

int subject_u1() => throw UnimplementedError('implement me');
''';
      expect(
        forecastMakeAttempt(
          subjectSource: legacy,
          testSource: '''
import 'package:test/test.dart';

void main() {
  test('U1', () {
    final result = subject.subject_u1();
    expect(result, equals(5));
  });
}
''',
        ),
        isNull,
        reason: 'the description-derived body is a different scaffold',
      );
    });

    test('U-1689-b7: non-stub bodies never fire (pattern misses)', () {
      const dummyBody = '''
library;

int subject_u1(int a, int b) {
  return 0;
}
''';
      expect(
        forecastMakeAttempt(
          subjectSource: dummyBody,
          testSource: scenarioTest('5'),
        ),
        isNull,
        reason: 'the dummy body is the 9b gate\'s class, not the forecast',
      );
      const realImpl = '''
library;

int subject_u1(int a, int b) => a + b;
''';
      expect(
        forecastMakeAttempt(
          subjectSource: realImpl,
          testSource: scenarioTest('5'),
        ),
        isNull,
      );
    });

    test('U-1689-b8: guard-only and type-only tests (the non-scenaried '
        'class) never fire', () {
      expect(
        forecastMakeAttempt(
          subjectSource: genStub('int', 'int a, int b'),
          testSource: guardOnlyTest,
        ),
        isNull,
        reason: 'no value assertion — the attempt is not this gate\'s call',
      );
      expect(
        forecastMakeAttempt(
          subjectSource: genStub('int', 'int a, int b'),
          testSource: '''
import 'package:test/test.dart';

import '../lib/u1_subject.dart' as subject;

void main() {
  test('U1', () {
    final result = subject.subject_u1(0, 0);
    expect(result, isA<int>());
  });
}
''',
        ),
        isNull,
        reason: 'the type-only fallback is the #1651 gate\'s class',
      );
    });

    test('U-1689-b9: unparseable matcher args never discriminate '
        '(fail-open)', () {
      expect(
        forecastMakeAttempt(
          subjectSource: genStub('int', 'int a, int b'),
          testSource: '''
import 'package:test/test.dart';

void main() {
  test('U1', () {
    final result = subject.subject_u1(2, 3);
    expect(result, equals(result));
  });
}
''',
        ),
        isNull,
        reason: 'a non-literal matcher arg is not provably unsatisfiable',
      );
      expect(
        forecastMakeAttempt(
          subjectSource: genStub('int', 'int a, int b'),
          testSource: '''
import 'package:test/test.dart';

void main() {
  test('U1', () {
    final result = subject.subject_u1(2, 3);
    expect(result, allOf(equals(result)));
  });
}
''',
        ),
        isNull,
      );
    });

    test('U-1689-b11: escape-bearing string args are undecodable '
        '(fail-open)', () {
      // The scan matches string args as RAW source text and the
      // comparator never unescapes, so a literal whose escapes the
      // compiler WOULD honor must not be compared as written:
      // `equals('\u0067reet')` asserts the value `greet`, and comparing
      // the raw text against the `greet` String dummy would refuse an
      // attempt the dummy in fact satisfies. Escaped quotes are the same
      // undecodable class — there the trailing `)` anchor already keeps
      // the shape unmatched, which is the same fail-open outcome.
      expect(
        forecastMakeAttempt(
          subjectSource: genStub('String', 'String name', name: 'greet'),
          testSource: scenarioTest(r"'\u0067reet'"),
        ),
        isNull,
        reason: 'the raw text is not the value — never refuse on it',
      );
      expect(
        forecastMakeAttempt(
          subjectSource: genStub('String', 'String name', name: 'greet'),
          testSource: scenarioTest(r"'It\'s'"),
        ),
        isNull,
        reason: 'an escaped quote never yields a decodable literal',
      );
    });
  });

  group('the remedy is single-sourced and names both artifacts', () {
    test('the remedy names the subject, the test, and the re-run', () {
      final remedy = wouldNeverPassRemedy(
        behaviorId: 'U1',
        subjectPath: 'lib/u1_subject.dart',
        testPath: 'test/tdd/zcalc3/u1_test.dart',
      );
      expect(remedy, contains('lib/u1_subject.dart'));
      expect(remedy, contains('test/tdd/zcalc3/u1_test.dart'));
      expect(remedy, contains('zfa tdd make U1'));
      expect(remedy, contains('#1689'));
    });
  });
}
