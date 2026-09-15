// Issue #1651 — the scalar-declared contract's TYPE-ONLY assertion is a
// vacuous green: the #1517 func pass fills the subject with `return 0;`,
// which satisfies `expect(result, isA<int>())`, so `make` certifies a
// dummy-body green and the receipt reports complete. The #1259 bar
// ("green must require at least one assertion on the observable outcome")
// is not met by a type check.
//
// Remediation pinned here (from the assessment / spec):
//   FR-001 — the writer emits the typed outcome assertion WITH the
//     `zfa:tdd: vacuous-guard` marker + the #1651 remedy comment for a
//     scalar-declared contract (the same marker discipline the
//     entity/void branch already carries — the marker is the run
//     driver's `stopped_at=<id>:hand` discriminator).
//   FR-002 — `contentIsVacuousGreen` classifies assertion sets that
//     reduce to scalar-type-only `expect(x, isA<T>())` checks
//     (T ∈ {String, int, num, double, bool}) as vacuous, so legacy
//     marker-less generated tests are refused by every existing
//     consumer; value-discriminating assertions (equals, throwsA,
//     isNot-wrapped, entity-type isA) keep the test real.
//
// Fast tier: detector + writer pins only. The make-level E2E repro
// (gen → verify-red → func → make) lives in
// `commands/bug_1651_make_dummy_green_refusal_test.dart` (e2e tier —
// it spawns a real `dart test` in the fixture).
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/unit_contract_shape.dart';
import 'package:zuraffa/src/plugins/tdd/services/vacuous_guard.dart';

/// Runs [body] and returns everything printed (via [ZoneSpecification.print])
/// as a single newline-joined string.
Future<String> capturePrint(Future<void> Function() body) async {
  final output = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        output.add(line);
      },
    ),
  );
  return output.join('\n');
}

/// The legacy generated shape for a declared scalar contract
/// (`add(int a, int b) -> int`): the UnimplementedError-catching capture
/// called with representative arguments, asserting the declared return
/// TYPE only — no marker (the pre-#1651 emission).
String legacyTypeOnlyTest() => '''
import '../lib/tdd/1651-vacuous-green/u1_subject.dart' as subject;
import 'package:test/test.dart';

void main() {
  test('U1 — the calculator adds two integers', () {
    final result = (() {
      try {
        return subject.subject_u1(0, 0);
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    expect(result, isA<int>());
  });
}
''';

Behavior unitBehavior(String id, String description) => Behavior(
  id: id,
  feature: '1651-vacuous-green-unit-dummies',
  kind: BehaviorKind.unit,
  description: description,
  sourceCriterion: 'FR-001',
  target: 'subjectUnderTest',
);

void main() {
  group('issue #1651 — the detector classifies scalar type-only greens as '
      'vacuous (FR-002)', () {
    test('U1a: a bare type-only assertion set is vacuous', () {
      const content = '''
void main() {
  test('adds', () {
    expect(result, isA<int>());
  });
}
''';
      expect(
        contentIsVacuousGreen(content),
        isTrue,
        reason:
            'a `return 0;` dummy satisfies `isA<int>()` — the assertion set '
            'proves nothing about the outcome (issue #1651)',
      );
    });

    test('U1b: the guard + a type-only assertion is vacuous', () {
      const content = '''
void main() {
  test('adds', () {
    expect(result, isNot(isA<UnimplementedError>()));
    expect(result, isA<int>());
  });
}
''';
      expect(contentIsVacuousGreen(content), isTrue);
    });

    test('U1c: the legacy generated shape (capture + type-only, no '
        'marker) is vacuous', () {
      expect(contentIsVacuousGreen(legacyTypeOnlyTest()), isTrue);
    });

    test('U2a: an equals assertion keeps the test real', () {
      const content = '''
void main() {
  test('adds', () {
    expect(result, isA<int>());
    expect(result, equals(5));
  });
}
''';
      expect(contentIsVacuousGreen(content), isFalse);
    });

    test('U2b: a throwsA assertion keeps the test real (a `return 0;` '
        'dummy fails it)', () {
      const content = '''
void main() {
  test('throws', () {
    expect(() => subject.f(), throwsA(isA<ArgumentError>()));
  });
}
''';
      expect(contentIsVacuousGreen(content), isFalse);
    });

    test('U2c: a negated type check keeps the test real (a `return 0;` '
        'dummy fails it)', () {
      const content = '''
void main() {
  test('adds', () {
    expect(result, isNot(isA<int>()));
  });
}
''';
      expect(contentIsVacuousGreen(content), isFalse);
    });

    test('U2d: an entity-type isA assertion keeps the test real (an '
        'entity-return subject cannot be dummied — issue #1517 leaves '
        'the throw in place)', () {
      const content = '''
void main() {
  test('logs in', () {
    expect(result, isA<User>());
  });
}
''';
      expect(contentIsVacuousGreen(content), isFalse);
    });

    test('U2e: a non-scalar composite type-only check keeps the test '
        'real (outside the dummy-satisfiable class)', () {
      const content = '''
void main() {
  test('adds', () {
    expect(result, isA<List<int>>());
  });
}
''';
      expect(contentIsVacuousGreen(content), isFalse);
    });
  });

  group('issue #1651 — the writer marks the scalar type-only assertion '
      '(FR-001)', () {
    test('U3: a scalar-declared contract emits the typed assertion WITH '
        'the vacuous-guard marker and the #1651 remedy comment', () async {
      final tmp = await Directory.systemTemp.createTemp('bug_1651_writer_');
      addTearDown(() => tmp.delete(recursive: true));
      final testPath = p.join(tmp.path, 'u1_test.dart');
      const shape = UnitContractShape(
        declaredSignature: 'add(int a, int b) -> int',
        declaredReturn: 'int',
        returnType: 'int',
        params: [],
        scalarOutcome: true,
      );
      final writer = const BehaviorTestWriter(contractShape: shape);
      final printed = await capturePrint(() async {
        await writer.write(
          behavior: unitBehavior(
            'U1',
            'the calculator MUST add two integers via Calculator.add',
          ),
          testPath: testPath,
          subjectPath: p.join(tmp.path, 'u1_subject.dart'),
        );
      });
      final content = File(testPath).readAsStringSync();
      // The typed assertion stands (issue #1259 remediation) — now with
      // the marker discipline the entity/void branch already carries.
      expect(content, contains('expect(result, isA<int>())'));
      expect(
        content,
        contains(vacuousGuardMarker),
        reason:
            'the func dummy `return 0;` satisfies the type check — the '
            'marker is what makes make refuse the dummy-body green '
            '(issue #1651)',
      );
      expect(
        content,
        contains('issue #1651'),
        reason: 'the comment names the vacuity class and its remedy',
      );
      // The traced row carries a contract shape, so the gen-time
      // FALLBACK warning (the `zfa:tdd: guard-only` token, gated on
      // `contractShape == null`) stays silent — the marker is the
      // warning surface here.
      expect(printed, isNot(contains(vacuousGuardWarningToken)));
    });
  });
}
