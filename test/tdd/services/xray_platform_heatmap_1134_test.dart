// EPIC 3 / issue #1134, lane 3 — the XRay overlay renders the
// PER-LAYOUT kind-coverage heatmap (exit criterion 2): kind coverage
// per platform layout slot, HIGHLIGHT on zero-traced cells — kind
// coverage, not just surface count — and the control deck lists one
// entry per (slot, kind) with a traced/untraced badge.
//
//  U-1134-t7: XrayLedgerOverlay.renderPlatformHeatmap renders the
//             per-layout kind-coverage lines (kind × slot), with
//             HIGHLIGHT on zero-traced kinds — never painted as proof.
//  U-1134-t8: XrayLedgerDeck.platformEntries lists one entry per
//             (slot, kind) with a traced/untraced badge.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/tdd/services/typed_ledger_row.dart';
import 'package:zuraffa/src/tdd/services/typed_platform_ledger.dart';
import 'package:zuraffa/src/tdd/services/xray_ledger_binding.dart';

void main() {
  final typed = TypedLedgerBuilder.derive(
    declared: const [
      DeclaredLedgerRow(
        surface: 'Sign in',
        kind: LedgerRowKind.presence,
        declaredProvers: ['A3'],
      ),
      DeclaredLedgerRow(
        surface: 'deal_list',
        kind: LedgerRowKind.navigation,
        declaredProvers: ['A4'],
      ),
    ],
    greenBehaviors: {'A3', 'A4'},
  );
  final rows = TypedPlatformLedger.derive(
    typedRows: typed,
    slots: const ['mobile', 'macos'],
    behaviorSlots: const {
      'A3': {'mobile'},
      'A4': {'mobile', 'macos'},
    },
  );

  test('U-1134-t7: the overlay renders the per-layout kind-coverage '
      'heatmap (kind coverage, not surface count)', () {
    final lines = XrayLedgerOverlay.renderPlatformHeatmap(
      rows,
      const ['mobile', 'macos'],
    );

    // A status line + one line per (kind × slot) — kind coverage per
    // LAYOUT, the exit-criterion-2 shape.
    expect(lines.first, contains('per-layout kind coverage'));
    // mobile presence traced 1/1; macos presence 0/1 → HIGHLIGHT.
    expect(
      lines.any((l) => l.contains('mobile') && l.contains('presence 1/1')),
      isTrue,
      reason: 'the traced cell renders its kind + traced/total',
    );
    expect(
      lines.any(
        (l) => l.contains('HIGHLIGHT') && l.contains('macos') && l.contains('presence 0/1'),
      ),
      isTrue,
      reason: 'a zero-traced kind × slot cell is HIGHLIGHTED — never '
          'painted as proof',
    );
    // navigation traced on BOTH slots (A4 exercised both).
    expect(
      lines.any(
        (l) =>
            l.contains('mobile') &&
            l.contains('navigation 1/1') &&
            !l.contains('HIGHLIGHT'),
      ),
      isTrue,
    );
    // The rendering is a KIND breakdown, never a per-surface listing.
    expect(lines.any((l) => l.contains('Sign in')), isFalse);
  });

  test('U-1134-t8: the deck lists one entry per (slot, kind) with a '
      'traced/untraced badge', () {
    final entries = XrayLedgerDeck.platformEntries(
      rows,
      const ['mobile', 'macos'],
    );

    // 2 kinds × 2 slots = 4 entries.
    expect(entries, hasLength(4));
    expect(
      entries.any(
        (e) =>
            e.label.contains('mobile') &&
            e.label.contains('presence') &&
            e.state == 'traced',
      ),
      isTrue,
    );
    expect(
      entries.any(
        (e) =>
            e.label.contains('macos') &&
            e.label.contains('presence') &&
            e.state == 'untraced',
      ),
      isTrue,
      reason: 'the deck names the untraced (slot, kind) cell — the '
          'per-layout gap, badge-level',
    );
    for (final entry in entries) {
      expect(entry.state, anyOf('traced', 'untraced'));
    }
  });
}
