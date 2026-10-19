import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/services/theme_importer.dart';

void main() {
  group('ThemeImporter helpers', () {
    test('ident lower-cases first char of first segment', () {
      const ti = ThemeImporter();
      expect(ti.ident('color.on-primary'), equals('colorOnPrimary'));
      expect(ti.ident('primary'), equals('primary'));
      expect(ti.ident('on-primary'), equals('onPrimary'));
      expect(ti.ident(''), equals('token'));
    });

    test('normalizeHex expands shorthand and upper-cases', () {
      const ti = ThemeImporter();
      expect(ti.normalizeHex('#abc'), equals('#AABBCC'));
      expect(ti.normalizeHex('#aabbcc'), equals('#AABBCC'));
      expect(ti.normalizeHex('aabbcc'), equals('#AABBCC'));
    });

    test('contrastPairs pairs top-level onPrimary/primary', () {
      const ti = ThemeImporter();
      final colors = <String, String>{
        'primary': '#1976D2',
        'onPrimary': '#FFFFFF',
      };
      final pairs = ti.contrastPairs(colors);
      expect(pairs, contains(('onPrimary', 'primary')));
    });

    test('contrastPairs pairs grouped camelCase colorOnPrimary', () {
      const ti = ThemeImporter();
      final colors = <String, String>{
        'colorPrimary': '#1976D2',
        'colorOnPrimary': '#FFFFFF',
      };
      final pairs = ti.contrastPairs(colors);
      expect(pairs, contains(('colorOnPrimary', 'colorPrimary')));
    });
  });

  group('ThemeImporter.import', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('theme_import_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('skips non-hex color tokens instead of crashing', () async {
      final tokens = File(p.join(tmp.path, 'tokens.json'));
      tokens.writeAsStringSync('''
{
  "color": {
    "primary": { "\$type": "color", "\$value": "#1976D2" },
    "bad": { "\$type": "color", "\$value": "red" }
  }
}
''');
      final result = await const ThemeImporter().import(
        tokens.path,
        projectRoot: tmp.path,
      );
      expect(result.colors.containsKey('colorPrimary'), isTrue);
      expect(result.colors.containsKey('colorBad'), isFalse);
    });

    test('does not bucket font weight into spacing', () async {
      final tokens = File(p.join(tmp.path, 'tokens.json'));
      tokens.writeAsStringSync('''
{
  "fontWeight": { "\$type": "number", "\$value": 400 },
  "opacity": { "\$type": "number", "\$value": 0.5 },
  "spacing": { "sm": { "\$type": "spacing", "\$value": 4 } }
}
''');
      final result = await const ThemeImporter().import(
        tokens.path,
        projectRoot: tmp.path,
      );
      expect(result.spacing.containsKey('fontWeight'), isFalse);
      expect(result.spacing.containsKey('opacity'), isFalse);
      expect(result.spacing.containsKey('spacingSm'), isTrue);
    });

    test('force=false does not overwrite existing file', () async {
      final tokens = File(p.join(tmp.path, 'tokens.json'));
      tokens.writeAsStringSync(
        '{"color":{"primary":{"\$type":"color","\$value":"#1976D2"}}}',
      );
      final out = File(p.join(tmp.path, 'lib', 'theme', 'theme_tokens.dart'));
      out.parent.createSync(recursive: true);
      out.writeAsStringSync('ORIGINAL');
      await const ThemeImporter().import(tokens.path, projectRoot: tmp.path);
      expect(out.readAsStringSync(), equals('ORIGINAL'));
    });

    test('force=true overwrites existing file', () async {
      final tokens = File(p.join(tmp.path, 'tokens.json'));
      tokens.writeAsStringSync(
        '{"color":{"primary":{"\$type":"color","\$value":"#1976D2"}}}',
      );
      final out = File(p.join(tmp.path, 'lib', 'theme', 'theme_tokens.dart'));
      out.parent.createSync(recursive: true);
      out.writeAsStringSync('ORIGINAL');
      await const ThemeImporter().import(
        tokens.path,
        projectRoot: tmp.path,
        force: true,
      );
      expect(out.readAsStringSync(), isNot(equals('ORIGINAL')));
    });

    test('jsonSummary escapes outputPath', () {
      const r = ThemeImportResult(
        tokensPath: '/t',
        projectRoot: '/p',
        outputPath: '/a"b\\c',
        colors: {},
        typography: {},
        spacing: {},
        contrastLines: [],
        violations: [],
      );
      expect(r.jsonSummary, contains(r'''"/a\"b\\c"'''));
    });

    test(
      'top-level onPrimary/primary yields contrast pair and violation gate',
      () async {
        final tokens = File(p.join(tmp.path, 'tokens.json'));
        tokens.writeAsStringSync('''
{
  "primary": { "\$type": "color", "\$value": "#FFFFFF" },
  "onPrimary": { "\$type": "color", "\$value": "#FFFFFF" }
}
''');
        final result = await const ThemeImporter().import(
          tokens.path,
          projectRoot: tmp.path,
          dryRun: true,
        );
        expect(result.contrastLines, isNotEmpty);
        expect(result.violations, isNotEmpty);
      },
    );
  });
}
