// Bug #1503: `zfa tdd plan`'s entity pipeline emitted
// `mock create --name <E>` WITHOUT `--certify` — the engine's own step
// produced an uncertified mock, then the engine's own spec-1001 preflight
// (run_command.dart) refused it on the next run: "CORE entity <E> has a
// mock on disk that is NOT certified — the engine refuses to proceed".
// The pipeline contradicted itself.
//
// Contract pinned here (post-#1001 semantics): BOTH entity pipeline arms
// in GenerationPlanner must request the CERTIFIED variant
// `['mock', 'create', '--name', <E>, '--certify']` so run #1 leaves a
// certified mock on disk and run #2's preflight passes. Standalone
// `mock create` (outside the TDD pipeline) stays opt-in — nothing here
// touches the mock command, the gate, or the preflight.
//
// Follow-up (review finding 1): the certify step's sandbox copies the
// entity's relative-import closure and refuses a missing `part` target
// (mock_certification_sandbox.dart `_copyImportClosure`), and
// `zfa entity create` does NOT build by default (`buildByDefault` is
// false — zfa_config.dart). So every plan that emits a certify step must
// give it a BUILT entity: the `entity create` step carries `--build`.
// Without it the plan hard-stops at the certify step on any run where
// nothing built the entity first (issue #1503's interrupted-run case).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/generation_plan.dart';
import 'package:zuraffa/src/plugins/tdd/models/routing.dart';
import 'package:zuraffa/src/plugins/tdd/services/generation_planner.dart';

/// The plan's `mock create` step, or null when the plan carries none.
GenerationStepSpec? _mockCreateStep(GenerationPlan plan) {
  for (final step in plan.steps) {
    if (step.args.length >= 2 &&
        step.args[0] == 'mock' &&
        step.args[1] == 'create') {
      return step;
    }
  }
  return null;
}

/// Index of the plan's `mock create` step, or -1 when the plan carries none.
int _mockCreateIndex(GenerationPlan plan) {
  for (var i = 0; i < plan.steps.length; i++) {
    final args = plan.steps[i].args;
    if (args.length >= 2 && args[0] == 'mock' && args[1] == 'create') {
      return i;
    }
  }
  return -1;
}

/// True when the step is an `entity create` that also builds the entity.
bool _isBuiltEntityCreate(GenerationStepSpec step) =>
    step.args.length >= 2 &&
    step.args[0] == 'entity' &&
    step.args[1] == 'create' &&
    step.args.contains('--build');

