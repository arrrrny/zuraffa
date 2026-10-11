/// Unit tests for the spec-mutation operator engine (spec
/// 0967-spec-mutation-arena): deterministic candidate generation per
/// contract element, line-surgical application, and budget/seed
/// selection.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/spec_mutation.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_mutator.dart';

const kFixtureSpec = '''
**Template Version**: `zuraffa-1.0`

# Feature Specification: Toy Greeter

**Feature Branch**: `toy-greeter`

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Greeting (Priority: P1)

**Acceptance Scenarios**:

1. **Given** any user, **When** the greeter greets, **Then** it shows the message 'Hello'.
   **Type**: acceptance
2. **Given** an empty name, **When** the greeter greets, **Then** it returns 0 as the greeting code.
   **Type**: acceptance

### Functional Requirements

- **FR-001**: The greeter MUST return 42 as the greeting code when the name is not empty.
- **FR-002**: The greeter MUST return 0 when the name is empty; it MUST NOT return 42 in that case.
- **FR-003**: The greeter MUST accept greeting counts within 0..100 and MUST return 100 when full.
- **FR-004**: The greeter MUST navigate to /home after greeting and use the key auth.session.
''';

void main() {
  const mutator = SpecMutator();

  group('operator set parsing', () {
    test('parses the declared operator labels', () {
      final ops = SpecMutationOperator.parseList(
        'weaken,drop,swap-literal,widen,drop-must-not',
      );
      expect(ops.length, 5);
    });

    test('unknown operator label is a FormatException naming it', () {
      expect(
        () => SpecMutationOperator.parseList('weaken,nuke'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('nuke'),
          ),
        ),
      );
    });

    test('labels are the CLI tokens', () {
      expect(SpecMutationOperator.weaken.label, 'weaken');
      expect(SpecMutationOperator.drop.label, 'drop');
      expect(SpecMutationOperator.swapLiteral.label, 'swap-literal');
      expect(SpecMutationOperator.widen.label, 'widen');
      expect(SpecMutationOperator.dropMustNot.label, 'drop-must-not');
    });
  });

  group('candidate generation', () {
    test('assigns SM-### ids in document order', () {
      final candidates = mutator.candidates(kFixtureSpec);
      expect(candidates, isNotEmpty);
      for (var i = 0; i < candidates.length; i++) {
        expect(
          candidates[i].mutationId,
          'SM-${(i + 1).toString().padLeft(3, '0')}',
        );
      }
    });

    test('ids are stable across an operator filter (same doc order)', () {
      final all = mutator.candidates(kFixtureSpec);
      final weaken = mutator.candidates(
        kFixtureSpec,
        operators: const {SpecMutationOperator.weaken},
      );
      final expected = all
          .where((c) => c.operator == SpecMutationOperator.weaken)
          .map((c) => c.mutationId)
          .toList();
      expect(weaken.map((c) => c.mutationId).toList(), expected);
    });

    test('weaken targets Then clauses carrying specifics', () {
      final weaken = mutator.candidates(
        kFixtureSpec,
        operators: const {SpecMutationOperator.weaken},
      );
      // AC-1 Then carries 'Hello'; AC-2 Then carries 0.
      expect(weaken, hasLength(2));
      expect(weaken.every((c) => c.element.contains(':Then')), isTrue);
      expect(weaken.any((c) => c.behaviorId == 'A1'), isTrue);
      expect(weaken.any((c) => c.behaviorId == 'A2'), isTrue);
    });

    test('drop targets only edge-case scenarios', () {
      final drops = mutator.candidates(
        kFixtureSpec,
        operators: const {SpecMutationOperator.drop},
      );
      // Only AC-2 matches the edge vocabulary ('empty').
      expect(drops, hasLength(1));
      expect(drops.single.behaviorId, 'A2');
      expect(drops.single.element, contains('AC-2'));
    });

    test('swap-literal covers quoted literals, numbers, routes, keys', () {
      final swaps = mutator.candidates(
        kFixtureSpec,
        operators: const {SpecMutationOperator.swapLiteral},
      );
      final elements = swaps.map((c) => c.element).toList();
      expect(
        elements.any((e) => e.startsWith('AC-1:Then:literal')),
        isTrue,
        reason: 'quoted literal Hello',
      );
      expect(
        elements.any((e) => e.startsWith('AC-2:Then:literal')),
        isTrue,
        reason: 'number 0 in the Then',
      );
      expect(
        elements.any((e) => e.startsWith('FR-001:literal')),
        isTrue,
        reason: 'number 42',
      );
      expect(
        elements.any((e) => e.startsWith('FR-004:literal')),
        isTrue,
        reason: 'route /home and key auth.session',
      );
      // Numbers swap deterministically n -> n+1.
      final swap42 = swaps.firstWhere((c) => c.element == 'FR-001:literal:42');
      expect(swap42.originalValues, ['42']);
    });

    test('widen targets ranges and bounds', () {
      final widened = mutator.candidates(
        kFixtureSpec,
        operators: const {SpecMutationOperator.widen},
      );
      expect(
        widened.any((c) => c.element.startsWith('FR-003:range')),
        isTrue,
        reason: '0..100 range',
      );
      expect(widened.length, greaterThanOrEqualTo(1));
    });

    test('drop-must-not targets FR statements with MUST NOT clauses', () {
      final drops = mutator.candidates(
        kFixtureSpec,
        operators: const {SpecMutationOperator.dropMustNot},
      );
      expect(drops, hasLength(1));
      expect(drops.single.behaviorId, 'U2');
      expect(drops.single.originalValues, contains('42'));
    });

    test('deterministic: same input yields identical candidates', () {
      final a = mutator
          .candidates(kFixtureSpec)
          .map((c) => c.toJson())
          .toList();
      final b = mutator
          .candidates(kFixtureSpec)
          .map((c) => c.toJson())
          .toList();
      expect(a, equals(b));
    });
  });

  group('application (line surgery)', () {
    test('weaken strips quoted literals and numbers from the Then', () {
      final candidate = mutator
          .candidates(
            kFixtureSpec,
            operators: const {SpecMutationOperator.weaken},
          )
          .firstWhere((c) => c.behaviorId == 'A1');
      final applied = mutator.apply(kFixtureSpec, candidate);
      expect(applied.mutatedSpec, isNot(contains("'Hello'")));
      expect(applied.mutatedSpec, contains('something'));
      // Only the Then line changed: the scenario header survives.
      expect(applied.mutatedSpec, contains('**Given** any user'));
    });

    test('weaken turns a numeric Then into a vague one', () {
      final candidate = mutator
          .candidates(
            kFixtureSpec,
            operators: const {SpecMutationOperator.weaken},
          )
          .firstWhere((c) => c.behaviorId == 'A2');
      final applied = mutator.apply(kFixtureSpec, candidate);
      expect(applied.mutatedSpec, contains('returns a number as the'));
    });

    test('drop removes the whole scenario block and nothing else', () {
      final candidate = mutator
          .candidates(
            kFixtureSpec,
            operators: const {SpecMutationOperator.drop},
          )
          .single;
      final applied = mutator.apply(kFixtureSpec, candidate);
      expect(applied.mutatedSpec, isNot(contains('empty name')));
      // FR section survives untouched.
      expect(applied.mutatedSpec, contains('**FR-001**'));
      expect(applied.mutatedSpec, contains('**FR-004**'));
      // First scenario survives.
      expect(applied.mutatedSpec, contains("'Hello'"));
    });

    test('swap-literal appends -swapped to string tokens', () {
      final swaps = mutator.candidates(
        kFixtureSpec,
        operators: const {SpecMutationOperator.swapLiteral},
      );
      final hello = swaps.firstWhere(
        (c) => c.element == "AC-1:Then:literal:'Hello'",
      );
      final applied = mutator.apply(kFixtureSpec, hello);
      expect(applied.mutatedSpec, contains("'Hello-swapped'"));
      expect(applied.mutatedSpec, isNot(contains("the message 'Hello'")));
    });

    test('swap-literal bumps numbers by one', () {
      final swaps = mutator.candidates(
        kFixtureSpec,
        operators: const {SpecMutationOperator.swapLiteral},
      );
      final n = swaps.firstWhere((c) => c.element == 'FR-001:literal:42');
      final applied = mutator.apply(kFixtureSpec, n);
      expect(applied.mutatedSpec, contains('MUST return 43 as the greeting'));
    });

    test('widen doubles the range upper bound and floors the lower', () {
      final widened = mutator.candidates(
        kFixtureSpec,
        operators: const {SpecMutationOperator.widen},
      );
      final range = widened.firstWhere(
        (c) => c.element.startsWith('FR-003:range'),
      );
      final applied = mutator.apply(kFixtureSpec, range);
      expect(applied.mutatedSpec, contains('within 0..200'));
    });

    test('drop-must-not removes the clause to the sentence boundary', () {
      final drops = mutator.candidates(
        kFixtureSpec,
        operators: const {SpecMutationOperator.dropMustNot},
      );
      final applied = mutator.apply(kFixtureSpec, drops.single);
      expect(applied.mutatedSpec, isNot(contains('MUST NOT')));
      expect(applied.mutatedSpec, contains('MUST return 0 when the name'));
    });

    test('apply reports the affected behavior for regen', () {
      final weaken = mutator
          .candidates(
            kFixtureSpec,
            operators: const {SpecMutationOperator.weaken},
          )
          .firstWhere((c) => c.behaviorId == 'A1');
      final applied = mutator.apply(kFixtureSpec, weaken);
      expect(applied.affectedBehaviorId, 'A1');
    });
  });

  group('budget + seed selection', () {
    test('seed 0 takes the document-order prefix', () {
      final selected = SpecMutator.select(
        mutator.candidates(kFixtureSpec),
        budget: 3,
        seed: 0,
      );
      final all = mutator.candidates(kFixtureSpec);
      expect(
        selected.map((c) => c.mutationId).toList(),
        all.take(3).map((c) => c.mutationId).toList(),
      );
    });

    test('a nonzero seed is a deterministic subset', () {
      final all = mutator.candidates(kFixtureSpec);
      final a = SpecMutator.select(all, budget: 3, seed: 7);
      final b = SpecMutator.select(all, budget: 3, seed: 7);
      expect(
        a.map((c) => c.mutationId).toList(),
        b.map((c) => c.mutationId).toList(),
      );
      expect(a, hasLength(3));
    });

    test('budget above the candidate count selects everything', () {
      final all = mutator.candidates(kFixtureSpec);
      final selected = SpecMutator.select(all, budget: 1000, seed: 0);
      expect(selected, hasLength(all.length));
    });
  });

  group('gate chain (P1)', () {
    test('accepts the fixture spec', () {
      final check = validateSpecContract(
        feature: 'toy-greeter',
        specMd: kFixtureSpec,
      );
      expect(check.accepted, isTrue, reason: check.refusal ?? '');
    });

    test('rejects a spec whose scenarios were all dropped', () {
      // Dropping BOTH scenarios leaves no acceptance scenarios — the
      // parser refuses; that refusal is a P1 kill.
      final twoScenarioSpec = kFixtureSpec
          .replaceFirst(
            "1. **Given** any user, **When** the greeter greets, **Then** it shows the message 'Hello'.\n"
                '   **Type**: acceptance\n',
            '',
          )
          .replaceFirst(
            '2. **Given** an empty name, **When** the greeter greets, '
                '**Then** it returns 0 as the greeting code.\n'
                '   **Type**: acceptance\n',
            '',
          );
      final check = validateSpecContract(
        feature: 'toy-greeter',
        specMd: twoScenarioSpec,
      );
      expect(check.accepted, isFalse);
      expect(check.refusal, isNotNull);
    });

    test('rejects a spec with an unknown template version', () {
      final broken = kFixtureSpec.replaceFirst('zuraffa-1.0', 'zuraffa-9.9');
      final check = validateSpecContract(
        feature: 'toy-greeter',
        specMd: broken,
      );
      expect(check.accepted, isFalse);
      expect(check.refusal, contains('template'));
    });
  });
}
