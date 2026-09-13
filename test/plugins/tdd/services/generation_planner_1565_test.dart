// SPEC 1565 — make's plan skips the doomed func step (fast tier).
//
// When the subject is already the gen contract-derived stub func would
// refuse (provenance markers + non-rewritable signature), the plan must not
// schedule `tdd func`: scheduling it dead-ends the make in a
// generation-error ON A SUBJECT THAT IS ALREADY WHAT THE BEHAVIOR NEEDS.
// The plan stays expressible (non-empty, ending in the terminal `build`).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/generation_planner.dart';

void main() {
  const planner = GenerationPlanner();

  BehaviorSummary unitSummary({bool skipFuncScaffold = false}) =>
      BehaviorSummary(
        behaviorId: 'U1',
        feature: '1565-func-recognize-contract-derived-subject',
        sourceCriterion: 'FR-1',
        description: 'the scanner returns the active session',
        skipFuncScaffold: skipFuncScaffold,
      );

  group('GenerationPlanner — SPEC 1565 plan skip', () {
    test('U-1565-8: skipFuncScaffold drops the func step; the plan stays '
        'expressible and ends in the terminal build step', () {
      final plan = planner.plan(unitSummary(skipFuncScaffold: true));

      expect(plan.isExpressible, isTrue, reason: plan.toString());
      expect(plan.unexpressibleReason, isNull);
      expect(plan.steps, hasLength(1));
      expect(plan.steps.single.args, ['build']);
      expect(
        plan.steps.single.purpose,
        contains('#1565'),
        reason: 'the skip reason must name the issue for audit',
      );
    });

    test('U-1565-8b: the unit-kind dispatch honors the skip too (U<n> id '
        'routing keeps its build step)', () {
      final plan = planner.plan(
        BehaviorSummary(
          behaviorId: 'U7',
          feature: '1565-func-recognize-contract-derived-subject',
          sourceCriterion: 'FR-1',
          description: 'the scanner returns the active session',
          skipFuncScaffold: true,
        ),
      );

      expect(
        plan.steps.where((s) => s.args.length >= 2 && s.args[0] == 'tdd'),
        isEmpty,
        reason: 'no tdd step may be scheduled for a skipped func scaffold',
      );
      expect(plan.steps.last.args, ['build']);
    });

    test('U-1565-9: the default summary keeps the func step (legacy '
        'plain-function and scalar contract-derived subjects)', () {
      final plan = planner.plan(unitSummary());

      expect(plan.isExpressible, isTrue);
      expect(plan.steps.first.args, [
        'tdd',
        'func',
        'U1',
        '--feature',
        '1565-func-recognize-contract-derived-subject',
      ]);
      expect(plan.steps.last.args, ['build']);
    });

    test('U-1565-9b: a function-intent description keeps the func step '
        'when the skip flag is absent (SC-4 regression guard)', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'B-009',
          feature: '1565-func-recognize-contract-derived-subject',
          sourceCriterion: 'FR-1',
          description: 'render returns a non-empty string for a task',
        ),
      );

      expect(plan.steps.first.args.first, 'tdd');
      expect(plan.steps.first.args[1], 'func');
    });
  });
}
