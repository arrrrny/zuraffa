// Issue #1651 — the unit test generator derives scenario-based
// assertions (RED phase).
//
// For a DECLARED scalar contract the pre-#1651 generator emits scaffold
// representative arguments `(0, 0)` and a type-only
// `expect(result, isA<int>())` — a func-scaffolded `return 0;` dummy
// satisfies it and the engine certifies a vacuous green. With a
// scenario example resolved from the spec's acceptance scenarios, the
// generated test must call the subject with the scenario's concrete
// arguments and assert the concrete outcome, so the dummy FAILS.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/models/routing.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/scenario_example.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';
import 'package:zuraffa/src/plugins/tdd/services/unit_contract_shape.dart';
import 'package:zuraffa/src/plugins/tdd/services/vacuous_guard.dart';

const zcalcSpec = '''
# Spec: zcalc

1. **Given** the integers 2 and 3, **When** `Calculator.add` is called,
   **Then** the sum 5 is returned.

2. **Given** the integers 6 and 3, **When** `Calculator.divide` is called,
   **Then** the quotient 2.0 is returned.
''';

Behavior unitBehavior(String id, String target) => Behavior(
  id: id,
  feature: 'zcalc',
  kind: BehaviorKind.unit,
  description:
      'The engine MUST add two integers via `Calculator.add` '
      'and return their sum.',
  sourceCriterion: 'FR-001',
  target: target,
);

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('bug_1651_writer_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    exitCode = 0;
  });

  Future<String> writePair({
    required Behavior behavior,
    required UnitContractShape? shape,
    ScenarioExample? scenario,
  }) async {
    final writer = BehaviorTestWriter(
      contractShape: shape,
      scenarioExample: scenario,
    );
    final testPath = p.join(tmpDir.path, '${behavior.id}_test.dart');
    final subjectPath = p.join(tmpDir.path, '${behavior.id}_subject.dart');
    await writer.write(
      behavior: behavior,
      testPath: testPath,
      subjectPath: subjectPath,
    );
    return File(testPath).readAsString();
  }

  group('BehaviorTestWriter scenario-derived assertions (issue #1651)', () {
    test('U1: a declared scalar contract with a scenario example emits the '
        'scenario arguments and a concrete equals assertion — not a '
        'type-only check', () async {
      final shape = UnitContractShape.of(
        const Signature(
          name: 'add',
          parameters: ['int a', 'int b'],
          returnType: 'int',
        ),
      );
      final scenario = ScenarioResolver.firstForTarget(
        SpecParser.parseScenarioExamples(zcalcSpec),
        target: 'add',
      );
      expect(scenario, isNotNull, reason: 'fixture scenario must resolve');

      final content = await writePair(
        behavior: unitBehavior('U1', 'subject_u1'),
        shape: shape,
        scenario: scenario,
      );

      expect(
        content,
        contains('subject.subject_u1(2, 3)'),
        reason:
            'the capture calls the subject with the scenario\'s concrete '
            'arguments, never the scaffold representatives (0, 0)',
      );
      expect(
        content,
        contains('expect(result, equals(5));'),
        reason:
            'the assertion pins the scenario\'s concrete outcome, so a '
            '`return 0;` dummy FAILS the test',
      );
      expect(
        content,
        isNot(contains('isA<int>()')),
        reason: 'the type-only assertion is the vacuity being fixed',
      );
      expect(
        content,
        isNot(contains('subject.subject_u1(0, 0)')),
        reason: 'the scaffold representative arguments are gone',
      );
    });

    test(
      'U2: NO scenario example keeps the legacy declared shape — the '
      'isA<T>() fallback and representative arguments (back-compat)',
      () async {
        final shape = UnitContractShape.of(
          const Signature(
            name: 'label',
            parameters: <String>[],
            returnType: 'bool',
          ),
        );

        final content = await writePair(
          behavior: unitBehavior('U2', 'subject_u2'),
          shape: shape,
          scenario: null,
        );

        expect(content, contains('subject.subject_u2()'));
        expect(content, contains('expect(result, isA<bool>());'));
      },
    );

    test('U3: a double declared return asserts the scenario\'s decimal '
        'outcome', () async {
      final shape = UnitContractShape.of(
        const Signature(
          name: 'divide',
          parameters: ['int a', 'int b'],
          returnType: 'double',
        ),
      );
      final scenario = ScenarioResolver.firstForTarget(
        SpecParser.parseScenarioExamples(zcalcSpec),
        target: 'divide',
      );

      final content = await writePair(
        behavior: unitBehavior('U4', 'subject_u4'),
        shape: shape,
        scenario: scenario,
      );

      expect(content, contains('subject.subject_u4(6, 3)'));
      expect(content, contains('expect(result, equals(2.0));'));
      expect(content, isNot(contains('isA<double>()')));
    });

    test('U4: a String declared param consumes the scenario\'s quoted '
        'value', () async {
      const spec = '''
# Spec: greet

1. **Given** the name 'Alice', **When** `Greeter.hello` is called,
   **Then** the greeting 'Hello Alice' is returned.
''';
      final shape = UnitContractShape.of(
        const Signature(
          name: 'hello',
          parameters: ['String name'],
          returnType: 'String',
        ),
      );
      final scenario = ScenarioResolver.firstForTarget(
        SpecParser.parseScenarioExamples(spec),
        target: 'hello',
      );

      final content = await writePair(
        behavior: unitBehavior('U5', 'subject_u5'),
        shape: shape,
        scenario: scenario,
      );

      expect(content, contains("subject.subject_u5('Alice')"));
      expect(content, contains("expect(result, equals('Hello Alice'));"));
      expect(content, isNot(contains('isA<String>()')));
    });

    test('U5: a scenario with fewer values than params falls back '
        'per-param — the compileable legacy literal fills the gap', () async {
      const spec = '''
# Spec: partial

1. **Given** the integer 7, **When** `Calc.combine` is called,
   **Then** the result 11 is returned.
''';
      final shape = UnitContractShape.of(
        const Signature(
          name: 'combine',
          parameters: ['int a', 'int b'],
          returnType: 'int',
        ),
      );
      final scenario = ScenarioResolver.firstForTarget(
        SpecParser.parseScenarioExamples(spec),
        target: 'combine',
      );

      final content = await writePair(
        behavior: unitBehavior('U6', 'subject_u6'),
        shape: shape,
        scenario: scenario,
      );

      expect(
        content,
        contains('subject.subject_u6(7, 0)'),
        reason:
            'the first param takes the scenario value; the second keeps '
            'the compileable representative literal',
      );
      expect(content, contains('expect(result, equals(11));'));
    });

    test('U6: the scenario plan does not leak into ACCEPTANCE rows — the '
        'acceptance capture stays the void-safe argument-free form', () async {
      final shape = UnitContractShape.of(
        const Signature(
          name: 'add',
          parameters: ['int a', 'int b'],
          returnType: 'int',
        ),
      );
      final scenario = ScenarioResolver.firstForTarget(
        SpecParser.parseScenarioExamples(zcalcSpec),
        target: 'add',
      );
      final behavior = Behavior(
        id: 'A1',
        feature: 'zcalc',
        kind: BehaviorKind.acceptance,
        description: 'the sum 5 is returned.',
        sourceCriterion: 'AC-1',
        target: 'subject_a1',
      );

      final content = await writePair(
        behavior: behavior,
        shape: shape,
        scenario: scenario,
      );

      expect(content, contains('subject.subject_a1();'));
      expect(content, isNot(contains('subject.subject_a1(2, 3)')));
      expect(content, isNot(contains('equals(5)')));
    });
  });

  group('type-only assertion detector (issue #1651)', () {
    test('U7: the declared-boolean pins are VALUE matchers — the #1310 '
        'dead-end removal stays intact', () {
      // `isFalse` pins the declared `bool` outcome (the twins of
      // `equals(true)` / `equals(false)`): plan_traces_cell_1310 U6
      // certifies exactly this pair over a dummy `=> false;` body.
      expect(
        contentIsTypeOnlyAssertion('expect(result, isFalse);'),
        isFalse,
        reason: 'the declared-boolean pin value-pins the outcome',
      );
      expect(
        contentIsTypeOnlyAssertion('expect(result, isTrue);'),
        isFalse,
        reason: 'the declared-boolean pin value-pins the outcome',
      );
    });

    test('U8: the placeholder-satisfiable shapes stay type-only', () {
      expect(
        contentIsTypeOnlyAssertion('expect(result, isA<int>());'),
        isTrue,
        reason: 'the post-#1259 generated shape is the refusal class',
      );
      expect(contentIsTypeOnlyAssertion('expect(result, isNotNull);'), isTrue);
      expect(
        contentIsTypeOnlyAssertion('''
          expect(result, isA<int>());
          expect(result, equals(5));
        '''),
        isFalse,
        reason: 'one value matcher flips the whole set',
      );
    });
  });
}
