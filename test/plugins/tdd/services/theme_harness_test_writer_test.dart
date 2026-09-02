// Tests for ThemeHarnessTestWriter (issue #841 — theme harness).
//
// The writer emits the Flutter widget test for a `theme`-kind behavior:
// dual-ThemeMode ShadTheme assertions, the analyzer-backed hardcoded-color
// audit, per-mode per-platform golden baselines, and the theme-switch
// latency assertion. These pins hold the emitted TEXT to the contract in
// .specify/bugs/tdd-theme-harness/assessment.md — the zuraffa CLI is pure
// Dart and never executes the emitted Flutter code; executing it is the
// target project's flutter-profile concern.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/generated_shape.dart';
import 'package:zuraffa/src/plugins/tdd/services/theme_harness_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/theme_harness_subject_writer.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('theme_harness_test_writer_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Behavior behavior() => Behavior(
    id: 'T1',
    feature: '090-theme-fixture',
    kind: BehaviorKind.theme,
    description:
        'pumps the shell under both ThemeModes and asserts '
        'ShadTheme brand values',
    sourceCriterion: 'SC-001',
    target: 'themed_shell',
  );

  Future<String> writePair({Behavior? behaviorOverride}) async {
    final testPath = p.join(tmp.path, 'test', 'tdd', 't1_test.dart');
    final subjectPath = p.join(tmp.path, 'lib', 'tdd', 't1_subject.dart');
    await const ThemeHarnessTestWriter().write(
      behavior: behaviorOverride ?? behavior(),
      testPath: testPath,
      subjectPath: subjectPath,
    );
    return File(testPath).readAsString();
  }

  group('provenance (adopt/recovery contract, bug #840 shape)', () {
    test('carries the GENERATED TEST marker and the behavior id', () async {
      final content = await writePair();
      expect(content, contains(generatedTestMarker));
      expect(behaviorIdFromContent(content), 'T1');
    });

    test('matches matchesGeneratedTestShape for its behavior id', () async {
      final content = await writePair();
      expect(matchesGeneratedTestShape(content, 'T1'), isTrue);
      expect(matchesGeneratedTestShape(content, 'T2'), isFalse);
    });
  });

  group('proof 1 — dual-ThemeMode ShadTheme assertions', () {
    test(
      'pumps the app shell under BOTH ThemeMode.light and ThemeMode.dark',
      () async {
        final content = await writePair();
        expect(content, contains('ThemeMode.light'));
        expect(content, contains('ThemeMode.dark'));
        // BOTH mode-driven proofs (ShadTheme assertions AND golden
        // capture) iterate every ThemeMode — a presence-only `contains`
        // is satisfied by the other proof's loop, so count occurrences
        // (deliberate mutant M3: proof-1's loop narrowed to light-only
        // survived a presence-only pin).
        expect(
          'for (final mode in ThemeMode.values)'.allMatches(content).length,
          2,
        );
      },
    );

    test('pumps via the subject shell contract, not an inline app', () async {
      final content = await writePair();
      expect(content, contains('subject.appShellFor(mode)'));
    });

    test('asserts ShadTheme.of(context).colorScheme.primary against the '
        'subject-wired spec per mode (dark inverse)', () async {
      final content = await writePair();
      expect(content, contains('ShadTheme.of'));
      expect(content, contains('theme.colorScheme.primary'));
      expect(content, contains('spec!.primaryLight'));
      expect(content, contains('spec!.primaryDark'));
    });

    test(
      'asserts typography family and headline weight from the spec',
      () async {
        final content = await writePair();
        expect(content, contains('theme.textTheme.family'));
        expect(content, contains('spec!.fontFamily'));
        expect(content, contains('theme.textTheme.h2.fontWeight'));
        expect(content, contains('spec!.headlineWeight'));
      },
    );

    test('asserts the sonner/toaster themed certification', () async {
      final content = await writePair();
      expect(content, contains('spec!.toastThemed'));
    });

    test(
      'captures the stub UnimplementedError as an assertion-level red',
      () async {
        final content = await writePair();
        // House honest-red pattern: capture, then expect — never an
        // uncaught error leaking out of the test body.
        expect(content, contains('UnimplementedError'));
        expect(content, contains('expect('));
      },
    );
  });

  group('proof 2 — hardcoded-color audit', () {
    test('emits an analyzer-backed (parseString) scan of lib/', () async {
      final content = await writePair();
      expect(content, contains('parseString'));
      expect(content, contains("Directory('lib')"));
    });

    test(
      'flags raw color constructors only, never comments or strings',
      () async {
        final content = await writePair();
        expect(content, contains("'Color.fromARGB'"));
        expect(content, contains("'Color.fromRGBO'"));
        expect(content, contains('_rawColorFactories'));
        // AST visitor — no regex over raw source lines.
        expect(content, contains('RecursiveAstVisitor<void>'));
      },
    );

    test('whitelists the constants files from the subject contract', () async {
      final content = await writePair();
      expect(content, contains('subject.themeConstantsFiles'));
      // The whitelist must be a live RUNTIME gate in the emitted audit,
      // not a dangling reference (deliberate mutant M4b: the gate was
      // replaced with `false` and survived a presence-only pin).
      expect(content, contains('whitelist.any('));
      expect(content, contains('if (whitelisted) continue;'));
    });
  });

  group('proof 3 — golden baselines per mode per platform', () {
    test('emits matchesGoldenFile under test/tdd/goldens', () async {
      final content = await writePair();
      expect(content, contains('matchesGoldenFile'));
      expect(content, contains('goldens/'));
    });

    test('golden path embeds the platform and the mode', () async {
      final content = await writePair();
      expect(content, contains('defaultTargetPlatform.name'));
      expect(content, contains(r'${mode.name}'));
      expect(content, contains('t1.png'));
    });

    test('documents the --update-goldens capture flow', () async {
      final content = await writePair();
      expect(content, contains('--update-goldens'));
    });
  });

  group('proof 4 — theme-switch latency', () {
    test(
      'measures the switch on the binding fake clock, not wall time',
      () async {
        final content = await writePair();
        expect(content, contains('tester.binding.clock'));
        expect(content, contains('spec!.themeSwitchTolerance'));
        expect(content, contains('lessThan'));
      },
    );

    test('pumps light first, then switches to dark', () async {
      final content = await writePair();
      expect(content, contains('subject.appShellFor(ThemeMode.light)'));
      expect(content, contains('subject.appShellFor(ThemeMode.dark)'));
    });
  });

  group('subject contract pairing', () {
    test('the emitted subject exposes the four contract members', () async {
      final subjectPath = p.join(tmp.path, 'lib', 'tdd', 't1_subject.dart');
      await const ThemeHarnessSubjectWriter().write(
        behavior: behavior(),
        subjectPath: subjectPath,
      );
      final content = File(subjectPath).readAsStringSync();

      expect(content, contains(generatedSubjectMarker));
      expect(behaviorIdFromContent(content), 'T1');
      expect(content, contains('class ThemeHarnessSpec'));
      expect(content, contains('themeHarnessSpec()'));
      expect(content, contains('appShellFor(ThemeMode mode)'));
      expect(content, contains('themeConstantsFiles'));
      // Honest red: the contract functions throw until wired.
      expect(content, contains('UnimplementedError'));
    });

    test('emitted subject carries ThemeMode + Widget contract types', () async {
      final subjectPath = p.join(tmp.path, 'lib', 'tdd', 't1_subject.dart');
      await const ThemeHarnessSubjectWriter().write(
        behavior: behavior(),
        subjectPath: subjectPath,
      );
      final content = File(subjectPath).readAsStringSync();
      expect(content, contains("import 'package:flutter/material.dart'"));
      expect(content, contains('Widget appShellFor'));
      expect(content, contains('Color primaryLight'));
      expect(content, contains('Color primaryDark'));
      expect(content, contains('FontWeight headlineWeight'));
      expect(content, contains('Duration themeSwitchTolerance'));
    });
  });
}
