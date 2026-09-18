// EPIC 3 / issue #1134, lane 3 — the per-layout TYPED ledger: every
// declared platform layout slot is traced independently against the
// TYPED kind vocabulary (presence|absence|navigation|state|sequence) —
// a mobile-only prover set leaves the macos cells untraced, and the
// kind × slot heatmap (exit criterion 2) renders the gap at a glance.
//
//  U-1134-t4: derive() produces (slot, surface, kind, status
//             traced|untraced) rows — a green prover that exercised
//             only the mobile slot traces mobile rows, leaves macos
//             rows untraced (each layout traced independently).
//  U-1134-t5: kindSlotHeatmap() renders the kind × slot grid —
//             `traced/total` cells, HIGHLIGHT on zero-traced cells,
//             `-` for kinds the plan never declared.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/tdd/services/typed_ledger_row.dart';
import 'package:zuraffa/src/tdd/services/typed_platform_ledger.dart';

void main() {
  final declared = <DeclaredLedgerRow>[
    const DeclaredLedgerRow(
      surface: 'Sign in',
      kind: LedgerRowKind.presence,
      declaredProvers: ['A3'],
    ),
    const DeclaredLedgerRow(
      surface: 'Sign in failed',
      kind: LedgerRowKind.absence,
      declaredProvers: ['A5'],
      notRenderedIn: 'a fresh login view',
    ),
    const DeclaredLedgerRow(
      surface: 'deal_list',
      kind: LedgerRowKind.navigation,
      declaredProvers: ['A4'],
    ),
  ];
  // A4 exercised the mobile slot only (SkinEvent evidence).
  final behaviorSlots = <String, Set<String>>{
    'A4': {'mobile'},
  };
  final typed = TypedLedgerBuilder.derive(
    declared: declared,
    greenBehaviors: {'A3', 'A4', 'A5'},
  );

  test('U-1134-t4: per-slot typed rows — a mobile-only prover set '
      'leaves macos untraced (each layout traced independently)', () {
    final rows = TypedPlatformLedger.derive(
      typedRows: typed,
      slots: const ['mobile', 'macos'],
      behaviorSlots: behaviorSlots,
    );

    // The row grammar: (slot, surface, kind, status traced|untraced).
    expect(rows, hasLength(6)); // 3 surfaces × 2 slots.
    for (final row in rows) {
      expect(
        row.status,
        anyOf('traced', 'untraced'),
        reason: 'the epic row grammar: status is traced|untraced',
      );
    }

    TypedPlatformRow rowOf(String slot, String surface, LedgerRowKind kind) {
      final matches = rows
          .where(
            (r) => r.slot == slot && r.surface == surface && r.kind == kind,
          )
          .toList();
      expect(
        matches,
        hasLength(1),
        reason: 'one row per (slot, surface, kind)',
      );
      return matches.single;
    }

    // A4 (mobile-only) proves 'deal_list' navigation ON MOBILE…
    expect(
      rowOf('mobile', 'deal_list', LedgerRowKind.navigation).status,
      'traced',
    );
    expect(rowOf('mobile', 'deal_list', LedgerRowKind.navigation).provers, [
      'A4',
    ]);
    // …and NOT on macos: the per-layout independence the aggregate
    // ledger cannot express.
    expect(
      rowOf('macos', 'deal_list', LedgerRowKind.navigation).status,
      'untraced',
    );
    // A3/A5 never emitted a skin event: untraced on BOTH slots.
    expect(
      rowOf('mobile', 'Sign in', LedgerRowKind.presence).status,
      'untraced',
    );
    expect(
      rowOf('macos', 'Sign in failed', LedgerRowKind.absence).status,
      'untraced',
    );
  });

  test('U-1134-t4b: plan-time evidence (no SkinEvent stream) is '
      'untraced everywhere, visible, never omitted', () {
    final rows = TypedPlatformLedger.derive(
      typedRows: typed,
      slots: const ['mobile', 'macos'],
    );
    expect(rows, hasLength(6));
    expect(rows.every((r) => r.status == 'untraced'), isTrue);
  });

  test('U-1134-t5: the kind × slot heatmap renders traced/total cells '
      'with HIGHLIGHT on zero-traced kinds and `-` for undeclared kinds', () {
    final rows = TypedPlatformLedger.derive(
      typedRows: typed,
      slots: const ['mobile', 'macos'],
      behaviorSlots: behaviorSlots,
    );
    final heatmap = TypedPlatformLedger.kindSlotHeatmap(rows, const [
      'mobile',
      'macos',
    ]);

    expect(heatmap, contains('| kind | mobile | macos |'));
    // presence: 0/1 on both slots (A3 green but no skin event) —
    // zero-traced cells carry the HIGHLIGHT prefix.
    expect(
      heatmap,
      contains(RegExp(r'\| presence \| HIGHLIGHT 0/1 \| HIGHLIGHT 0/1 \|')),
    );
    // navigation: 1/1 on mobile (A4 exercised it), HIGHLIGHT 0/1 on
    // macos — the mobile-only blind spot, visible.
    expect(
      heatmap,
      contains(RegExp(r'\| navigation \| 1/1 \| HIGHLIGHT 0/1 \|')),
    );
    // absence: 0/1 both (HIGHLIGHT).
    expect(
      heatmap,
      contains(RegExp(r'\| absence \| HIGHLIGHT 0/1 \| HIGHLIGHT 0/1 \|')),
    );
    // state/sequence: declared nowhere — `-` cells.
    expect(heatmap, contains(RegExp(r'\| state \| - \| - \|')));
    expect(heatmap, contains(RegExp(r'\| sequence \| - \| - \|')));
    // Zero-traced cells are HIGHLIGHTED — never painted as proof.
    expect(heatmap, contains('HIGHLIGHT'));
  });

  test('U-1134-t5b: toJson carries the typed platform rows with the '
      'traced|untraced status vocabulary', () {
    final rows = TypedPlatformLedger.derive(
      typedRows: typed,
      slots: const ['mobile'],
      behaviorSlots: behaviorSlots,
    );
    final json = TypedPlatformLedger.toJson(rows);
    expect(json, contains('"slot":"mobile"'));
    expect(json, contains('"kind":"navigation"'));
    expect(json, contains('"status":"traced"'));
    expect(json, contains('"status":"untraced"'));
    expect(json, isNot(contains('DONE')));
  });

  test('U-1134-t11: a NOT-DONE typed row never traces a slot, even when '
      'its prover exercised it', () {
    // A malformed absence (no pinned state) is NOT-DONE (#966 FR-002) —
    // its green prover must not paint the slot traced.
    final malformed = TypedLedgerBuilder.derive(
      declared: const [
        DeclaredLedgerRow(
          surface: 'Sign in failed',
          kind: LedgerRowKind.absence,
          declaredProvers: ['A5'],
        ),
      ],
      greenBehaviors: {'A5'},
    );
    expect(malformed.single.state, 'NOT-DONE');

    final rows = TypedPlatformLedger.derive(
      typedRows: malformed,
      slots: const ['mobile'],
      behaviorSlots: const {
        'A5': {'mobile'},
      },
    );

    expect(rows.single.status, 'untraced');
    expect(rows.single.provers, isEmpty);
  });
}
