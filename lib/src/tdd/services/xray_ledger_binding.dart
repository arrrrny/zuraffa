/// XrayLedgerBinding (feature 075, issue #963): the ledger is the
/// single inventory behind the X-Ray overlay and the control deck —
/// the overlay paints by ledger state, the deck lists ledger rows and
/// drives 072 dependency-mock fixture scenarios. An absent ledger
/// reports absence; absence is never painted as proof.
///
/// Spec 0966 (issue #966) extended the binding with KIND coverage: the
/// overlay renders kind coverage, not just surface coverage — a page
/// with presence-only rows shows as partially traced, and untraced
/// kinds highlight, never painted as proof.
///
/// Spec 1334 (issue #1143) REPLACES the surface-count overlay with the
/// per-kind view for typed ledgers: [XrayLedgerOverlay.renderScreen]
/// renders, per screen, a status line (`fully-traced` /
/// `partially-traced` / `untraced`) plus one line per kind with its
/// traced/total counts — zero-traced kinds are HIGHLIGHTED, never
/// painted as proof. The legacy `paint`/`highlights` surface-count view
/// ([UiSurfaceRow], the 075 shape) remains ONLY for kindless legacy
/// ledgers; the deck lists per-screen status entries.
///
/// Pure and synchronous: ledger rows in, paint/deck decisions out.
library;

import 'typed_ledger_row.dart';
import 'ui_ledger_builder.dart';

/// The paint decision for one surface.
enum XrayLedgerPaint { clean, highlight, noLedger }

/// The overlay binding: surfaces painted by ledger state.
abstract final class XrayLedgerOverlay {
  /// LEGACY surface-count view (075 shape — [UiSurfaceRow]). For typed
  /// ledgers this view is REPLACED by the per-kind rendering
  /// ([renderScreen], issue #1143 AC-3); it stays for kindless legacy
  /// ledgers only.
  ///
  /// The paint decision per surface: proven rows paint clean, unproven
  /// rows highlight. A null ledger (absent artifact) yields
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

  /// LEGACY surface-count view: the exact set of surfaces the overlay
  /// highlights right now — the unproven affordances. Typed ledgers
  /// render [renderScreen] instead (issue #1143 AC-3).
  static List<String> highlights(List<UiSurfaceRow> ledger) => [
    for (final row in ledger)
      if (row.state != 'DONE') row.surface,
  ];

  /// The overlay's KIND coverage for one screen (spec 0966, issue
  /// #966): every DECLARED kind with its traced/total counts. Advisory
  /// rows (goldens) are not gate surface and never appear here.
  static List<KindCoverage> kindCoverage(
    List<TypedLedgerRow> ledger, {
    String screen = '',
  }) {
    return TypedLedgerBuilder.kindCoverage(ledger, screen: screen);
  }

  /// Kind coverage PER SCREEN (spec 0966): the overlay distinguishes
  /// the kinds on each screen — a presence-only screen shows as
  /// partially traced next to a fully-traced one.
  static Map<String, List<KindCoverage>> kindCoverageByScreen(
    Map<String, List<TypedLedgerRow>> ledgerByScreen,
  ) => {
    for (final entry in ledgerByScreen.entries)
      entry.key: kindCoverage(entry.value, screen: entry.key),
  };

  /// A screen is PARTIALLY traced when some declared kinds have traced
  /// rows and others do not — the presence-only lie, visible (the 0966
  /// declared-kinds view).
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

  // --- the per-kind view (spec 1334, issue #1143, AC-3) --------------

  /// The per-kind rendering of one screen (issue #1143): a status line
  /// (`/login: partially-traced`) followed by one line per kind with
  /// its traced/total counts. Zero-traced kinds are prefixed
  /// HIGHLIGHT — never painted as proof. This view REPLACES the
  /// surface-count rendering for typed ledgers: the lines are a kind
  /// breakdown, never a per-surface listing.
  static List<String> renderScreen(ScreenKindReport report) => [
    '${report.screenLabel}: ${report.status.label}',
    for (final c in report.coverage)
      c.zeroTraced ? 'HIGHLIGHT ${c.label}' : c.label,
  ];

  /// The per-kind rendering of every screen (issue #1143): each screen
  /// renders its status line + per-kind lines, carrying its own counts.
  static Map<String, List<String>> renderByScreen(
    Map<String, ScreenKindReport> reports,
  ) => {
    for (final entry in reports.entries) entry.key: renderScreen(entry.value),
  };
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
  /// LEGACY deck rows (075 shape): one per ledger row, labeled with its
  /// state. Typed ledgers list [kindEntries] and [screenEntries].
  static List<DeckEntry> entries(List<UiSurfaceRow> ledger) => [
    for (final row in ledger)
      DeckEntry('${row.surface} (${row.kind.name})', row.state),
  ];

  /// The deck's KIND entries (spec 0966, FR-007): one per DECLARED
  /// kind, labeled with its traced/total counts; untraced kinds read
  /// NOT-DONE (the deck names them, never paints them as proof).
  static List<DeckEntry> kindEntries(List<TypedLedgerRow> ledger) => [
    for (final c in TypedLedgerBuilder.kindCoverage(ledger))
      DeckEntry(c.label, c.untraced ? 'NOT-DONE' : 'DONE'),
  ];

  /// The deck's ADVISORY entries (spec 0966, FR-007): golden rows
  /// reported separately — they never block the merge gate (recorded
  /// decision: flaky economics on slow CI), carry their per-platform
  /// tolerance, and read ADVISORY, never DONE/proof. Issue #1143: a
  /// golden row is a presence row with `advisory: true` (golden is a
  /// flag, not a kind) — the deck still names it `golden`.
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

  /// The deck's SCREEN entries (spec 1334, issue #1143): one per
  /// screen, labeled `screen: status` — the per-kind overlay's status
  /// line, badge DONE only when the screen is fully traced.
  static List<DeckEntry> screenEntries(Map<String, ScreenKindReport> reports) =>
      [
        for (final report in reports.values)
          DeckEntry(
            '${report.screenLabel}: ${report.status.label}',
            report.fullyTraced ? 'DONE' : 'NOT-DONE',
          ),
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
