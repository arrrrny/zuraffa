// Bug #950 (widget-func-verb-routing): kind must outrank prose. A
// widget-kind behavior whose description carries a function-intent verb
// ("renders" being the most natural widget-scenario verb) must NEVER be
// planned to `tdd func` — the func scaffold refuses the gen-shaped
// view-builder stub, dead-ending the make in a generation-error, and the
// #939 view lane lives in the composition fallback, which only engages on
// an unexpressible plan. The planner therefore plans widget-kind rows
// unexpressible (the same principle #835 applied to ffi), letting the
// fallback's view-builder lane route them. Kindless summaries (pre-#835
// call sites and unreadable lists) keep routing exactly as before, and a
// unit-kind row with "renders" still routes to func (units legitimately
// render/format/parse).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/generation_planner.dart';

void main() {
  const planner = GenerationPlanner();

  BehaviorSummary summary({
    String id = 'A1',
    BehaviorKind? kind,
    String description = "the widget renders 'Hello, shopper'",
  }) => BehaviorSummary(
    behaviorId: id,
    feature: '003-widget-probe',
    sourceCriterion: 'FR-002',
    description: description,
    kind: kind,
  );

  group('bug 950: widget-kind rows never plan tdd func, even with a func verb', () {
    test('a widget-kind row whose description says "renders" is NOT routed '
        'to tdd func', () {
      final plan = planner.plan(summary(kind: BehaviorKind.widget));
      expect(
        plan.isExpressible,
        isFalse,
        reason: 'the func scaffold cannot express a view-builder subject; '
            'the row must fall to the composition fallback view lane',
      );
      expect(plan.steps, isEmpty);
      expect(plan.unexpressibleReason, contains('A1'));
    });

    test('every render inflection (renders/rendered/rendering) stays off '
        'the func surface', () {
      for (final description in [
        "the widget renders 'Hello, shopper'",
        "the widget rendered 'Hello, shopper'",
        "the widget is rendering 'Hello, shopper'",
      ]) {
        final plan = planner.plan(
          summary(kind: BehaviorKind.widget, description: description),
        );
        expect(
          plan.isExpressible,
          isFalse,
          reason: 'description: $description',
        );
        final plannedArgs = plan.steps.expand((s) => s.args);
        expect(
          plannedArgs,
          isNot(contains('func')),
          reason: 'description: $description',
        );
      }
    });

    test('the reason names the view lane (the fallback route)', () {
      final plan = planner.plan(summary(kind: BehaviorKind.widget));
      expect(plan.unexpressibleReason, contains('view'));
      expect(plan.unexpressibleReason, contains('widget'));
      // The reason is the operator-facing route instruction: it must
      // name the `tdd view` command itself, not just any fallback words
      // (audit mutant: a reason naming the WRONG command survived until
      // this assertion landed).
      expect(plan.unexpressibleReason, contains('`zfa tdd view'));
    });

    test('the widget guard outranks the U<n> id-prefix dispatch', () {
      // Contradictory metadata (a widget-kind row on a U<n> id): the
      // test-list row is the kind source of truth — a U<n> widget row
      // must not hit `tdd func` either.
      final plan = planner.plan(
        summary(id: 'U2', kind: BehaviorKind.widget),
      );
      expect(plan.isExpressible, isFalse);
      final plannedArgs = plan.steps.expand((s) => s.args);
      expect(plannedArgs, isNot(contains('func')));
    });

    test('the widget guard outranks the entity/CRUD description branches', () {
      // The prose deliberately carries no "widget"/"view" literal, so the
      // 'widget' reason assertion below discriminates the guard from the
      // #758 CRUD-acceptance stop (whose reason merely embeds the
      // description verbatim).
      final plan = planner.plan(
        summary(
          kind: BehaviorKind.widget,
          description: 'the cart repository list renders prices with totals',
        ),
      );
      expect(plan.isExpressible, isFalse);
      expect(
        plan.unexpressibleReason,
        contains('widget'),
        reason: 'the refusal must come from the widget guard naming the '
            'view lane, not from the #758 CRUD-acceptance stop',
      );
      final plannedFirstArgs = plan.steps.expand((s) => s.args);
      expect(plannedFirstArgs, isNot(contains('make')));
      expect(plannedFirstArgs, isNot(contains('entity')));
    });
  });

  group('bug 950 regressions: non-widget routing is untouched', () {
    test('a unit-kind row with "renders" still routes to the func surface', () {
      final plan = planner.plan(summary(kind: BehaviorKind.unit));
      expect(plan.isExpressible, isTrue);
      final plannedArgs = plan.steps.expand((s) => s.args).toSet();
      expect(plannedArgs, contains('func'));
      expect(plannedArgs, contains('tdd'));
    });

    test('a kindless summary with "renders" keeps the legacy branch-3 '
        'func routing', () {
      // Unreadable list / pre-#835 call sites: kind == null — routing is
      // exactly as before (description-keyed).
      final plan = planner.plan(summary(kind: null));
      expect(plan.isExpressible, isTrue);
      final plannedArgs = plan.steps.expand((s) => s.args).toSet();
      expect(plannedArgs, contains('func'));
      expect(plannedArgs, contains('tdd'));
    });

    test('the ffi guard keeps precedence and its own reason', () {
      final plan = planner.plan(
        summary(
          id: 'U2',
          kind: BehaviorKind.ffi,
          description: 'the ocr ffi binding renders scanned fields',
        ),
      );
      expect(plan.isExpressible, isFalse);
      expect(plan.unexpressibleReason, contains('DynamicLibrary'));
    });
  });
}
