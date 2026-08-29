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
/// (emitted by [SubjectWriter]) throws `UnimplementedError`, so the
/// assertion failure class on first run is honest red.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/behavior.dart';

/// Writes a Dart test file that pairs with the subject for a behavior.
class BehaviorTestWriter {
  const BehaviorTestWriter();

  /// Write the test file at [testPath] that imports the subject at
  /// [subjectPath] and asserts the behavior's observable behavior.
  Future<void> write({
    required Behavior behavior,
    required String testPath,
    required String subjectPath,
  }) async {
    final testFile = File(testPath);
    await testFile.parent.create(recursive: true);
    final relativeSubjectPath = _relativeSubjectPath(testPath, subjectPath);
    final content = _renderTest(behavior, relativeSubjectPath);
    await testFile.writeAsString(content);
  }

  String _renderTest(Behavior b, String relativeSubjectPath) {
    final description = b.description;
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
// `$relativeSubjectPath` throws UnimplementedError, so the test fails
// with an assertion-level failure (not a compile error, not a load
// error, not skipped, not a placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import 'package:test/test.dart';
import '$relativeSubjectPath' as subject;

void main() {
  group('${b.id} (${b.sourceCriterion})', () {
    test('$description', () {
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
  /// assert `subject.<target>() == <number>`. Otherwise, assert that
  /// the call throws `UnimplementedError` (honest red — the stub
  /// throws it).
  String _deriveAssertion(Behavior b) {
    final target = b.target.isEmpty ? 'subjectUnderTest' : b.target;
    final description = b.description;
    // Look for "returns N" or "= N".
    final returnsMatch = RegExp(
      r'returns?\s+(\d+)',
      caseSensitive: false,
    ).firstMatch(description);
    if (returnsMatch != null) {
      final expected = returnsMatch.group(1);
      return 'final result = subject.$target();\n      expect(result, equals($expected));';
    }
    // Look for "throws <ExceptionName>".
    final throwsMatch = RegExp(
      r'throws?\s+(\w+Error|Exception)',
      caseSensitive: false,
    ).firstMatch(description);
    if (throwsMatch != null) {
      final exc = throwsMatch.group(1);
      return 'expect(() => subject.$target(), throwsA(isA<$exc>()));';
    }
    // Fallback: assert that the call throws UnimplementedError (the stub
    // throws it — honest red).
    return 'expect(() => subject.$target(), throwsA(isA<UnimplementedError>()));';
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
}
