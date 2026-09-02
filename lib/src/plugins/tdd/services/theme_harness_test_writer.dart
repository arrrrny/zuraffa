/// ThemeHarnessTestWriter — emits the Flutter widget test for a
/// `theme`-kind behavior (issue #841 — theme harness: light/dark scheme +
/// typography as executable proof, shadcn_ui/ShadTheme).
///
/// The emitted file is the FOUR-PROOF harness:
///
///   1. ShadTheme assertions — pumps the app shell (subject contract
///      `appShellFor(mode)`) under BOTH `ThemeMode.light` and
///      `ThemeMode.dark` and asserts `ShadTheme.of(context)` against the
///      certified values the subject wires from the app's constants file:
///      `colorScheme.primary` per mode (dark inverse), `textTheme.family`,
///      headline weight, and the sonner/toaster themed certification.
///   2. Hardcoded-color audit — an analyzer-backed (AST via
///      `parseString`) scan of `lib/` that fails on raw `Color(0x...)`,
///      `Color.fromARGB`, `Color.fromRGBO` literals OUTSIDE the
///      constants files the subject whitelists. AST-based, so comments
///      and string literals never false-positive (the hard constraint).
///   3. Golden baselines — one `matchesGoldenFile` capture per mode per
///      platform under `test/tdd/goldens/<platform>/<mode>/<id>.png`;
///      drift = exit 1 with the diff path (VISION §6). Baselines are
///      captured per platform with `flutter test --update-goldens`.
///   4. Theme-switch latency — pump-and-measure against the certified
///      tolerance using the test binding's FAKE clock (deterministic —
///      never a flaky wall-clock sleep).
///
/// The emitted code is honest red against the emitted subject stub: the
/// contract functions throw `UnimplementedError`, which the harness
/// captures into assertion-level failures (house `_captureInvocation`
/// pattern from `BehaviorTestWriter`).
///
/// The emitted test references the subject contract types through the
/// prefixed import (`subject.ThemeHarnessSpec`) so every field access is
/// statically checked in the target project.
///
/// The emitted test carries the standard provenance headers
/// (`// GENERATED TEST` + `// behavior_id:`) so `--adopt` (bug #840) and
/// the staleness re-render (bug #683) keep working unchanged.
///
/// Target-project prerequisites (documented in the emitted header):
/// Flutter + the flutter test profile (`TddProfile.flutter`), the
/// `shadcn_ui` dependency (the shell installs ShadTheme via ShadApp), and
/// the `analyzer` dev_dependency for the audit block.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/behavior.dart';

/// Writes the theme-harness test file for a theme behavior.
class ThemeHarnessTestWriter {
  const ThemeHarnessTestWriter();

  /// Write the harness test file at [testPath] importing the subject at
  /// [subjectPath]. The [golden] flag is accepted for shape parity with
  /// [BehaviorTestWriter.write] (so a single dispatch site can call
  /// either writer); theme-harness tests do not currently emit
  /// `matchesGoldenFile` blocks, so the flag is reserved.
  Future<void> write({
    required Behavior behavior,
    required String testPath,
    required String subjectPath,
    bool golden = false,
  }) async {
    final testFile = File(testPath);
    await testFile.parent.create(recursive: true);
    final relativeSubjectPath = p.relative(
      subjectPath,
      from: p.dirname(testPath),
    );
    final content = _renderTest(behavior, relativeSubjectPath);
    await testFile.writeAsString(content);
  }

