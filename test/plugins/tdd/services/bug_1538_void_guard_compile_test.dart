// Issue #1538 — a VOID-returning traced contract emitted a NON-COMPILING
// guard test. `UnitContractShape.of` treats `void` as a renderable scalar,
// so the paired subject stub renders the declared return verbatim
// (`void subject_u3(...) => throw UnimplementedError(...)`) while
// `BehaviorTestWriter._captureInvocation` unconditionally wraps the
// invocation in the IIFE capture (`final result = (() { try { return
// subject.subject_u3(...); } ... })();`) — `return`ing a void expression
// from an `Object? Function()` closure is `use_of_void_result` +
// `return_of_invalid_type_from_closure`, and the behavior dead-ends at
// `verify-red -> compile-error` before reaching the designed
// vacuous-guard -> hand-step transition (#1259 marker dispatch, #1308).
//
// Fix under test (spec 1538-void-returning-contract-compile-fix): for
// declared `void` returns the capture becomes the statement-based,
// compile-safe form — the call stands alone, completion records
// `result = null`, the caught `UnimplementedError` records
// `result = error` — and the vacuous-guard comment/marker + guard follow
// unchanged. Non-void shapes keep the IIFE byte-for-byte (#1512's unit
// guardrails); the subject's declared signature is untouched.
//
// Behaviors:
//   A1 — a void scalar-param contract emits the statement-based void-safe
//        capture (no `return subject.`, no IIFE).
//   A2 — a void entity-param contract keeps the `_argN()` placeholder
//        helpers composing with the void-safe capture (the issue's exact
//        `subject.subject_u3(_arg0(), _arg1())` symptom shape).
//   A3 — the void test carries the vacuous-guard marker, its only
//        expectation is the guard, and the existing detectors classify it
//        as the traced hand-delta seam (the #1308 transition), with no
//        typed outcome assertion.
//   B1 — a non-void scalar contract keeps the IIFE capture (characterization
//        guard: the fix must not break non-void generation).
//   B2 — a non-void entity-return contract keeps the IIFE + marker guard
//        (characterization guard).
//   C1 — the emitted void pair (test + `void` subject stub) compiles under
//        `dart test` and fails through an ASSERTION, never a compile error
//        (the slow pair-compile proof, mirroring bug #1512's).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/models/routing.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/subject_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/unit_contract_shape.dart';
import 'package:zuraffa/src/plugins/tdd/services/vacuous_guard.dart';

Behavior unitBehavior({String id = 'U1', String target = 'subject_u1'}) =>
    Behavior(
      id: id,
      feature: '1538-void-returning-contract-compile-fix',
      kind: BehaviorKind.unit,
      description: 'the declared contract holds.',
      sourceCriterion: 'FR-1',
      target: target,
    );

UnitContractShape shapeOf(String declared) =>
    UnitContractShape.of(Signature.parse(declared));

