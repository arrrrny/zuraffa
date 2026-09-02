// Bug #835 (tdd-ffi-ocr-harness): the planner refuses ffi-kind behaviors
// honestly. The test-list row's kind rides into the planner via
// BehaviorSummary.kind; an ffi behavior must NEVER route into the
// id-prefix dispatch (a U<n> ffi behavior would hit `tdd func`, whose
// scaffold refuses the harness shape, dead-ending the run in a
// generation-error). Kindless summaries (every pre-#835 call site and
// unreadable lists) keep routing exactly as before.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/generation_planner.dart';

void main() {
  const planner = GenerationPlanner();

  BehaviorSummary summary({
    String id = 'U2',
    BehaviorKind? kind,
    String description =
        'the ocr ffi binding extracts invoice fields within tolerance',
  }) => BehaviorSummary(
    behaviorId: id,
    feature: '090-ffi-fixture',
    sourceCriterion: 'FR-002',
    description: description,
    kind: kind,
  );

  group('bug 835: ffi-kind behaviors plan as unexpressible', () {
    test('a U-prefixed ffi behavior is NOT routed to tdd func', () {
      final plan = planner.plan(summary(kind: BehaviorKind.ffi));
      expect(
        plan.isExpressible,
        isFalse,
        reason: 'native binding work has no generator surface',
      );
      expect(plan.steps, isEmpty);
      expect(plan.unexpressibleReason, contains('U2'));
      expect(plan.unexpressibleReason, contains('ffi'));
    });

    test('an A-prefixed ffi behavior skips the composition fallback too', () {
      final plan = planner.plan(
        summary(
          id: 'A3',
          kind: BehaviorKind.ffi,
          description: 'the pdf-to-markdown ffi binding converts a sample pdf',
        ),
      );
      expect(plan.isExpressible, isFalse);
      // The reason names the manual wiring path (honest stop, not a
      // dead-end misfire).
      expect(plan.unexpressibleReason, contains('symbolResolved'));
      expect(plan.unexpressibleReason, contains('convertGolden'));
    });

    test('the reason names the contract seams and the fixture lane', () {
      final plan = planner.plan(summary(kind: BehaviorKind.ffi));
      expect(plan.unexpressibleReason, contains('roundTrip'));
      expect(plan.unexpressibleReason, contains('preset=integration'));
    });

    test('a kindless summary keeps the legacy id-prefix routing', () {
      // Unreadable list / pre-#835 call sites: kind == null — the U-id
      // dispatch must stay exactly as it was (bug #718 func surface).
      final kindless = planner.plan(summary());
      expect(kindless.isExpressible, isTrue);
      expect(kindless.steps.map((s) => s.args.first), contains('tdd'));
    });

    test('a unit-kind summary is unaffected (no behavior drift)', () {
      final unit = planner.plan(summary(kind: BehaviorKind.unit));
      expect(unit.isExpressible, isTrue);
    });
  });
}
