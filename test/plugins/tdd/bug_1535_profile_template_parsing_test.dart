// Tests for issue #1535: tdd-profile `single:` template parsing.
//
// Two stacked defects (see .specify/bugs/1535-tdd-profile-yaml-escape-placeholder/):
//   1. YAML double-quoted scalar escapes (`\"`) are captured verbatim and never
//      unescaped → `--plain-name` argument arrives as `\"name\"` → zero matches
//      → exit 79 → honest red classified runner-error.
//   2. Unknown placeholder spellings (`<test name>`) survive `_normalize`, get
//      shredded by whitespace tokenization → nonexistent positional path →
//      honest red classified load-error.
//
// Expected contract: escapes unescaped at load (double-quoted YAML style),
// unknown placeholders rejected at load time with a remedy naming the accepted
// `{file}`/`{name}` spellings, honest red certified as `assertion`.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/red_classification.dart';
import 'package:zuraffa/src/plugins/tdd/services/red_classifier.dart';
import 'package:zuraffa/src/plugins/tdd/services/runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  /// Write a profile with the given Keys-block YAML content and load the
  /// `single:` template through the real loader.
  Future<String> loadSingleFromKeys(Directory root, String keysYaml) async {
    final dir = Directory(p.join(root.path, '.specify', 'memory'));
    await dir.create(recursive: true);
    await File(p.join(dir.path, 'tdd-profile.md')).writeAsString(
      '# Profile\n\n'
      '## Keys (machine-readable)\n\n'
      '```yaml\n'
      '$keysYaml\n'
      '```\n',
    );
    return const SingleTestRunner().loadSingleTemplate(
      workingDirectory: root.path,
    );
  }

  /// Write a profile with YAML frontmatter and load the `single:` template.
  Future<String> loadSingleFromFrontmatter(
    Directory root,
    String frontmatter,
  ) async {
    final dir = Directory(p.join(root.path, '.specify', 'memory'));
    await dir.create(recursive: true);
    await File(
      p.join(dir.path, 'tdd-profile.md'),
    ).writeAsString('---\n$frontmatter\n---\n\n# Profile\n');
    return const SingleTestRunner().loadSingleTemplate(
      workingDirectory: root.path,
    );
  }

  group('#1535 YAML double-quoted escape unescaping (AC-1)', () {
    test(
      'unescapes YAML double-quoted escapes in the Keys block single: value',
      () async {
        final fx = await TddFixture.create(writeProfile: false);
        try {
          final template = await loadSingleFromKeys(
            fx.root,
            r"runner: dart"
            '\n'
            r'single: "dart test {file} --plain-name \"{name}\""'
            '\n'
            r"suite: 'dart test'"
            '\n'
            r"file: 'dart test {file}'",
          );
          expect(template, 'dart test {file} --plain-name "{name}"');
          expect(template, isNot(contains(r'\"')));
        } finally {
          fx.dispose();
        }
      },
    );

    test(
      'unescapes YAML double-quoted escapes in frontmatter single: value',
      () async {
        final fx = await TddFixture.create(writeProfile: false);
        try {
          final template = await loadSingleFromFrontmatter(
            fx.root,
            r'single: "dart test {file} --plain-name \"{name}\""',
          );
          expect(template, 'dart test {file} --plain-name "{name}"');
          expect(template, isNot(contains(r'\"')));
        } finally {
          fx.dispose();
        }
      },
    );

    test('unescapes YAML double-quoted escapes in file:/suite: keys', () async {
      final fx = await TddFixture.create(writeProfile: false);
      try {
        final runner = const SingleTestRunner();
        final dir = Directory(p.join(fx.root.path, '.specify', 'memory'));
        await dir.create(recursive: true);
        await File(p.join(dir.path, 'tdd-profile.md')).writeAsString(
          '# Profile\n\n'
          '## Keys (machine-readable)\n\n'
          '```yaml\n'
          r'single: "dart test {file} --plain-name \"{name}\""'
          '\n'
          r'file: "dart test {file} --reporter \"expanded\""'
          '\n'
          r'suite: "dart test --exclude-tags \"slow\""'
          '\n'
          '```\n',
        );
        final fileTemplate = await runner.loadFileTemplate(
          workingDirectory: fx.root.path,
        );
        expect(fileTemplate, r'dart test {file} --reporter "expanded"');
        final suiteTemplate = await runner.loadSuiteTemplate(
          workingDirectory: fx.root.path,
        );
        expect(suiteTemplate, r'dart test --exclude-tags "slow"');
      } finally {
        fx.dispose();
      }
    });
  });

  group('#1535 unknown placeholder rejection at load time (AC-2)', () {
    test('rejects unknown placeholder <test name> at load time naming accepted '
        'placeholders', () async {
      final fx = await TddFixture.create(writeProfile: false);
      try {
        // Issue case 1: the two-word legacy spelling survives normalization
        // and gets shredded by tokenization — must be rejected at load.
        final template = await loadSingleFromKeys(
          fx.root,
          r'single: "dart test <file> --plain-name \"<test name>\""'
          '\n'
          r"suite: 'dart test'"
          '\n'
          r"file: 'dart test {file}'",
        );
        fail('expected a StateError, got template: $template');
      } on StateError catch (e) {
        expect(e.message, contains('<test name>'));
        expect(e.message, contains('{file}'));
        expect(e.message, contains('{name}'));
      } finally {
        fx.dispose();
      }
    });

    test(
      'still accepts legacy <file>/<name> spellings in a double-quoted value',
      () async {
        final fx = await TddFixture.create(writeProfile: false);
        try {
          final template = await loadSingleFromKeys(
            fx.root,
            r'single: "dart test <file> --plain-name \"{name}\""'
            '\n'
            r"suite: 'dart test'"
            '\n'
            r"file: 'dart test {file}'",
          );
          expect(template, 'dart test {file} --plain-name "{name}"');
        } finally {
          fx.dispose();
        }
      },
    );

    test('bullet path also rejects an unknown placeholder spelling', () async {
      final fx = await TddFixture.create(writeProfile: false);
      try {
        final dir = Directory(p.join(fx.root.path, '.specify', 'memory'));
        await dir.create(recursive: true);
        await File(p.join(dir.path, 'tdd-profile.md')).writeAsString('''
# Profile

## Commands

- Single test: `dart test <path> --plain-name "<test name>"` (substring).
''');
        await const SingleTestRunner().loadSingleTemplate(
          workingDirectory: fx.root.path,
        );
        fail('expected a StateError for the unknown <test name> placeholder');
      } on StateError catch (e) {
        expect(e.message, contains('<test name>'));
        expect(e.message, contains('{file}'));
        expect(e.message, contains('{name}'));
      } finally {
        fx.dispose();
      }
    });
  });

  group('#1535 honest red through the YAML-escaped template (AC-3)', () {
    test(
      'certifies an honest red through the YAML-escaped double-quoted '
      'single: template',
      tags: 'slow',
      () async {
        final fx = await TddFixture.create(writeProfile: false);
        try {
          const description = 'returns 42 when invoked with no args';
          // Reproduce issue case 2 verbatim: the double-quoted YAML form with
          // escaped quotes — the profile the toolchain accepted but whose
          // honest red was classified runner-error (exit 79).
          final dir = Directory(p.join(fx.root.path, '.specify', 'memory'));
          await dir.create(recursive: true);
          await File(p.join(dir.path, 'tdd-profile.md')).writeAsString(
            '# TDD Profile — 1535 repro\n\n'
            '## Keys (machine-readable)\n\n'
            '```yaml\n'
            'runner: dart\n'
            r'single: "dart test {file} --plain-name \"{name}\""'
            '\n'
            "suite: 'dart test'\n"
            "file: 'dart test {file}'\n"
            "coverage: 'dart test --coverage'\n"
            '```\n',
          );
          await fx.registerBehavior(id: 'B-001', description: description);
          final runner = const SingleTestRunner();
          final template = await runner.loadSingleTemplate(
            workingDirectory: fx.root.path,
          );
          // The loaded template is the unescaped canonical form.
          expect(template, 'dart test {file} --plain-name "{name}"');
          final record = await runner.runSingle(
            singleTemplate: template,
            testPath: fx.testPathOf('B-001'),
            testName: description,
            workingDirectory: fx.root.path,
          );
          // Exactly the target test ran, and its honest red is certified.
          expect(record.testCount, 1);
          expect(classify(record), RedClassification.assertion);
        } finally {
          fx.dispose();
        }
      },
    );
  });

  group('#1535 no-regression guards (AC-4)', () {
    test(
      'returns the single-quoted form verbatim (no over-escaping)',
      () async {
        final fx = await TddFixture.create(writeProfile: false);
        try {
          final template = await loadSingleFromKeys(fx.root, r"""
suite: 'dart test'
single: 'dart test {file} --name "{name} \d items"'
file: 'dart test {file}'
""");
          // Single-quoted YAML has NO backslash escapes: the value must be
          // returned byte-for-byte, backslashes and all.
          expect(template, r'dart test {file} --name "{name} \d items"');
        } finally {
          fx.dispose();
        }
      },
    );

    test('keeps normalizing the legacy Single test bullet', () async {
      final fx = await TddFixture.create(writeProfile: false);
      try {
        final dir = Directory(p.join(fx.root.path, '.specify', 'memory'));
        await dir.create(recursive: true);
        await File(p.join(dir.path, 'tdd-profile.md')).writeAsString('''
# Profile

## Commands

- Single test: `dart test <path> --plain-name "<name>"` (substring).
''');
        final template = await const SingleTestRunner().loadSingleTemplate(
          workingDirectory: fx.root.path,
        );
        expect(template, 'dart test {file} --plain-name "{name}"');
      } finally {
        fx.dispose();
      }
    });
  });
}
