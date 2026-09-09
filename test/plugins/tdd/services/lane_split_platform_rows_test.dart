// Issue #1432 — the lane-split renderers partition `LaneRow`s by kind into
// sections, but no section carried `BehaviorKind.platform`: a platform-typed
// acceptance scenario routed to the SKIN lane was silently dropped from
// 04-SKIN.md while the plan's route log claimed its lane.
//
// Contract under test: the acceptance outer-loop section carries platform
// rows with the canonical 4-column shape, in BOTH lane plans (a BOTH row
// renders engine-side too).
//
// RED phase: the platform row matches no section filter — the assertions
// below fail on the unfixed tree.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/models/lane.dart';
import 'package:zuraffa/src/plugins/tdd/services/lane_split.dart';

LaneRow _row(String id, BehaviorKind kind, Lane lane) => LaneRow(
  id: id,
  description: 'the $id behavior asserts its criterion',
  traces: 'FR-001',
  state: 'PENDING',
  kind: kind,
  lane: lane,
);

/// The rendered acceptance section: from its header to the next `## `.
String _acceptanceSection(String md) {
  const marker = '## Outer loop: acceptance behaviors';
  final start = md.indexOf(marker);
  final rest = md.substring(start + marker.length);
  final end = rest.indexOf('\n## ');
  return rest.substring(0, end == -1 ? rest.length : end);
}

void main() {
  group('issue #1432 — lane plans render platform rows', () {
    test('renderSkinPlan places a platform row in the acceptance section '
        'with the 4-column shape', () {
      final md = renderSkinPlan(
        feature: '1432-platform-lane-skin-plan',
        rows: [
          _row('A1', BehaviorKind.platform, Lane.skin),
          _row('A2', BehaviorKind.acceptance, Lane.skin),
        ],
        adaptiveSlots: const [],
      );

      final acceptance = _acceptanceSection(md);
      expect(
        acceptance,
        contains('| A1 |'),
        reason:
            'the platform-typed scenario is routed to the SKIN lane, so '
            'the acceptance section must carry its row (issue #1432)',
      );
      expect(acceptance, contains('| A2 |'));
      expect(
        acceptance,
        matches(
          RegExp(r'^\| A1 \|[^|]+\|[^|]+\| PENDING \|$', multiLine: true),
        ),
        reason:
            'the platform row uses the canonical 4-column shape — the '
            'same columns the acceptance rows use',
      );
      expect(md, contains('| A1 | the A1 behavior'));
    });

    test('renderEnginePlan places a platform row in the acceptance section '
        '(the BOTH-lane engine copy)', () {
      final md = renderEnginePlan(
        feature: '1432-platform-lane-skin-plan',
        rows: [
          _row('A1', BehaviorKind.platform, Lane.both),
          _row('U1', BehaviorKind.unit, Lane.core),
        ],
      );

      final acceptance = _acceptanceSection(md);
      expect(
        acceptance,
        contains('| A1 |'),
        reason:
            'a BOTH-lane platform behavior renders its engine copy in '
            'the acceptance section too (the reader dedupes by id)',
      );
      expect(acceptance, isNot(contains('| U1 |')));
    });

    test('every kind renders or refuses — renderability equals the home '
        'sets the plan guard enforces (issue #1432)', () {
      // The totality contract (SC-003): for every behavior kind, the lane
      // plan either renders the row or the plan-time guard refuses it —
      // never a silent drop. These sets ARE the contract (data-model.md);
      // if this test fails after adding a kind, extend BOTH the renderer
      // section filters in lane_split.dart AND the guard sets in
      // plan_command.dart together. `contract` is open issue #1419.
      const engineHomes = {
        BehaviorKind.acceptance,
        BehaviorKind.platform,
        BehaviorKind.widget,
        BehaviorKind.unit,
        BehaviorKind.ffi,
      };
      const skinHomes = {
        BehaviorKind.acceptance,
        BehaviorKind.platform,
        BehaviorKind.widget,
        BehaviorKind.unit,
      };
      for (final kind in BehaviorKind.values) {
        if (kind == BehaviorKind.contract) continue;
        final renderedSkin = renderSkinPlan(
          feature: 'f',
          rows: [_row('X1', kind, Lane.skin)],
          adaptiveSlots: const [],
        ).contains('| X1 |');
        expect(
          renderedSkin,
          skinHomes.contains(kind),
          reason:
              '${kind.name}: SKIN renderability must equal the skin home '
              'set — a mismatch re-opens the #1432 silent drop',
        );
        final renderedEngine = renderEnginePlan(
          feature: 'f',
          rows: [_row('X1', kind, Lane.core)],
        ).contains('| X1 |');
        expect(
          renderedEngine,
          engineHomes.contains(kind),
          reason:
              '${kind.name}: ENGINE renderability must equal the engine '
              'home set — a mismatch re-opens the #1432 silent drop',
        );
      }
    });
  });
}
