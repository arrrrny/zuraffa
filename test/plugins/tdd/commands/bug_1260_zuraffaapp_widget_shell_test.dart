// BUG 1260 — the certified skin vocabulary (zuraffa_ui / ZuraffaApp) is
// unreachable from the TDD toolchain.
//
// `zfa tdd gen --kind widget` boots the generated widget test in a raw
// ShadApp (or MaterialApp via `--widget-shell materialapp`): there is no
// `zuraffaapp` shell option, so skin tests never exercise the certified
// shell the real app runs under — no ZuraffaRouteObserver, no ZfaAuditBus,
// no violation chrome (issue #1260, remediation 1).
//
// Fix contract pinned here:
//   - `WidgetAppShell.parse('zuraffaapp')` resolves the certified shell
//     and its emitted widget name is `ZuraffaApp`;
//   - `--widget-shell zuraffaapp` is an accepted gen option that emits the
//     `package:zuraffa_ui/zuraffa_ui.dart` import and pumps the view
//     through `ZuraffaApp`;
//   - a SKIN-LANE project (pubspec declares `zuraffa_ui`) defaults the
//     widget shell to `zuraffaapp` — no flag needed;
//   - `.zfa.json` `tdd.widgetShell: "zuraffaapp"` is honored;
//   - a project whose pubspec does NOT declare `zuraffa_ui` gets the
//     issue-#938 treatment: gen refuses BEFORE writing artifacts with a
//     machine-parseable `--> fix:` line (`flutter pub add zuraffa_ui`);
//   - the pre-1260 shells are unchanged: shadapp default on non-skin
//     projects, materialapp opt-out.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/widget_scaffold.dart';

/// The certified import the zuraffaapp shell must emit (issue #1260).
const String kZuraffaUiImport = "import 'package:zuraffa_ui/zuraffa_ui.dart';";

/// The machine-parseable fix line for a missing certified dependency.
const String kZuraffaUiFixLine =
    '--> fix: flutter pub add zuraffa_ui '
    '(widget-lane behaviors boot a ZuraffaApp shell — the skin lane\'s '
    'certified shell)';

