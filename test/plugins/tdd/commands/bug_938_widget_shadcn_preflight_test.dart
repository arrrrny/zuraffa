// Bug #938 — widget-lane gen must preflight the project's shadcn_ui
// dependency BEFORE writing artifacts (VISION §4 errors-are-an-API).
//
// The widget-pair generator (issue #912 defect 2) boots generated widget
// tests inside a ShadApp shell, which emits
// `import 'package:shadcn_ui/shadcn_ui.dart';`. On a fresh zfa setup /
// zfa-init project whose pubspec does not declare shadcn_ui, that import
// cannot resolve: `verify-red` dies at compile-error and the TDD loop can
// never reach an honest RED.
//
// Fix contract (issue #938): `zfa tdd gen` (widget kind) resolves the
// project pubspec FIRST; when `shadcn_ui` is absent it refuses — exit
// non-zero, a machine-parseable `--> fix:` line on stdout, zero artifacts
// written — instead of emitting a test that can only die at compile.
//
// Determinism constraints pinned here:
//   - a pubspec that DECLARES shadcn_ui → gen proceeds unchanged;
//   - an explicit `--widget-shell materialapp` opt-out emits no shadcn
//     import → the preflight does not apply;
//   - no pubspec.yaml at all → pre-existing behavior (nothing to resolve).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

/// The canonical, machine-parseable fix line (issue #938).
const String kExpectedFixLine =
    '--> fix: flutter pub add shadcn_ui '
    '(widget-lane behaviors boot a ShadApp shell)';

