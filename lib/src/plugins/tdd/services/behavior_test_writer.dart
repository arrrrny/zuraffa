/// BehaviorTestWriter — emits the failing test half of a `gen` pair
/// (spec 044-test-tdd-generation, FR-001, FR-010, FR-018).
///
/// The generated test:
///   - imports the paired subject file,
///   - asserts the behavior's `description`, NOT a placeholder
///     `expect(true, isFalse)`,
///   - carries the behavior id + source criterion in its group name +
///     doc comment, so the later `verify` report can trace outcomes
///     (FR-018),
///   - fails with an assertion-level failure on first execution
///     (FR-010: honest red — not skipped, not pending, not a compile
///     error, not a load error, not an unconditional placeholder).
///
/// The test asserts the OBSERVABLE behavior described in `behavior.description`.
/// For a description like "returns 42 when invoked with no args", the test
/// calls `subject()` and asserts the result is `42`. The paired subject
/// (emitted by [SubjectWriter]) throws `UnimplementedError`, which the
/// generated assertion captures as a mismatched result so first run is red.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/behavior.dart';
import 'finder_taxonomy.dart';
import 'widget_scaffold.dart';

/// Writes a Dart test file that pairs with the subject for a behavior.
class BehaviorTestWriter {
  /// The app shell the generated WIDGET test pumps the feature view in
  /// (issue #912 defect 2): default [WidgetAppShell.shadapp] — zuraffa
  /// apps are shadcn_ui apps — overridable per project.
  const BehaviorTestWriter({this.widgetShell = WidgetAppShell.shadapp});

  final WidgetAppShell widgetShell;

  /// Escapes [raw] for safe interpolation into a single-quoted Dart
  /// string literal (issue #912 defect 1): backslash, the single quote
  /// form, `$` (interpolation — a raw `${...}` in a behavior description
  /// must never reach the generated source as code), and control
  /// characters. A double quote is NOT escaped: every interpolation site
  /// is a single-quoted literal, so `\"` would be an UNNECESSARY escape
  /// that trips `unnecessary_string_escapes` in the generated artifact
  /// (issue #1035).
  static String escapeDartString(String raw) {
    final out = StringBuffer();
    for (final code in raw.codeUnits) {
      switch (code) {
        case 0x5C:
          out.write(r'\\');
        case 0x27:
          out.write(r"\'");
        case 0x24:
          out.write(r'\$');
        case 0x0A:
          out.write(r'\n');
        case 0x0D:
          out.write(r'\r');
        case 0x09:
          out.write(r'\t');
        case 0x08:
          out.write(r'\b');
        case 0x0C:
          out.write(r'\f');
        case 0x0B:
          out.write(r'\v');
        default:
          if (code < 0x20 || code == 0x7F) {
            out.write('\\u{${code.toRadixString(16)}}');
          } else {
            out.writeCharCode(code);
          }
      }
    }
    return out.toString();
  }

  /// Makes [raw] safe for a `//` comment line: line breaks would
  /// terminate the comment and spill the remainder into code.
  static String _commentSafe(String raw) =>
      raw.replaceAll('\r', ' ').replaceAll('\n', ' ').replaceAll('\t', ' ');

  /// Write the test file at [testPath] that imports the subject at
  /// [subjectPath] and asserts the behavior's observable behavior.
  ///
  /// [golden] (bug #830, widget kind only) appends a `matchesGoldenFile`
  /// baseline hook whose PNG is committed per platform under
  /// `test/tdd/goldens/` and refreshed with
  /// `flutter test --update-goldens <file>`.
  Future<void> write({
    required Behavior behavior,
    required String testPath,
    required String subjectPath,
    bool golden = false,
  }) async {
    final testFile = File(testPath);
    await testFile.parent.create(recursive: true);
    final relativeSubjectPath = _relativeSubjectPath(testPath, subjectPath);
    final content = behavior.kind == BehaviorKind.ffi
        ? renderContractTest(behavior, testPath, subjectPath)
        : behavior.persistence
        ? _renderPersistenceTest(
            behavior,
            relativeSubjectPath,
            // Issue #912 defect 1: the behavior description reached the
            // persistence template RAW (the parameter was named
            // `escapedDescription` but carried the unescaped text), so a
            // description like "persist the user's theme preference"
            // produced an unterminated string literal.
            escapeDartString('${behavior.id} (${behavior.sourceCriterion})'),
            escapeDartString(behavior.description),
          )
        : behavior.kind == BehaviorKind.widget
        ? _renderWidgetTest(behavior, relativeSubjectPath, golden)
        : _renderTest(behavior, relativeSubjectPath);
    await testFile.writeAsString(content);
  }

