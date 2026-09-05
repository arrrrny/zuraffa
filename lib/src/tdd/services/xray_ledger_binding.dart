/// XrayLedgerBinding (feature 075, issue #963): the ledger is the
/// single inventory behind the X-Ray overlay and the control deck —
/// the overlay paints by ledger state, the deck lists ledger rows and
/// drives 072 dependency-mock fixture scenarios. An absent ledger
/// reports absence; absence is never painted as proof.
///
/// Spec 0966 (issue #966) extends the binding with KIND coverage: the
/// overlay renders kind coverage, not just surface coverage — a page
/// with presence-only rows shows as partially traced, and untraced
/// kinds highlight, never painted as proof.
///
/// Pure and synchronous: ledger rows in, paint/deck decisions out.
library;

import 'typed_ledger_row.dart';
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

  /// The overlay's KIND coverage for one screen (spec 0966, issue
  /// #966): every declared kind with its traced/total counts. Advisory
  /// rows (goldens) are not gate surface and never appear here.
  static List<KindCoverage> kindCoverage(
    List<TypedLedgerRow> ledger, {
    String screen = '',
  }) {
    return TypedLedgerBuilder.kindCoverage(ledger, screen: screen);
  }

  /// Kind coverage PER SCREEN: the overlay distinguishes the kinds on
  /// each screen — a presence-only screen shows as partially traced
  /// next to a fully-traced one.
  static Map<String, List<KindCoverage>> kindCoverageByScreen(
    Map<String, List<TypedLedgerRow>> ledgerByScreen,
  ) => {
    for (final entry in ledgerByScreen.entries)
      entry.key: kindCoverage(entry.value, screen: entry.key),
  };

  /// A screen is PARTIALLY traced when some declared kinds have traced
  /// rows and others do not — the presence-only lie, visible.
  static bool partiallyTraced(List<KindCoverage> coverage) {
    final complete = coverage.where((c) => c.complete).length;
    final untraced = coverage.where((c) => c.untraced).length;
    return complete > 0 && untraced > 0;
  }

  /// The kind labels the overlay HIGHLIGHTS on this screen — the
  /// untraced kinds, never painted as proof.
  static List<String> untracedKindLabels(List<KindCoverage> coverage) => [
    for (final c in coverage)
      if (c.untraced) c.kind.label,
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

  /// The deck's KIND entries (spec 0966, issue #966): one per declared
  /// kind, labeled with its traced/total counts; untraced kinds read
  /// NOT-DONE (the deck names them, never paints them as proof).
  static List<DeckEntry> kindEntries(List<TypedLedgerRow> ledger) => [
    for (final c in TypedLedgerBuilder.kindCoverage(ledger))
      DeckEntry(c.label, c.untraced ? 'NOT-DONE' : 'DONE'),
  ];

  /// The deck's ADVISORY entries (spec 0966, FR-007): golden rows
  /// reported separately — they never block the merge gate (recorded
  /// decision: flaky economics on slow CI), carry their per-platform
  /// tolerance, and read ADVISORY, never DONE/proof.
  static List<DeckEntry> advisoryEntries(List<TypedLedgerRow> ledger) => [
    for (final row in ledger)
      if (row.advisory)
        DeckEntry(
          '${row.surface} (golden'
              '${row.platformTolerance.isEmpty ? "" : ": ${_toleranceLabel(row)}"}'
              ')',
          'ADVISORY',
        ),
  ];

  static String _toleranceLabel(TypedLedgerRow row) => row
      .platformTolerance
      .entries
      .map((e) => '${e.key}: ±${e.value}px')
      .join(', ');

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
