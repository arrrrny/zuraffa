// EPIC 3 / issue #1134, lane 3 — the typed ledger projection: derives
// #966's typed rows (kind: presence|absence|navigation|state|sequence)
// from the DECLARED plan inputs — the behavior descriptions' scenario
// assertions (the #964 finder-kind taxonomy), the Presentation
// component tokens, and the i18n keys. The projection is the
// production caller the typed-ledger library (#966/#1143) has been
// waiting for: `zfa tdd plan` derives + writes the typed ledger.
//
//  U-1134-t1: kinds assign from the scenario verbs — shows→presence,
//             is not shown→absence (with the Given state pinned),
//             navigates to→navigation, is disabled→state (with the
//             attribute), while…in flight→sequence (with the chain
//             steps).
//  U-1134-t2: component tokens and i18n keys derive presence rows
//             (`t.<key>` surfaces); rows de-duplicate by
//             (surface, kind) with provers merged.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/i18n_key_contract.dart';
import 'package:zuraffa/src/plugins/tdd/services/typed_ledger_projection.dart';
import 'package:zuraffa/src/plugins/tdd/services/ui_ledger_projection.dart';
import 'package:zuraffa/src/tdd/services/typed_ledger_row.dart';

void main() {
  test('U-1134-t1: the five kinds assign from the scenario verbs', () {
    final rows = TypedLedgerProjection.declaredRows(
      behaviors: const [
        LedgerBehaviorInput(
          id: 'A3',
          description:
              "Given the login view When it renders Then the app "
              "shows 'Sign in'",
        ),
        LedgerBehaviorInput(
          id: 'A5',
          description:
              "Given a fresh login view When no sign-in attempt has "
              "failed Then the 'Sign in failed' banner is not shown",
        ),
        LedgerBehaviorInput(
          id: 'A4',
          description:
              "Given a completed sign-in When the user signs in Then "
              "the app navigates to the route 'deal_list'",
        ),
        LedgerBehaviorInput(
          id: 'A6',
          description:
              "Given an empty form When validation runs Then the "
              "'Sign in' button is disabled",
        ),
        LedgerBehaviorInput(
          id: 'A7',
          description:
              "Given a submitted form Then while the sign-in request "
              "is in flight the app shows 'Signing in…' and then the app "
              "navigates to the route 'deal_list'",
        ),
      ],
    );

    DeclaredLedgerRow rowOf(String surface, LedgerRowKind kind) {
      final matches = rows
          .where((r) => r.surface == surface && r.kind == kind)
          .toList();
      expect(
        matches,
        hasLength(1),
        reason:
            'exactly one ($surface, ${kind.label}) row, got: '
            '${rows.map((r) => '(${r.surface}, ${r.kind.label})')}',
      );
      return matches.single;
    }

    // shows → presence.
    expect(rowOf('Sign in', LedgerRowKind.presence).declaredProvers, ['A3']);
    // is not shown → absence, with the Given state pinned (a row that
    // never pins its state never counts as proof — the #966 FR-002
    // honest-red discipline).
    final absence = rowOf('Sign in failed', LedgerRowKind.absence);
    expect(absence.declaredProvers, ['A5']);
    expect(absence.notRenderedIn, 'a fresh login view');
    // navigates to the route → navigation (never presence text). The
    // chain behavior A7 navigates to the same route — its assertion
    // MERGES into the row's provers (both behaviors trace it).
    expect(rowOf('deal_list', LedgerRowKind.navigation).declaredProvers, [
      'A4',
      'A7',
    ]);
    // is disabled → state, with the asserted attribute.
    final state = rowOf('Sign in', LedgerRowKind.state);
    expect(state.declaredProvers, ['A6']);
    expect(state.attribute, 'enabled = false');
    // while…in flight + and then → sequence, with the chain steps.
    final sequence = rows
        .where((r) => r.kind == LedgerRowKind.sequence)
        .toList();
    expect(sequence, hasLength(1), reason: 'the in-flight chain is a row');
    expect(sequence.single.declaredProvers, ['A7']);
    expect(
      sequence.single.steps.length,
      greaterThanOrEqualTo(2),
      reason:
          'a sequence row records its chain (≥ 2 steps) — the '
          'single-pump presence assertion cannot satisfy it',
    );
  });

  test('U-1134-t2: component tokens and i18n keys derive presence rows; '
      'rows de-duplicate by (surface, kind) with provers merged', () {
    final rows = TypedLedgerProjection.declaredRows(
      behaviors: const [
        LedgerBehaviorInput(
          id: 'A3',
          description:
              "Given the login view When it renders Then the app "
              "shows 'Sign in'",
        ),
        LedgerBehaviorInput(
          id: 'A8',
          description:
              "Given the login view When it renders again Then the "
              "app shows 'Sign in'",
        ),
      ],
      componentTokens: const ['ShadInput', 'ShadButton'],
      keys: I18nKeyTable.of([
        const I18nKeyContract(key: 'auth.signIn', anchor: 'Sign in'),
      ]),
    );

    // The declared key ANCHORS the literal: the keyed assertion
    // derives the `t.<key>` surface (code identity, issue #965 — the
    // quoted EN literal is the anchor, never the surface). Both
    // behaviors' assertions MERGE into the row's provers.
    final presence = rows
        .where(
          (r) =>
              r.surface == 't.auth.signIn' && r.kind == LedgerRowKind.presence,
        )
        .toList();
    expect(presence, hasLength(1));
    expect(presence.single.declaredProvers, containsAll(['A3', 'A8']));
    // The plain EN-literal surface does NOT exist on a keyed host.
    expect(
      rows.any(
        (r) => r.surface == 'Sign in' && r.kind == LedgerRowKind.presence,
      ),
      isFalse,
      reason: 'the key is the contract — the accessor is the surface',
    );

    // Component tokens: presence rows.
    for (final token in ['ShadInput', 'ShadButton']) {
      expect(
        rows.any((r) => r.surface == token && r.kind == LedgerRowKind.presence),
        isTrue,
        reason: 'the declared component "$token" is a presence row',
      );
    }

    // i18n keys: presence rows with the `t.<key>` surface.
    expect(
      rows.any(
        (r) => r.surface == 't.auth.signIn' && r.kind == LedgerRowKind.presence,
      ),
      isTrue,
      reason: 'the declared key is a presence row keyed by its accessor',
    );
  });

  test('U-1134-t10: rows with the same surface and kind but different '
      'proof semantics stay SEPARATE (never merged into one state)', () {
    final rows = TypedLedgerProjection.declaredRows(
      behaviors: const [
        LedgerBehaviorInput(
          id: 'A5',
          description:
              "Given a fresh login view When no sign-in attempt has "
              "failed Then the 'Sign in failed' banner is not shown",
        ),
        LedgerBehaviorInput(
          id: 'A6',
          description:
              "Given a submitted form When validation runs Then the "
              "'Sign in failed' banner is not shown",
        ),
      ],
    );

    final absences = rows
        .where(
          (r) =>
              r.surface == 'Sign in failed' && r.kind == LedgerRowKind.absence,
        )
        .toList();
    expect(
      absences,
      hasLength(2),
      reason:
          'the two absences are pinned to DIFFERENT states — merging '
          'them would keep one state while accumulating both provers',
    );
    expect(absences.map((r) => r.notRenderedIn).toSet(), {
      'a fresh login view',
      'a submitted form',
    });
  });
}