  String _renderTest(Behavior b, String relativeSubjectPath) {
    final description = _commentSafe(b.description);
    final escapedDescription = escapeDartString(b.description);
    final escapedGroupDescription = escapeDartString(
      '${b.id} (${b.sourceCriterion})',
    );
    final assertion = _deriveAssertion(b);
    return '''
// GENERATED TEST — `zfa tdd gen ${b.id}` (spec 044-test-tdd-generation).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// kind: ${b.kind.name}
// description: $description
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `$relativeSubjectPath` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import '$relativeSubjectPath' as subject;

void main() {
  group('$escapedGroupDescription', () {
    test('${b.id} \u2014 $escapedDescription', () {
      $assertion
    });
  });
}
''';
  }

  /// Derive the test's assertion from the behavior description. The
  /// assertion must NOT be a placeholder `expect(true, isFalse)` — it must
  /// assert the observable behavior (FR-010).
  ///
  /// Heuristic: if the description contains a number (`returns 42`),
  /// assert `subject.<target>() == <number>`. Otherwise, assert that the
  /// paired stub is no longer unimplemented. In both cases an
  /// `UnimplementedError` is captured as the assertion's actual value, so
  /// the generated test is deliberately red without leaking the error.
  String _deriveAssertion(Behavior b) {
    final target = b.target.isEmpty ? 'subjectUnderTest' : b.target;
    final description = b.description;
    // Look for "returns N" or "= N".
    // On first run, capture the stub's UnimplementedError as the actual
    // result so the value comparison produces an assertion failure.
    final returnsMatch = RegExp(
      r'returns?\s+(\d+)',
      caseSensitive: false,
    ).firstMatch(description);
    if (returnsMatch != null) {
      final expected = returnsMatch.group(1);
      return '${_captureInvocation(b, target)}\n'
          '      expect(result, equals($expected));';
    }
    // Look for "throws <ExceptionName>" — only known Dart built-in types
    // to avoid generating unimported exception types from prose.
    const knownExceptions = {
      'FormatException',
      'StateError',
      'ArgumentError',
      'RangeError',
      'TypeError',
      'UnsupportedError',
      'NoSuchMethodError',
      'Exception',
      'Error',
    };
    final throwsMatch = RegExp(
      r'throws?\s+(\w+)',
      caseSensitive: false,
    ).firstMatch(description);
    if (throwsMatch != null) {
      final exc = throwsMatch.group(1)!;
      if (knownExceptions.contains(exc)) {
        if (exc == 'Error') {
          return 'expect(() => subject.$target(), '
              'throwsA(allOf(isA<Error>(), '
              'isNot(isA<UnimplementedError>()))));';
        }
        return 'expect(() => subject.$target(), throwsA(isA<$exc>()));';
      }
      // Unknown exception types and UnimplementedError fall through to the
      // generic assertion to avoid either an unimported type or a green stub.
    }
    return '${_captureInvocation(b, target)}\n'
        '      expect(result, isNot(isA<UnimplementedError>()));';
  }

