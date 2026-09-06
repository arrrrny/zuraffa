/// PlatformCoverageLedger (spec 1142, issue #1142 — extending #963/#966):
/// per-platform kind coverage for the UI surface ledger — every declared
/// platform layout slot is traced INDEPENDENTLY, so a "mobile-only 100%
/// traced" login is still missing macOS coverage.
///
/// The aggregate ledger (#963, #1141) collapses all provers into one row:
/// a login whose behaviors all pump the mobile slot posts a 100% matrix
/// while the macos layout never rendered a single asserted surface — the
/// exact blind spot the #1102 pilot caught live ("macOS layout had NO
/// loading scrim; mobile-only testing had pumped only the mobile slot").
///
/// The per-platform model mirrors the aggregate discipline:
/// - DECLARED facts in, ledger out (pure, synchronous; no guesses): the
///   declared surfaces (the #1141 projection's rows) × the declared
///   platform layout slots (the #1142 Presentation contract).
/// - EVIDENCE recomputes state at read time — a stored state is a cache,
///   never the truth. The behavior→slot mapping is the SkinEvent stream
///   (`skin-event: behavior=W1 slot=mobile`, issue #1005): a behavior
///   proves a surface FOR THE SLOTS IT EXERCISED, never for the slots it
///   skipped.
/// - A platform slot that is declared but never exercised by any green
///   prover of a surface renders that surface's row NOT-DONE on that
///   slot — visible at plan time (empty evidence ⇒ every per-slot row
///   NOT-DONE), never omitted.
/// - The heatmap renders per-slot KIND coverage (kind × slot traced/total
///   cells) so the gap is readable at a glance, not just per-surface.
library;

import 'dart:convert';

import '../../../tdd/services/ui_ledger_builder.dart';
import 'skin_event_trace.dart';

/// One per-platform ledger row: the declared surface traced against ONE
/// declared platform layout slot.
class PlatformSurfaceRow {
  /// The platform layout slot (`mobile`, `macos`, …).
  final String slot;

  final String surface;
  final UiSurfaceKind kind;

  /// The green behaviors that EXERCISED this slot (SkinEvent evidence).
  final List<String> provers;

  /// Recomputed state: `DONE` iff at least one green prover of the
  /// surface exercised this slot; `NOT-DONE` otherwise.
  final String state;

  const PlatformSurfaceRow({
    required this.slot,
    required this.surface,
    required this.kind,
    this.provers = const [],
    required this.state,
  });
}

/// Derives and renders the per-platform coverage ledger (issue #1142).
abstract final class PlatformCoverageLedger {
  /// The behavior→slots map from a SkinEvent trace (issue #1005): the
  /// runtime evidence a [derive] call consumes. A behavior that never
  /// emitted an event maps to no entry (proves nothing per-slot).
  static Map<String, Set<String>> slotsFromTrace(SkinEventTrace trace) {
    final map = <String, Set<String>>{};
    for (final event in trace.events) {
      map.putIfAbsent(event.behavior, () => <String>{}).add(event.slot);
    }
    return map;
  }

  /// Derive the per-platform rows: the declared surfaces × the declared
  /// slots. A surface is DONE on a slot iff at least one of its green
  /// provers exercised that slot ([behaviorSlots] maps behavior id → the
  /// slots it exercised — empty evidence ⇒ NOT-DONE everywhere, the
  /// plan-time shape).
  static List<PlatformSurfaceRow> derive({
    required List<UiSurfaceRow> aggregate,
    required List<String> slots,
    Map<String, Set<String>> behaviorSlots = const {},
  }) {
    final rows = <PlatformSurfaceRow>[];
    for (final slot in slots) {
      // The behavior→slots evidence inverts to the slot's prover set:
      // the behaviors whose runs emitted THIS slot's skin-event.
      final exercised = {
        for (final entry in behaviorSlots.entries)
          if (entry.value.contains(slot)) entry.key,
      };
      for (final surface in aggregate) {
        final proven = surface.provers
            .where((id) => exercised.contains(id))
            .toList();
        rows.add(
          PlatformSurfaceRow(
            slot: slot,
            surface: surface.surface,
            kind: surface.kind,
            provers: proven,
            state: proven.isEmpty ? 'NOT-DONE' : 'DONE',
          ),
        );
      }
    }
    return rows;
  }