void main() {
  group('bug 1260: WidgetAppShell resolves the certified zuraffaapp shell', () {
    test('parse("zuraffaapp") → the certified shell', () {
      final shell = WidgetAppShell.parse('zuraffaapp');
      expect(
        shell.widgetName,
        'ZuraffaApp',
        reason:
            'issue #1260: the certified vocabulary must be reachable — '
            'the zuraffaapp shell emits ZuraffaApp, not a raw engine shell '
            '(got ${shell.widgetName})',
      );
    });

    test('the certified shell emits the zuraffa_ui barrel import', () async {
      final tmpDir = Directory.systemTemp.createTempSync('bug1260_writer_');
      addTearDown(() {
        if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
      });
      final testPath = p.join(tmpDir.path, 'w_1_test.dart');
      final subjectPath = p.join(tmpDir.path, 'w_1_subject.dart');
      await BehaviorTestWriter(
        widgetShell: WidgetAppShell.parse('zuraffaapp'),
      ).write(
        behavior: Behavior(
          id: 'W-1',
          feature: '1260-certified-vocabulary',
          kind: BehaviorKind.widget,
          description: 'renders the dashboard shell on mount',
          sourceCriterion: 'SC-001',
          target: 'subject_w1',
        ),
        testPath: testPath,
        subjectPath: subjectPath,
      );
      final content = File(testPath).readAsStringSync();
      expect(content, contains('pumpWidget(ZuraffaApp('));
      expect(content, contains(kZuraffaUiImport));
    });
  });

  group('bug 1260: zfa tdd gen accepts --widget-shell zuraffaapp', () {
    late Directory tmpDir;
    late String featureDir;
    const featureName = '1260-certified-vocabulary';

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('bug1260_gen_');
      featureDir = p.join(tmpDir.path, 'specs', featureName);
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    Future<void> seedWidgetBehavior({String behaviorId = 'A1'}) async {
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
| $behaviorId | renders the dashboard shell on mount | AC-1 | widget | PENDING | subject_a1 |
''');
    }

    /// Seeds a pubspec with the given [dependencies] lines.
    Future<void> seedPubspec({List<String> dependencies = const []}) async {
      final buffer = StringBuffer('''
name: bug1260_fixture
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

    /// Writes `.zfa.json` with a `tdd.widgetShell` project default.
    Future<void> seedConfig(String widgetShell) async {
      await File(p.join(tmpDir.path, '.zfa.json')).writeAsString('''
{
  "tdd": {
    "widgetShell": "$widgetShell"
  }
}
''');
    }

    String testArtifact(String id) =>
        p.join(tmpDir.path, 'test', 'tdd', featureName, 'a1_test.dart');

    test(
      'explicit --widget-shell zuraffaapp: emits the certified shell + import',
      () async {
        await seedWidgetBehavior();
        await seedPubspec(
          dependencies: ['flutter: {sdk: flutter}', 'zuraffa_ui: ^0.1.0'],
        );

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'gen',
          '--project',
          tmpDir.path,
          '--feature',
          featureName,
          '--widget-shell',
          'zuraffaapp',
          'A1',
        ]);

        expect(exitCode, 0, reason: out);
        final content = File(testArtifact('A1')).readAsStringSync();
        expect(
          content,
          contains('pumpWidget(ZuraffaApp('),
          reason:
              'issue #1260 remediation 1: skin tests must exercise the '
              'certified shell (ZuraffaRouteObserver + ZfaAuditBus + '
              'violation chrome), not a raw engine shell',
        );
        expect(content, contains(kZuraffaUiImport));
        expect(content, isNot(contains('pumpWidget(ShadApp(')));
      },
    );

    test('skin-lane project (pubspec declares zuraffa_ui): the certified shell '
        'is the DEFAULT — no flag needed', () async {
      await seedWidgetBehavior();
      // shadcn_ui is present so the PRE-1260 default (shadapp) can run
      // un-refused: the pre-fix emission is a ShadApp pump, which is
      // exactly what this test pins as wrong (issue #1260).
      await seedPubspec(
        dependencies: [
          'flutter: {sdk: flutter}',
          'shadcn_ui: ^1.0.0',
          'zuraffa_ui: ^0.1.0',
        ],
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'gen',
        '--project',
        tmpDir.path,
        '--feature',
        featureName,
        'A1',
      ]);

      expect(exitCode, 0, reason: out);
      final content = File(testArtifact('A1')).readAsStringSync();
      expect(
        content,
        contains('pumpWidget(ZuraffaApp('),
        reason:
            'issue #1260: skin-lane projects (pubspec declares zuraffa_ui) '
            'must DEFAULT to the certified shell so skin tests exercise '
            'the contract infrastructure the real app runs under',
      );
    });

    test('.zfa.json tdd.widgetShell: "zuraffaapp" is honored as a project '
        'default', () async {
      await seedWidgetBehavior();
      await seedPubspec(
        dependencies: ['flutter: {sdk: flutter}', 'zuraffa_ui: ^0.1.0'],
      );
      await seedConfig('zuraffaapp');

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'gen',
        '--project',
        tmpDir.path,
        '--feature',
        featureName,
        'A1',
      ]);

      expect(exitCode, 0, reason: out);
      final content = File(testArtifact('A1')).readAsStringSync();
      expect(content, contains('pumpWidget(ZuraffaApp('), reason: out);
    });

    test('project without zuraffa_ui: gen refuses BEFORE writing with the '
        'machine-parseable --> fix: line', () async {
      await seedWidgetBehavior();
      // A pre-#1260 project: flutter only — no certified dependency.
      await seedPubspec(dependencies: ['flutter: {sdk: flutter}']);

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'gen',
        '--project',
        tmpDir.path,
        '--feature',
        featureName,
        '--widget-shell',
        'zuraffaapp',
        'A1',
      ]);

      expect(
        exitCode,
        isNot(0),
        reason:
            'issue #1260 (the #938 discipline): a gen that would emit an '
            'import the target cannot resolve must refuse — got:\n$out',
      );
      expect(
        out,
        contains(kZuraffaUiFixLine),
        reason:
            'the refusal must name the exact machine-parseable remedy: '
            'flutter pub add zuraffa_ui',
      );
      expect(
        File(testArtifact('A1')).existsSync(),
        isFalse,
        reason: 'a refused gen writes no artifacts',
      );
    });

    test('non-skin project without flags: shadapp default is PRESERVED '
        '(no regression)', () async {
      await seedWidgetBehavior();
      await seedPubspec(
        dependencies: ['flutter: {sdk: flutter}', 'shadcn_ui: ^1.0.0'],
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'gen',
        '--project',
        tmpDir.path,
        '--feature',
        featureName,
        'A1',
      ]);

      expect(exitCode, 0, reason: out);
      final content = File(testArtifact('A1')).readAsStringSync();
      expect(content, contains('pumpWidget(ShadApp('));
      expect(content, isNot(contains('pumpWidget(ZuraffaApp(')));
    });

    test(
      'explicit materialapp opt-out: still emits MaterialApp (no regression)',
      () async {
        await seedWidgetBehavior();
        await seedPubspec(dependencies: ['flutter: {sdk: flutter}']);

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'gen',
          '--project',
          tmpDir.path,
          '--feature',
          featureName,
          '--widget-shell',
          'materialapp',
          'A1',
        ]);

        expect(exitCode, 0, reason: out);
        final content = File(testArtifact('A1')).readAsStringSync();
        expect(content, contains('pumpWidget(MaterialApp('));
      },
    );
  });
}