  String _renderTest(Behavior b, String relativeSubjectPath) {
    final description = b.description;
    final escapedDescription = description.replaceAll("'", "\\'");
    final escapedGroup = '${b.id} (${b.sourceCriterion})'.replaceAll(
      "'",
      "\\'",
    );
    final snakeId = _toSnakeCase(b.id);
    return '''
// GENERATED TEST — `zfa tdd gen ${b.id}` (spec 044-test-tdd-generation).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// kind: ${b.kind.name}
// harness: theme (issue #841 — light/dark scheme + typography as executable proof)
// description: $description
//
// THEME HARNESS — four executable proofs in this one file:
//
//   1. ShadTheme assertions — pumps the app shell under ThemeMode.light
//      AND ThemeMode.dark and asserts ShadTheme.of(context) against the
//      values wired in the paired subject: brand primary per mode (dark
//      inverse), typography family + headline weight, and the sonner/
//      toaster themed certification.
//   2. Hardcoded-color audit — analyzer-backed (AST via parseString) scan
//      of lib/ that fails on raw Color(0x...), Color.fromARGB and
//      Color.fromRGBO literals OUTSIDE the whitelisted constants files
//      (subject.themeConstantsFiles). SC-003 as a red/green gate: AST
//      comments/strings cannot false-positive; constants are whitelisted
//      by path.
//   3. Golden baselines — per mode per platform, committed as baselines;
//      drift = exit 1 with the diff path (VISION §6). Capture baselines
//      with: flutter test --update-goldens test/tdd/${snakeId}_test.dart
//      (goldens are platform-specific — capture on every target platform).
//   4. Theme-switch latency — pump-and-measure against the certified
//      tolerance on the test binding's FAKE clock (deterministic — not a
//      flaky wall-clock sleep).
//
// PREREQUISITES (target project): Flutter + the flutter test profile;
// the shadcn_ui dependency (the shell must install ShadTheme via
// ShadApp); the analyzer dev_dependency (the audit block parses lib/
// sources). The paired subject at `$relativeSubjectPath` must be wired to
// the app's REAL theme constants and shell — never inline values here.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '$relativeSubjectPath' as subject;

/// The ShadTheme installed above [element], or null when no ShadTheme
/// ancestor exists (ShadTheme.of throws a FlutterError there — walking is
/// how the harness reads the theme from an arbitrary shell structure).
ShadThemeData? _themeAbove(Element element) {
  try {
    return ShadTheme.of(element);
  } on FlutterError {
    return null;
  }
}

/// Walks the pumped tree deepest-first and returns the first ShadTheme
/// found. A single ShadApp installs exactly one ShadTheme, so any
/// descendant read yields the same data.
ShadThemeData _readInstalledTheme(WidgetTester tester) {
  for (final element in tester.allElements.reversed) {
    final theme = _themeAbove(element);
    if (theme != null) return theme;
  }
  fail(
    'no ShadTheme found in the pumped tree — the app shell must install '
    'ShadTheme (ShadApp) for the theme harness to assert on it',
  );
}

/// Captures the error a not-yet-wired subject contract throws, so the
/// harness fails with an ASSERTION (honest red), not an uncaught error.
Object? _captureSubjectError(void Function() invoke) {
  try {
    invoke();
    return null;
  } catch (error) {
    return error;
  }
}

/// AST visitor collecting RAW color constructor invocations
/// (`Color(0x...)`, `Color.fromARGB(...)`, `Color.fromRGBO(...)`),
/// optionally import-prefixed (e.g. `ui.Color(0x...)`). Comments and
/// string literals never reach the AST visitor — no false positives.
class _RawColorCollector extends RecursiveAstVisitor<void> {
  static const _rawColorFactories = {
    'Color',
    'Color.fromARGB',
    'Color.fromRGBO',
  };

  final violations = <String>[];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.toSource();
    final isRawColor = _rawColorFactories.any(
      (name) => typeName == name || typeName.endsWith('.\$name'),
    );
    if (isRawColor) {
      violations.add(node.toSource());
    }
    super.visitInstanceCreationExpression(node);
  }
}

void main() {
  group('$escapedGroup', () {
    // ------------------------------------------------------------------
    // Proof 1 — ShadTheme assertions under BOTH ThemeModes.
    // ------------------------------------------------------------------
    for (final mode in ThemeMode.values) {
      testWidgets(
        '${b.id} — $escapedDescription (mode: \${mode.name})',
        (tester) async {
          subject.ThemeHarnessSpec? spec;
          Widget? shell;
          final wireError = _captureSubjectError(() {
            spec = subject.themeHarnessSpec();
            shell = subject.appShellFor(mode);
          });
          expect(
            wireError,
            isNull,
            reason:
                'the theme-harness subject must be wired to the app '
                'constants + shell before this proof can run (the stub '
                'throws UnimplementedError by design — honest red)',
          );
          if (wireError != null) return;

          await tester.pumpWidget(shell!);
          await tester.pumpAndSettle();

          final theme = _readInstalledTheme(tester);

          // 1a. Brand primary — per mode, dark inverse; values come from
          // the constants file wired in the subject (never literals here).
          final expectedPrimary = mode == ThemeMode.light
              ? spec!.primaryLight
              : spec!.primaryDark;
          expect(
            theme.colorScheme.primary,
            expectedPrimary,
            reason:
                'ShadTheme primary must equal the constants-file brand '
                'color in \${mode.name} mode (dark mode inverse)',
          );

          // 1b. Typography — family + headline weight from the manifest.
          expect(
            theme.textTheme.family,
            spec!.fontFamily,
            reason: 'typography family must come from the theme manifest',
          );
          expect(
            theme.textTheme.h2.fontWeight,
            spec!.headlineWeight,
            reason: 'headline weight must come from the theme manifest',
          );

          // 1c. Sonner certification — the shell's toaster is wired
          // themed (SC-004). Certified via the subject flag: the sonner
          // package exposes no stable themed-API to reflect on.
          expect(
            spec!.toastThemed,
            isTrue,
            reason: 'sonner/toaster must be configured themed (SC-004)',
          );
        },
      );
    }

    // ------------------------------------------------------------------
    // Proof 2 — hardcoded-color audit (SC-003 red/green gate).
    // ------------------------------------------------------------------
    test(
      '${b.id} — hardcoded-color audit: lib/ has no raw Color(0x...) '
      'outside the constants files',
      () {
        final whitelist = subject.themeConstantsFiles;
        final libDir = Directory('lib');
        expect(
          libDir.existsSync(),
          isTrue,
          reason: 'the audit scans lib/ — run from the package root',
        );
        final violations = <String>[];
        for (final entity in libDir.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final normalized = entity.path.replaceAll(r'\\', '/');
          final whitelisted = whitelist.any(
            (path) => normalized == path || normalized.endsWith(path),
          );
          if (whitelisted) continue;
          final result = parseString(
            content: entity.readAsStringSync(),
            path: entity.path,
            throwIfDiagnostics: false,
          );
          final collector = _RawColorCollector();
          collector.visitCompilationUnit(result.unit);
          for (final violation in collector.violations) {
            violations.add('\$normalized: \$violation');
          }
        }
        expect(
          violations,
          isEmpty,
          reason:
              'SC-003: zero hardcoded colors — raw color literals are '
              'allowed ONLY in the constants files \$whitelist',
        );
      },
    );

    // ------------------------------------------------------------------
    // Proof 3 — golden baselines per mode per platform.
    // ------------------------------------------------------------------
    for (final mode in ThemeMode.values) {
      testWidgets(
        '${b.id} — golden baseline (mode: \${mode.name}, '
        'platform: \${defaultTargetPlatform.name})',
        (tester) async {
          Widget? shell;
          final wireError = _captureSubjectError(() {
            shell = subject.appShellFor(mode);
          });
          expect(
            wireError,
            isNull,
            reason: 'wire the subject shell before capturing goldens',
          );
          if (wireError != null) return;

          await tester.pumpWidget(shell!);
          await tester.pumpAndSettle();
          await expectLater(
            find.byType(ShadApp),
            matchesGoldenFile(
              'goldens/\${defaultTargetPlatform.name}/\${mode.name}/'
              '$snakeId.png',
            ),
          );
        },
      );
    }

    // ------------------------------------------------------------------
    // Proof 4 — theme-switch latency (SC-002, certified tolerance).
    // ------------------------------------------------------------------
    testWidgets('${b.id} — theme-switch latency within certified tolerance', (
      tester,
    ) async {
      subject.ThemeHarnessSpec? spec;
      Widget? lightShell;
      Widget? darkShell;
      final wireError = _captureSubjectError(() {
        spec = subject.themeHarnessSpec();
        lightShell = subject.appShellFor(ThemeMode.light);
        darkShell = subject.appShellFor(ThemeMode.dark);
      });
      expect(
        wireError,
        isNull,
        reason: 'wire the subject before measuring switch latency',
      );
      if (wireError != null) return;

      await tester.pumpWidget(lightShell!);
      await tester.pumpAndSettle();

      // Fake-clock measurement: the test binding's clock advances with
      // the pumps, so the elapsed fake time IS the simulated switch
      // duration — deterministic, never a wall-clock sleep.
      final clock = tester.binding.clock;
      final startedAt = clock.now();
      await tester.pumpWidget(darkShell!);
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
      final switchDuration = clock.now().difference(startedAt);

      expect(
        switchDuration,
        lessThan(spec!.themeSwitchTolerance),
        reason:
            'theme switch must settle within the certified tolerance '
            '(SC-002) — measured on the binding fake clock',
      );
    });
  });
}
''';
  }

  String _toSnakeCase(String s) {
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
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
}
