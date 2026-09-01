// Unit tests for `CompositionPlanner` (spec 052-acceptance-make-composition,
// T004: U6, U7, A9) — the pure fallback planner that shapes the
// composition plan (compose → build) for an unexpressible acceptance
// behavior, and the SC-006 purity pin on the PRIMARY planner.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/composition_planner.dart';
import 'package:zuraffa/src/plugins/tdd/services/composition_targets.dart';
import 'package:zuraffa/src/plugins/tdd/services/generation_planner.dart';

BehaviorSummary _summary(String description) => BehaviorSummary(
  behaviorId: 'A-001',
  feature: '052-compose',
  sourceCriterion: 'FR-007',
  description: description,
);

void main() {
  group('CompositionPlanner — the fallback plan (U6, U7)', () {
    const planner = CompositionPlanner();
    final anchors = const [
      ComposableUnitSubject(
        behaviorId: 'U-001',
        subjectPath: '/proj/lib/u_001_subject.dart',
        symbol: 'subject_u_001',
      ),
    ];

    test('U6: an acceptance summary + ≥1 anchor yields the compose → build '
        'plan, terminating in a build step', () {
      final plan = planner.plan(
        _summary('the signup flow completes and the account is usable'),
        anchors,
      );

      expect(plan.isExpressible, isTrue);
      expect(plan.steps, hasLength(2));
      expect(plan.steps[0].args, [
        'tdd',
        'compose',
        'A-001',
        '--feature',
        '052-compose',
      ]);
      expect(plan.steps[0].purpose, contains('compose'));
      expect(plan.steps[0].purpose, contains('A-001'));
      expect(plan.steps[0].purpose, contains('1'));
      // 047 FR-005 rule: every expressible plan terminates in a build.
      expect(plan.steps.last.args, ['build']);
      expect(plan.steps.last.purpose, contains('build'));
      expect(plan.steps.last.purpose, contains('A-001'));
      expect(plan.unexpressibleReason, isNull);
    });

    test('U6b: the plan purpose names the anchor count', () {
      final two = planner.plan(_summary('the signup flow completes'), [
        anchors.first,
        const ComposableUnitSubject(
          behaviorId: 'U-002',
          subjectPath: '/proj/lib/u_002_subject.dart',
          symbol: 'subject_u_002',
        ),
      ]);
      expect(two.steps.first.purpose, contains('2'));
    });

    test('U7: the planner is pure — same inputs, same plan; no I/O', () {
      final summary = _summary('the signup flow completes');
      final a = planner.plan(summary, anchors);
      final b = planner.plan(summary, anchors);
      expect(a.steps.length, b.steps.length);
      for (var i = 0; i < a.steps.length; i++) {
        expect(a.steps[i].args, b.steps[i].args);
        expect(a.steps[i].purpose, b.steps[i].purpose);
      }
      expect(a.unexpressibleReason, b.unexpressibleReason);
    });
  });

  group('A9 — SC-006 purity pin: the primary planner is byte-identical', () {
    const primary = GenerationPlanner();

    test('entity-bearing description maps to the pinned 3-step plan', () {
      final plan = primary.plan(
        BehaviorSummary(
          behaviorId: 'B-001',
          feature: '052-compose',
          sourceCriterion: 'FR-007',
          description: 'create entity User with email',
        ),
      );
      expect(plan.isExpressible, isTrue);
      expect(plan.steps.map((s) => s.args).toList(), [
        ['entity', 'create', '-n', 'User'],
        ['tdd', 'wire', 'B-001', '--entity', 'User'],
        ['build'],
      ]);
      expect(plan.steps[0].purpose, 'create entity User for behavior B-001');
      expect(
        plan.steps[1].purpose,
        'wire subject of behavior B-001 to entity User',
      );
      expect(plan.steps[2].purpose, 'build generated code for behavior B-001');
    });

    test('CRUD description maps to the pinned make + build plan', () {
      final plan = primary.plan(
        BehaviorSummary(
          behaviorId: 'B-002',
          feature: '052-compose',
          sourceCriterion: 'FR-007',
          description: 'crud for user profiles',
        ),
      );
      expect(plan.isExpressible, isTrue);
      expect(plan.steps.map((s) => s.args).toList(), [
        ['make', 'b_002'],
        ['build'],
      ]);
      expect(
        plan.steps[0].purpose,
        'generate use-case/repository scaffolds for b_002 '
        '(behavior B-002)',
      );
    });

    test('prose stays unexpressible with the pinned reason text', () {
      final plan = primary.plan(
        BehaviorSummary(
          behaviorId: 'B-003',
          feature: '052-compose',
          sourceCriterion: 'FR-007',
          description: 'interpret bespoke DSL syntax with no generator surface',
        ),
      );
      expect(plan.isExpressible, isFalse);
      expect(
        plan.unexpressibleReason,
        'behavior "B-003" requires an implementation '
        'the zuraffa generation pipeline cannot express: no generator '
        'surface maps the behavior description '
        '"interpret bespoke DSL syntax with no generator surface" to a `zfa '
        'entity create` / `zfa make` '
        '/ `zfa build` invocation. File a zuraffa gap per the STOP-ON-'
        'ROADBLOCK policy.',
      );
    });
  });
}
