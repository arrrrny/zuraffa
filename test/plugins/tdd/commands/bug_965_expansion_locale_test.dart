/// Tests for the optional expansion-locale tier (issue #965, T005).
///
/// `--i18n-expansion de` (or `.zfa.json` `tdd.i18nExpansion`) adds an
/// expansion `testWidgets` per locale to the generated widget test — the
/// view is re-pumped under the expansion locale and every keyed surface
/// is re-asserted through its resolved key (de strings run ~30% longer,
/// catching overflow assumptions before goldens do) — and scaffolds
/// `strings_<loc>.i18n.json` alongside the base locale. Without the tier
/// the generated test carries no expansion block.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/i18n_key_contract.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  final keyedTable = I18nKeyTable.of([
    const I18nKeyContract(key: 'auth.signIn', anchor: 'Sign in'),
  ]);
  const keyedImport = 'package:tdd_fixture/i18n/strings.g.dart';

  Future<String> renderTest({List<String> expansion = const []}) async {
    final dir = Directory.systemTemp.createTempSync('bug965_expand_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final testPath = p.join(dir.path, 'test', 'tdd', 'a1_test.dart');
    final subjectPath = p.join(dir.path, 'lib', 'tdd', 'a1_subject.dart');
    await BehaviorTestWriter(
      i18nKeys: keyedTable,
      i18nImport: keyedImport,
      i18nExpansion: expansion,
    ).write(
      behavior: Behavior(
        id: 'A1',
        feature: '0965-i18n-keyed-widget-contracts',
        kind: BehaviorKind.widget,
        description: "the login page shows 'Sign in'",
        sourceCriterion: 'FR-006',
        target: 'subject_login',
      ),
      testPath: testPath,
      subjectPath: subjectPath,
    );
    return File(testPath).readAsString();
  }

  group('bug 965 T005: the expansion tier (writer level)', () {
    test('US5: the expansion locale re-pumps and re-asserts keyed '
        'surfaces through the resolved keys', () async {
      final content = await renderTest(expansion: const ['de']);

      expect(
        content,
        contains(
          "testWidgets('A1 \u2014 expansion locale de renders every keyed "
          'surface (issue #965)',
        ),
      );
      expect(content, contains("LocaleSettings.setLocaleRaw('de');"));
      // The keyed surface is re-asserted under the expansion locale.
      expect(
        content,
        contains('the keyed surface t.auth.signIn must render under de'),
      );
      expect(
        content.indexOf("LocaleSettings.setLocaleRaw('en');"),
        lessThan(content.indexOf("LocaleSettings.setLocaleRaw('de');")),
        reason:
            'the base shell boots first; the expansion pump comes '
            'after in its own testWidgets',
      );
    });

    test('US5: without the tier there is no expansion block', () async {
      final content = await renderTest();

      expect(content, isNot(contains('expansion locale')));
      expect(content, isNot(contains("LocaleSettings.setLocaleRaw('de');")));
    });

    test('US5: the tier is inert without keyed surfaces even when '
        'configured', () async {
      final dir = Directory.systemTemp.createTempSync('bug965_expand0_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final testPath = p.join(dir.path, 'test', 'tdd', 'a1_test.dart');
      final subjectPath = p.join(dir.path, 'lib', 'tdd', 'a1_subject.dart');
      await BehaviorTestWriter(i18nExpansion: const ['de']).write(
        behavior: Behavior(
          id: 'A1',
          feature: '0965-i18n-keyed-widget-contracts',
          kind: BehaviorKind.widget,
          description: "renders the 'Home' label after sign-in.",
          sourceCriterion: 'FR-006',
          target: 'subject_login',
        ),
        testPath: testPath,
        subjectPath: subjectPath,
      );
      final content = await File(testPath).readAsString();

      expect(content, isNot(contains('expansion locale')));
      expect(
        content,
        contains("find.text('Home')"),
        reason: 'the non-keyed template stays byte-for-byte',
      );
    });
  });

  group('bug 965 T005: the gen + view CLI wiring', () {
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

    test('gen --i18n-expansion de emits the tier', () async {
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
        '--i18n-expansion',
        'de',
      ]);

      expect(out, contains('verdict=created'), reason: 'out: $out');
      final content = await File(
        p.join(fx.root.path, 'test', 'tdd', fx.featureName, 'a_001_test.dart'),
      ).readAsString();
      expect(content, contains('expansion locale de'));
      expect(content, contains("LocaleSettings.setLocaleRaw('de');"));
    });

    test('view --i18n-expansion de scaffolds strings_de.i18n.json alongside '
        'the base locale', () async {
      await seedKeyedContract();
      await fx.registerBehavior(
        id: 'A-001',
        description: "the login page shows 'Sign in'",
      );
      await File(fx.subjectPathOf('A-001')).writeAsString('''
// GENERATED STUB — `zfa tdd gen A-001` (spec 044-test-tdd-generation).
library;

import 'package:flutter/material.dart';

/// View-builder subject for behavior A-001.
Widget subject_a_001() => throw UnimplementedError('not implemented');
''');
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'view',
        'A-001',
        '--project',
        fx.root.path,
        '--i18n-expansion',
        'de',
      ]);

      expect(exitCode, 0, reason: 'out: $out');
      final de = await File(
        '${fx.root.path}/lib/i18n/strings_de.i18n.json',
      ).readAsString();
      expect(de, contains('"signIn": "Sign in"'));
      final base = await File(
        '${fx.root.path}/lib/i18n/strings.i18n.json',
      ).readAsString();
      expect(base, contains('"signIn": "Sign in"'));
    });

    test(
      '.zfa.json tdd.i18nExpansion is honored when the flag is absent',
      () async {
        await seedKeyedContract();
        await fx.registerBehavior(
          id: 'A-001',
          description: "the login page shows 'Sign in'",
        );
        await File(
          '${fx.root.path}/.zfa.json',
        ).writeAsString('{"tdd": {"i18nExpansion": "de"}}');
        await File(fx.subjectPathOf('A-001')).writeAsString('''
// GENERATED STUB — `zfa tdd gen A-001` (spec 044-test-tdd-generation).
library;

import 'package:flutter/material.dart';

/// View-builder subject for behavior A-001.
Widget subject_a_001() => throw UnimplementedError('not implemented');
''');
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'view',
          'A-001',
          '--project',
          fx.root.path,
        ]);

        expect(exitCode, 0, reason: 'out: $out');
        expect(
          File('${fx.root.path}/lib/i18n/strings_de.i18n.json').existsSync(),
          isTrue,
          reason: 'the config-declared expansion locale is scaffolded',
        );
      },
    );
  });
}
