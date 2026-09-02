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
      expect(plan.steps[1].args, [
        'tdd',
        'wire',
        'B-003',
        '--entity',
        'User',
        '--feature',
        '047-tdd-make',
      ]);
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
      expect(plan.steps.first.args, [
        'tdd',
        'func',
        'U1',
        '--feature',
        '004-cloud-agent-task-dispatch',
      ]);
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
        expect(plan.steps.first.args, [
          'tdd',
          'func',
          'B-fn',
          '--feature',
          'f',
        ], reason: desc);
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
        'verb stays unexpressible (spec 003 shape) — the non-stop '
        'fallback handles it downstream', () {
      // Bug #718: unexpressibility keyed on the description is now only
      // reachable for NON-unit behavior ids — a `U<n>` id routes to the
      // func surface before description matching ever runs (see the bug
      // 718 group below). The pin uses a legacy non-unit id.
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'B-003',
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
      // Bug #718 note: unit-kind ids (`U<n>`) no longer reach the CRUD
      // branch at all — they route to the `tdd func` surface before
      // description matching (see the bug 718 group below). The #696
      // name-derivation contract is pinned here on non-unit ids, the
      // only callers the CRUD branch still serves.
      test('U-696a: a CRUD/use-case behavior whose description names the '
          'entity derives the `make` name from the description trace, not '
          'from the behavior ID', () {
        // The issue #696 repro shape: the behavior id is NOT an entity.
        // The description carries the real name — the plan must use it.
        final plan = planner.plan(
          const BehaviorSummary(
            behaviorId: 'B-005',
            feature: '001-app-bootstrap',
            sourceCriterion: 'FR-005',
            description: 'create User use case returns the saved entity',
          ),
        );
        expect(plan.isExpressible, isTrue, reason: plan.unexpressibleReason);
        // Pre-fix this was `['make', 'b_005']` — the slugified behavior
        // ID — which the real CLI rejects with "no entity source file
        // was found" (#496 fail-fast).
        expect(plan.steps.first.args, ['make', 'User']);
        expect(plan.steps.last.args, contains('build'));
      });

      test('U-696b: a CRUD/use-case behavior whose description names no '
          'entity passes --no-entity so the real CLI does not fail-fast on '
          'a missing entity source file', () {
        final plan = planner.plan(
          const BehaviorSummary(
            behaviorId: 'B-006',
            feature: '001-app-bootstrap',
            sourceCriterion: 'FR-006',
            description: 'service exposes the count of pending items',
          ),
        );
        expect(plan.isExpressible, isTrue, reason: plan.unexpressibleReason);
        // No entity name is derivable anywhere: the slugified ID is the
        // only name left, and the real CLI REQUIRES --no-entity for it
        // (issue #696's exact failure without the flag).
        expect(plan.steps.first.args, ['make', 'b_006', '--no-entity']);
        expect(plan.steps.last.args, contains('build'));
      });

      test('U-696c: an explicit target still wins over the description '
          'trace and never carries --no-entity', () {
        final plan = planner.plan(
          const BehaviorSummary(
            behaviorId: 'B-007',
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

  group('GenerationPlanner — bug 718: unit behaviors route to the '
      'plain-function generator', () {
    // Issue #718: `zfa tdd make` stopped at the first unit behavior
    // (U5+) with `outcome=generation-error` because the planner keyed
    // dispatch on the DESCRIPTION: CRUD keyword prose ("service",
    // "repository", "use case", ...) won branch 2 and produced
    // `zfa make u5` — the slugified behavior id as an entity name.
    // A unit behavior's paired artifacts are a plain no-argument
    // subject function and its test (spec 044), so entity/CRUD
    // scaffolds can never flip its test green. The fix: the behavior
    // id prefix IS the kind (SpecParser emits `U<n>` for unit, `A<n>`
    // for acceptance) and unit-kind dispatches to the `tdd func`
    // surface (bug #657/#660) BEFORE any description matching.
    test('U-718a: a unit behavior with CRUD-keyword prose routes to '
        '`tdd func <id>` — never `zfa make <slugified-id>` '
        '(the issue #718 repro)', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'U5',
          feature: '001-app-bootstrap',
          sourceCriterion: 'FR-005',
          description: 'service exposes the count of pending items',
        ),
      );
      expect(plan.isExpressible, isTrue, reason: plan.unexpressibleReason);
      // Pre-fix this was `['make', 'u5', '--no-entity']` — the exact
      // issue #718 dispatch (behavior id as entity name).
      expect(plan.steps.first.args, [
        'tdd',
        'func',
        'U5',
        '--feature',
        '001-app-bootstrap',
      ]);
      expect(plan.steps.last.args, contains('build'));
      expect(plan.unexpressibleReason, isNull);
    });

    test('U-718b: a unit behavior with entity-bearing prose routes to '
        '`tdd func <id>` — never `entity create` + `tdd wire`', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'U6',
          feature: '001-app-bootstrap',
          sourceCriterion: 'FR-006',
          description: 'create entity User with email',
        ),
      );
      expect(plan.isExpressible, isTrue, reason: plan.unexpressibleReason);
      expect(plan.steps, hasLength(2));
      expect(plan.steps.first.args, [
        'tdd',
        'func',
        'U6',
        '--feature',
        '001-app-bootstrap',
      ]);
      expect(plan.steps.last.args, contains('build'));
    });

    test('U-718c: an explicit target cannot pull a unit behavior back '
        'onto the CRUD branch', () {
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
      expect(plan.steps.first.args, [
        'tdd',
        'func',
        'U7',
        '--feature',
        '001-app-bootstrap',
      ]);
    });

    test('U-718d: a unit behavior keeps its function-intent verb in the '
        'step purpose when the description carries one', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'U8',
          feature: '001-app-bootstrap',
          sourceCriterion: 'FR-008',
          description: 'service renders the pending count and returns a string',
        ),
      );
      expect(plan.isExpressible, isTrue, reason: plan.unexpressibleReason);
      expect(plan.steps.first.args, [
        'tdd',
        'func',
        'U8',
        '--feature',
        '001-app-bootstrap',
      ]);
      expect(plan.steps.first.purpose, contains('render'));
    });

    test('U-718e: acceptance and legacy ids keep description-keyed '
        'routing — the unit branch never captures them', () {
      // Acceptance id + entity prose → entity branch (unchanged).
      final acceptance = planner.plan(
        const BehaviorSummary(
          behaviorId: 'A1',
          feature: '001-app-bootstrap',
          sourceCriterion: 'AC-1',
          description: 'create entity User with email',
        ),
      );
      expect(acceptance.isExpressible, isTrue);
      expect(acceptance.steps.first.args, ['entity', 'create', '-n', 'User']);

      // Legacy id + CRUD prose → CRUD branch (unchanged); the entity
      // name comes from the description trace (#696), not the id.
      final legacy = planner.plan(
        const BehaviorSummary(
          behaviorId: 'B-007',
          feature: '001-app-bootstrap',
          sourceCriterion: 'FR-005',
          description: 'create User use case returns the saved entity',
        ),
      );
      expect(legacy.isExpressible, isTrue);
      expect(legacy.steps.first.args, ['make', 'User']);

      // Dashed unit-style id (legacy dialect, not the SpecParser
      // `U<n>` encoding) keeps the #696 CRUD contract.
      final dashed = planner.plan(
        const BehaviorSummary(
          behaviorId: 'U-6',
          feature: '001-app-bootstrap',
          sourceCriterion: 'FR-006',
          description: 'service exposes the count of pending items',
        ),
      );
      expect(dashed.isExpressible, isTrue);
      expect(dashed.steps.first.args, ['make', 'u_6', '--no-entity']);
    });

    test('U-718f: the unit-id matcher recognizes exactly the SpecParser '
        '`U<n>` encoding', () {
      for (final id in ['U1', 'U5', 'U12', 'U999']) {
        expect(GenerationPlanner.isUnitBehaviorId(id), isTrue, reason: id);
      }
      for (final id in ['A1', 'A12', 'B-003', 'U-6', 'u5', 'UU5', 'U', '']) {
        expect(GenerationPlanner.isUnitBehaviorId(id), isFalse, reason: id);
      }
    });
  });

  group('GenerationPlanner — issue 758: CRUD-routed acceptance behaviors '
      'implement the subject', () {
    // Issue #758: an acceptance behavior whose prose carries CRUD keywords
    // ("the Todo repository service persists a todo item") routes to the
    // CRUD branch, but that branch's plan (`make <slug>` + `build`) never
    // implemented the gen'd acceptance subject — `lib/tdd/<id>_subject.dart`
    // stayed an `UnimplementedError` stub, the post-build target run stayed
    // red, and `make` honestly stopped with `generation-error`. The loop was
    // blocked for a natural spec phrasing.
    //
    // Fix (the issue's option (a), mirroring the entity branch's #610
    // contract): when the description names an entity, append the
    // subject-implementation step (`tdd wire <id> --entity <Name>`) between
    // `make` and `build` — by wire time `make` has generated the entity, so
    // the wire command's entity-exists precondition holds. When no entity is
    // named, option (b): fail fast at plan time as unexpressible, which also
    // lets make's composition fallback (#642) engage for features that hold
    // composable green unit subjects.
    test('A-758a: an acceptance CRUD behavior naming an entity gets a wire '
        'step between make and build', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'A1',
          feature: '001-crud-probe',
          sourceCriterion: 'AC-1',
          description: 'the Todo repository service persists a todo item.',
        ),
      );
      expect(plan.isExpressible, isTrue, reason: plan.unexpressibleReason);
      expect(
        plan.steps.map((s) => s.args),
        [
          ['entity', 'create', '-n', 'Todo'],
          ['make', 'Todo'],
          [
            'tdd',
            'wire',
            'A1',
            '--entity',
            'Todo',
            '--feature',
            '001-crud-probe',
          ],
          ['build'],
        ],
        reason:
            'the subject-implementation step must follow the scaffold '
            'generation and precede the build',
      );
    });

    test('A-758b: an acceptance CRUD behavior naming no entity is '
        'unexpressible at plan time (fail fast, composition fallback can '
        'engage)', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'A2',
          feature: '001-crud-probe',
          sourceCriterion: 'AC-2',
          description: 'the repository service persists the item.',
        ),
      );
      expect(plan.isExpressible, isFalse);
      expect(plan.unexpressibleReason, contains('A2'));
      expect(
        plan.unexpressibleReason,
        contains('entity'),
        reason: 'the reason must name the missing anchor',
      );
      expect(
        plan.unexpressibleReason,
        contains('--entity'),
        reason: 'the reason must be actionable',
      );
    });

    test('A-758c: an acceptance behavior with entity prose keeps the entity '
        'branch (unchanged)', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'A3',
          feature: '001-crud-probe',
          sourceCriterion: 'AC-3',
          description: 'create entity User with email',
        ),
      );
      expect(plan.isExpressible, isTrue);
      expect(plan.steps.first.args, ['entity', 'create', '-n', 'User']);
      expect(
        plan.steps.where((s) => s.args.first == 'wire'),
        isEmpty,
        reason: 'the entity branch already carries its own wire step',
      );
    });

    test('A-758d: legacy dashed ids keep the plain CRUD contract (no wire '
        'step added by this fix)', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'B-005',
          feature: '001-app-bootstrap',
          sourceCriterion: 'FR-005',
          description: 'create User use case returns the saved entity',
        ),
      );
      expect(plan.isExpressible, isTrue);
      expect(plan.steps.first.args, ['make', 'User']);
      expect(plan.steps.where((s) => s.args.first == 'wire'), isEmpty);
    });

    test('A-758e: an explicit target wins over the description trace and '
        'drives the wire entity too', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'A4',
          feature: '001-crud-probe',
          sourceCriterion: 'AC-4',
          description: 'the Invoice repository service persists an invoice.',
          target: 'Invoice',
        ),
      );
      expect(plan.isExpressible, isTrue, reason: plan.unexpressibleReason);
      expect(plan.steps.map((s) => s.args).toList(), [
        ['entity', 'create', '-n', 'Invoice'],
        ['make', 'Invoice'],
        [
          'tdd',
          'wire',
          'A4',
          '--entity',
          'Invoice',
          '--feature',
          '001-crud-probe',
        ],
        ['build'],
      ]);
    });
  });

  group('GenerationPlanner — bug 829: entity-traced unit behaviors route '
      'to the entity pipeline', () {
    test('U-829a: a unit behavior traced to a declared entity plans '
        'entity create -> make <Entity> -> wire -> build — the '
        'architecture engages instead of the empty func subject', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'U1',
          feature: '090-entity-orch',
          sourceCriterion: 'FR-001',
          description: 'The system shall persist a User with a name.',
          entityTraced: 'User',
        ),
      );
      expect(plan.isExpressible, isTrue, reason: plan.unexpressibleReason);
      expect(plan.steps.map((s) => s.args).toList(), [
        ['entity', 'create', '-n', 'User'],
        ['make', 'User'],
        [
          'tdd',
          'wire',
          'U1',
          '--entity',
          'User',
          '--feature',
          '090-entity-orch',
        ],
        ['build'],
      ]);
    });

    test('U-829b: a unit behavior with NO entity trace keeps the '
        'bug-718 func surface (the pure-function path for pure '
        'functions)', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'U3',
          feature: '090-entity-orch',
          sourceCriterion: 'FR-003',
          description: 'render returns a non-empty string',
        ),
      );
      expect(plan.isExpressible, isTrue, reason: plan.unexpressibleReason);
      expect(plan.steps.map((s) => s.args).toList(), [
        ['tdd', 'func', 'U3', '--feature', '090-entity-orch'],
        ['build'],
      ]);
    });
  });

  group('GenerationPlanner — bug 829: entity-traced unit behaviors route '
      'to the entity pipeline', () {
    test('U-829a: a unit behavior traced to a declared entity plans '
        'entity create -> make <Entity> -> wire -> build — the '
        'architecture engages instead of the empty func subject', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'U1',
          feature: '090-entity-orch',
          sourceCriterion: 'FR-001',
          description: 'The system shall persist a User with a name.',
          entityTraced: 'User',
        ),
      );
      expect(plan.isExpressible, isTrue, reason: plan.unexpressibleReason);
      expect(plan.steps.map((s) => s.args), [
        ['entity', 'create', '-n', 'User'],
        ['make', 'User'],
        ['tdd', 'wire', 'U1', '--entity', 'User'],
        ['build'],
      ]);
    });

    test('U-829b: a unit behavior with NO entity trace keeps the '
        'bug-718 func surface (the pure-function path for pure '
        'functions)', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'U3',
          feature: '090-entity-orch',
          sourceCriterion: 'FR-003',
          description: 'render returns a non-empty string',
        ),
      );
      expect(plan.isExpressible, isTrue, reason: plan.unexpressibleReason);
      expect(plan.steps.map((s) => s.args), [
        ['tdd', 'func', 'U3'],
        ['build'],
      ]);
    });
  });
}
