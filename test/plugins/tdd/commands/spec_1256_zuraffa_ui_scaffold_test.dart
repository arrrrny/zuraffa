// Spec 1256 (issue #1256) — zfa setup/scaffold must use zuraffa_ui, not
// ShadApp/shadcn_ui.
//
// Issue: `zfa` initialization is outdated and the generated scaffolds
// reference `ShadApp` (shadcn_ui), forcing manual migration to
// `zuraffa_ui` — a violation of the "zfa-only" generation contract.
//
// Expected behavior (from the issue):
//   1. `zfa setup`/`zfa init` wire `zuraffa_ui` into new Flutter apps by
//      default (DependencyWirer.standardSet — the shared wiring both
//      commands use).
//   2. New Flutter application scaffolds created by zfa use zuraffa_ui:
//      the widget lane's default app shell becomes ZuraffaApp
//      (package:zuraffa_ui/zuraffa_ui.dart) instead of ShadApp
//      (package:shadcn_ui/shadcn_ui.dart), and the emitted templates
//      import zuraffa_ui.
//
// The `shadapp` shell stays available as an explicit opt-out (back-compat
// for projects already on shadcn_ui); the DEFAULT follows the issue.
//
// House pattern (issue #938 precedent): these pins import the new API
// surface and are RED (assertion- or compile-red) until the fix lands.
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/core/dependencies/dependency_wirer.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/theme_harness_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/widget_scaffold.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('spec1256_zui_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Behavior widgetBehavior(String id) => Behavior(
    id: id,
    feature: '1256-zuraffa-ui-scaffold',
    kind: BehaviorKind.widget,
    description: "shows the 'Add to cart' action on the product view",
    sourceCriterion: 'SC-001',
    target: 'subject_$id',
  );

  group('spec 1256: WidgetAppShell gains the zuraffaapp default', () {
    test(
      'parse(null) falls back to the ZuraffaApp shell (the new default)',
      () {
        expect(WidgetAppShell.parse(null), WidgetAppShell.zuraffaapp);
      },
    );

    test('parse accepts all three shell names explicitly', () {
      expect(WidgetAppShell.parse('zuraffaapp'), WidgetAppShell.zuraffaapp);
      expect(WidgetAppShell.parse('shadapp'), WidgetAppShell.shadapp);
      expect(WidgetAppShell.parse('materialapp'), WidgetAppShell.materialapp);
    });

    test('parse warns the user when the value is unknown (issue #1256 '
        'follow-up: typo in .zfa.json must not silently default)', () {
      // The warning is printed via `print(...)`; capture stdout via the
      // provided `runZonedPrint` pattern that the test runner uses to
      // route `print` through the test reporter.
      final buffer = StringBuffer();
      final zoneSpec = ZoneSpecification(
        print: (self, parent, zone, message) => buffer.write(message),
      );
      runZoned(
        () => expect(WidgetAppShell.parse('shadap'), WidgetAppShell.zuraffaapp),
        zoneSpecification: zoneSpec,
      );
      expect(
        buffer.toString(),
        contains("tdd.widgetShell='shadap'"),
        reason:
            'the warning must name the unknown value so a user can '
            'fix their .zfa.json',
      );
      expect(buffer.toString(), contains('zuraffaapp'));
      expect(buffer.toString(), contains('shadapp'));
      expect(buffer.toString(), contains('materialapp'));
    });

    test('the zuraffaapp shell emits the ZuraffaApp widget name', () {
      expect(WidgetAppShell.zuraffaapp.widgetName, 'ZuraffaApp');
    });

    test('each shell co-locates widgetName + widgetImport so a future rename '
        'of the host package or the shell widget forces both to update', () {
      expect(
        WidgetAppShell.zuraffaapp.widgetImport,
        "import 'package:zuraffa_ui/zuraffa_ui.dart';\n",
        reason:
            'issue #1256 follow-up: widgetImport names the host '
            'package barrel — a rename of zuraffa_ui must break this '
            'pin so both the import and the widget name update together.',
      );
      expect(
        WidgetAppShell.shadapp.widgetImport,
        "import 'package:shadcn_ui/shadcn_ui.dart';\n",
      );
      expect(WidgetAppShell.materialapp.widgetImport, isNull);
    });
  });

  group('spec 1256: BehaviorTestWriter scaffolds zuraffa_ui by default', () {
    Future<String> renderWidget(
      Behavior behavior, {
      WidgetAppShell? widgetShell,
    }) async {
      final testPath = p.join(tmpDir.path, 'w_1_test.dart');
      final subjectPath = p.join(tmpDir.path, 'w_1_subject.dart');
      await BehaviorTestWriter(
        widgetShell: widgetShell ?? WidgetAppShell.zuraffaapp,
      ).write(behavior: behavior, testPath: testPath, subjectPath: subjectPath);
      return File(testPath).readAsString();
    }

    test('the default shell pumps ZuraffaApp and imports zuraffa_ui', () async {
      final content = await renderWidget(widgetBehavior('S1256-W1'));
      expect(
        content,
        contains('pumpWidget(ZuraffaApp('),
        reason:
            'issue #1256: new Flutter scaffolds use zuraffa_ui — the '
            'generated widget test pumps ZuraffaApp, not ShadApp',
      );
      expect(
        content,
        contains("import 'package:zuraffa_ui/zuraffa_ui.dart';"),
        reason: 'the ZuraffaApp shell needs the zuraffa_ui import',
      );
      expect(
        content,
        isNot(contains('package:shadcn_ui/shadcn_ui.dart')),
        reason: 'the default scaffold no longer references shadcn_ui',
      );
    });

    test(
      'the explicit shadapp shell keeps emitting ShadApp (back-compat)',
      () async {
        final content = await renderWidget(
          widgetBehavior('S1256-W2'),
          widgetShell: WidgetAppShell.shadapp,
        );
        expect(content, contains('pumpWidget(ShadApp('));
        expect(content, contains("import 'package:shadcn_ui/shadcn_ui.dart';"));
      },
    );

    test('the materialapp shell still emits MaterialApp', () async {
      final content = await renderWidget(
        widgetBehavior('S1256-W3'),
        widgetShell: WidgetAppShell.materialapp,
      );
      expect(content, contains('pumpWidget(MaterialApp('));
      expect(content, isNot(contains('ZuraffaApp(')));
    });
  });

  group('spec 1256: ThemeHarnessTestWriter asserts through zuraffa_ui', () {
    Future<String> renderTheme(Behavior behavior) async {
      final testPath = p.join(tmpDir.path, 't_1_test.dart');
      final subjectPath = p.join(tmpDir.path, 't_1_subject.dart');
      await ThemeHarnessTestWriter().write(
        behavior: behavior,
        testPath: testPath,
        subjectPath: subjectPath,
      );
      return File(testPath).readAsString();
    }

    test('the theme harness imports zuraffa_ui and asserts ZfaTheme', () async {
      final content = await renderTheme(
        Behavior(
          id: 'S1256-T1',
          feature: '1256-zuraffa-ui-scaffold',
          kind: BehaviorKind.theme,
          description: 'the brand primary matches the constants per mode',
          sourceCriterion: 'SC-003',
          target: 'subject_t1',
        ),
      );
      expect(
        content,
        contains("import 'package:zuraffa_ui/zuraffa_ui.dart';"),
        reason: 'issue #1256: templates import zuraffa_ui',
      );
      expect(
        content,
        isNot(contains('package:shadcn_ui/shadcn_ui.dart')),
        reason: 'the harness no longer imports shadcn_ui directly',
      );
      expect(
        content,
        contains('ZfaTheme.of('),
        reason: 'theme assertions go through the certified ZfaTheme alias',
      );
      expect(
        content,
        contains('find.byType(ZuraffaApp)'),
        reason: 'the shell finder targets the certified ZuraffaApp shell',
      );
      expect(
        content,
        isNot(contains('ShadApp')),
        reason: 'no raw Shad engine name leaks into the emitted template',
      );
    });
  });

  group('spec 1256: the shell preflight guards the zuraffa_ui import', () {
    void writePubspec(String content) {
      File(p.join(tmpDir.path, 'pubspec.yaml')).writeAsStringSync(content);
    }

    test('the zuraffaapp shell requires zuraffa_ui; materialapp does not', () {
      expect(
        WidgetShadcnPreflight.importRequired(WidgetAppShell.zuraffaapp),
        isTrue,
      );
      expect(
        WidgetShadcnPreflight.importRequired(WidgetAppShell.shadapp),
        isTrue,
      );
      expect(
        WidgetShadcnPreflight.importRequired(WidgetAppShell.materialapp),
        isFalse,
      );
    });

    test('the required package maps per shell', () {
      expect(
        WidgetShadcnPreflight.requiredPackage(WidgetAppShell.zuraffaapp),
        'zuraffa_ui',
      );
      expect(
        WidgetShadcnPreflight.requiredPackage(WidgetAppShell.shadapp),
        'shadcn_ui',
      );
      expect(
        WidgetShadcnPreflight.requiredPackage(WidgetAppShell.materialapp),
        isNull,
      );
    });

    test('projectDeclares reports zuraffa_ui presence truthfully', () {
      writePubspec('''
name: probe
dependencies:
  flutter: {sdk: flutter}
  zuraffa_ui: ^0.1.0
''');
      expect(
        WidgetShadcnPreflight.projectDeclares(
          tmpDir.path,
          WidgetShadcnPreflight.requiredPackage(WidgetAppShell.zuraffaapp)!,
        ),
        isTrue,
      );
    });

    test('projectDeclares reports a missing zuraffa_ui', () {
      writePubspec('''
name: probe
dependencies:
  flutter: {sdk: flutter}
''');
      expect(
        WidgetShadcnPreflight.projectDeclares(
          tmpDir.path,
          WidgetShadcnPreflight.requiredPackage(WidgetAppShell.zuraffaapp)!,
        ),
        isFalse,
      );
    });

    test(
      'the fix line for the default shell names flutter pub add zuraffa_ui',
      () {
        final fixLine = WidgetShadcnPreflight.fixLineFor(
          WidgetAppShell.zuraffaapp,
        );
        expect(fixLine, startsWith('--> fix: flutter pub add zuraffa_ui'));
        expect(fixLine, contains('ZuraffaApp shell'));
      },
    );
  });

  group('spec 1256: DependencyWirer wires zuraffa_ui into Flutter apps', () {
    test('the Flutter standard set includes zuraffa_ui as a regular dep', () {
      final specs = DependencyWirer.standardSet(isFlutter: true);
      final zui = specs.where((s) => s.name == 'zuraffa_ui').toList();
      expect(
        zui,
        hasLength(1),
        reason: 'issue #1256: zuraffa_ui is wired by default',
      );
      expect(zui.single.kind, DependencyKind.regular);
      expect(zui.single.isGit, isFalse, reason: 'hosted on pub.dev, not git');
    });

    test('the pure-Dart standard set does NOT include zuraffa_ui', () {
      final names = DependencyWirer.standardSet(
        isFlutter: false,
      ).map((s) => s.name);
      expect(names, isNot(contains('zuraffa_ui')));
    });

    test('findMissing reports zuraffa_ui on a fresh Flutter pubspec', () {
      const pubspec = '''
name: fresh_app
dependencies:
  flutter: {sdk: flutter}
  zuraffa_flutter: ^6.0.0
''';
      final missing = DependencyWirer.findMissing(pubspec, isFlutter: true);
      expect(missing.map((s) => s.name), contains('zuraffa_ui'));
    });

    test('findMissing is satisfied once zuraffa_ui is declared', () {
      const pubspec = '''
name: fresh_app
dependencies:
  flutter: {sdk: flutter}
  zuraffa_flutter: ^6.0.0
  zuraffa_ui: ^0.1.0
''';
      final missing = DependencyWirer.findMissing(pubspec, isFlutter: true);
      expect(missing.map((s) => s.name), isNot(contains('zuraffa_ui')));
    });

    test('the wired zuraffa_ui version is caret-prefixed (no explicit upper '
        'bound past the next major) so a 0.2.0 release would be picked up', () {
      final specs = DependencyWirer.standardSet(isFlutter: true);
      final zui = specs.firstWhere((s) => s.name == 'zuraffa_ui');
      expect(
        zui.version,
        matches(RegExp(r'^\^\d+\.\d+\.\d+$')),
        reason:
            'issue #1256 follow-up: the wired zuraffa_ui range must '
            'be caret-prefixed so a 0.2.0 release is reachable without '
            'a wired-bump PR; if this fails, the `zuraffa_ui` version '
            'constant in `dependency_wirer.dart` is stale and needs to '
            'track the latest stable release on pub.dev.',
      );
    });
  });

  group('spec 1256: gen CLI scaffolds the ZuraffaApp shell by default', () {
    List<String> genArgs(String id, [List<String> extra = const <String>[]]) =>
        ['tdd', 'gen', '--project', tmpDir.path, id, ...extra];

    Future<void> seedWidgetBehavior({
      String behaviorId = 'S1256-W9',
      String description = "shows the 'Add to cart' action on the product view",
    }) async {
      final specDir = Directory(p.join(tmpDir.path, 'specs', '1256-widget'));
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

    test(
      'default gen emits the ZuraffaApp shell + zuraffa_ui import',
      () async {
        await seedWidgetBehavior();
        // A pubspec that declares zuraffa_ui (issue #938 preflight analog:
        // the default shell's import must resolve or gen refuses).
        File(p.join(tmpDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: spec1256_probe
dependencies:
  flutter: {sdk: flutter}
  zuraffa_ui: ^0.1.0
''');
        final runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing(genArgs('S1256-W9', ['--kind', 'widget']));
        final file = File(
          p.join(
            tmpDir.path,
            'test',
            'tdd',
            '1256-widget',
            's1256_w9_test.dart',
          ),
        );
        final content = await file.readAsString();
        expect(content, contains('pumpWidget(ZuraffaApp('));
        expect(
          content,
          contains("import 'package:zuraffa_ui/zuraffa_ui.dart';"),
        );
      },
    );
  });
}
