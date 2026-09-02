/// ThemeHarnessSubjectWriter — emits the subject contract half of the
/// theme-harness `gen` pair (issue #841).
///
/// The emitted subject is the CONTRACT the four-proof harness test drives:
///
///   - `ThemeHarnessSpec` — the certified theme values (brand primary per
///     mode, typography family, headline weight, sonner/toaster themed
///     flag, theme-switch tolerance).
///   - `themeHarnessSpec()` — returns the spec; throws
///     `UnimplementedError` until wired to the app's constants file
///     (honest red — the paired harness fails through its assertion).
///   - `appShellFor(mode)` — builds the production app shell with the
///     given `ThemeMode` applied; throws `UnimplementedError` until wired.
///   - `themeConstantsFiles` — the raw-color WHITELIST: the only paths the
///     hardcoded-color audit allows to carry `Color(0x...)` literals.
///     This one is a const, not a stub: the audit is a GATE, green on a
///     clean lib/ from day one, and must not false-positive on the
///     constants file (the hard constraint from the issue).
///
/// The emitted subject carries the standard provenance headers
/// (`// GENERATED STUB` + `// behavior_id:`) so `--adopt` (bug #840) and
/// the staleness re-render (bug #683) keep working unchanged.
library;

import 'dart:io';

import '../models/behavior.dart';

/// Writes the theme-harness subject contract file for a theme behavior.
class ThemeHarnessSubjectWriter {
  const ThemeHarnessSubjectWriter();

  /// Write the subject file at [subjectPath] for [behavior].
  Future<void> write({
    required Behavior behavior,
    required String subjectPath,
  }) async {
    final file = File(subjectPath);
    await file.parent.create(recursive: true);
    final content = render(behavior);
    await file.writeAsString(content);
  }

  /// Render the subject content the CURRENT binary would write for
  /// [behavior], without touching disk (staleness check contract, bug
  /// #683).
  String render(Behavior b) {
    final snakeId = _toSnakeCase(b.id);
    return '''
// GENERATED STUB — `zfa tdd gen ${b.id}` (spec 044-test-tdd-generation).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// kind: ${b.kind.name}
// description: ${b.description}
//
// THEME-HARNESS SUBJECT CONTRACT (issue #841).
//
// The paired harness test pumps the app shell under ThemeMode.light and
// ThemeMode.dark and asserts ShadTheme values against the inputs below.
// Wire every member to the app's REAL theme surface:
//
//   - themeHarnessSpec() → the certified values, re-exported from the
//     constants file(s) (e.g. lib/theme/theme_constants.dart). Import the
//     constants — never inline new literals here.
//   - appShellFor(mode) → the production app shell (e.g. lib/app.dart's
//     App) built with the given ThemeMode applied.
//
// The contract functions throw [UnimplementedError] until wired — the
// paired harness is honest red on the stub by design. The constants
// whitelist below is a const (the audit is a gate, not a behavior): it is
// the ONLY place raw color literals are allowed, and the audit skips
// exactly these paths.
library;

import 'package:flutter/material.dart';

/// Certified theme inputs for behavior ${b.id} (issue #841).
///
/// Every value is wired from the app's constants file / theme manifest —
/// never hardcoded here.
class ThemeHarnessSpec {
  const ThemeHarnessSpec({
    required this.primaryLight,
    required this.primaryDark,
    required this.fontFamily,
    required this.headlineWeight,
    required this.toastThemed,
    required this.themeSwitchTolerance,
  });

  /// Brand primary from the constants file — light mode.
  final Color primaryLight;

  /// Brand primary from the constants file — dark mode (the inverse).
  final Color primaryDark;

  /// Typography family from the manifest (e.g. 'Axiforma').
  final String fontFamily;

  /// Headline weight from the manifest.
  final FontWeight headlineWeight;

  /// Whether the sonner/toaster host is configured themed (SC-004).
  final bool toastThemed;

  /// Certified theme-switch tolerance (SC-002), measured on the test
  /// binding's fake clock by the harness.
  final Duration themeSwitchTolerance;
}

/// Harness inputs for behavior ${b.id}. Throws [UnimplementedError] until
/// wired to the real constants — honest red by design.
///
/// Target: `themeHarnessSpec() => ThemeHarnessSpec(
///   primaryLight: kBrandGreen,
///   primaryDark: kBrandGreenDark,
///   fontFamily: 'Axiforma',
///   headlineWeight: FontWeight.w700,
///   toastThemed: true,
///   themeSwitchTolerance: Duration(milliseconds: 400),
/// )` — with every identifier imported from the constants file.
ThemeHarnessSpec themeHarnessSpec() => throw UnimplementedError(
    'themeHarnessSpec not implemented — wire to the app constants file '
    '($snakeId subject, issue #841)');

/// Builds the app shell with [mode] applied. Throws [UnimplementedError]
/// until wired to the production shell — honest red by design.
///
/// Target: `appShellFor(mode) => App(themeMode: mode)` (the production
/// shell from lib/app.dart, NOT a local re-implementation).
Widget appShellFor(ThemeMode mode) => throw UnimplementedError(
    'appShellFor not implemented — wire to the production app shell '
    '($snakeId subject, issue #841)');

/// Paths (forward slashes, relative to the package root) whose raw color
/// literals are ALLOWED — the hardcoded-color audit skips exactly these.
/// Adjust to the project's constants layout; keep it minimal (the audit
/// gate weakens with every entry).
const List<String> themeConstantsFiles = <String>[
  'lib/theme/theme_constants.dart',
];
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
