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
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/generation_planner.dart';

void main() {
  const planner = GenerationPlanner();

  group('GenerationPlanner (T005 / FR-005)', () {
    test('U3: an entity-bearing behavior maps to a plan whose first step '
        'is `entity create` carrying the exact real-CLI argv — including '
        'the required -n/--name flag (bug #609)', () {
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
      // Exact argv pin: the REAL EntityCommand rejects a bare positional
      // name ("Error: Entity name is required. Use -n or --name to
      // specify."), so the plan must carry `-n` (bug #609).
      expect(plan.steps.first.args, ['entity', 'create', '-n', 'User']);
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
      // Entity behavior → exactly 3 steps: entity create, tdd wire
      // (bug #610 — the subject-implementation step without which green
      // is unreachable on the real pipeline), build.
      expect(plan.steps, hasLength(3));
      // The wire step carries the behavior id and the entity name so
      // `zfa tdd wire` can resolve both artifacts.
      expect(plan.steps[1].args, ['tdd', 'wire', 'B-003', '--entity', 'User']);
    });

    test('U7: an unmappable behavior yields an unexpressibleReason naming '
        'the unmet capability in behavior terms', () {
      // Bug #657: verb phrases like "parse" now map to the `tdd func`
      // generator surface, so the unmappable case here uses a verb that
      // carries no function-generation intent.
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'B-042',
          feature: '047-tdd-make',
          sourceCriterion: 'FR-005',
          description: 'provision bespoke DSL syntax with no generator surface',
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

  group('GenerationPlanner — bug 657: function-intent behaviors map to the '
      '`tdd func` generator surface', () {
    test('U8-657: a render-type behavior maps to a plan whose first step '
        'is `tdd func <id>` and whose last step is `build` (spec 004 U1 '
        'shape)', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'U1',
          feature: '004-cloud-agent-task-dispatch',
          sourceCriterion: 'FR-001',
          description:
              'render returns a non-empty string for a fully '
              'populated task',
        ),
      );
      expect(plan.isExpressible, isTrue, reason: plan.unexpressibleReason);
      expect(plan.steps.first.args, ['tdd', 'func', 'U1']);
      // Every expressible plan still terminates in a `build` step (U5).
      expect(plan.steps.last.args, contains('build'));
      expect(plan.unexpressibleReason, isNull);
    });

    test('U9-657: every function-intent verb phrase maps to the func '
        'surface (render, format, parse, compute, convert, return)', () {
      for (final desc in [
        'render returns a non-empty string for a fully populated task',
        'format the timestamp as an ISO string',
        'parse the raw payload into a map',
        'compute the total price for the cart',
        'convert the record into a row',
        'return true when the task is fully populated',
      ]) {
        final plan = planner.plan(
          BehaviorSummary(
            behaviorId: 'B-fn',
            feature: 'f',
            sourceCriterion: 'FR-005',
            description: desc,
          ),
        );
        expect(plan.isExpressible, isTrue, reason: desc);
        expect(plan.steps.first.args, ['tdd', 'func', 'B-fn'], reason: desc);
      }
    });

    test('U10-657: entity and CRUD/use-case surfaces take precedence — a '
        'description carrying both an entity and a function verb still '
        'maps to `entity create`', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'B-both',
          feature: 'f',
          sourceCriterion: 'FR-005',
          description: 'create entity Invoice with totals to render',
        ),
      );
      expect(plan.isExpressible, isTrue);
      expect(plan.steps.first.args, ['entity', 'create', '-n', 'Invoice']);
    });

    test('U11-657: a behavior whose description carries no function-intent '
        'verb stays unexpressible (spec 003 U3 shape) — the non-stop '
        'fallback handles it downstream', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'U3',
          feature: '003-user-communication-interface',
          sourceCriterion: 'FR-003',
          description:
              'system must provide a conversational interface '
              'between the operator',
        ),
      );
      expect(plan.isExpressible, isFalse);
      expect(plan.steps, isEmpty);
      expect(plan.unexpressibleReason, isNotNull);
    });

    test('U12-657: the shared function-intent matcher scans past framing '
        'words', () {
      expect(
        GenerationPlanner.functionIntentVerb(
          'The operator must parse the raw payload',
        ),
        'parse',
      );
      expect(
        GenerationPlanner.functionIntentVerb('Provision bespoke DSL syntax'),
        isNull,
      );
    });
  });

  group(
    'GenerationPlanner — bug 696: the behavior ID is not an entity name',
    () {
      test('U-696a: a CRUD/use-case behavior whose description names the '
          'entity derives the `make` name from the description trace, not '
          'from the behavior ID', () {
        // The issue #696 repro: behavior U5 ("u5" after slugification) is
        // NOT an entity. The description carries the real name — the plan
        // must use it.
        final plan = planner.plan(
          const BehaviorSummary(
            behaviorId: 'U5',
            feature: '001-app-bootstrap',
            sourceCriterion: 'FR-005',
            description: 'create User use case returns the saved entity',
          ),
        );
        expect(plan.isExpressible, isTrue, reason: plan.unexpressibleReason);
        // Pre-fix this was `['make', 'u5']` — the slugified behavior ID —
        // which the real CLI rejects with "no entity source file was
        // found" (#496 fail-fast).
        expect(plan.steps.first.args, ['make', 'User']);
        expect(plan.steps.last.args, contains('build'));
      });

      test('U-696b: a CRUD/use-case behavior whose description names no '
          'entity passes --no-entity so the real CLI does not fail-fast on '
          'a missing entity source file', () {
        final plan = planner.plan(
          const BehaviorSummary(
            behaviorId: 'U6',
            feature: '001-app-bootstrap',
            sourceCriterion: 'FR-006',
            description: 'service exposes the count of pending items',
          ),
        );
        expect(plan.isExpressible, isTrue, reason: plan.unexpressibleReason);
        // No entity name is derivable anywhere: the slugified ID is the
        // only name left, and the real CLI REQUIRES --no-entity for it
        // (issue #696's exact failure without the flag).
        expect(plan.steps.first.args, ['make', 'u6', '--no-entity']);
        expect(plan.steps.last.args, contains('build'));
      });

      test('U-696c: an explicit target still wins over the description '
          'trace and never carries --no-entity', () {
        final plan = planner.plan(
          const BehaviorSummary(
            behaviorId: 'U7',
            feature: '001-app-bootstrap',
            sourceCriterion: 'FR-007',
            description: 'create Invoice use case with totals',
            target: 'Invoice',
          ),
        );
        expect(plan.isExpressible, isTrue, reason: plan.unexpressibleReason);
        expect(plan.steps.first.args, ['make', 'Invoice']);
      });
    },
  );

  group('GenerationPlanner — bug 723: unit behaviors route to the '
      'plain-function generator', () {
    test('U-723a: a unit-kind behavior whose description hits the CRUD '
        'branch maps to `tdd func <id>`, never `zfa make <slug>`', () {
      // The #718/#723 repro shape: unit behavior U5 whose prose carries
      // a CRUD keyword. Pre-fix the plan was `['make', 'u5',
      // '--no-entity']` — the lowercased behavior ID as an entity name —
      // which never implements the unit subject, so the run loop
      // stopped at U5:make with generation-error.
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'U5',
          feature: '001-app-bootstrap',
          sourceCriterion: 'FR-005',
          description: 'the validation service returns a non-empty label',
          kind: BehaviorKind.unit,
        ),
      );
      expect(plan.isExpressible, isTrue, reason: plan.unexpressibleReason);
      expect(plan.steps.first.args, ['tdd', 'func', 'U5']);
      // Every expressible plan still terminates in a `build` step (U5).
      expect(plan.steps.last.args, contains('build'));
    });

    test('U-723b: with no kind signal the dispatch stays '
        'description-keyed — the #696 `make <slug> --no-entity` plan is '
        'preserved', () {
      // Backward compatibility: pre-list fixtures and hand-registered
      // behaviors (kind null) keep the exact #696 plan.
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'U6',
          feature: '001-app-bootstrap',
          sourceCriterion: 'FR-006',
          description: 'service exposes the count of pending items',
        ),
      );
      expect(plan.isExpressible, isTrue, reason: plan.unexpressibleReason);
      expect(plan.steps.first.args, ['make', 'u6', '--no-entity']);
      expect(plan.steps.last.args, contains('build'));
    });

    test('U-723c: an acceptance-kind behavior with a CRUD description '
        'keeps the entity `make` path', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'A2',
          feature: '001-app-bootstrap',
          sourceCriterion: 'AC-2',
          description: 'the repository exposes the saved session',
          kind: BehaviorKind.acceptance,
        ),
      );
      expect(plan.isExpressible, isTrue, reason: plan.unexpressibleReason);
      expect(plan.steps.first.args.first, 'make');
    });

    test('U-723d: an entity-bearing unit behavior keeps the entity '
        'pipeline — only the CRUD/make dispatch reroutes', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'U9',
          feature: '001-app-bootstrap',
          sourceCriterion: 'FR-009',
          description: 'create entity User with email',
          kind: BehaviorKind.unit,
        ),
      );
      expect(plan.isExpressible, isTrue, reason: plan.unexpressibleReason);
      expect(plan.steps.first.args, ['entity', 'create', '-n', 'User']);
      expect(plan.steps[1].args, ['tdd', 'wire', 'U9', '--entity', 'User']);
      expect(plan.steps.last.args, contains('build'));
    });
  });
}
