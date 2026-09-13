// Issue #1541 — the contract lane harness invoked the seam with a bare
// `null` for every `dynamic`-typed declared parameter, and the emitted
// `_captured` caught ONLY `UnimplementedError`. An argument-validating
// implementation wired to the seam (`Logger logger(dynamic subsystem) =>
// AgentLog.logger(subsystem as String)`) rejected the scaffold argument:
// the cast threw `TypeError` / the validation threw `ArgumentError`, the
// error escaped uncaught, and verify-red graded the transcript segment
// `runner-error` (no `Expected:`/`Actual:` signature) — never a named
// contract verdict. The contract could not be satisfied by ANY
// argument-validating implementation.
//
// Fix under test (spec 1541-contract-harness-declared-shape-args):
//   FR-1 — `_representativeArg` resolves `dynamic`/empty declared types to
//          the `_argN()` scaffold placeholder seam (the unit lane's
//          `provide a representative argument` discipline), never the bare
//          `null` literal; nullable complex types keep `null` (their
//          declared shape IS nullable).
//   FR-2 — the emitted `_captured` catches ALL errors (`on Object`):
//          `UnimplementedError` keeps driving BLOCKED via the Case 2
//          assertion; any other captured error is a
//          satisfied-with-rejection (the seam is implemented and
//          validating) — never an uncaught escape.
//   FR-4 — the return-type case (Case 3, non-nullable scalar returns) is
//          guarded: the `isA<...>` assertion runs only when the captured
//          outcome is not a rejection. Case 1/Case 2 text and the
//          `isNot(isA<UnimplementedError>())` pin stay unchanged.
//
// Fast tier only: pure render pins against `ContractTestWriter` (no
// `dart test` spawn). The real-runner e2e lives in
// contract_satisfied_with_rejection_e2e_1541_test.dart (slow tier).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/contract_test_writer.dart';

Behavior _contract(String description, {String target = 'logger'}) => Behavior(
  id: 'A1',
  feature: '1541-harness',
  kind: BehaviorKind.contract,
  description: description,
  sourceCriterion: 'AC-1',
  target: target,
);

const dynamicParamContract =
    'contract:A1 — Logger.logger(dynamic subsystem) -> Logger '
    '(interface method contract)';
const scalarContract =
    'contract:A1 — User.validateEmail(String email) -> bool '
    '(entity method contract)';
const nullableComplexParamContract =
    'contract:A1 — Session.restore(UserPrefs? prefs) -> bool '
    '(entity method contract)';