  /// The slots in first-occurrence order across the rows.
  static List<String> slotsOf(List<PlatformSurfaceRow> rows) {
    final slots = <String>[];
    for (final row in rows) {
      if (!slots.contains(row.slot)) slots.add(row.slot);
    }
    return slots;
  }

  /// The kinds in first-occurrence order across the rows.
  static List<UiSurfaceKind> kindsOf(List<PlatformSurfaceRow> rows) {
    final kinds = <UiSurfaceKind>[];
    for (final row in rows) {
      if (!kinds.contains(row.kind)) kinds.add(row.kind);
    }
    return kinds;
  }

  /// The per-platform kind-coverage heatmap: one row per declared kind,
  /// one cell per slot, each cell the `traced/total` fraction of the
  /// kind's surfaces on that slot. A declared slot with no rows of a
  /// kind renders `-` (a kind the plan never declared).
  static String kindCoverageHeatmap(
    List<PlatformSurfaceRow> rows,
    List<String> slots,
  ) {
    final buffer = StringBuffer()
      ..writeln('## Platform coverage heatmap')
      ..writeln()
      ..writeln(
        'Per-platform kind coverage (issue #1142): every declared '
        'platform layout slot is traced independently — an aggregate '
        '"100% traced" with a mobile-only prover set is still missing '
        'macOS coverage.',
      )
      ..writeln();
    buffer
      ..write('| kind |')
      ..write(slots.map((slot) => ' $slot |').join())
      ..writeln()
      ..write('| ')
      ..write(List.filled(slots.length + 1, '---').join(' | '))
      ..writeln(' |');
    for (final kind in kindsOf(rows)) {
      final cells = <String>[];
      for (final slot in slots) {
        final ofKindOnSlot = rows
            .where((r) => r.slot == slot && r.kind == kind)
            .toList();
        if (ofKindOnSlot.isEmpty) {
          cells.add('-');
          continue;
        }
        final traced = ofKindOnSlot.where((r) => r.state == 'DONE').length;
        cells.add('$traced/${ofKindOnSlot.length}');
      }
      buffer
        ..write('| ${kind.name} |')
        ..write(cells.map((c) => ' $c |').join())
        ..writeln();
    }
    return buffer.toString();
  }

  /// The per-platform ledger markdown (the platform section appended to
  /// the feature's `tdd/ui-ledger.md` when slots are declared).
  static String toMarkdown(List<PlatformSurfaceRow> rows) {
    final buffer = StringBuffer()
      ..writeln('# Platform Coverage Ledger')
      ..writeln()
      ..writeln('| slot | surface | kind | proven by | state |')
      ..writeln('| ---- | ------- | ---- | --------- | ----- |');
    for (final row in rows) {
      buffer.writeln(
        '| ${row.slot} | ${row.surface} | ${row.kind.name} | '
        '${row.provers.isEmpty ? "" : row.provers.join(", ")} '
        '| ${row.state} |',
      );
    }
    buffer
      ..writeln()
      ..write(kindCoverageHeatmap(rows, slotsOf(rows)));
    return buffer.toString();
  }

  /// The per-platform ledger JSON (the cache; truth is recomputed on
  /// read) — flat rows under the `platformCoverage` dimension.
  static String toJson(List<PlatformSurfaceRow> rows) => jsonEncode([
    for (final row in rows)
      <String, Object>{
        'slot': row.slot,
        'surface': row.surface,
        'kind': row.kind.name,
        'provenBy': row.provers,
        'state': row.state,
      },
  ]);
}
