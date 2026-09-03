// Bug #912 defects 2+3 — widget template shell + scenario finders.
//
// Defect 2: the widget test template pumps inside a hardcoded
// MaterialApp; zuraffa apps are ShadApp/shadcn_ui apps (ZikZak: SC-001
// asserts ShadTheme). The shell must be shell-configurable
// (`--widget-shell` flag > `.zfa.json` `tdd.widgetShell` > default
// ShadApp) and the emitted test must import shadcn_ui when it pumps a
// ShadApp shell.
//
// Defect 3: the widget template asserts `findsOneWidget` on the mounted
// view as a PLACEHOLDER — green achievable by returning `SizedBox()`.
// The template must derive concrete finders from the behavior's scenario
// description (quoted literals become `find.text(...)` assertions), and
// when no scenario finder can be derived the emitted test must carry the
// machine-readable scaffold marker (`zfa:tdd: scaffolded`) so the loop's
// green certification EXCLUDES it from contract-green accounting.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/widget_scaffold.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('bug912_widget_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<String> renderWidget(
    Behavior behavior, {
    WidgetAppShell widgetShell = WidgetAppShell.shadapp,
  }) async {
    final testPath = p.join(tmpDir.path, 'w_1_test.dart');
    final subjectPath = p.join(tmpDir.path, 'w_1_subject.dart');
    await BehaviorTestWriter(
      widgetShell: widgetShell,
    ).write(behavior: behavior, testPath: testPath, subjectPath: subjectPath);
    return File(testPath).readAsString();
  }

  group('bug 912 defect 2: shell-configurable widget template', () {
    test(
      'default shell is ShadApp (zuraffa apps) with the shadcn import',
      () async {
        final content = await renderWidget(
          Behavior(
            id: 'W-1',
            feature: '912-template-self-hosting',
            kind: BehaviorKind.widget,
            description: 'renders the dashboard shell on mount',
            sourceCriterion: 'SC-001',
            target: 'subject_w1',
          ),
        );
        expect(
          content,
          contains('pumpWidget(ShadApp('),
          reason:
              'issue #912 defect 2: zuraffa apps pump ShadApp, not '
              'MaterialApp',
        );
        expect(
          content,
          contains("import 'package:shadcn_ui/shadcn_ui.dart';"),
          reason: 'the ShadApp shell needs the shadcn_ui import',
        );
        expect(content, isNot(contains('MaterialApp(')));
      },
    );

    test('widgetShell: materialapp keeps the MaterialApp shell', () async {
      final content = await renderWidget(
        Behavior(
          id: 'W-2',
          feature: '912-template-self-hosting',
          kind: BehaviorKind.widget,
          description: 'renders the dashboard shell on mount',
          sourceCriterion: 'SC-001',
          target: 'subject_w2',
        ),
        widgetShell: WidgetAppShell.materialapp,
      );
      expect(content, contains('pumpWidget(MaterialApp('));
      expect(content, isNot(contains('ShadApp(')));
    });
  });

  group('bug 912 defect 3: scenario-derived finders + scaffold marker', () {
    test(
      'a quoted scenario literal becomes a concrete find.text assertion',
      () async {
        final content = await renderWidget(
          Behavior(
            id: 'W-3',
            feature: '912-template-self-hosting',
            kind: BehaviorKind.widget,
            description: "shows the 'Add to cart' action on the product view",
            sourceCriterion: 'SC-002',
            target: 'subject_w3',
          ),
        );
        expect(
          content,
          contains("find.text('Add to cart')"),
          reason:
              'the scenario finder must derive from the description '
              '(issue #912 defect 3: findsOneWidget alone is greenable by '
              'a SizedBox)',
        );
        // A scenario-derived test is NOT scaffolded.
        expect(content, isNot(contains(scaffoldedMarker)));
      },
    );

    test('a scenario-less description carries the scaffold marker', () async {
      final content = await renderWidget(
        Behavior(
          id: 'W-4',
          feature: '912-template-self-hosting',
          kind: BehaviorKind.widget,
          description: 'renders the dashboard shell on mount',
          sourceCriterion: 'SC-001',
          target: 'subject_w4',
        ),
      );
      expect(
        content,
        contains(scaffoldedMarker),
        reason:
            'placeholder finders must mark the test scaffolded so it '
            'is excluded from contract-green accounting (issue #912 '
            'defect 3)',
      );
    });

    test('the scaffold marker helper detects only marked files', () {
      expect(
        contentIsScaffolded(
          '// comment\n$widgetScaffoldComment\nvoid main() {}',
        ),
        isTrue,
      );
      expect(contentIsScaffolded('void main() {}'), isFalse);
    });
  });

  group('bug 912 defect 2+3: gen CLI wiring (--widget-shell, .zfa.json)', () {
    List<String> genArgs(String id, [List<String> extra = const <String>[]]) =>
        ['tdd', 'gen', '--project', tmpDir.path, id, ...extra];

    Future<void> seedWidgetBehavior({
      String behaviorId = 'W-5',
      String description = "shows the 'Add to cart' action on the product view",
    }) async {
      final specDir = Directory(p.join(tmpDir.path, 'specs', '912-widget'));
      await specDir.create(recursive: true);
      await File(p.join(specDir.path, 'spec.md')).writeAsString(
        '**Template Version**: `zuraffa-1.0`\n\n- **SC-1**: $description\n',
      );
      await Directory(p.join(specDir.path, 'tdd')).create(recursive: true);
      await File(p.join(specDir.path, 'tdd', 'test-list.md')).writeAsString('''
| id | behavior | traces | kind | state | target |
|----|----------|--------|------|-------|--------|
| $behaviorId | $description | SC-1 | widget | PENDING | subject_$behaviorId |
''');
    }

    Future<String> generatedWidgetTest() async {
      final file = File(
        p.join(tmpDir.path, 'test', 'tdd', '912-widget', 'w_5_test.dart'),
      );
      return file.readAsString();
    }

    test('default gen emits the ShadApp shell + scenario finder', () async {
      await seedWidgetBehavior();
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(genArgs('W-5', ['--kind', 'widget']));
      final content = await generatedWidgetTest();
      expect(content, contains('pumpWidget(ShadApp('));
      expect(content, contains("find.text('Add to cart')"));
    });

    test('--widget-shell materialapp overrides the default', () async {
      await seedWidgetBehavior();
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(
        genArgs('W-5', ['--kind', 'widget', '--widget-shell', 'materialapp']),
      );
      final content = await generatedWidgetTest();
      expect(content, contains('pumpWidget(MaterialApp('));
      expect(content, isNot(contains('ShadApp(')));
    });

    test('.zfa.json tdd.widgetShell=materialapp is honored', () async {
      await seedWidgetBehavior();
      await File(p.join(tmpDir.path, '.zfa.json')).writeAsString('''
{
  "tdd": {
    "widgetShell": "materialapp"
  }
}
''');
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(genArgs('W-5', ['--kind', 'widget']));
      final content = await generatedWidgetTest();
      expect(content, contains('pumpWidget(MaterialApp('));
      expect(content, isNot(contains('ShadApp(')));
    });
  });
}