  String _captureInvocation(Behavior behavior, String target) {
    // Issue #1035: the UNIT lane's capture initializer is provably
    // non-nullable (the closure returns the subject's value or the
    // caught UnimplementedError — never null), so an explicit `Object?`
    // annotation trips unnecessary_nullable_for_final_variable_declarations
    // in the generated test. Inference types the capture correctly for
    // both the red stub (static return type) and the implemented subject;
    // the acceptance lane's capture CAN be null (`return null;`), so it
    // keeps the explicit nullable annotation its initializer matches.
    final capture = behavior.kind == BehaviorKind.acceptance
        ? 'final Object? result'
        : 'final result';
    final invocation = behavior.kind == BehaviorKind.acceptance
        ? 'subject.$target();\n          return null;'
        : 'return subject.$target();';
    return '''$capture = (() {
        try {
          $invocation
        } on UnimplementedError catch (error) {
          return error;
        }
      })();''';
  }

  /// Compute the import URI the generated test uses to reach the paired
  /// subject file.
  ///
  /// Issue #1035: the emitted artifacts must be lint-clean, and a
  /// relative import that reaches into the project's `lib/` from `test/`
  /// provably trips `avoid_relative_lib_imports`. When the subject lives
  /// under the project's `lib/` and the package name is resolvable from
  /// the enclosing `pubspec.yaml`, the import is a `package:` URI
  /// (`package:<name>/<path-under-lib>`). Otherwise (non-absolute fixture
  /// paths, no pubspec), the legacy relative path is kept so the pair
  /// still resolves — and so is portable.
  String _relativeSubjectPath(String testPath, String subjectPath) {
    if (p.isAbsolute(subjectPath) && p.isAbsolute(testPath)) {
      final packageImport = _packageSubjectImport(testPath, subjectPath);
      if (packageImport != null) return packageImport;
      // Compute the relative path from testPath's parent to subjectPath.
      final rel = p.relative(subjectPath, from: p.dirname(testPath));
      // Ensure it has a `./` or `../` prefix OR is just a relative path.
      return rel;
    }
    // Otherwise, just return the subject path as-is.
    return subjectPath;
  }

