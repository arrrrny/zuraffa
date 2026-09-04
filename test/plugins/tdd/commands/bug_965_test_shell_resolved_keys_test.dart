/// Tests for the translation test shell (issue #965, T003).
///
/// Generated widget tests must boot a slang test shell pinned to the base
/// locale and assert through the RESOLVED key — `find.text(t.auth.signIn)`
/// — never the EN string, so a copy edit to the anchor copy cannot break
/// green (US3). Non-keyed output stays byte-identical to the pre-#965
/// template (zero drift for non-i18n hosts). The gen CLI wiring threads
/// the feature's declared key table into the writer.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/i18n_key_contract.dart';
import 'package:zuraffa/src/plugins/tdd/services/widget_scaffold.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  /// Render a widget test through the writer with [i18nKeys].
  Future<String> renderTest({
    required String description,
    I18nKeyTable i18nKeys = I18nKeyTable.empty,
    String? i18nImport,
    WidgetAppShell shell = WidgetAppShell.materialapp,
  }) async {
    final dir = Directory.systemTemp.createTempSync('bug965_shell_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final testPath = p.join(dir.path, 'test', 'tdd', 'a1_test.dart');
    final subjectPath = p.join(dir.path, 'lib', 'tdd', 'a1_subject.dart');
    await BehaviorTestWriter(
      widgetShell: shell,
      i18nKeys: i18nKeys,
      i18nImport: i18nImport,
    ).write(
      behavior: Behavior(
        id: 'A1',
        feature: '0965-i18n-keyed-widget-contracts',
        kind: BehaviorKind.widget,
        description: description,
        sourceCriterion: 'FR-004',
        target: 'subject_login',
      ),
      testPath: testPath,
      subjectPath: subjectPath,
    );
    return File(testPath).readAsString();
  }

  final keyedTable = I18nKeyTable.of([
    const I18nKeyContract(key: 'auth.signIn', anchor: 'Sign in'),
  ]);
  const keyedImport = 'package:tdd_fixture/i18n/strings.g.dart';

  group('bug 965 T003: the translation test shell (writer level)', () {
    test('US3.AC1: a keyed presence assertion resolves the accessor, '
        'never the EN literal', () async {
      final content = await renderTest(
        description: "the login page shows 'Sign in'",
        i18nKeys: keyedTable,
        i18nImport: keyedImport,
      );

      expect(content, contains('find.text(t.auth.signIn), findsOneWidget'));
      expect(content, isNot(contains("find.text('Sign in')")));
    });

    test('US3.AC1: the shell boots — accessor import + base-locale pin '
        'before the pump', () async {
      final content = await renderTest(
        description: "the login page shows 'Sign in'",
        i18nKeys: keyedTable,
        i18nImport: keyedImport,
      );

      expect(content, contains("import '$keyedImport';"));
      expect(content, contains("LocaleSettings.setLocaleRaw('en');"));
      final pin = content.indexOf("LocaleSettings.setLocaleRaw('en');");
      final pump = content.indexOf('pumpWidget(');
      expect(
        pin,
        greaterThanOrEqualTo(0),
        reason: 'the shell pins the base locale',
      );
      expect(
        pin,
        lessThan(pump),
        reason: 'the locale pin boots BEFORE the pump (the shell)',
      );
    });

    test('US3.AC2: copy-edit survival — the assertion line is '
        'byte-identical when the EN anchor is edited', () async {
      final before = await renderTest(
        description: "the login page shows 'Sign in'",
        i18nKeys: keyedTable,
        i18nImport: keyedImport,
      );
      // The copy edit: the anchor copy changes in the contract.
      final after = await renderTest(
        description: "the login page shows 'Sign In'",
        i18nKeys: I18nKeyTable.of([
          const I18nKeyContract(key: 'auth.signIn', anchor: 'Sign In'),
        ]),
        i18nImport: keyedImport,
      );

      String assertionLine(String source) => source
          .split('\n')
          .firstWhere((l) => l.contains('find.text(t.auth.signIn)'));
      expect(
        assertionLine(after),
        assertionLine(before),
        reason:
            'a copy edit to the EN anchor cannot break green — the '
            'assertion resolves the key',
      );
      // And the EN copy never leaked into the test's FINDER lines (the
      // description comment may legitimately quote the scenario prose).
      expect(assertionLine(before), isNot(contains("'Sign in'")));
      expect(assertionLine(after), isNot(contains("'Sign In'")));
    });

    test('US3.AC3: zero drift — no keys declared means no import, no pin, '
        'and quoted EN literals exactly as before', () async {
      final content = await renderTest(
        description: "renders the 'Home' label after sign-in.",
      );

      expect(content, isNot(contains('strings.g.dart')));
      expect(content, isNot(contains('LocaleSettings')));
      expect(content, isNot(contains('t.auth')));
      expect(content, contains("find.text('Home')"));
    });

    test('a keyed absence asserts findsNothing through the accessor', () async {
      final content = await renderTest(
        description: "the 'Incorrect password' error is not shown",
        i18nKeys: I18nKeyTable.of([
          const I18nKeyContract(
            key: 'auth.error',
            anchor: 'Incorrect password',
          ),
        ]),
        i18nImport: keyedImport,
      );

      expect(content, contains('find.text(t.auth.error), findsNothing'));
    });

    test('a keyed enabled-state asserts widgetWithText through the '
        'accessor', () async {
      final content = await renderTest(
        description: "the 'Sign in' button is disabled",
        i18nKeys: keyedTable,
        i18nImport: keyedImport,
      );

      expect(
        content,
        contains('find.widgetWithText(ElevatedButton, t.auth.signIn)'),
      );
    });

    test('a route literal is NEVER keyed (routes are route names, not '
        'display text)', () async {
      final content = await renderTest(
        description: "the user navigates to the route 'deal_list'",
        i18nKeys: I18nKeyTable.of([
          const I18nKeyContract(key: 'deal.list', anchor: 'deal_list'),
        ]),
        i18nImport: keyedImport,
      );

      expect(content, contains("contains('deal_list')"));
      expect(content, isNot(contains('t.deal.list')));
    });
  });

  group('bug 965 T003: the gen CLI wiring threads the key table', () {
    late TddFixture fx;

    setUp(() async {
      fx = await TddFixture.create();
      await Directory('${fx.root.path}/lib').create(recursive: true);
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    Future<void> seedKeyedContract() async {
      final list = File(fx.testListPath);
      await list.parent.create(recursive: true);
      await list.writeAsString('''
# Test List: ${fx.featureName}

## Outer loop: widget behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A-001 | the login page shows 'Sign in' | FR-001 | PENDING |

## Layer contracts

### Presentation

- `LoginSection`: `ShadInput` for email, `key: auth.signIn -> 'Sign in'`
''');
    }

    test(
      'gen emits the resolved-key test through the declared contract',
      () async {
        await seedKeyedContract();
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'gen',
          'A-001',
          '--project',
          fx.root.path,
          '--widget-shell',
          'materialapp',
        ]);

        expect(
          out,
          contains('gen: behavior=A-001 verdict=created'),
          reason: 'out: $out',
        );
        final testFile = File(
          p.join(
            fx.root.path,
            'test',
            'tdd',
            fx.featureName,
            'a_001_test.dart',
          ),
        );
        expect(testFile.existsSync(), isTrue);
        final content = await testFile.readAsString();
        expect(content, contains('find.text(t.auth.signIn), findsOneWidget'));
        expect(content, isNot(contains("find.text('Sign in')")));
        expect(
          content,
          contains("import 'package:tdd_fixture/i18n/strings.g.dart';"),
        );
        expect(content, contains("LocaleSettings.setLocaleRaw('en');"));
      },
    );

    test(
      'a malformed key contract refuses BEFORE any artifact is written',
      () async {
        final list = File(fx.testListPath);
        await list.parent.create(recursive: true);
        await list.writeAsString('''
# Test List: ${fx.featureName}

## Outer loop: widget behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A-001 | the login page shows 'Sign in' | FR-001 | PENDING |

## Layer contracts

### Presentation

- `LoginSection`: `key: broken -> 'Sign in'`
''');
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'gen',
          'A-001',
          '--project',
          fx.root.path,
          '--widget-shell',
          'materialapp',
        ]);

        expect(exitCode, isNot(0));
        expect(out, contains('malformed i18n key token'));
        expect(
          File(
            p.join(
              fx.root.path,
              'test',
              'tdd',
              fx.featureName,
              'a_001_test.dart',
            ),
          ).existsSync(),
          isFalse,
          reason: 'no test artifact is written from a broken contract',
        );
        expect(
          File(
            p.join(
              fx.root.path,
              'lib',
              'tdd',
              fx.featureName,
              'a_001_subject.dart',
            ),
          ).existsSync(),
          isFalse,
          reason: 'no subject artifact is written from a broken contract',
        );
      },
    );
  });
}
