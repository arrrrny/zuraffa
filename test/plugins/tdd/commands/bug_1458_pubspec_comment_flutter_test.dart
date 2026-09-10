// Issue #1458 — `zfa tdd gen` treated a pure-Dart pubspec as a Flutter
// project when "flutter" appeared in a COMMENT (`pubspec.contains`
// substring matching / `sdk:\s*flutter` regex both false-positive). The
// fix parses the YAML and checks the `dependencies: flutter:` key. This
// regression test pins the exact #1458 shape: a pubspec whose only
// "flutter" mention sits behind a `#` comment must keep gen on the
// plain `package:test` import surface — never `flutter_test`.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

/// The issue's repro pubspec: valid pure-Dart package whose ONLY
/// "flutter" mention is inside a comment. Every pre-#1458 matcher
/// (substring, `sdk:\s*flutter` regex) returned true for this.
const commentFalsePositivePubspec = '''
name: tdd_fixture
# Tooling note: the `flutter: sdk: flutter` dependency lives in the
# app-shell package, not this pure-Dart library.
environment:
  sdk: ^3.11.0
dev_dependencies:
  test: ^1.25.0
''';

const reproSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1458-repro

## Functional Requirements

- **FR-001**: System MUST let the user add a todo with a title

## Acceptance Scenarios

1. **Given** the todo list **When** the user adds a todo **Then** the todo appears in the list.
''';

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create(featureName: '1458-repro');
    // Overwrite the fixture's pubspec with the #1458 false-positive
    // shape AFTER create so gen's detection reads exactly this file.
    await File(
      p.join(fx.root.path, 'pubspec.yaml'),
    ).writeAsString(commentFalsePositivePubspec);
    await Directory(fx.featureDir).create(recursive: true);
    await File(p.join(fx.featureDir, 'spec.md')).writeAsString(reproSpec);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test('gen keeps the plain package:test import surface for a pure-Dart '
      'pubspec whose flutter mention is comment-only (issue #1458)', () async {
    await CliRunner(
      exitOnCompletion: false,
    ).runCapturing(['tdd', 'plan', '1458-repro', '--project', fx.root.path]);
    final out = await CliRunner(
      exitOnCompletion: false,
    ).runCapturing(['tdd', 'gen', 'U1', '--project', fx.root.path]);
    expect(exitCode, 0, reason: 'gen must succeed: $out');

    final record = await fx.registryRecordOf('U1');
    final testPath = record['test_path'] as String;
    final generated = await File(
      p.isAbsolute(testPath) ? testPath : p.join(fx.root.path, testPath),
    ).readAsString();

    expect(
      generated,
      contains("import 'package:test/test.dart';"),
      reason:
          'a pure-Dart host must generate the plain test import — the '
          'plain `test` package does not resolve under flutter_test:\n'
          '$generated',
    );
    expect(
      generated,
      isNot(contains('flutter_test')),
      reason:
          'the comment-only `flutter: sdk: flutter` mention must not flip '
          'the host to the Flutter runner (issue #1458):\n$generated',
    );
  });
}
