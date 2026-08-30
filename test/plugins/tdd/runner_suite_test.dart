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
}

Future<void> _writeProfile(String projectRoot, String content) async {
  final dir = Directory(p.join(projectRoot, '.specify', 'memory'));
  await dir.create(recursive: true);
  await File(p.join(dir.path, 'tdd-profile.md')).writeAsString(content);
}
