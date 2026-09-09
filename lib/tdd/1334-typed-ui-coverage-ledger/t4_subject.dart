// Subject T4 (spec 1334, issue #1143): the XRay overlay renders kind
// coverage PER SCREEN — the per-kind view replaces the surface-count view.
//
// AC-3: a status line per screen (fully-traced / partially-traced /
// untraced) plus one line per kind with traced/total; zero-traced kinds
// are HIGHLIGHTED, never painted as proof; the rendering is a kind
// breakdown, not a surface count.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/tdd/services/typed_ledger_row.dart';
import 'package:zuraffa/src/tdd/services/ui_ledger_builder.dart';
import 'package:zuraffa/src/tdd/services/xray_ledger_binding.dart';

Object? subject_t4() {
  // --- fixtures -----------------------------------------------------------
  final gamingLogin = TypedLedgerBuilder.derive(
    declared: [
      for (final literal in const ['Sign In', 'Email', 'Password'])
        DeclaredLedgerRow(
          surface: literal,
          kind: LedgerRowKind.presence,
          screen: '/login',
          declaredProvers: ['A1'],
        ),
    ],
    greenBehaviors: const {'A1'},
  );

  final honestDealList = TypedLedgerBuilder.derive(
    declared: [
      const DeclaredLedgerRow(
        surface: 'deal row title',
        kind: LedgerRowKind.presence,
        screen: '/deal_list',
        declaredProvers: ['B1'],
      ),
      const DeclaredLedgerRow(
        surface: 'empty-state banner',
        kind: LedgerRowKind.absence,
        screen: '/deal_list',
        declaredProvers: ['B3'],
        notRenderedIn: 'loaded',
      ),
      const DeclaredLedgerRow(
        surface: 'deal detail route',
        kind: LedgerRowKind.navigation,
        screen: '/deal_list',
        declaredProvers: ['B4'],
      ),
      const DeclaredLedgerRow(
        surface: 'load-more button',
        kind: LedgerRowKind.state,
        screen: '/deal_list',
        declaredProvers: ['B2'],
        attribute: 'onPressed = null @ end-of-list',
      ),
      const DeclaredLedgerRow(
        surface: 'pull-to-refresh',
        kind: LedgerRowKind.sequence,
        screen: '/deal_list',
        declaredProvers: ['B5'],
        steps: ['pull', 'loading', 'resolve'],
      ),
    ],
    greenBehaviors: const {'B1', 'B2', 'B3', 'B4', 'B5'},
  );

  final reports = TypedLedgerBuilder.screenReports({
    '/login': gamingLogin,
    '/deal_list': honestDealList,
  });

  // --- the per-screen rendering: status + one line per kind (AC-3) -------
  final loginLines = XrayLedgerOverlay.renderScreen(reports['/login']!);
  expect(loginLines.first, '/login: partially-traced');
  expect(loginLines, hasLength(6)); // status + 5 kinds — not N surfaces
  expect(loginLines, contains('presence 3/3'));
  // zero-traced kinds are HIGHLIGHTED, never painted as proof.
  expect(loginLines, contains('HIGHLIGHT absence 0/0'));
  expect(loginLines, contains('HIGHLIGHT navigation 0/0'));
  expect(loginLines, contains('HIGHLIGHT state 0/0'));
  expect(loginLines, contains('HIGHLIGHT sequence 0/0'));
  // the rendering is a KIND breakdown — no surface names anywhere.
  expect(loginLines.join('\n'), isNot(contains('Sign In')));
  expect(loginLines.join('\n'), isNot(contains('Email')));

  // --- a fully-traced screen renders clean --------------------------------
  final dealLines = XrayLedgerOverlay.renderScreen(reports['/deal_list']!);
  expect(dealLines.first, '/deal_list: fully-traced');
  expect(dealLines, hasLength(6));
  expect(dealLines.where((l) => l.startsWith('HIGHLIGHT')).toList(), isEmpty);
  expect(dealLines, contains('presence 1/1'));
  expect(dealLines, contains('absence 1/1'));

  // --- both screens render, distinguished (AC-3) --------------------------
  final byScreen = XrayLedgerOverlay.renderByScreen(reports);
  expect(byScreen.keys.toSet(), {'/login', '/deal_list'});
  expect(byScreen['/login']!.first, '/login: partially-traced');
  expect(byScreen['/deal_list']!.first, '/deal_list: fully-traced');

  // --- the deck lists screens with their status ---------------------------
  final screenEntries = XrayLedgerDeck.screenEntries(reports);
  expect(screenEntries, hasLength(2));
  final loginEntry = screenEntries.singleWhere(
    (e) => e.label.startsWith('/login'),
  );
  expect(loginEntry.label, '/login: partially-traced');
  expect(loginEntry.state, 'NOT-DONE');
  final dealEntry = screenEntries.singleWhere(
    (e) => e.label.startsWith('/deal_list'),
  );
  expect(dealEntry.label, '/deal_list: fully-traced');
  expect(dealEntry.state, 'DONE');

  // --- the legacy surface-count view still serves kindless ledgers -------
  // (paint/highlights take the 075 UiSurfaceRow shape — legacy-only now;
  // they are NOT the typed overlay path.)
  final legacyLine = XrayLedgerOverlay.paint(
    surface: 'Sign In',
    ledger: [
      const UiSurfaceRow(
        surface: 'Sign In',
        kind: UiSurfaceKind.text,
        provers: ['A1'],
        state: 'DONE',
      ),
    ],
  );
  expect(legacyLine, XrayLedgerPaint.clean);

  return null;
}
