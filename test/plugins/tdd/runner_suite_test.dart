// Tests for the SingleTestRunner suite extension (spec 048-tdd-refactor,
// T005; behaviors U11, U12).
//
// These extend the existing runner_test.dart coverage to the new
// loadSuiteTemplate() and runSuite() methods, mirroring the single-template
// tests already in place.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/runner.dart';

void main() {
  late Directory tmp;
  late SingleTestRunner runner;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('runner_suite_');
    runner = const SingleTestRunner();
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('SingleTestRunner.loadSuiteTemplate (T005 / U11)', () {
    test(
      'U11: loads the suite template from the Keys (machine-readable) block',
      () async {
        await _writeProfile(tmp.path, '''
# TDD Profile

## Keys (machine-readable)

```yaml
runner: dart
single: 'dart test {file} --plain-name "{name}"'
suite: 'dart test test/plugins/tdd/'
```
''');
        final template = await runner.loadSuiteTemplate(
          workingDirectory: tmp.path,
        );
        expect(template, 'dart test test/plugins/tdd/');
      },
    );

    test(
      'U11: falls back to the Full suite bullet when no Keys block',
      () async {
        await _writeProfile(tmp.path, '''
# TDD Profile

## Commands

- Single test: `dart test {file} --plain-name "{name}"`
- Full suite: `dart test test/plugins/tdd/`
''');
        final template = await runner.loadSuiteTemplate(
          workingDirectory: tmp.path,
        );
        expect(template, 'dart test test/plugins/tdd/');
      },
    );

    test(
      'U11: misfire-stops with StateError when profile is missing',
      () async {
        expect(
          () => runner.loadSuiteTemplate(workingDirectory: tmp.path),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'U11: misfire-stops when profile has no suite key or bullet',
      () async {
        await _writeProfile(tmp.path, '''
# TDD Profile

## Keys (machine-readable)

```yaml
runner: dart
single: 'dart test {file} --plain-name "{name}"'
```
''');
        expect(
          () => runner.loadSuiteTemplate(workingDirectory: tmp.path),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('U11: normalizes legacy <suite> placeholder if present', () async {
      // Edge: a profile that uses the legacy placeholder shape. The suite
      // template should be returned as-is unless it contains placeholders;
      // the runSuite() method does not substitute anything for the suite
      // template (the suite runs the whole tree, not a single file/name).
      await _writeProfile(tmp.path, '''
# TDD Profile

## Keys (machine-readable)

```yaml
runner: dart
suite: 'dart test'
```
''');
      final template = await runner.loadSuiteTemplate(
        workingDirectory: tmp.path,
      );
      expect(template, 'dart test');
    });
  });

  group('SingleTestRunner.runSuite (T005 / U12)', () {
    test(
      'U12: runSuite captures exit code and combined output (green)',
      () async {
        // Use a real `dart --version` invocation — always exits 0 and prints
        // a known string. This proves runSuite captures both fields.
        await _writeProfile(tmp.path, '''
# TDD Profile

## Keys (machine-readable)

```yaml
runner: dart
suite: 'dart --version'
```
''');
        final template = await runner.loadSuiteTemplate(
          workingDirectory: tmp.path,
        );
        final record = await runner.runSuite(
          suiteTemplate: template,
          workingDirectory: tmp.path,
        );
        expect(record.exitCode, 0);
        expect(record.output, contains('Dart SDK version'));
        expect(record.startedProcess, isTrue);
        expect(record.command, 'dart --version');
      },
    );

    test(
      'U12: runSuite captures non-zero exit code on a failing command',
      () async {
        // `dart test` against an empty temp dir returns non-zero (no tests
        // found). Use a deterministic exit-1 sentinel via `dart run` against
        // a non-existent entrypoint.
        await _writeProfile(tmp.path, '''
# TDD Profile

## Keys (machine-readable)

```yaml
runner: dart
suite: 'dart --invalid-flag-for-testing'
```
''');
        final template = await runner.loadSuiteTemplate(
          workingDirectory: tmp.path,
        );
        final record = await runner.runSuite(
          suiteTemplate: template,
          workingDirectory: tmp.path,
        );
        expect(record.exitCode, isNot(0));
        expect(record.output, isNotEmpty);
        expect(record.startedProcess, isTrue);
      },
    );

    test(
      'U12: runSuite reports startedProcess=false on a missing executable',
      () async {
        await _writeProfile(tmp.path, '''
# TDD Profile

## Keys (machine-readable)

```yaml
runner: dart
suite: 'definitely_not_a_real_binary_xyz_suite'
```
''');
        final template = await runner.loadSuiteTemplate(
          workingDirectory: tmp.path,
        );
        final record = await runner.runSuite(
          suiteTemplate: template,
          workingDirectory: tmp.path,
        );
        expect(record.startedProcess, isFalse);
        expect(record.exitCode, -1);
        expect(record.output, contains('Failed to start'));
      },
    );
  });

  // -------------------------------------------------------------------
  // Bug #681 — tdd-runner-legacy-frontmatter-template.
  // The frontmatter block regex used `multiLine: true`, which made `^`
  // match at EVERY line start, so the non-greedy `([\s\S]*?)` stopped at
  // the first `\n---` and captured only a prefix of the frontmatter. The
  // downstream `single:`/`suite:` search then failed and verify-red/make/
  // run threw "no 'single' command template found" on legacy profiles
  // whose commands live in a `---...---` YAML frontmatter (nested
  // `stacks:<label>:` shape, no Keys block).
  // The fix anchors the block with `dotAll: true` in both loaders.
  // -------------------------------------------------------------------
  group('bug #681: legacy frontmatter template loading', () {
    // The exact legacy shape from the issue: YAML frontmatter with the
    // command keys nested under `stacks:`, and NO Keys block.
    const legacyNestedProfile = '''
---
detected_at: 2026-01-15
project: legacy_app
stacks:
  dart:
    runner: dart
    single: 'dart test -n "{name}"'
    file: 'dart test {file}'
    suite: 'dart test'
---
# TDD Profile

Generated by the spec-kit detector before the Keys block existed.
''';

    test('loadSingleTemplate resolves single: from nested stacks frontmatter '
        '(no Keys block)', () async {
      await _writeProfile(tmp.path, legacyNestedProfile);
      final template = await runner.loadSingleTemplate(
        workingDirectory: tmp.path,
      );
      expect(template, 'dart test -n "{name}"');
    });

    test('loadSuiteTemplate resolves suite: from nested stacks frontmatter '
        '(no Keys block)', () async {
      await _writeProfile(tmp.path, legacyNestedProfile);
      final template = await runner.loadSuiteTemplate(
        workingDirectory: tmp.path,
      );
      expect(template, 'dart test');
    });

    test(
      'loadSingleTemplate resolves a flat top-level single: in frontmatter',
      () async {
        await _writeProfile(tmp.path, '''
---
runner: dart
single: 'dart test {file} --plain-name "{name}"'
suite: 'dart test'
---
# body
''');
        final template = await runner.loadSingleTemplate(
          workingDirectory: tmp.path,
        );
        expect(template, 'dart test {file} --plain-name "{name}"');
      },
    );

    test(
      'the Keys (machine-readable) block still wins over the frontmatter',
      () async {
        await _writeProfile(tmp.path, '''
---
single: 'dart test -n "{name}"'
---
# TDD Profile

## Keys (machine-readable)

```yaml
runner: dart
single: 'dart test {file} --name "{name}"'
```
''');
        final template = await runner.loadSingleTemplate(
          workingDirectory: tmp.path,
        );
        expect(template, 'dart test {file} --name "{name}"');
      },
    );

    test('a frontmatter containing a horizontal rule does not truncate the '
        'block (the multiLine:true regression)', () async {
      // `---` on a line inside the frontmatter body is where the old
      // regex stopped early; the nested single: after it was invisible.
      await _writeProfile(tmp.path, '''
---
detected_at: 2026-01-15
notes: |
  divider below
  ---
stacks:
  dart:
    single: 'dart test -n "{name}"'
---
# body
''');
      final template = await runner.loadSingleTemplate(
        workingDirectory: tmp.path,
      );
      expect(template, 'dart test -n "{name}"');
    });
  });

  // -------------------------------------------------------------------
  // Bug #726 — tdd-suite-template-truncation.
  // The unquoted-value alternative `[^\s#]+` stopped at the first
  // whitespace, so a multi-word unquoted command (`suite: dart test`)
  // was resolved as just `dart`: the end-of-line-anchored patterns
  // failed to match entirely and the unanchored nested fallback
  // captured only the first word. The fix extends the unquoted
  // alternative to `[^\s#]+(?:[ \t]+[^\s#]+)*` — one or more
  // whitespace-separated words on a single line — while keeping the
  // quoted alternatives, the `#` comment exclusion, and the per-line
  // anchor semantics intact.
  // -------------------------------------------------------------------
  group('bug #726: multi-word unquoted command templates', () {
    test(
      'loadSuiteTemplate resolves an unquoted multi-word suite: from the '
      'Keys block (mid-block — must not swallow the keys after it)',
      () async {
        await _writeProfile(tmp.path, '''
# TDD Profile

## Keys (machine-readable)

```yaml
runner: dart
single: 'dart test {file} --plain-name "{name}"'
suite: dart test
coverage: dart test --coverage
```
''');
        final template = await runner.loadSuiteTemplate(
          workingDirectory: tmp.path,
        );
        expect(template, 'dart test');
      },
    );

    test('loadSuiteTemplate resolves an unquoted multi-word suite: from the '
        'Keys block (last key)', () async {
      await _writeProfile(tmp.path, '''
# TDD Profile

## Keys (machine-readable)

```yaml
runner: dart
suite: dart test
```
''');
      final template = await runner.loadSuiteTemplate(
        workingDirectory: tmp.path,
      );
      expect(template, 'dart test');
    });

    test('loadSuiteTemplate resolves an unquoted multi-word suite: from '
        'nested stacks frontmatter (the issue repro)', () async {
      await _writeProfile(tmp.path, '''
---
detected_at: 2026-01-15
project: legacy_app
stacks:
  dart:
    runner: dart
    single: dart test -n "{name}"
    file: dart test {file}
    suite: dart test
---
# TDD Profile

Generated by the ecosystem detector (unquoted command values).
''');
      final template = await runner.loadSuiteTemplate(
        workingDirectory: tmp.path,
      );
      expect(template, 'dart test');
    });

    test('loadSingleTemplate resolves an unquoted multi-word single: from '
        'nested stacks frontmatter', () async {
      await _writeProfile(tmp.path, '''
---
stacks:
  dart:
    single: dart test {file} --plain-name "{name}"
    suite: dart test
---
# TDD Profile
''');
      final template = await runner.loadSingleTemplate(
        workingDirectory: tmp.path,
      );
      expect(template, 'dart test {file} --plain-name "{name}"');
    });

    test('an unquoted suite value with a trailing comment captures only the '
        'command (no comment swallowing)', () async {
      await _writeProfile(tmp.path, '''
---
stacks:
  dart:
    suite: dart test # the real suite
---
# TDD Profile
''');
      final template = await runner.loadSuiteTemplate(
        workingDirectory: tmp.path,
      );
      expect(template, 'dart test');
    });

    test('runSuite executes the full multi-word command loaded from an '
        'unquoted profile (both words reach the process)', () async {
      // `dart --version` is multi-word AND unquoted: before the fix the
      // template truncated to `dart`, which runs the bare CLI (help text,
      // exit 0) instead of the version report.
      await _writeProfile(tmp.path, '''
---
stacks:
  dart:
    suite: dart --version
---
# TDD Profile
''');
      final template = await runner.loadSuiteTemplate(
        workingDirectory: tmp.path,
      );
      final record = await runner.runSuite(
        suiteTemplate: template,
        workingDirectory: tmp.path,
      );
      expect(record.startedProcess, isTrue);
      expect(record.exitCode, 0);
      // The colon matters: the bare-`dart` HELP text contains the phrase
      // "Dart SDK version" (in `--version  Print the Dart SDK version.`),
      // which the truncated pre-fix command would still print. Only the
      // real `dart --version` report emits "Dart SDK version: ".
      expect(record.output, contains('Dart SDK version: '));
    });
  });
}

Future<void> _writeProfile(String projectRoot, String content) async {
  final dir = Directory(p.join(projectRoot, '.specify', 'memory'));
  await dir.create(recursive: true);
  await File(p.join(dir.path, 'tdd-profile.md')).writeAsString(content);
}
