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
      'Case 3 runs only when the capture signal records no rejection',
      () async {
        final test = await _render(scalarContract, target: 'validateEmail');
        expect(
          test,
          contains('if (_rejection == null) {'),
          reason:
              'a captured rejection has no return value to type-check — '
              'the guard keys on the rejection SIGNAL `_captured` records '
              '(review finding), never the outcome runtime type:\n'
              '$test',
        );
        expect(
          test,
          contains('_rejection = error;'),
          reason: 'the capture records the thrown value as the signal:\n$test',
        );
        expect(
          test,
          isNot(contains('outcome is! Error && outcome is! Exception')),
          reason:
              'the runtime-type guess IS the review finding — a thrown raw '
              'value matching the declared return type was graded as a '
              'return that never happened:\n$test',
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

    test('a non-scalar return carries no Case 3 and no rejection signal '
        '(the #1007 two-case shape)', () async {
      final test = await _render(dynamicParamContract);
      expect(test, contains('Case 1 of 2'));
      expect(test, contains('Case 2 of 2'));
      expect(test, isNot(contains('Case 3')));
      // The rejection signal is emitted WITH its Case 3 reader — an
      // unread declaration would leak an `unused_element` analyzer
      // warning into every two-case scaffold (review finding follow-up).
      expect(test, isNot(contains('_rejection')));
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

  group('U-1541-8: declared types the seam renders verbatim get '
      'representative literals, never the Object? placeholder (review '
      'finding 1)', () {
    test('List<T> / Iterable<T> render an empty typed list literal', () async {
      expect(
        await _render(
          'contract:A1 — User.assign(List<String> roles) -> bool '
          '(entity method contract)',
        ),
        contains('impl(<String>[])'),
        reason:
            'the placeholder Object? cannot be assigned to '
            'List<String> — the pair must pass a typed literal',
      );
      expect(
        await _render(
          'contract:A1 — User.list(Iterable<String> names) -> bool '
          '(entity method contract)',
        ),
        contains('impl(<String>[])'),
      );
    });

    test('Set<T> / Map<K, V> render empty typed collection literals', () async {
      expect(
        await _render(
          'contract:A1 — User.tag(Set<int> ids) -> bool '
          '(entity method contract)',
        ),
        contains('impl(<int>{})'),
      );
      expect(
        await _render(
          'contract:A1 — User.score(Map<String, int> scores) -> bool '
          '(entity method contract)',
        ),
        contains('impl(<String, int>{})'),
      );
    });

    test('Future<void> / Stream<T> render their value-less literals', () async {
      expect(
        await _render(
          'contract:A1 — Api.wait(Future<void> done) -> bool '
          '(usecase contract)',
        ),
        contains('impl(Future<void>.value())'),
      );
      expect(
        await _render(
          'contract:A1 — Api.watch(Stream<int> ticks) -> bool '
          '(usecase contract)',
        ),
        contains('impl(const Stream.empty())'),
      );
    });

    test('a renderable collection settles its INNER type in the literal — '
        'the inner dynamic never nests a placeholder', () async {
      final test = await _render(
        'contract:A1 — Api.send(List<dynamic> cells) -> bool '
        '(usecase contract)',
      );
      expect(test, contains('impl(<dynamic>[])'), reason: test);
      expect(test, isNot(contains('_arg0')), reason: test);
    });

    test('Future<dynamic> nests the placeholder, labeled with the INNER '
        'type the author must supply', () async {
      final test = await _render(
        'contract:A1 — Api.poll(Future<dynamic> task) -> int '
        '(usecase contract)',
      );
      expect(
        test,
        contains('impl(Future<dynamic>.value(_arg0()))'),
        reason: test,
      );
      expect(
        test,
        contains('_arg0() -> a representative `dynamic` value'),
        reason: test,
      );
      expect(
        test,
        contains('provide a representative `dynamic` '),
        reason: test,
      );
    });

    test('a declared type with a NON-renderable inner keeps the '
        'placeholder (the seam parameter is Object? there)', () async {
      final test = await _render(
        'contract:A1 — Repo.save(List<Product> items) -> bool '
        '(usecase contract)',
      );
      expect(test, contains('impl(_arg0())'), reason: test);
      expect(
        test,
        contains('provide a representative `List<Product>` '),
        reason: test,
      );
    });
  });

  group('U-1541-9: raw thrown values are surfaced by Case 3 (review '
      'finding 2)', () {
    test('the guard asserts the captured rejection is an Error/Exception, '
        'so a raw throw fails instead of passing as a return', () async {
      final test = await _render(scalarContract, target: 'validateEmail');
      expect(
        test,
        contains('expect(_rejection, anyOf(isA<Error>(), isA<Exception>()),'),
        reason: test,
      );
      expect(test, contains('threw a raw value'), reason: test);
    });

    test('a returned value still type-checks against the declared return '
        '(the signal is only set on a capture)', () async {
      final test = await _render(scalarContract, target: 'validateEmail');
      expect(test, contains('if (_rejection == null) {'), reason: test);
      expect(test, contains('expect(outcome, isA<bool>(),'), reason: test);
    });
  });
}