  /// The `package:` import URI for [subjectPath] when it sits under the
  /// enclosing project's `lib/` and the package name is resolvable from
  /// the nearest `pubspec.yaml` (walked up from the test file's
  /// directory); null otherwise (caller falls back to the relative shape).
  String? _packageSubjectImport(String testPath, String subjectPath) {
    var dir = p.dirname(testPath);
    String? projectRoot;
    for (var i = 0; i < 24; i++) {
      final candidate = p.join(dir, 'pubspec.yaml');
      if (File(candidate).existsSync()) {
        projectRoot = dir;
        break;
      }
      final parent = p.dirname(dir);
      if (parent == dir) break;
      dir = parent;
    }
    if (projectRoot == null) return null;
    final String pubspec;
    try {
      pubspec = File(p.join(projectRoot, 'pubspec.yaml')).readAsStringSync();
    } catch (_) {
      return null;
    }
    final nameMatch = RegExp(
      r'^name:\s*(.+?)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    final packageName = nameMatch?.group(1)?.trim() ?? '';
    if (packageName.isEmpty) return null;
    final libDir = p.join(projectRoot, 'lib');
    if (!p.isWithin(libDir, subjectPath)) return null;
    final underLib = p.relative(subjectPath, from: libDir);
    return 'package:$packageName/$underLib';
  }

  /// Render the WIDGET test (bug #830): a `testWidgets` pair that boots
  /// the feature view through the subject's view-builder contract, pumps
  /// it inside a configurable app shell (issue #912 defect 2 — ShadApp
  /// by default, MaterialApp for plain-Material projects), and asserts
  /// the acceptance scenario through finders DERIVED from the scenario
  /// description (issue #912 defect 3 — a bare `findsOneWidget`
  /// placeholder is greenable by a SizedBox and marks the test
  /// scaffolded).
  ///
  /// Red surfaces (issue #959): the inert stub (`SizedBox.shrink()`,
  /// see SubjectWriter's widget branch) lets the guard pass and the pump
  /// run, so the
  /// AUTHORED FINDER assertions fail at red time — red is certified on
  /// the assertions, never born green. The UnimplementedError capture
  /// BEFORE the pump stays as the SECONDARY guard: a subject that still
  /// throws fails through the guard assertion instead of an exception
  /// escaping pump (which the red classifier routes to runner-error, not
  /// honest red, per issue #830's widget failure taxonomy).
  String _renderWidgetTest(
    Behavior b,
    String relativeSubjectPath,
    bool golden,
  ) {
    final description = _commentSafe(b.description);
    final escapedDescription = escapeDartString(b.description);
    final escapedGroupDescription = escapeDartString(
      '${b.id} (${b.sourceCriterion})',
    );
    final target = b.target.isEmpty ? 'subjectUnderTest' : b.target;
    final snakeId = _toSnakeCase(b.id);
    // Issue #912 defect 2: the shell is configurable; the shadcn shell
    // needs its own import (material.dart stays for Scaffold + Theme).
    final shellName = widgetShell.widgetName;
    final shellImport = widgetShell == WidgetAppShell.shadapp
        ? "import 'package:shadcn_ui/shadcn_ui.dart';\n"
        : '';
    // Issue #964 (finder-kind taxonomy): the scenario verb decides the
    // assertion class — presence stays find.text, navigation becomes a
    // route-outcome assertion on a recording NavigatorObserver, absence
    // becomes findsNothing, enabled-state asserts onPressed null-ness,
    // and a sequence scenario (while … in flight) is marked scaffolded
    // instead of silently flattened to presence.
    final analysis = FinderTaxonomy.analyze(b.description);
    final finders = FinderTaxonomy.emitTestAssertions(
      analysis,
      escape: escapeDartString,
    );
    final assertionsHeader = FinderTaxonomy.headerLine(analysis);
    final routeObserver = analysis.needsRouteObserver;
    // Issue #912 defect 3 (as refined by issue #964): a test with NO
    // derivable finder is a scaffolded placeholder; a SEQUENCE scenario
    // is scaffolded too (a single pump cannot honestly assert the
    // act → intermediate → final machine), even when it carries
    // derivable sub-assertions.
    final String scenarioBlock;
    if (analysis.sequence) {
      final sequenceComment =
          '// $scaffoldedMarker — SEQUENCE scenario '
          '(issue #964): the scenario describes an in-flight state\n'
          '      // machine (act → intermediate → final). A single-pump '
          'template cannot assert\n'
          '      // the sequence honestly, so this test is SCAFFOLDED, not '
          'certified: implement\n'
          '      // the sequence here (act → pump the intermediate state → '
          'assert → settle →\n'
          '      // assert the final state) and remove this marker before '
          'certifying green.';
      scenarioBlock = finders.isEmpty
          ? sequenceComment
          : '$sequenceComment\n      ${finders.join('\n      ')}';
    } else if (finders.isEmpty) {
      scenarioBlock =
          '$widgetScaffoldComment\n      expect(find.byWidget(view), findsOneWidget);';
    } else if (routeObserver) {
      // Route-outcome scenarios carry NO trailing mounted-view smoke
      // assertion: once the scenario's route is pushed, the home route
      // goes offstage and `find.byWidget(view)` would honestly fail —
      // the pushedNames assertion IS the scenario.
      scenarioBlock = finders.join('\n      ');
    } else {
      scenarioBlock =
          "${finders.join('\n      ')}\n      expect(find.byWidget(view), findsOneWidget);";
    }
    final observerDecl = routeObserver
        ? '      // Route-outcome recording (issue #964): the scenario asserts\n'
              '      // navigation, so pushed ROUTES are observed — never the\n'
              '      // route name rendered as on-screen text.\n'
              '      final observer = _RouteRecorder();\n'
        : '';
    final pumpCall = routeObserver
        ? 'await tester.pumpWidget($shellName(\n'
              '        navigatorObservers: <NavigatorObserver>[observer],\n'
              '        home: Scaffold(body: view),\n'
              '      ));'
        : 'await tester.pumpWidget($shellName(home: Scaffold(body: view)));';
    // Issue #964 (code review on #981): a route-outcome scenario's
    // golden hook can NEVER pass — after the route pushes, the home
    // route goes offstage and find.byWidget(view) resolves to nothing
    // (the same mechanism that killed the smoke assertion). Skip the
    // hook for route scenarios; goldens stay available for the other
    // assertion classes.
    final goldenBlock = golden && !routeObserver
        ? '''
      // Golden baseline (bug #830): commit one PNG per platform under
      // test/tdd/goldens/ (VISION §6 institutional memory). Refresh with:
      //   flutter test --update-goldens test/tdd/${snakeId}_test.dart
      await expectLater(
        find.byWidget(view),
        matchesGoldenFile('goldens/$snakeId.png'),
      );
'''
        : golden && routeObserver
        ? '''
      // No golden hook (issue #964): a route-outcome scenario's view is
      // offstage once the asserted route is pushed, so a
      // matchesGoldenFile on the home view can never settle. Remove
      // --golden or drop the navigation assertion to use goldens here.
'''
        : '';
    final recorderClass = routeObserver
        ? '''

/// Records pushed route names so route-outcome assertions (issue #964)
/// observe real navigation — the scenario's green measures the ROUTE
/// outcome, not the route name rendered as display text.
class _RouteRecorder extends NavigatorObserver {
  final List<String?> pushedNames = <String?>[];

  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) {
    pushedNames.add(route.settings.name);
  }
}
'''
        : '';
    return '''
// GENERATED TEST — `zfa tdd gen ${b.id}` (spec 044-test-tdd-generation).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// kind: widget
${assertionsHeader.isEmpty ? '' : '$assertionsHeader\n'}// description: $description
//
// This is a WIDGET test (bug #830): it boots the feature view through
// the subject's view-builder contract, pumps it inside a $shellName
// shell, and asserts the acceptance scenario through verb-matched
// assertions (issue #964 finder-kind taxonomy: shows/renders → presence,
// navigates → route outcome via the recorded pushed routes, hides/not
// shown → absence, disables/enables → enabled state; a while/in-flight
// sequence scenario is marked scaffolded). RED SURFACE (issue #959): the
// stub is inert (SizedBox.shrink), so the guard passes, the pump runs,
// and these verb-matched authored finders fail against the empty view —
// red is certified on the assertions, never at the guard. The
// UnimplementedError capture below is the SECONDARY guard: if a subject
// still throws, the error lands in the guard assertion instead of
// escaping the pump (classified runner/compile, not red — issue #830
// widget failure taxonomy). Widget tests run on the flutter profile's
// slower tier; golden baselines are committed per platform under
// test/tdd/goldens/.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
${shellImport}import '$relativeSubjectPath' as subject;

void main() {
  group('$escapedGroupDescription', () {
    testWidgets('${b.id} \u2014 $escapedDescription', (tester) async {
      // Honest-red capture + secondary guard (issue #959): call the
      // view-builder OUTSIDE pumpWidget so a subject that still throws
      // UnimplementedError lands in the expect below (an assertion
      // failure) instead of escaping the pump as a runner error (issue
      // #830 widget failure taxonomy). With the inert stub this passes
      // and the authored finders below are the primary red surface.
$observerDecl      final Object? built = (() {
        try {
          return subject.$target();
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(built, isNot(isA<UnimplementedError>()));
      final view = built! as Widget;
      // Boot the view inside an app shell so Theme.of / ShadTheme.of /
      // Navigator / MediaQuery lookups resolve (issue #830 remediation 2;
      // shell configurable per issue #912 defect 2).
      $pumpCall
      await tester.pumpAndSettle();
      // PRIMARY red surface (issue #959 + issue #964 taxonomy):
      // verb-matched authored finders derived from the scenario
      // description (issue #912 defect 3) execute after the pump and
      // fail against the inert stub's empty view — red is certified on
      // these assertions, never a placeholder a bare SizedBox() would
      // satisfy, never a route outcome flattened into presence-of-text.
      $scenarioBlock
$goldenBlock    });
  });
}$recorderClass''';
  }

  /// The same snake-case convention `zfa tdd gen` uses for artifact
  /// paths (mirrored locally so the writer stays dependency-free).

  String renderContractTest(Behavior b, String testPath, String subjectPath) {
    final relativeSubjectPath = _relativeSubjectPath(testPath, subjectPath);
    final escapedDescription = escapeDartString(b.description);
    final escapedGroupDescription = escapeDartString(
      '${b.id} (${b.sourceCriterion})',
    );
    return '''
// GENERATED TEST — `zfa tdd gen ${b.id}` (spec 044-test-tdd-generation).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// kind: ffi
// description: ${b.description}
//
// BINDING CONTRACT lane (bug #835). This test asserts the native-binding
// CONTRACT — required symbols resolve, marshalling round-trips — through
// the harness at
// `$relativeSubjectPath`,
// wired to the SAME binding production uses. It runs in the default test
// tier on the host runner. With the binding unwired it is honestly red
// (assertion-level, never skipped). The golden-fixture assertion lives in
// the marked integration lane next to this file (*_golden_test.dart),
// gated by `dart test --preset=integration` in CI.
library;

import 'package:test/test.dart';
import '$relativeSubjectPath' as subject;

void main() {
  group('$escapedGroupDescription', () {
    test('${b.id} \u2014 $escapedDescription', () {
      // (1) The declared contract: every required symbol resolves on the
      // wired production binding.
      expect(subject.kRequiredSymbols, isNotEmpty,
          reason: 'declare the symbols the production binding must export '
              'in kRequiredSymbols');
      for (final symbol in subject.kRequiredSymbols) {
        final Object? resolved =
            _captured(() => subject.symbolResolved(symbol));
        expect(resolved, isTrue,
            reason: 'symbol "\$symbol" must resolve on '
                '\${subject.kNativeLibrary} (wire the production binding '
                'in the subject harness)');
      }
      // (2) Marshalling: a payload round-trips through the binding
      // to native memory and back unchanged.
      const payload = '${b.id.toLowerCase()}-ffi-round-trip-payload';
      final Object? roundTripped = _captured(() => subject.roundTrip(payload));
      expect(roundTripped, equals(payload),
          reason: 'the binding must marshal the payload to native memory '
              'and back unchanged (wire roundTrip in the subject harness)');
    });
  });
}

/// Captures an [UnimplementedError] thrown by an unwired harness seam as
/// the assertion's actual value, so the unwired state fails through an
/// assertion (honest red) instead of an uncaught error.
Object? _captured(Object? Function() invoke) {
  try {
    return invoke();
  } on UnimplementedError catch (error) {
    return error;
  }
}
''';
  }

  /// The persistence-kind test shape (bug #833).
  String _renderPersistenceTest(
    Behavior b,
    String relativeSubjectPath,
    String escapedGroupDescription,
    String escapedDescription,
  ) {
    final assertion = _deriveAssertion(b);
    final boxName = 'tdd_${_toSnakeCase(b.id)}';
    return '''
// GENERATED TEST for ${b.id} (bug #833 persistence test harness).
//
// Persistence-kind behavior -- the persistence harness is wired in:
//   1. a fresh temp-directory Hive box set is bootstrapped PER TEST and
//      torn down PER TEST (never shared across tests);
//   2. TTL assertions use the injected test clock (advanceTime) -- no
//      real sleeps in the suite;
//   3. corruption drills: harness.seedCorruptedBox('${escapeDartString(boxName)}') +
//      harness.openWithRecovery('${escapeDartString(boxName)}') drive the clear + re-fetch
//      recovery path against a pre-corrupted fixture;
//   4. registrar gate: pass registerAdapters + expectedTypeIds to
//      the harness below so init-time registration failures surface as
//      RegistrarGateError -- a deterministic red at init, not a runtime
//      read crash.
library;

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';
import '$relativeSubjectPath' as subject;

void main() {
  group('$escapedGroupDescription', () {
    final harness = PersistenceTestHarness(boxNames: ['${escapeDartString(boxName)}']);
    final clock = TestClock();

    setUp(() async {
      await harness.bootstrap();
    });

    tearDown(() async {
      await harness.teardown();
    });

    test('${b.id} - $escapedDescription', () {
      clock.advanceTime(const Duration(minutes: 1));
      $assertion
    });
  });
}
''';
  }

  static String _toSnakeCase(String s) {
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