void main() {
  late Directory tmpDir;
  late String featureDir;
  const featureName = '090-shadcn-preflight-fixture';

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('bug938_preflight_');
    featureDir = p.join(tmpDir.path, 'specs', featureName);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  /// Seeds the spec + a 6-column WIDGET-kind test-list row (the same
  /// fixture shape the bug-830 gen tests prove out).
  Future<void> seedWidgetBehavior({
    String behaviorId = 'A1',
    String target = 'subject_a1',
  }) async {
    final specDir = Directory(featureDir);
    await specDir.create(recursive: true);
    await File(p.join(specDir.path, 'spec.md')).writeAsString(
      '**Template Version**: `zuraffa-1.0`\n\n'
      '- **AC-1**: renders the dashboard shell on mount\n',
    );
    await Directory(p.join(specDir.path, 'tdd')).create(recursive: true);
    await File(p.join(specDir.path, 'tdd', 'test-list.md')).writeAsString('''
| id | behavior | traces | kind | state | target |
|----|----------|--------|------|-------|--------|
| $behaviorId | renders the dashboard shell on mount | AC-1 | widget | PENDING | $target |
''');
  }

  /// Writes a pubspec.yaml whose dependencies set is [dependencies].
  Future<void> seedPubspec({List<String> dependencies = const []}) async {
    final buffer = StringBuffer('''
name: bug938_fixture
environment:
  sdk: ^3.11.0
''');
    if (dependencies.isNotEmpty) {
      buffer.writeln('dependencies:');
      for (final dep in dependencies) {
        buffer.writeln('  $dep');
      }
    }
    await File(
      p.join(tmpDir.path, 'pubspec.yaml'),
    ).writeAsString(buffer.toString());
  }

  List<String> genArgs(String id, [List<String> extra = const <String>[]]) => [
    'tdd',
    'gen',
    '--project',
    tmpDir.path,
    '--feature',
    featureName,
    id,
    ...extra,
  ];

  /// Mirrors gen's `_toSnakeCase` artifact naming (bug #827 paths):
  /// `A1` → `a1`, `B-003` → `b_003`.
  String snake(String id) {
    final out = StringBuffer();
    for (var i = 0; i < id.length; i++) {
      final c = id[i];
      if (c == '-' || c == ' ' || c == '_') {
        out.write('_');
      } else if (c.toUpperCase() == c && c.toLowerCase() != c && i > 0) {
        out.write('_');
        out.write(c.toLowerCase());
      } else {
        out.write(c.toLowerCase());
      }
    }
    return out.toString();
  }

  String testArtifact(String id) =>
      p.join(tmpDir.path, 'test', 'tdd', featureName, '${snake(id)}_test.dart');

  String subjectArtifact(String id) => p.join(
    tmpDir.path,
    'lib',
    'tdd',
    featureName,
    '${snake(id)}_subject.dart',
  );

  // ------------------------------------------------------------------
  // Acceptance (issue #938): shadcn-less project → refuse with the fix.
  // ------------------------------------------------------------------
  group('bug938: widget gen preflights the shadcn_ui dependency', () {
    test('shadcn-less project: widget gen exits non-zero with the --> fix: '
        'line and writes NO artifacts', () async {
      await seedWidgetBehavior();
      // A fresh zfa setup project: flutter, zorphy_annotation,
      // zuraffa_flutter — NO shadcn_ui (issue #938 repro pubspec).
      await seedPubspec(
        dependencies: ['flutter: {sdk: flutter}', 'zorphy_annotation: ^2.3.0'],
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(genArgs('A1'));

      expect(
        exitCode,
        isNot(0),
        reason:
            'issue #938: gen must refuse on a shadcn_ui-less project — '
            'got stdout:\n$out',
      );
      expect(
        out,
        contains(kExpectedFixLine),
        reason:
            'the fix line must be machine-parseable and name the exact '
            'remedy (flutter pub add shadcn_ui)',
      );
      // Errors-are-an-API: no artifact that can only die at compile.
      expect(
        File(testArtifact('A1')).existsSync(),
        isFalse,
        reason: 'no test artifact may be written by a refused gen',
      );
      expect(
        File(subjectArtifact('A1')).existsSync(),
        isFalse,
        reason: 'no subject artifact may be written by a refused gen',
      );
      // Registry untouched: the refusal happens before the append.
      final registry = File(p.join(featureDir, 'tdd', 'artifacts.json'));
      expect(
        registry.existsSync(),
        isFalse,
        reason: 'a refused gen must not register artifacts',
      );
    });

    test(
      'project declaring shadcn_ui: widget gen proceeds unchanged',
      () async {
        await seedWidgetBehavior();
        await seedPubspec(
          dependencies: ['flutter: {sdk: flutter}', 'shadcn_ui: ^1.0.0'],
        );

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(genArgs('A1'));

        expect(exitCode, 0, reason: out);
        final testFile = File(testArtifact('A1'));
        expect(testFile.existsSync(), isTrue, reason: out);
        final content = testFile.readAsStringSync();
        expect(content, contains("import 'package:shadcn_ui/shadcn_ui.dart';"));
      },
    );

    test(
      'explicit materialapp shell: no shadcn import, no preflight',
      () async {
        await seedWidgetBehavior();
        await seedPubspec(dependencies: ['flutter: {sdk: flutter}']);

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(
          genArgs('A1', ['--widget-shell', 'materialapp']),
        );

        expect(exitCode, 0, reason: out);
        final content = File(testArtifact('A1')).readAsStringSync();
        expect(content, contains('pumpWidget(MaterialApp('));
        expect(
          content,
          isNot(contains('package:shadcn_ui')),
          reason:
              'a materialapp shell emits no shadcn import, so the '
              'preflight must not fire',
        );
      },
    );

    test('no pubspec.yaml: pre-existing gen behavior preserved', () async {
      await seedWidgetBehavior();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(genArgs('A1'));

      // Bug-830 fixture contexts carry no pubspec; the preflight must not
      // change gen's behavior where there is no pubspec to resolve.
      expect(exitCode, 0, reason: out);
      expect(File(testArtifact('A1')).existsSync(), isTrue, reason: out);
    });
  });
}
// Unit pins for the preflight probe + fix-line contract live in
// test/plugins/tdd/services/bug_938_shadcn_preflight_unit_test.dart.