void main() {
  const planner = GenerationPlanner();

  group('GenerationPlanner — bug 1503: the entity pipeline requests '
      'CERTIFIED mocks (spec 1001 reconciliation)', () {
    test('U-1503a: the traced-entity arm emits '
        '`mock create --name Task --certify` — run #1 leaves a certified '
        'mock, so run #2s spec-1001 preflight passes', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'U1',
          feature: '001-todo-app',
          sourceCriterion: 'FR-001',
          description: 'The system shall persist a Task with a title.',
          entityTraced: 'Task',
        ),
      );
      expect(plan.isExpressible, isTrue, reason: plan.unexpressibleReason);
      final mock = _mockCreateStep(plan);
      expect(
        mock,
        isNotNull,
        reason:
            'the traced-entity arm plans a mock '
            'step — the bug 829 entity pipeline',
      );
      // THE bug-1503 pin: the certified variant, exactly.
      expect(mock!.args, ['mock', 'create', '--name', 'Task', '--certify']);
      // Review finding 1: the certify step is preceded by a BUILT entity —
      // its sandbox refuses a dangling `part` target, and `entity create`
      // does not build by default.
      final idx = _mockCreateIndex(plan);
      expect(
        idx,
        greaterThan(0),
        reason: 'the certify step follows the entity step',
      );
      expect(
        _isBuiltEntityCreate(plan.steps[idx - 1]),
        isTrue,
        reason:
            'the entity must be built before it is certified — '
            '`entity create -n Task --build`',
      );
      // The full plan shape: entity create --build -> mock create
      // (--certify) -> wire -> build.
      expect(plan.steps.map((s) => s.args).toList(), [
        ['entity', 'create', '-n', 'Task', '--build'],
        ['mock', 'create', '--name', 'Task', '--certify'],
        ['tdd', 'wire', 'U1', '--entity', 'Task', '--feature', '001-todo-app'],
        ['build'],
      ]);
    });

    test('U-1503b: the declared entityPipeline arm emits '
        '`mock create --name Task --certify` too — both arms reconcile '
        'with the spec-1001 gate', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'U2',
          feature: '071-probe',
          sourceCriterion: 'FR-004',
          description: 'the Task repository persists a task',
          traces: ['Task'],
          declarations: SpecDeclarations(
            contractRows: {
              'Task': ContractRowDecl(
                name: 'Task',
                kind: ContractRowKind.entity,
                specLine: 20,
              ),
            },
          ),
        ),
      );
      expect(plan.isExpressible, isTrue, reason: plan.unexpressibleReason);
      final mock = _mockCreateStep(plan);
      expect(
        mock,
        isNotNull,
        reason: 'the declared entity pipeline plans a mock step',
      );
      // THE bug-1503 pin, declared arm: same certified argv.
      expect(mock!.args, ['mock', 'create', '--name', 'Task', '--certify']);
      // Review finding 1, declared arm: same built-entity precondition —
      // the certify step's sandbox needs the entity's build_runner
      // outputs on disk, and this arm's `entity create` came later than
      // any phase-0 build.
      final idx = _mockCreateIndex(plan);
      expect(idx, greaterThan(0));
      expect(
        _isBuiltEntityCreate(plan.steps[idx - 1]),
        isTrue,
        reason:
            'the declared entity pipeline must build the entity '
            'before certifying its mock',
      );
    });

    test('U-1503c: the certification invariant holds across every planner '
        'arm shape — no plan the planner emits carries an uncertified '
        '`mock create`, and each one is preceded by a BUILT entity '
        '(review finding 3: asserted over the arm table, not a third '
        'copy of the two literal plans)', () {
      // One fixture per arm/surface the planner accepts. The invariant is
      // asserted over every plan produced; a NEW arm must add its shape
      // here, which is what makes this a coverage guard rather than a
      // re-assertion of U-1503a/U-1503b.
      final arms = <String, BehaviorSummary>{
        'traced-entity arm (non-stub)': const BehaviorSummary(
          behaviorId: 'U1',
          feature: '001-todo-app',
          sourceCriterion: 'FR-001',
          description: 'The system shall persist a Task with a title.',
          entityTraced: 'Task',
        ),
        'traced-entity arm (stub)': const BehaviorSummary(
          behaviorId: 'U1',
          feature: '001-todo-app',
          sourceCriterion: 'FR-001',
          description: 'The system shall persist a Task with a title.',
          entityTraced: 'Task',
          stub: true,
        ),
        'declared entityPipeline arm': const BehaviorSummary(
          behaviorId: 'U2',
          feature: '071-probe',
          sourceCriterion: 'FR-004',
          description: 'the Task repository persists a task',
          traces: ['Task'],
          declarations: SpecDeclarations(
            contractRows: {
              'Task': ContractRowDecl(
                name: 'Task',
                kind: ContractRowKind.entity,
                specLine: 20,
              ),
            },
          ),
        ),
        'declared function surface': const BehaviorSummary(
          behaviorId: 'U2',
          feature: '071-probe',
          sourceCriterion: 'FR-004',
          description: 'create entity Invoice with email',
          traces: ['Formatter.format'],
          declarations: SpecDeclarations(
            contractRows: {
              'Formatter': ContractRowDecl(
                name: 'Formatter',
                kind: ContractRowKind.function,
                signatures: [
                  Signature(
                    name: 'format',
                    parameters: [],
                    returnType: 'String',
                  ),
                ],
                specLine: 30,
              ),
            },
          ),
        ),
        'declared presentation (view) surface': const BehaviorSummary(
          behaviorId: 'A1',
          feature: '071-probe',
          sourceCriterion: 'FR-004',
          description: 'the login page renders',
          traces: ['Login page'],
          declarations: SpecDeclarations(
            contractRows: {
              'Login page': ContractRowDecl(
                name: 'Login page',
                kind: ContractRowKind.presentation,
                specLine: 40,
              ),
            },
          ),
        ),
        'undeclared entity-bearing prose (fallback)': const BehaviorSummary(
          behaviorId: 'B-7',
          feature: '071-probe',
          sourceCriterion: 'FR-004',
          description: 'create entity Invoice with email',
        ),
        'undeclared plain-function prose (fallback)': const BehaviorSummary(
          behaviorId: 'U9',
          feature: '071-probe',
          sourceCriterion: 'FR-004',
          description: 'computes the total for the given items',
        ),
      };
      final armsWithMockCreate = <String>{};
      for (final entry in arms.entries) {
        final plan = planner.plan(entry.value);
        final label = entry.key;
        for (var i = 0; i < plan.steps.length; i++) {
          final args = plan.steps[i].args;
          if (!(args.length >= 2 && args[0] == 'mock' && args[1] == 'create')) {
            continue;
          }
          armsWithMockCreate.add(label);
          expect(
            args,
            contains('--certify'),
            reason:
                '$label: run #1 must leave a certified mock on disk — an '
                'uncertified engine-planned mock dead-ends run #2 at the '
                'spec-1001 preflight (bug #1503)',
          );
          expect(
            i > 0 && _isBuiltEntityCreate(plan.steps[i - 1]),
            isTrue,
            reason:
                '$label: the certify sandbox needs a BUILT entity — an '
                'unbuilt `part` target makes the import-closure copy '
                'refuse and hard-stops the plan (review finding 1)',
          );
        }
      }
      // Non-vacuity: the table must actually reach both mock-emitting
      // arms — an empty set would let this guard pass over nothing.
      expect(
        armsWithMockCreate,
        {'traced-entity arm (non-stub)', 'declared entityPipeline arm'},
        reason:
            'the invariant table must exercise every arm the planner '
            'routes to a `mock create` step',
      );
    });

    test('U-1503d: the stub escape hatch still plans NO mock step — '
        '--certify rides only the entity pipeline, nothing else changes', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'U1',
          feature: '001-todo-app',
          sourceCriterion: 'FR-001',
          description: 'The system shall persist a Task with a title.',
          entityTraced: 'Task',
          stub: true,
        ),
      );
      expect(plan.isExpressible, isTrue, reason: plan.unexpressibleReason);
      expect(
        _mockCreateStep(plan),
        isNull,
        reason: 'the stub arm demotes to `make` — unchanged by bug #1503',
      );
      expect(plan.steps.map((s) => s.args).toList(), [
        ['entity', 'create', '-n', 'Task'],
        ['make', 'Task'],
        ['tdd', 'wire', 'U1', '--entity', 'Task', '--feature', '001-todo-app'],
        ['build'],
      ]);
    });
  });
}
