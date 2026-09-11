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

const malformedPubspec = '''
name: tdd_fixture
dependencies:
  flutter: [
''';

const invalidDependenciesShapePubspec = '''
name: tdd_fixture
dependencies: []
''';

const nonMapPubspec = '''
[]
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
    await CliRunner(exitOnCompletion: false).runCapturing([
      'tdd',
      'plan',
      '1458-repro',
      '--allow-unit-fallback',
      '--project',
      fx.root.path,
    ]);
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

  test('init keeps the pure-Dart smoke test surface for a pubspec whose '
      'flutter mention is comment-only (issue #1458)', () async {
    // The same detection changed in `InitCommand._isFlutterProject` too;
    // if it regresses back to substring matching, `tdd init` would emit a
    // `bootstrap_smoke_test.dart` importing `flutter_test` — which cannot
    // resolve in this pure-Dart fixture. Same fixture as the gen pin.
    final out = await CliRunner(
      exitOnCompletion: false,
    ).runCapturing(['tdd', 'init', '--project', fx.root.path]);
    expect(exitCode, 0, reason: 'init must succeed: $out');

    final smoke = await File(
      p.join(fx.root.path, 'test', 'bootstrap_smoke_test.dart'),
    ).readAsString();
    expect(
      smoke,
      contains("import 'package:test/test.dart';"),
      reason:
          'a pure-Dart host must get the plain test import in the '
          'bootstrap smoke test:\n$smoke',
    );
    expect(
      smoke,
      isNot(contains('flutter_test')),
      reason:
          'the comment-only `flutter: sdk: flutter` mention must not flip '
          'init to the Flutter runner (issue #1458):\n$smoke',
    );
  });

  test('gen fails loudly on malformed pubspec.yaml instead of silently '
      'taking the pure-Dart lane', () async {
    await CliRunner(exitOnCompletion: false).runCapturing([
      'tdd',
      'plan',
      '1458-repro',
      '--allow-unit-fallback',
      '--project',
      fx.root.path,
    ]);
    await File(
      p.join(fx.root.path, 'pubspec.yaml'),
    ).writeAsString(malformedPubspec);

    final out = await CliRunner(
      exitOnCompletion: false,
    ).runCapturing(['tdd', 'gen', 'U1', '--project', fx.root.path]);
    expect(exitCode, isNot(0), reason: 'gen must fail loudly: $out');
    expect(
      out,
      allOf(contains('pubspec.yaml at'), contains('is not valid YAML')),
      reason: 'the failure must point at the malformed pubspec: $out',
    );
    expect(
      File(fx.artifactsPath).existsSync(),
      isFalse,
      reason: 'gen must stop before writing artifact records on a bad pubspec.',
    );
  });

  test('init fails loudly on malformed pubspec.yaml instead of silently '
      'taking the pure-Dart lane', () async {
    await File(
      p.join(fx.root.path, 'pubspec.yaml'),
    ).writeAsString(malformedPubspec);

    final out = await CliRunner(
      exitOnCompletion: false,
    ).runCapturing(['tdd', 'init', '--project', fx.root.path]);
    expect(exitCode, isNot(0), reason: 'init must fail loudly: $out');
    expect(
      out,
      allOf(contains('pubspec.yaml at'), contains('is not valid YAML')),
      reason: 'the failure must point at the malformed pubspec: $out',
    );
    expect(
      File(
        p.join(fx.root.path, 'test', 'bootstrap_smoke_test.dart'),
      ).existsSync(),
      isFalse,
      reason: 'init must stop before writing the smoke test on a bad pubspec.',
    );
  });

  test(
    'gen fails loudly when pubspec.yaml dependencies is not a mapping',
    () async {
      await CliRunner(exitOnCompletion: false).runCapturing([
        'tdd',
        'plan',
        '1458-repro',
        '--allow-unit-fallback',
        '--project',
        fx.root.path,
      ]);
      await File(
        p.join(fx.root.path, 'pubspec.yaml'),
      ).writeAsString(invalidDependenciesShapePubspec);

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'gen', 'U1', '--project', fx.root.path]);
      expect(exitCode, isNot(0), reason: 'gen must fail loudly: $out');
      expect(
        out,
        contains(
          "pubspec.yaml at ${p.join(fx.root.path, 'pubspec.yaml')} has a non-map dependencies value",
        ),
        reason: 'the failure must name the invalid dependencies shape: $out',
      );
    },
  );

  test(
    'init fails loudly when pubspec.yaml dependencies is not a mapping',
    () async {
      await File(
        p.join(fx.root.path, 'pubspec.yaml'),
      ).writeAsString(invalidDependenciesShapePubspec);

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'init', '--project', fx.root.path]);
      expect(exitCode, isNot(0), reason: 'init must fail loudly: $out');
      expect(
        out,
        contains(
          "pubspec.yaml at ${p.join(fx.root.path, 'pubspec.yaml')} has a non-map dependencies value",
        ),
        reason: 'the failure must name the invalid dependencies shape: $out',
      );
    },
  );

  test('gen fails loudly when pubspec.yaml does not parse to a map', () async {
    await CliRunner(exitOnCompletion: false).runCapturing([
      'tdd',
      'plan',
      '1458-repro',
      '--allow-unit-fallback',
      '--project',
      fx.root.path,
    ]);
    await File(
      p.join(fx.root.path, 'pubspec.yaml'),
    ).writeAsString(nonMapPubspec);

    final out = await CliRunner(
      exitOnCompletion: false,
    ).runCapturing(['tdd', 'gen', 'U1', '--project', fx.root.path]);
    expect(exitCode, isNot(0), reason: 'gen must fail loudly: $out');
    expect(
      out,
      contains(
        "pubspec.yaml at ${p.join(fx.root.path, 'pubspec.yaml')} did not parse to a Map",
      ),
      reason: 'the failure must name the invalid top-level pubspec shape: $out',
    );
  });

  test('init fails loudly when pubspec.yaml does not parse to a map', () async {
    await File(
      p.join(fx.root.path, 'pubspec.yaml'),
    ).writeAsString(nonMapPubspec);

    final out = await CliRunner(
      exitOnCompletion: false,
    ).runCapturing(['tdd', 'init', '--project', fx.root.path]);
    expect(exitCode, isNot(0), reason: 'init must fail loudly: $out');
    expect(
      out,
      contains(
        "pubspec.yaml at ${p.join(fx.root.path, 'pubspec.yaml')} did not parse to a Map",
      ),
      reason: 'the failure must name the invalid top-level pubspec shape: $out',
    );
  });
}
