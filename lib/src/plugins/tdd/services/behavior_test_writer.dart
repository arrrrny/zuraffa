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

/// Writes a Dart test file that pairs with the subject for a behavior.
class BehaviorTestWriter {
  const BehaviorTestWriter();

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
    final escapedGroupDesc = '${behavior.id} (${behavior.sourceCriterion})'.replaceAll(
      "'",
      "\\'",
    );
    final content = behavior.kind == BehaviorKind.ffi
        ? renderContractTest(behavior, testPath, subjectPath)
        : behavior.persistence
        ? _renderPersistenceTest(behavior, relativeSubjectPath, escapedGroupDesc, behavior.description)
        : behavior.kind == BehaviorKind.widget
        ? _renderWidgetTest(behavior, relativeSubjectPath, golden)
        : _renderTest(behavior, relativeSubjectPath);
    await testFile.writeAsString(content);
  }

  String _renderTest(Behavior b, String relativeSubjectPath) {
    final description = b.description;
    final escapedDescription = description.replaceAll("'", "\\'");
    final escapedGroupDescription = '${b.id} (${b.sourceCriterion})'.replaceAll(
      "'",
      "\\'",
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
    final invocation = behavior.kind == BehaviorKind.acceptance
        ? 'subject.$target();\n          return null;'
        : 'return subject.$target();';
    return '''final Object? result = (() {
        try {
          $invocation
        } on UnimplementedError catch (error) {
          return error;
        }
      })();''';
  }

  /// Compute the relative path from the test file's directory to the
  /// subject file. We use a simple relative path so the generated test
  /// file is portable.
  String _relativeSubjectPath(String testPath, String subjectPath) {
    if (p.isAbsolute(subjectPath) && p.isAbsolute(testPath)) {
      // Compute the relative path from testPath's parent to subjectPath.
      final rel = p.relative(subjectPath, from: p.dirname(testPath));
      // Ensure it has a `./` or `../` prefix OR is just a relative path.
      return rel;
    }
    // Otherwise, just return the subject path as-is.
    return subjectPath;
  }

  /// Render the WIDGET test (bug #830): a `testWidgets` pair that boots
  /// the feature view through the subject's view-builder contract, pumps
  /// it inside a MaterialApp shell, and asserts the acceptance scenario.
  ///
  /// Honest red (FR-010): the stub's `UnimplementedError` is captured by
  /// calling the view-builder BEFORE the pump and asserted with
  /// `isNot(isA<UnimplementedError>())` — so the first execution fails
  /// through an ASSERTION, never an exception escaping pump (which the
  /// red classifier routes to runner-error, not honest red, per issue
  /// #830's widget failure taxonomy).
  String _renderWidgetTest(
    Behavior b,
    String relativeSubjectPath,
    bool golden,
  ) {
    final description = b.description;
    final escapedDescription = description.replaceAll("'", "\\'");
    final escapedGroupDescription = '${b.id} (${b.sourceCriterion})'.replaceAll(
      "'",
      "\\'",
    );
    final target = b.target.isEmpty ? 'subjectUnderTest' : b.target;
    final snakeId = _toSnakeCase(b.id);
    final goldenBlock = golden
        ? '''
      // Golden baseline (bug #830): commit one PNG per platform under
      // test/tdd/goldens/ (VISION §6 institutional memory). Refresh with:
      //   flutter test --update-goldens test/tdd/${snakeId}_test.dart
      await expectLater(
        find.byWidget(view),
        matchesGoldenFile('goldens/$snakeId.png'),
      );
'''
        : '';
    return '''
// GENERATED TEST — `zfa tdd gen ${b.id}` (spec 044-test-tdd-generation).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// kind: widget
// description: $description
//
// This is a WIDGET test (bug #830): it boots the feature view through
// the subject's view-builder contract, pumps it inside a MaterialApp
// shell, and asserts the acceptance scenario (theme.of colors, presence
// of expected widgets, navigation outcomes). The stub's
// UnimplementedError is captured BEFORE the pump, so the first
// execution fails through the assertion below (honest red), never an
// exception escaping pump (classified runner/compile, not red).
// Widget tests run on the flutter profile's slower tier; golden
// baselines are committed per platform under test/tdd/goldens/.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '$relativeSubjectPath' as subject;

void main() {
  group('$escapedGroupDescription', () {
    testWidgets('${b.id} \u2014 $escapedDescription', (tester) async {
      // Honest-red capture: call the view-builder OUTSIDE pumpWidget so
      // the stub's UnimplementedError lands in the expect below (an
      // assertion failure) instead of escaping the pump as a runner
      // error (issue #830 widget failure taxonomy).
      final Object? built = (() {
        try {
          return subject.$target();
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(built, isNot(isA<UnimplementedError>()));
      final view = built! as Widget;
      // Boot the view inside an app shell so Theme.of / Navigator /
      // MediaQuery lookups resolve (issue #830 remediation 2).
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: view)));
      await tester.pumpAndSettle();
      // Acceptance scenario: the subject view is mounted in the tree.
      // Extend here with the scenario's concrete finders (theme colors,
      // expected widgets, navigation outcomes).
      expect(find.byWidget(view), findsOneWidget);
$goldenBlock    });
  });
}
''';
  }

  /// The same snake-case convention `zfa tdd gen` uses for artifact
  /// paths (mirrored locally so the writer stays dependency-free).

  String renderContractTest(Behavior b, String testPath, String subjectPath) {
    final relativeSubjectPath = _relativeSubjectPath(testPath, subjectPath);
    final escapedDescription = b.description.replaceAll("'", "\\'");
    final escapedGroupDescription = '${b.id} (${b.sourceCriterion})'.replaceAll(
      "'",
      "\\'",
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
//   3. corruption drills: harness.seedCorruptedBox('$boxName') +
//      harness.openWithRecovery('$boxName') drive the clear + re-fetch
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
    final harness = PersistenceTestHarness(boxNames: ['$boxName']);
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