Future<String> _render(String description, {String target = 'logger'}) async {
  final dir = await Directory.systemTemp.createTemp('zfa_1541_');
  try {
    final testPath = p.join(dir.path, 'test', 'tdd', '1541', 'a1_test.dart');
    await const ContractTestWriter().write(
      behavior: _contract(description, target: target),
      testPath: testPath,
      subjectPath: p.join(dir.path, 'lib', 'tdd', '1541', 'a1_subject.dart'),
    );
    return File(testPath).readAsStringSync();
  } finally {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

void main() {
  group('U-1541-1: dynamic params get the declared-shape placeholder, not '
      'bare null (FR-1)', () {
    test(
      'the Case 2 invocation passes _arg0(), never the literal null',
      () async {
        final test = await _render(dynamicParamContract);
        expect(
          test,
          contains('impl(_arg0())'),
          reason:
              'a dynamic-typed declared param must receive the scaffold '
              'placeholder argument (the unit-lane discipline), never the '
              'bare null an argument-validating implementation rejects:\n'
              '$test',
        );
        expect(
          test,
          isNot(contains('impl(null)')),
          reason:
              'the bare null scaffold argument is the #1541 defect itself '
              '(type Null is not a subtype of String in type cast):\n$test',
        );
      },
    );

    test('the placeholder helper instructs the author to provide a '
        'representative argument', () async {
      final test = await _render(dynamicParamContract);
      expect(
        test,
        contains("Object? _arg0() =>"),
        reason:
            'the placeholder seam must be emitted for the dynamic '
            'param:\n$test',
      );
      expect(
        test,
        contains('provide a representative `dynamic` '),
        reason:
            'the instruction must name the declared type so the author '
            'knows what to replace it with:\n$test',
      );
      expect(
        test,
        contains('Logger.logger` contract test'),
        reason: 'the instruction must name the declared contract:\n$test',
      );
      expect(
        test,
        contains('SCAFFOLD PLACEHOLDERS'),
        reason:
            'the scaffold comment block must list the dynamic '
            'placeholder:\n$test',
      );
    });

    test('a nullable complex type still legitimately resolves to null '
        '(the declared shape IS nullable)', () async {
      final test = await _render(
        nullableComplexParamContract,
        target: 'restore',
      );
      expect(
        test,
        contains('impl(null)'),
        reason:
            '`UserPrefs? prefs` accepts null as its representative value '
            '(only dynamic/empty lost the bare-null scaffold):\n$test',
      );
      expect(test, isNot(contains('_arg0()')));
    });

    test('a scalar-typed param keeps its representative literal '
        '(the #1007 scalar path is untouched)', () async {
      final test = await _render(scalarContract, target: 'validateEmail');
      expect(
        test,
        contains("impl('contract-sample')"),
        reason: 'String params keep the representative literal:\n$test',
      );
      expect(test, isNot(contains('_arg0()')));
    });
  });

  group('U-1541-2: _captured catches ALL errors (FR-2)', () {
    test('every parseable render emits the catch-all capture arm', () async {
      for (final description in [
        dynamicParamContract,
        scalarContract,
        nullableComplexParamContract,
      ]) {
        final test = await _render(description);
        expect(
          test,
          contains('on Object catch (error)'),
          reason:
              'the emitted _captured must catch every thrown error '
              '(ArgumentError from a validating implementation, TypeError '
              'from a cast, ...) — never an uncaught escape into '
              'runner-error:\n$test',
        );
      }
    });

    test('the captured-error doc names the outcome split (BLOCKED vs '
        'satisfied-with-rejection)', () async {
      final test = await _render(scalarContract);
      expect(
        test,
        contains('issue #1541'),
        reason:
            'the emitted helper doc must name the #1541 split so the '
            'scaffold reads honestly:\n$test',
      );
    });
  });

  group('U-1541-3: the return-type case is rejection-guarded, the #1007 '
      'pins unchanged (FR-4)', () {
    test(
      'Case 3 runs only when the captured outcome is not a rejection',
      () async {
        final test = await _render(scalarContract, target: 'validateEmail');
        expect(
          test,
          contains('outcome is! Error && outcome is! Exception'),
          reason:
              'a captured rejection has no return value to type-check — '
              'the guard records the satisfied-with-rejection outcome:\n'
              '$test',
        );
        expect(
          test,
          contains('isA<bool>()'),
          reason:
              'the guarded assertion keeps the declared return type:\n'
              '$test',
        );
      },
    );

    test('the #1007 case enumeration and Case 2 pin are unchanged', () async {
      final test = await _render(scalarContract, target: 'validateEmail');
      expect(test, contains('Case 1 of 3'));
      expect(test, contains('Case 2 of 3'));
      expect(test, contains('Case 3 of 3'));
      expect(
        test,
        contains('isNot(isA<UnimplementedError>())'),
        reason: 'the BLOCKED-driving assertion is byte-unchanged:\n$test',
      );
      expect(RegExp(r'\btest\(').allMatches(test), hasLength(1));
    });

    test('a non-scalar return carries no Case 3 and no guard (the '
        '#1007 two-case shape)', () async {
      final test = await _render(dynamicParamContract);
      expect(test, contains('Case 1 of 2'));
      expect(test, contains('Case 2 of 2'));
      expect(test, isNot(contains('Case 3')));
      expect(test, isNot(contains('outcome is! Error')));
    });
  });

  group('U-1541-6: the #1513 golden pin tracks the documented render '
      'change (FR-6)', () {
    test('the default render still emits the plain package:test import '
        'and the relative subject import (the #1513 surface)', () async {
      final test = await _render(scalarContract, target: 'validateEmail');
      expect(test, contains("import 'package:test/test.dart';"));
      expect(test, isNot(contains('flutter_test')));
      expect(test, contains("as subject;"));
    });
  });
}
