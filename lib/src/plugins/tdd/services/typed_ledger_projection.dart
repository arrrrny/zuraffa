/// TypedLedgerProjection (EPIC 3 / issue #1134, lane 3 — merging #963
/// and #966): derives the DECLARED typed ledger rows from the plan's
/// declared inputs at plan time.
///
/// This is the production caller the typed-ledger library (spec 0966,
/// spec 1334 — `TypedLedgerBuilder`, complete but previously
/// unwired) has been waiting for: `zfa tdd plan` derives the rows and
/// writes `tdd/typed-ledger.md` + `tdd/typed-ledger.json` alongside
/// the 075 surface ledger.
///
/// Row grammar — every row is (surface, kind, status) with the kind
/// assigned from the scenario verbs (#966: kinds come from plan-time
/// verbs, never inferred post hoc; composing with the #964 finder-kind
/// taxonomy, the same classification the paired widget test and
/// `zfa tdd view` apply):
///
/// - a PRESENCE assertion (the taxonomy's `shows '…'` class) → a
///   `presence` row (surface = the literal, or `t.<key>` when the
///   anchor is a declared i18n key);
/// - an ABSENCE assertion (`… is not shown`) → an `absence` row with
///   `notRenderedIn` pinned to the scenario's Given state — a row
///   that never pins a state never counts as proof (0966 FR-002);
/// - a ROUTE-OUTCOME assertion (`navigates to the route '…'`) → a
///   `navigation` row (never presence text — the #964 certified-lie
///   fix);
/// - an ENABLED-STATE assertion (`… is disabled`) → a `state` row
///   with the asserted attribute (`enabled = false`) — the FR-005
///   class a presence row cannot express;
/// - a SEQUENCE scenario (`while … in flight … and then …`) → a
///   `sequence` row recording the chain steps (the When clause the
///   presence-only ledger discarded);
/// - every declared Presentation component token → a `presence` row
///   (the #939 stand-in surfaces);
/// - every declared i18n key → a `presence` row keyed `t.<key>`.
///
/// Rows de-duplicate by (surface, kind) with provers merged. Pure and
/// synchronous: declared facts in, rows out — the state recomputes at
/// read time (a stored state is a cache, never the truth).
library;

import '../../../tdd/services/typed_ledger_row.dart';
import 'finder_taxonomy.dart';
import 'i18n_key_contract.dart';
import 'ui_ledger_projection.dart';

/// Derives the declared typed ledger rows (issue #1134 lane 3).
abstract final class TypedLedgerProjection {
  /// The ordered behavior rows → declared typed rows. [componentTokens]
  /// are the Presentation contract's declared components (the #939
  /// stand-in labels, `UiLedgerProjection.componentTokensOf`); [keys]
  /// the declared i18n key table (issue #965).
  static List<DeclaredLedgerRow> declaredRows({
    required List<LedgerBehaviorInput> behaviors,
    List<String> componentTokens = const [],
    I18nKeyTable keys = I18nKeyTable.empty,
  }) {
    final rows = <String, DeclaredLedgerRow>{};

    void addRow(DeclaredLedgerRow row) {
      final key = '${row.kind.label}:${row.surface}';
      final existing = rows[key];
      if (existing == null) {
        rows[key] = row;
        return;
      }
      // Merge the provers (order-preserving, de-duplicated).
      final provers = [...existing.declaredProvers];
      for (final prover in row.declaredProvers) {
        if (!provers.contains(prover)) provers.add(prover);
      }
      rows[key] = DeclaredLedgerRow(
        surface: row.surface,
        kind: row.kind,
        screen: row.screen,
        declaredProvers: provers,
        advisory: existing.advisory || row.advisory,
        notRenderedIn: existing.notRenderedIn ?? row.notRenderedIn,
        steps: existing.steps.isNotEmpty ? existing.steps : row.steps,
        attribute: existing.attribute ?? row.attribute,
        platformTolerance: row.platformTolerance,
      );
    }

    for (final behavior in behaviors) {
      final analysis = FinderTaxonomy.resolveKeys(
        FinderTaxonomy.analyze(behavior.description),
        keys,
      );
      for (final assertion in analysis.assertions) {
        switch (assertion.assertionClass) {
          case ScenarioAssertionClass.absence:
            addRow(
              DeclaredLedgerRow(
                surface: assertion.literal,
                kind: LedgerRowKind.absence,
                declaredProvers: [behavior.id],
                // The pinned state the surface must be hidden in —
                // the Given clause. An absence row that never pins a
                // state never counts as proof (0966 FR-002) but stays
                // VISIBLE in the ledger (never omitted).
                notRenderedIn: _givenState(behavior.description),
              ),
            );
          case ScenarioAssertionClass.routeOutcome:
            addRow(
              DeclaredLedgerRow(
                surface: assertion.literal,
                kind: LedgerRowKind.navigation,
                declaredProvers: [behavior.id],
              ),
            );
          case ScenarioAssertionClass.enabledState:
            addRow(
              DeclaredLedgerRow(
                surface: assertion.literal,
                kind: LedgerRowKind.state,
                declaredProvers: [behavior.id],
                attribute: assertion.disabled
                    ? 'enabled = false'
                    : 'enabled = true',
              ),
            );
          case ScenarioAssertionClass.presence ||
                ScenarioAssertionClass.sequence:
            // A presence-class assertion on a sequence scenario still
            // traces its literal as a presence row; the CHAIN itself
            // is the sequence row emitted below.
            addRow(
              DeclaredLedgerRow(
                surface: assertion.literal,
                kind: LedgerRowKind.presence,
                declaredProvers: [behavior.id],
                advisory: LedgerRowKind.isGoldenScenario(
                  behavior.description,
                ),
              ),
            );
        }
      }
      // The interaction chain (the `while … in flight … and then …`
      // grammar): a sequence row recording the ordered steps — the
      // When clause the presence-only ledger discarded. The surface is
      // the literal chain (deterministic, greppable); the steps are
      // the scenario's ordered literal surfaces (≥ 2 = well-formed —
      // a chain with fewer steps never counts as proof, 0966 FR-003).
      if (analysis.sequence) {
        final steps = [
          for (final assertion in analysis.assertions) assertion.literal,
        ];
        addRow(
          DeclaredLedgerRow(
            surface: steps.join(' → '),
            kind: LedgerRowKind.sequence,
            declaredProvers: [behavior.id],
            steps: steps,
          ),
        );
      }
    }

    // The declared Presentation component tokens: presence rows (the
    // #939 stand-in surfaces the generated view renders).
    for (final token in componentTokens) {
      addRow(
        DeclaredLedgerRow(
          surface: token,
          kind: LedgerRowKind.presence,
        ),
      );
    }

    // The declared i18n keys: presence rows keyed by the accessor
    // surface (`t.<key>` — code identity, issue #965).
    for (final contract in keys.contracts) {
      addRow(
        DeclaredLedgerRow(
          surface: contract.ledgerSurface,
          kind: LedgerRowKind.presence,
        ),
      );
    }

    return rows.values.toList();
  }

  /// The Given clause of a scenario description (the state an absence
  /// row is pinned to), or null when the scenario declares none.
  static final RegExp _givenClause = RegExp(
    r'\bGiven\s+(.+?)(?=\s+(?:When|Then)\b|$)',
    caseSensitive: false,
    dotAll: true,
  );

  static String? _givenState(String description) {
    final match = _givenClause.firstMatch(description);
    final state = match?.group(1)?.trim();
    if (state == null || state.isEmpty) return null;
    // Collapse newlines — the pinned state reads as one line.
    return state.replaceAll(RegExp(r'\s+'), ' ');
  }
}
