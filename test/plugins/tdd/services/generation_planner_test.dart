// Tests for `GenerationPlanner` (spec 047-tdd-make T005/T008,
// U3-U7 / FR-005).
//
// Pure unit tests: the planner takes a behavior summary and returns a
// plan, never touching the filesystem. Cases:
//   U3: entity-bearing → first step is `entity create <Name>`
//   U4: CRUD/use-case  → `make <slug>` step
//   U5: every expressible plan ends in `build`
//   U6: a plan contains no steps beyond what the behavior requires
//   U7: unmappable behavior → unexpressibleReason naming the
//       unmet capability in behavior terms.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/generation_plan.dart';
import 'package:zuraffa/src/plugins/tdd/services/generation_planner.dart';

void main() {
  const planner = GenerationPlanner();

  group('GenerationPlanner (T005 / FR-005)', () {
    test('U3: an entity-bearing behavior maps to a plan whose first step '
        'is `entity create`', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'B-003',
          feature: '047-tdd-make',
          sourceCriterion: 'FR-005',
          description: 'create entity User with email',
        ),
      );
      expect(plan.isExpressible, isTrue);
      expect(plan.steps, isNotEmpty);
      expect(plan.steps.first.args.first, 'entity');
      expect(plan.steps.first.args[1], 'create');
    });

    test('U4: a CRUD/use-case behavior maps to a `make` step with the '
        'minimal preset', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'B-007',
          feature: '047-tdd-make',
          sourceCriterion: 'FR-005',
          description: 'CRUD repository for User',
        ),
      );
      expect(plan.isExpressible, isTrue);
      expect(plan.steps.first.args.first, 'make');
    });

    test('U5: every expressible plan terminates in a `build` step', () {
      for (final desc in [
        'create entity User with email',
        'CRUD use-case for Account',
        'use-case UpdateUser',
        'repository UserRepository',
        'service UserAuthentication',
      ]) {
        final plan = planner.plan(
          BehaviorSummary(
            behaviorId: 'B-$desc',
            feature: '047-tdd-make',
            sourceCriterion: 'FR-005',
            description: desc,
          ),
        );
        expect(plan.isExpressible, isTrue, reason: desc);
        expect(plan.steps.last.args, contains('build'));
      }
    });

    test('U6: a plan contains no steps beyond what the behavior requires '
        '(minimal generation)', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'B-003',
          feature: '047-tdd-make',
          sourceCriterion: 'FR-005',
          description: 'create entity User with email',
        ),
      );
      // Entity behavior → exactly 2 steps: entity create, build.
      expect(plan.steps, hasLength(2));
    });

    test('U7: an unmappable behavior yields an unexpressibleReason naming '
        'the unmet capability in behavior terms', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'B-042',
          feature: '047-tdd-make',
          sourceCriterion: 'FR-005',
          description: 'parse bespoke DSL syntax with no generator surface',
        ),
      );
      expect(plan.isExpressible, isFalse);
      expect(plan.steps, isEmpty);
      expect(plan.unexpressibleReason, isNotNull);
      // The reason names the behavior id and the unmet capability.
      expect(plan.unexpressibleReason!, contains('B-042'));
      expect(plan.unexpressibleReason!.toLowerCase(), contains('pipeline'));
      expect(
        plan.unexpressibleReason!.toLowerCase(),
        contains('cannot express'),
      );
    });

    test('U1: a plan is either expressible with non-empty steps ending in '
        'build, or carries an unexpressibleReason — never both', () {
      // Expressible plan: steps non-empty, reason null.
      final ok = planner.plan(
        const BehaviorSummary(
          behaviorId: 'B-OK',
          feature: 'f',
          sourceCriterion: 'FR-005',
          description: 'create entity Foo with bar',
        ),
      );
      expect(ok.isExpressible, isTrue);
      expect(ok.unexpressibleReason, isNull);
      expect(ok.steps.last.args, contains('build'));

      // Unexpressible plan: steps empty, reason set.
      final bad = planner.plan(
        const BehaviorSummary(
          behaviorId: 'B-BAD',
          feature: 'f',
          sourceCriterion: 'FR-005',
          description: 'do something wild that no generator supports',
        ),
      );
      expect(bad.isExpressible, isFalse);
      expect(bad.unexpressibleReason, isNotNull);
      expect(bad.steps, isEmpty);
    });
  });
}
