// Issue #1651 — scenario example extraction (RED phase).
//
// The engine's unit lane ignores the spec's acceptance scenarios: gen
// invents scaffold representative arguments `(0, 0)` and a type-only
// `isA<int>()` assertion, so a func-scaffolded `return 0;` dummy
// certifies green. Remediation 1 derives example-based assertions from
// the acceptance scenarios' concrete values — the parser must expose
// the Given/When/Then values the acceptance lane already consumes.
//
// The `ScenarioExample` model + `SpecParser.parseScenarioExamples` +
// `ScenarioResolver.firstForTarget` are the new surface under test.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/scenario_example.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';

void main() {
  group('SpecParser.parseScenarioExamples (issue #1651)', () {
    test('U1: extracts the issue\'s concrete values — Given 2 and 3, '
        'When Calculator.add, Then the sum 5', () {
      const spec = '''
**Template Version**: `zuraffa-1.0`

# Spec: zcalc

## Acceptance Scenarios

1. **Given** the integers 2 and 3, **When** `Calculator.add` is called,
   **Then** the sum 5 is returned. **Type**: acceptance
''';
      final examples = SpecParser.parseScenarioExamples(spec);
      expect(examples, hasLength(1));
      final e = examples.single;
      expect(e.id, 'A1');
      expect(e.when, contains('Calculator.add'));
      // The Given clause carries the concrete arguments, in order.
      expect(
        e.givenValues.map((v) => v.literal),
        containsAllInOrder(<String>['2', '3']),
      );
      // The Then clause carries the concrete outcome.
      expect(e.thenValues.map((v) => v.literal), contains('5'));
    });

    test('U2: bold and plain markers, flat and dotted numbering, '
        'multi-line blocks', () {
      const spec = '''
# Spec: mixed

1. **Given** a stack **When** pop is called **Then** the size 0 is returned.

2.1. Given the numbers 6 and 3
When `Calculator.divide` is called
Then the quotient 2.0 is returned.
''';
      final examples = SpecParser.parseScenarioExamples(spec);
      expect(examples, hasLength(2));
      expect(examples[0].id, 'A1');
      // "Given a stack" carries no concrete value; the outcome 0 lives
      // in the Then clause.
      expect(examples[0].givenValues, isEmpty);
      expect(examples[0].thenValues.last.literal, '0');
      expect(examples[1].id, 'A2');
      expect(examples[1].when, contains('divide'));
      expect(
        examples[1].givenValues.map((v) => v.literal),
        containsAllInOrder(<String>['6', '3']),
      );
      expect(examples[1].thenValues.map((v) => v.literal), contains('2.0'));
    });

    test('U3: quoted string and boolean values parse with their kinds', () {
      const spec = '''
# Spec: greet

1. **Given** the name 'Alice' **When** `Greeter.hello` is called
   **Then** the greeting 'Hello Alice' is returned.
''';
      final examples = SpecParser.parseScenarioExamples(spec);
      expect(examples, hasLength(1));
      final values = examples.single.givenValues;
      expect(values, hasLength(1));
      expect(values.single.kind, ScenarioValueKind.string);
      expect(values.single.literal, 'Alice');
      final then = examples.single.thenValues;
      expect(then.first.kind, ScenarioValueKind.string);
      expect(then.first.literal, 'Hello Alice');
    });

    test('U4: negative numbers parse as literals', () {
      const spec = '''
# Spec: temp

1. **Given** the integers -4 and 2, **When** `Calc.add` is called,
   **Then** the sum -2 is returned.
''';
      final examples = SpecParser.parseScenarioExamples(spec);
      expect(
        examples.single.givenValues.map((v) => v.literal),
        containsAllInOrder(<String>['-4', '2']),
      );
      expect(examples.single.thenValues.map((v) => v.literal), contains('-2'));
    });

    test('U5: a spec with no acceptance scenarios yields no examples', () {
      const spec = '''
# Spec: empty

### Layer Contracts

**Function**:
- `Formatter`: `label() -> bool`
''';
      expect(SpecParser.parseScenarioExamples(spec), isEmpty);
    });

    test('U6: FR numbers and AC ids never leak into the value list', () {
      const spec = '''
# Spec: leak

1. **Given** the integers 2 and 3, **When** `Calculator.add` is called,
   **Then** the sum 5 is returned. **Type**: acceptance

2. **Given** the integers 10 and 20, **When** `Calculator.add` is called,
   **Then** the sum 30 is returned.
''';
      final examples = SpecParser.parseScenarioExamples(spec);
      expect(examples, hasLength(2));
      // The leading AC numbers (`1.`, `2.`) are segment headers, not
      // Given values: the first example's values are exactly 2 and 3.
      expect(examples[0].givenValues.map((v) => v.literal).toList(), <String>[
        '2',
        '3',
      ]);
      expect(examples[1].givenValues.map((v) => v.literal).toList(), <String>[
        '10',
        '20',
      ]);
    });
  });

  group('ScenarioResolver.firstForTarget (issue #1651)', () {
    const spec = '''
# Spec: zcalc

1. **Given** the integers 2 and 3, **When** `Calculator.add` is called,
   **Then** the sum 5 is returned.

2. **Given** the integers 6 and 3, **When** `Calculator.divide` is called,
   **Then** the quotient 2.0 is returned.
''';

    test('U7: matches the scenario whose When clause names the target', () {
      final examples = SpecParser.parseScenarioExamples(spec);
      final add = ScenarioResolver.firstForTarget(examples, target: 'add');
      expect(add, isNotNull);
      expect(add!.when, contains('Calculator.add'));

      final divide = ScenarioResolver.firstForTarget(
        examples,
        target: 'divide',
      );
      expect(divide, isNotNull);
      expect(divide!.when, contains('Calculator.divide'));
    });

    test('U8: no matching scenario returns null (legacy shape stands)', () {
      final examples = SpecParser.parseScenarioExamples(spec);
      expect(
        ScenarioResolver.firstForTarget(examples, target: 'multiply'),
        isNull,
      );
    });

    test('U9: the target matches the method suffix of a qualified call '
        '(Calculator.add names add)', () {
      final examples = SpecParser.parseScenarioExamples(spec);
      // The declared method name is the match key; the scenario spells
      // the qualified `Calculator.add` form.
      final add = ScenarioResolver.firstForTarget(examples, target: 'add');
      expect(add, isNotNull);
    });
  });
}
