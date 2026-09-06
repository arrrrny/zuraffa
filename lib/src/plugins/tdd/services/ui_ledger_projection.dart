/// The UI ledger projection + the view-side localization audit
/// (issue #1141, extending #965/#963).
///
/// #965 shipped the ledger library (`UiLedgerBuilder`) and the
/// `untracedHardcodedStrings` detector with no command wiring (075's
/// outstanding T002). This file is the missing projection layer:
///
/// - [UiLedgerProjection] derives the DECLARED surfaces of a feature
///   from its behavior rows + Presentation layer contract — the single
///   derivation both `zfa tdd plan` (the `specs/<f>/tdd/ui-ledger.md`
///   artifact) and `zfa tdd view` (the pre-write audit) share, so the
///   artifact and the gate can never drift apart.
/// - [UiViewAudit] is the localization gate `zfa tdd view` runs on its
///   own rendered output BEFORE any write: every quoted user-facing
///   string must trace to a ledger surface, and on a keyed host a
///   declared anchor may never render as a quoted literal (the key is
///   the contract — the accessor `t.<key>` is code identity).
library;

import '../../../tdd/services/ui_ledger_builder.dart';
import 'finder_taxonomy.dart';
import 'i18n_key_contract.dart';
import 'spec_parser.dart';

/// One behavior row feeding the projection — the minimal shape both the
/// plan-side [Behavior]/[LaneRow] models and the reader-side
/// [BehaviorRow] map into, so every producer derives the same ledger.
class LedgerBehaviorInput {
  const LedgerBehaviorInput({required this.id, required this.description});

  final String id;
  final String description;

  @override
  String toString() => 'LedgerBehaviorInput($id: $description)';
}

/// Derives the declared UI surfaces (issue #963's ledger, #965's key
/// rows, #1141's wiring).
abstract final class UiLedgerProjection {
  /// The declared Presentation component tokens (the #939 stand-in
  /// labels): the non-`key:` method tokens of the Presentation layer
  /// contract, de-duplicated, order-preserving. Domain/Data rows never
  /// contribute.
  static List<String> componentTokensOf(List<LayerContract> contracts) {
    final tokens = <String>[];
    for (final contract in contracts) {
      if (!contract.layer.toLowerCase().contains('presentation')) continue;
      for (final method in contract.methods) {
        final token = method.trim();
        if (token.isEmpty) continue;
        if (I18nKeyContract.isKeyToken(token)) continue;
        if (!tokens.contains(token)) tokens.add(token);
      }
    }
    return tokens;
  }

  /// The declared surfaces, in first-declaration order, de-duplicated by
  /// (surface, kind) with provers merged.
  ///
  /// Row grammar (the finder-kind taxonomy's own classification):
  ///   - a PRESENCE literal that is a declared key's anchor feeds that
  ///     key's `t.<key>` row as a prover — never a text row (0965: "the
  ///     ledger knows only `t.app.name` anchored 'ZikZak'");
  ///   - a PRESENCE literal with no anchored key is a `text` row;
  ///   - a ROUTE-OUTCOME literal is a `route` row;
  ///   - an ENABLED-STATE literal is an `affordance` row;
  ///   - an ABSENCE literal contributes NO row (075 U5: absent:/example
  ///     values never become rows);
  ///   - every declared Presentation component token is an `affordance`
  ///     row (the #939 stand-in labels render as on-screen affordances);
  ///   - every declared i18n key is a `t.<key>` `key` row.
  static List<DeclaredSurface> derive({
    required List<LedgerBehaviorInput> behaviors,
    required I18nKeyTable keys,
    List<String> componentTokens = const [],
  }) {
    final anchorToKey = keys.anchorToKey;
    final proversByKey = <String, List<String>>{};
    final rows = <String, DeclaredSurface>{};

    void addRow(String surface, UiSurfaceKind kind, String prover) {
      final key = '$kind:$surface';
      final existing = rows[key];
      if (existing == null) {
        rows[key] = DeclaredSurface(
          surface: surface,
          kind: kind,
          declaredProvers: prover.isEmpty ? const [] : [prover],
        );
        return;
      }
      if (prover.isEmpty || existing.declaredProvers.contains(prover)) {
        return;
      }
      rows[key] = DeclaredSurface(
        surface: surface,
        kind: kind,
        declaredProvers: [...existing.declaredProvers, prover],
      );
    }

    for (final behavior in behaviors) {
      final analysis = FinderTaxonomy.analyze(behavior.description);
      for (final assertion in analysis.assertions) {
        switch (assertion.assertionClass) {
          case ScenarioAssertionClass.absence:
            continue;
          case ScenarioAssertionClass.presence ||
              ScenarioAssertionClass.enabledState ||
              ScenarioAssertionClass.sequence:
            // A literal equal to a declared anchor feeds the key row as a
            // prover (the same mapping FinderTaxonomy.resolveKeys applies
            // when the generator emits the accessor — routes are never
            // keyed).
            final anchoredKey = anchorToKey[assertion.literal];
            if (anchoredKey != null) {
              proversByKey.putIfAbsent(anchoredKey, () => []).add(behavior.id);
              continue;
            }
            addRow(
              assertion.literal,
              assertion.assertionClass == ScenarioAssertionClass.presence
                  ? UiSurfaceKind.text
                  : UiSurfaceKind.affordance,
              behavior.id,
            );
          case ScenarioAssertionClass.routeOutcome:
            addRow(assertion.literal, UiSurfaceKind.route, behavior.id);
        }
      }
    }
    for (final token in componentTokens) {
      if (token.isEmpty) continue;
      addRow(token, UiSurfaceKind.affordance, '');
    }
    return [
      ...rows.values,
      // The key rows come last (declaration order in the contract), with
      // the behaviors quoting each anchor as provers.
      ...keys.toDeclaredSurfaces(proversByKey: proversByKey),
    ];
  }

