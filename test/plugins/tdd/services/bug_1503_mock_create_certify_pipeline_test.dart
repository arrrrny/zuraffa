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
      // The full plan shape is otherwise unchanged:
      // entity create -> mock create (--certify) -> wire -> build.
      expect(plan.steps.map((s) => s.args).toList(), [
        ['entity', 'create', '-n', 'Task'],
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
    });

    test('U-1503c: every `mock create` step the planner emits carries '
        '--certify — the engine never plans an uncertified mock for '
        'itself (the self-contradiction is unreachable)', () {
      final plans = [
        // traced-entity arm
        planner.plan(
          const BehaviorSummary(
            behaviorId: 'U1',
            feature: '001-todo-app',
            sourceCriterion: 'FR-001',
            description: 'The system shall persist a Task with a title.',
            entityTraced: 'Task',
          ),
        ),
        // declared entityPipeline arm
        planner.plan(
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
        ),
      ];
      for (final plan in plans) {
        for (final step in plan.steps) {
          if (step.args.length >= 2 &&
              step.args[0] == 'mock' &&
              step.args[1] == 'create') {
            expect(
              step.args,
              contains('--certify'),
              reason:
                  'run #1 must leave a certified mock on disk — an '
                  'uncertified engine-planned mock dead-ends run #2 at '
                  'the spec-1001 preflight (bug #1503)',
            );
          }
        }
      }
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
