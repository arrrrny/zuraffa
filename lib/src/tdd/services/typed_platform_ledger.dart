/// TypedPlatformLedger (EPIC 3 / issue #1134, lane 3 — merging #963
/// and #966, extending #1142): the per-platform TYPED coverage ledger
/// — every declared platform layout slot traced independently against
/// the typed kind vocabulary (`presence | absence | navigation |
/// state | sequence`).
///
/// The #1142 platform ledger crosses the surfaces × slots with the
/// 075 legacy kinds (text/route/affordance/key); this module crosses
/// the TYPED rows × slots with the epic's row grammar — every row is
/// (slot, surface, kind, status: `traced | untraced`) — so the
/// per-layout kind-coverage heatmap (exit criterion 2) renders KIND
/// coverage per layout: a mobile-only prover set leaves the macos
/// cells untraced, and a presence-only feature shows its absent
/// kinds, per slot, at a glance.
///
/// Evidence discipline (the #1142 model): the behavior→slot mapping
/// is the SkinEvent stream (`skin-event: behavior=W1 slot=mobile`,
/// issue #1005) — a behavior proves a surface FOR THE SLOTS IT
/// EXERCISED, never for the slots it skipped. Plan-time evidence is
/// empty ⇒ every per-slot row untraced — visible, never omitted.
///
/// Pure and synchronous: declared rows + slot evidence in, per-slot
/// rows + heatmap out.
library;

import 'dart:convert';

import 'typed_ledger_row.dart';

/// One per-platform TYPED ledger row: the typed row traced against ONE
/// declared platform layout slot.
class TypedPlatformRow {
  /// The platform layout slot (`mobile`, `macos`, …).
  final String slot;

  /// What the row traces (the typed row's surface).
  final String surface;

  /// The typed kind (`presence|absence|navigation|state|sequence`).
  final LedgerRowKind kind;

  /// The green behaviors that EXERCISED this slot for this row.
  final List<String> provers;

  /// The epic's status vocabulary: `traced` iff at least one green
  /// prover of the row exercised this slot; `untraced` otherwise.
  final String status;

  const TypedPlatformRow({
    required this.slot,
    required this.surface,
    required this.kind,
    this.provers = const [],
    required this.status,
  });
}

/// Derives and renders the per-platform TYPED ledger (issue #1134).
abstract final class TypedPlatformLedger {
  /// Derive the per-slot rows: the typed rows × the declared slots. A
  /// row is `traced` on a slot iff the typed row is `DONE` (state
  /// recomputed at read time — a NOT-DONE row never proves) AND at
  /// least one of its green provers exercised that slot
  /// ([behaviorSlots] maps behavior id → the slots it exercised — the
  /// SkinEvent evidence; empty evidence ⇒ untraced everywhere, the
  /// plan-time shape).
  static List<TypedPlatformRow> derive({
    required List<TypedLedgerRow> typedRows,
    required List<String> slots,
    Map<String, Set<String>> behaviorSlots = const {},
  }) {
    final rows = <TypedPlatformRow>[];
    for (final slot in slots) {
      final exercised = {
        for (final entry in behaviorSlots.entries)
          if (entry.value.contains(slot)) entry.key,
      };
      for (final typed in typedRows) {
        // Only a DONE typed row proves anything: a NOT-DONE row (the
        // #966 malformed discipline — an absence with no state, a
        // sequence under two steps, a state row with no attribute) is
        // never traced, even when one of its provers exercised the
        // slot. Otherwise the aggregate would paint a slot traced off
        // a row the typed ledger itself refuses to call proven.
        final proven = typed.state == 'DONE'
            ? typed.provers.where((id) => exercised.contains(id)).toList()
            : <String>[];
        rows.add(
          TypedPlatformRow(
            slot: slot,
            surface: typed.surface,
            kind: typed.kind,
            provers: proven,
            status: proven.isEmpty ? 'untraced' : 'traced',
          ),
        );
      }
    }
    return rows;
  }

  /// The kind × slot heatmap (exit criterion 2's artifact): one row
  /// per declared kind, one cell per slot, each cell the
  /// `traced/total` fraction of the kind's rows on that slot. A
  /// declared slot with no rows of a kind renders `-` (a kind the plan
  /// never declared). Zero-traced cells carry the `HIGHLIGHT` prefix —
  /// never painted as proof.
  static String kindSlotHeatmap(
    List<TypedPlatformRow> rows,
    List<String> slots,
  ) {
    final buffer = StringBuffer()
      ..writeln('## Per-layout kind coverage heatmap')
      ..writeln()
      ..writeln(
        'Per-layout kind coverage (issue #1134, exit criterion 2): '
        'every declared platform layout slot is traced independently '
        'against the typed kinds — a mobile-only prover set leaves the '
        'macos cells untraced, and a presence-only feature shows its '
        'absent kinds per slot.',
      )
      ..writeln();
    buffer
      ..write('| kind |')
      ..write(slots.map((slot) => ' $slot |').join())
      ..writeln()
      ..write('| ')
      ..write(List.filled(slots.length + 1, '---').join(' | '))
      ..writeln(' |');
    for (final kind in LedgerRowKind.values) {
      final cells = <String>[];
      for (final slot in slots) {
        final ofKindOnSlot = rows
            .where((r) => r.slot == slot && r.kind == kind)
            .toList();
        if (ofKindOnSlot.isEmpty) {
          cells.add('-');
          continue;
        }
        final traced = ofKindOnSlot.where((r) => r.status == 'traced').length;
        final cell = '$traced/${ofKindOnSlot.length}';
        cells.add(traced == 0 ? 'HIGHLIGHT $cell' : cell);
      }
      buffer
        ..write('| ${kind.label} |')
        ..write(cells.map((c) => ' $c |').join())
        ..writeln();
    }
    return buffer.toString();
  }

  /// The per-layout ledger markdown: the typed rows per slot + the
  /// kind × slot heatmap (appended into `tdd/typed-ledger.md` when
  /// the feature declares platform layout slots).
  static String toMarkdown(List<TypedPlatformRow> rows, List<String> slots) {
    final buffer = StringBuffer()
      ..writeln('# Per-Layout Typed Coverage Ledger')
      ..writeln()
      ..writeln('| slot | surface | kind | proven by | status |')
      ..writeln('| ---- | ------- | ---- | --------- | ------ |');
    for (final row in rows) {
      buffer.writeln(
        '| ${row.slot} | ${row.surface} | ${row.kind.label} | '
        '${row.provers.isEmpty ? "" : row.provers.join(", ")} '
        '| ${row.status} |',
      );
    }
    buffer
      ..writeln()
      ..write(kindSlotHeatmap(rows, slots));
    return buffer.toString();
  }

  /// The per-layout ledger JSON: flat rows under the epic's status
  /// vocabulary (`traced|untraced`) — appended into
  /// `tdd/typed-ledger.json` alongside the typed rows.
  static String toJson(List<TypedPlatformRow> rows) => jsonEncode([
    for (final row in rows)
      <String, Object>{
        'slot': row.slot,
        'surface': row.surface,
        'kind': row.kind.label,
        'provenBy': row.provers,
        'status': row.status,
      },
  ]);
}
