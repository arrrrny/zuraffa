/// Tests for the ledger's i18n composition (issue #965, T004).
///
/// The ledger (#963) traces `t.<key>` per declared row — kind `key` —
/// and any hardcoded user-facing string in a generated view (a quoted
/// string inside `Text(...)`) that no ledger surface traces is an
/// untraced-surface violation. The keyed accessor form `Text(t.app.name)`
/// is code identity and is never flagged.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/i18n_key_contract.dart';
import 'package:zuraffa/src/tdd/services/ui_ledger_builder.dart';

void main() {
  group('bug 965 T004: the ledger traces t.<key> per declared row', () {
    test('US4.AC1: one key-kind row per declared key, DONE only with a '
        'green prover', () {
      final table = I18nKeyTable.of([
        const I18nKeyContract(key: 'auth.signIn', anchor: 'Sign in'),
        const I18nKeyContract(key: 'auth.signOut', anchor: 'Sign out'),
      ]);
      final rows = UiLedgerBuilder.derive(
        declared: [
          ...table.toDeclaredSurfaces(
            proversByKey: const {
              'auth.signIn': ['A-001'],
            },
          ),
        ],
        greenBehaviors: const {'A-001'},
      );

      final signIn = rows.singleWhere((r) => r.surface == 't.auth.signIn');
      expect(signIn.kind, UiSurfaceKind.key);
      expect(signIn.state, 'DONE');
      expect(signIn.provers, ['A-001']);

      final signOut = rows.singleWhere((r) => r.surface == 't.auth.signOut');
      expect(signOut.kind, UiSurfaceKind.key);
      expect(signOut.state, 'NOT-DONE');
      expect(signOut.provers, isEmpty);
    });

    test('US4.AC1: the ledger markdown renders the key rows', () {
      final table = I18nKeyTable.of([
        const I18nKeyContract(key: 'app.name', anchor: 'ZikZak'),
      ]);
      final rows = UiLedgerBuilder.derive(
        declared: table.toDeclaredSurfaces(),
        greenBehaviors: const {},
      );
      final markdown = UiLedgerBuilder.toMarkdown(rows);
      expect(markdown, contains('| t.app.name | key |  | NOT-DONE |'));
    });
  });

  group('bug 965 T004: untraced-surface violations', () {
    final keyTable = I18nKeyTable.of([
      const I18nKeyContract(key: 'app.name', anchor: 'ZikZak'),
      const I18nKeyContract(key: 'auth.signIn', anchor: 'Sign in'),
    ]);
    final ledger = UiLedgerBuilder.derive(
      declared: [
        ...keyTable.toDeclaredSurfaces(),
        const DeclaredSurface(
          surface: 'Welcome back',
          kind: UiSurfaceKind.text,
          declaredProvers: ['A-002'],
        ),
      ],
      greenBehaviors: const {'A-001'},
    );

    test('US4.AC2: a hardcoded string that traces to nothing is reported', () {
      const view = '''
Column(
  children: [
    Text(t.app.name),
    Text('Some hardcode'),
  ],
)''';
      final violations = UiLedgerBuilder.untracedHardcodedStrings(
        viewSource: view,
        ledger: ledger,
        anchorToKey: keyTable.anchorToKey,
      );
      expect(violations, ['Some hardcode']);
    });

    test('the keyed accessor is never flagged (code identity)', () {
      const view = '''
Column(
  children: [
    Text(t.app.name),
    Text(t.auth.signIn),
  ],
)''';
      final violations = UiLedgerBuilder.untracedHardcodedStrings(
        viewSource: view,
        ledger: ledger,
        anchorToKey: keyTable.anchorToKey,
      );
      expect(violations, isEmpty);
    });

    test('an anchor whose key row exists is traced (the ledger composes '
        'with the key contract)', () {
      const view = '''
Column(
  children: [
    Text('ZikZak'),
  ],
)''';
      final violations = UiLedgerBuilder.untracedHardcodedStrings(
        viewSource: view,
        ledger: ledger,
        anchorToKey: keyTable.anchorToKey,
      );
      expect(violations, isEmpty, reason: "'ZikZak' traces to t.app.name");
    });

    test('a literal with a declared TEXT row is traced', () {
      const view = '''
Column(
  children: [
    Text('Welcome back'),
  ],
)''';
      final violations = UiLedgerBuilder.untracedHardcodedStrings(
        viewSource: view,
        ledger: ledger,
        anchorToKey: keyTable.anchorToKey,
      );
      expect(violations, isEmpty);
    });

    test('button-child hardcoded strings are user-facing surfaces too', () {
      const view = '''
Column(
  children: [
    ElevatedButton(
      onPressed: () {},
      child: Text('mystery action'),
    ),
  ],
)''';
      final violations = UiLedgerBuilder.untracedHardcodedStrings(
        viewSource: view,
        ledger: ledger,
        anchorToKey: keyTable.anchorToKey,
      );
      expect(violations, ['mystery action']);
    });

    test('no declared keys — every quoted Text literal is audited against '
        'the text rows alone', () {
      const view = '''
Column(
  children: [
    Text('Welcome back'),
    Text('untraced'),
  ],
)''';
      final violations = UiLedgerBuilder.untracedHardcodedStrings(
        viewSource: view,
        ledger: ledger,
      );
      expect(violations, ['untraced']);
    });
  });
}