  /// The derived ledger rows with states recomputed from the CURRENT
  /// evidence (`green` = behavior ids whose tests are green — a stored
  /// state is a cache, never the truth; planned provers are NOT-DONE).
  static List<UiSurfaceRow> rows({
    required List<LedgerBehaviorInput> behaviors,
    required I18nKeyTable keys,
    List<String> componentTokens = const [],
    Set<String> greenBehaviors = const {},
  }) => UiLedgerBuilder.derive(
    declared: derive(
      behaviors: behaviors,
      keys: keys,
      componentTokens: componentTokens,
    ),
    greenBehaviors: greenBehaviors,
  );
}

/// The violation kinds the audit reports.
enum UiViewAuditViolationKind {
  /// A quoted user-facing string that traces to no ledger surface.
  untracedSurface,

  /// A quoted literal that IS a declared key's anchor — the key contract
  /// requires the accessor `t.<key>`, never the EN literal.
  hardcodedKey,
}

/// One audit violation: the literal, the kind, and a message that
/// carries the `--> fix:` line (errors-are-an-API).
class UiViewAuditViolation {
  const UiViewAuditViolation({
    required this.kind,
    required this.literal,
    required this.message,
  });

  final UiViewAuditViolationKind kind;
  final String literal;
  final String message;

  @override
  String toString() => 'UiViewAuditViolation(${kind.name}: $literal)';
}

/// The result of auditing one rendered view source.
class UiViewAuditResult {
  const UiViewAuditResult({
    required this.quotedUserFacingStrings,
    required this.violations,
    required this.ledgerRowCount,
  });

  /// Every quoted user-facing string the view renders, in
  /// first-occurrence order, de-duplicated.
  final List<String> quotedUserFacingStrings;

  /// The violations (untraced + hardcoded-key), in scan order.
  final List<UiViewAuditViolation> violations;

  /// How many surfaces the derived ledger carries (for the clean-audit
  /// summary line).
  final int ledgerRowCount;

  bool get isClean => violations.isEmpty;
}

/// The localization gate (issue #1141): audits a RENDERED view source
/// against the derived ledger BEFORE any write.
///
/// A string is TRACED when a ledger row names it verbatim (any
/// renderable kind — text, route, affordance, key), when it is the
/// anchor of a declared key whose `t.<key>` row the ledger carries (the
/// #965 fallback contract), or when it is one of [markerLiterals] (the
/// #939 behavior-id marker text). On a keyed host, a declared anchor
/// that renders as a QUOTED literal is a [UiViewAuditViolationKind
/// .hardcodedKey] violation — the exact regression the #965 mutation
/// audit's M3 proved possible (a generator degraded to EN emission).
abstract final class UiViewAudit {
  static UiViewAuditResult audit({
    required String viewSource,
    required List<UiSurfaceRow> ledger,
    Map<String, String> anchorToKey = const {},
    Iterable<String> markerLiterals = const [],
  }) {
    final markers = markerLiterals.toSet();
    final quoted = UiLedgerBuilder.quotedUserFacingStrings(viewSource);
    final untraced = UiLedgerBuilder.untracedHardcodedStrings(
      viewSource: viewSource,
      ledger: ledger,
      anchorToKey: anchorToKey,
      allowLiterals: markers,
    );
    final violations = <UiViewAuditViolation>[];
    for (final literal in untraced) {
      violations.add(
        UiViewAuditViolation(
          kind: UiViewAuditViolationKind.untracedSurface,
          literal: literal,
          message:
              "untraced-surface violation: '$_escape(literal)' renders as "
              'a quoted user-facing string but traces to no ledger '
              'surface.\n'
              '           --> fix: declare `key: <dotted.key> -> '
              "'${_escape(literal)}'` in the Presentation contract, or "
              're-plan so a behavior row quotes the literal (a text row).',
        ),
      );
    }
    // The keyed-host half: a declared anchor rendered as a quoted literal
    // is a hardcoded-key violation even though it TRACES (0965's fallback
    // semantics) — the key contract requires the accessor.
    for (final literal in quoted) {
      if (markers.contains(literal)) continue;
      final key = anchorToKey[literal];
      if (key == null) continue;
      violations.add(
        UiViewAuditViolation(
          kind: UiViewAuditViolationKind.hardcodedKey,
          literal: literal,
          message:
              "hardcoded-key violation: '$_escape(literal)' is the anchor "
              'of the declared key $key but renders as a quoted EN '
              'literal — the key is the contract.\n'
              '           --> fix: render the accessor t.$key (the '
              'localization gate hard-fails quoted user-facing strings).',
        ),
      );
    }
    return UiViewAuditResult(
      quotedUserFacingStrings: quoted,
      violations: violations,
      ledgerRowCount: ledger.length,
    );
  }

  static String _escape(String raw) => raw.replaceAll("'", r"\'");
}
