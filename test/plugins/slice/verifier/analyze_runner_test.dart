/// Tests for AnalyzeRunner (U48, U49, U50).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   U48: An analyzer-clean sandbox yields a pass result
///   U49: Analyzer errors are captured and returned as a structured failure
///        listing the errors
///   U50: A missing dart/flutter toolchain yields a clear environment
///        error, not a crash
///
/// The repo test environment is pure Dart; the runner executes through an
/// injected process seam (fake launcher) so tests stay deterministic.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/verifier/analyze_runner.dart';

void main() {
  group('AnalyzeRunner (FR-014)', () {
    test('U48: an analyzer-clean sandbox passes', () async {
      final calls = <List<String>>[];
      final runner = AnalyzeRunner(
        launcher: (executable, args, {workingDirectory}) async {
          calls.add([executable, ...args]);
          return ProcessResult(
            1,
            0,
            'Analyzing sandbox...\nNo issues found!',
            '',
          );
        },
      );

      final result = await runner.analyze('/tmp/some_sandbox');

      expect(result.passed, isTrue);
      expect(result.errors, isEmpty);
      expect(result.toolchainMissing, isFalse);
      expect(calls.single.first, equals('dart'));
      expect(calls.single, contains('analyze'));
      expect(calls.single, contains('/tmp/some_sandbox'));
    });

    test('U49: analyzer errors are captured as a structured failure',
        () async {
      final runner = AnalyzeRunner(
        launcher: (executable, args, {workingDirectory}) async {
          return ProcessResult(
            1,
            2,
            'Analyzing sandbox...\n'
                '  error - lib/foo.dart:3:7 - Undefined name \'Bar\'. - '
                'undefined_identifier\n'
                '  error - lib/bar.dart:9:1 - Expected \';\'. - '
                'expected_token\n'
                '2 issues found.',
            '',
          );
        },
      );

      final result = await runner.analyze('/tmp/some_sandbox');

      expect(result.passed, isFalse);
      expect(result.toolchainMissing, isFalse);
      expect(result.errors, hasLength(2));
      expect(result.errors.first, contains('lib/foo.dart'));
      expect(result.errors.first, contains('Undefined name'));
      expect(result.errors[1], contains('lib/bar.dart'));
    });

    test('U50: a missing toolchain yields a clear environment error',
        () async {
      final runner = AnalyzeRunner(
        launcher: (executable, args, {workingDirectory}) async {
          throw ProcessException(executable, args, 'No such file or '
              'directory');
        },
      );

      final result = await runner.analyze('/tmp/some_sandbox');

      expect(result.passed, isFalse);
      expect(result.toolchainMissing, isTrue);
      expect(result.message, isNotNull);
      expect(result.message, contains('dart'));
      expect(result.message, contains('PATH'));
    });

    test('a flutter project runs flutter analyze', () async {
      final calls = <String>[];
      final runner = AnalyzeRunner(
        launcher: (executable, args, {workingDirectory}) async {
          calls.add(executable);
          return ProcessResult(1, 0, 'No issues found!', '');
        },
      );

      await runner.analyze('/tmp/some_sandbox', flutter: true);

      expect(calls.single, equals('flutter'));
    });
  });
}
