/// XrayLedgerBinding (feature 075, issue #963): the ledger is the
/// single inventory behind the X-Ray overlay and the control deck —
/// the overlay paints by ledger state, the deck lists ledger rows and
/// drives 072 dependency-mock fixture scenarios. An absent ledger
/// reports absence; absence is never painted as proof.
///
/// Pure and synchronous: ledger rows in, paint/deck decisions out.
library;

import 'ui_ledger_builder.dart';

/// The paint decision for one surface.
enum XrayLedgerPaint { clean, highlight, noLedger }

/// The overlay binding: surfaces painted by ledger state.
abstract final class XrayLedgerOverlay {
  /// The paint decision per surface: proven rows paint clean,
  /// unproven rows highlight. A null ledger (absent artifact) yields
  /// [XrayLedgerPaint.noLedger] for every queried surface — absence is
  /// never painted as proof.
  static XrayLedgerPaint paint({
    required String surface,
    List<UiSurfaceRow>? ledger,
  }) {
    if (ledger == null) return XrayLedgerPaint.noLedger;
    for (final row in ledger) {
      if (row.surface == surface) {
        return row.state == 'DONE'
            ? XrayLedgerPaint.clean
            : XrayLedgerPaint.highlight;
      }
    }
    return XrayLedgerPaint.highlight;
  }

  /// The exact set of surfaces the overlay highlights right now —
  /// the unproven affordances.
  static List<String> highlights(List<UiSurfaceRow> ledger) => [
    for (final row in ledger)
      if (row.state != 'DONE') row.surface,
  ];
}

/// One control-deck entry.
class DeckEntry {
  final String label;

  /// The ledger state behind the entry (drives the row badge).
  final String state;

  const DeckEntry(this.label, this.state);
}

/// The control-deck binding: ledger rows as deck entries plus the 072
/// dependency-mock scenario entries.
abstract final class XrayLedgerDeck {
  /// The deck rows: one per ledger row, labeled with its state.
  static List<DeckEntry> entries(List<UiSurfaceRow> ledger) => [
    for (final row in ledger)
      DeckEntry('${row.surface} (${row.kind.name})', row.state),
  ];

  /// The drive-able scenario entries for a dependency touchpoint (the
  /// 072 rail): the certified mock's fixture scenarios. A touchpoint
  /// without a generated mock refuses naming the rail command.
  static List<String> scenarioEntries({
    required String dependency,
    required Map<String, List<String>> certifiedMockScenarios,
  }) {
    final scenarios = certifiedMockScenarios[dependency];
    if (scenarios == null) {
      return <String>[
        "$dependency has no certified mock --> fix: `zfa mock dependency $dependency` (issue #963; no hand-authored stand-ins).",
      ];
    }
    return scenarios;
  }
}