Future<(String test, String subject)> writePair(
  Behavior behavior,
  UnitContractShape shape,
  Directory tmp, {
  required String testFile,
  required String subjectFile,
}) async {
  final testPath = p.join(tmp.path, 'test', 'tdd', testFile);
  final subjectPath = p.join(tmp.path, 'lib', 'tdd', subjectFile);
  await BehaviorTestWriter(
    contractShape: shape,
  ).write(behavior: behavior, testPath: testPath, subjectPath: subjectPath);
  await SubjectWriter(
    contractShape: shape,
  ).write(behavior: behavior, subjectPath: subjectPath);
  return (
    File(testPath).readAsStringSync(),
    File(subjectPath).readAsStringSync(),
  );
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('bug_1538_');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  group(
    'A: void-returning contracts emit the compile-safe guard (SC-1/SC-3)',
    () {
      test('A1: a void scalar-param contract emits the statement-based '
          'void-safe capture — never a returned void', () async {
        final (content, _) = await writePair(
          unitBehavior(),
          shapeOf('log(String message) -> void'),
          tmp,
          testFile: 'u1_test.dart',
          subjectFile: 'u1_subject.dart',
        );
        expect(
          content,
          contains('Object? result;'),
          reason:
              'the void-safe capture declares a nullable variable, not a '
              'final with the IIFE initializer',
        );
        expect(
          content,
          contains("subject.subject_u1(r'sample');"),
          reason: 'the invocation stands alone — its void result is never used',
        );
        expect(
          content,
          contains('result = null;'),
          reason: 'completion of the void call is recorded explicitly',
        );
        expect(
          content,
          contains('result = error;'),
          reason: 'the caught UnimplementedError is captured as before',
        );
        expect(
          content,
          isNot(contains('return subject.')),
          reason:
              'returning a void expression is the use_of_void_result '
              'compile error this fix removes',
        );
        expect(
          content,
          isNot(contains('final result')),
          reason: 'the IIFE capture shape must not survive for void contracts',
        );
      });

      test(
        'A2: a void entity-param contract keeps the placeholder helpers '
        'composing with the void-safe capture (the issue symptom shape)',
        () async {
          final (content, subject) = await writePair(
            unitBehavior(id: 'U3', target: 'subject_u3'),
            shapeOf('sync(SyncRequest request, SyncOptions options) -> void'),
            tmp,
            testFile: 'u3_test.dart',
            subjectFile: 'u3_subject.dart',
          );
          expect(
            subject,
            contains('void subject_u3('),
            reason:
                'the subject keeps the DECLARED contract return verbatim — the '
                'test-side capture is the fix, not the signature',
          );
          expect(
            content,
            contains('Object? _arg0() =>'),
            reason:
                'the non-scalar declared params keep their placeholder '
                'helpers, declared before the capture',
          );
          expect(
            content,
            contains('Object? _arg1() =>'),
            reason: 'both placeholders are kept',
          );
          expect(
            content,
            contains('subject.subject_u3(_arg0(), _arg1());'),
            reason:
                'the issue #1538 symptom call site — args threaded, result not '
                'returned',
          );
          expect(
            content,
            contains('result = null;'),
            reason: 'the void-safe recording survives helper composition',
          );
          expect(
            content,
            isNot(contains('return subject.')),
            reason: 'no void expression is returned from the capture',
          );
        },
      );

      test(
        'A3: the void test reaches the designed vacuous-guard -> hand-step '
        'transition (marker + detector classification), not compile-error',
        () async {
          final (content, _) = await writePair(
            unitBehavior(id: 'U3', target: 'subject_u3'),
            shapeOf('sync(SyncRequest request, SyncOptions options) -> void'),
            tmp,
            testFile: 'u3_test.dart',
            subjectFile: 'u3_subject.dart',
          );
          expect(
            content,
            contains(vacuousGuardComment),
            reason:
                'the traced void-returning path carries the #1259 marker '
                'comment — the run driver keys its hand-step dispatch on it',
          );
          expect(
            contentCarriesVacuousGuardMarker(content),
            isTrue,
            reason:
                'marker present => stopped_at=<id>:hand (the designed '
                'hand-delta seam), per vacuous_guard.dart',
          );
          expect(
            content,
            contains('expect(result, isNot(isA<UnimplementedError>()));'),
            reason:
                'the guard is the honest red surface while the contract is '
                'unimplemented',
          );
          expect(
            content,
            isNot(contains('expect(result, isA<')),
            reason:
                'a void contract has no assertable outcome value — no typed '
                'outcome assertion may be emitted',
          );
          expect(
            contentIsVacuousGreen(content),
            isTrue,
            reason:
                'the guard-only assertion set is the designed vacuous-green '
                'class — make refuses it and the hand step is named (the '
                'transition the compile error used to swallow)',
          );
        },
      );
    },
  );

  group('B: non-void generation stays byte-for-byte (SC-2)', () {
    test('B1: a scalar-return contract keeps the IIFE capture and the typed '
        'outcome assertion', () async {
      final (content, _) = await writePair(
        unitBehavior(),
        shapeOf('login(String session) -> bool'),
        tmp,
        testFile: 'u1_test.dart',
        subjectFile: 'u1_subject.dart',
      );
      expect(
        content,
        contains('final result = (() {'),
        reason: 'the IIFE capture is the non-void shape — unchanged',
      );
      expect(
        content,
        contains("return subject.subject_u1(r'sample');"),
        reason: 'the non-void subject result is returned from the closure',
      );
      expect(
        content,
        contains('expect(result, isA<bool>())'),
        reason: 'the scalar declared outcome keeps its typed assertion',
      );
      expect(
        content,
        isNot(contains('result = null;')),
        reason:
            'the void-safe statement form must not leak into non-void '
            'contracts',
      );
      expect(
        content,
        isNot(contains(vacuousGuardMarker)),
        reason: 'a scalar contract asserts a real outcome — no marker',
      );
    });

    test(
      'B2: an entity-return contract keeps the IIFE + marker guard',
      () async {
        final (content, _) = await writePair(
          unitBehavior(),
          shapeOf('complete(String session) -> Todo'),
          tmp,
          testFile: 'u1_test.dart',
          subjectFile: 'u1_subject.dart',
        );
        expect(
          content,
          contains('final result = (() {'),
          reason: 'entity returns compile through the IIFE — unchanged',
        );
        expect(content, contains("return subject.subject_u1(r'sample');"));
        expect(
          content,
          contains(vacuousGuardComment),
          reason:
              'the #1308 entity-return hand-step seam keeps its marker '
              'comment — untouched',
        );
        expect(
          content,
          contains('expect(result, isNot(isA<UnimplementedError>()));'),
        );
        expect(
          contentIsVacuousGreen(content),
          isTrue,
          reason:
              'the entity-return guard remains the designed vacuous-green '
              'class (characterization — unchanged by this fix)',
        );
      },
    );
  });

  test(
    'C1: the emitted void pair compiles and fails through an assertion '
    '(the compile proof the issue demands — never verify-red -> '
    'compile-error)',
    () async {
      final pair = await Directory.systemTemp.createTemp('bug_1538_pair_');
      addTearDown(() => pair.deleteSync(recursive: true));
      final testPath = p.join(pair.path, 'u3_test.dart');
      final subjectPath = p.join(pair.path, 'u3_subject.dart');
      final behavior = unitBehavior(id: 'U3', target: 'subject_u3');
      final shape = shapeOf(
        'sync(SyncRequest request, SyncOptions options) -> void',
      );
      await BehaviorTestWriter(
        contractShape: shape,
      ).write(behavior: behavior, testPath: testPath, subjectPath: subjectPath);
      await SubjectWriter(
        contractShape: shape,
      ).write(behavior: behavior, subjectPath: subjectPath);
      await File(p.join(pair.path, 'pubspec.yaml')).writeAsString('''
name: bug_1538_compile_pair
environment:
  sdk: ^3.11.0
dependencies:
  test: ^1.25.0
''');
      final result = await Process.run('dart', [
        'test',
        testPath,
      ], workingDirectory: pair.path);
      final combined = '${result.stdout}\n${result.stderr}';
      // The pair must RUN: a compile error never reaches an assertion.
      expect(
        result.exitCode,
        isNot(0),
        reason: 'the void stub must be honestly red on first run',
      );
      expect(
        combined.toLowerCase(),
        isNot(contains('compile-time error')),
        reason: combined,
      );
      expect(
        combined.toLowerCase(),
        isNot(contains('use_of_void_result')),
        reason: combined,
      );
      expect(
        combined.toLowerCase(),
        isNot(contains('undefined name')),
        reason: combined,
      );
      // The emitted test's own name is the identity that proves an
      // ASSERTION ran: a load/compile failure never reaches a reporter
      // that names the test, so seeing the name means the pair executed.
      // `Expected:`/`Actual:` is package:test's reporter wording, not the
      // behavior's — it moves with the reporter (`--reporter=json`) and
      // matcher versions, so it cannot carry this proof.
      final emittedName = RegExp(
        r"test\('([^']*)'",
      ).firstMatch(File(testPath).readAsStringSync())!.group(1)!;
      expect(
        combined,
        contains(emittedName),
        reason:
            'the runner named the emitted test, so the pair RAN and failed '
            'through an assertion:\n$combined',
      );
    },
    tags: 'slow',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
