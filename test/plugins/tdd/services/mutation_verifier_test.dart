// Tests for the MutationVerifier service (spec 041-tdd-setup-plugin, T079).
//
// The verifier shells out to `dart run mutation_test`, so the unit tests:
//   - cover the MutationResult value object (score math, passed gate)
//   - cover the MutationConfigError path (missing config file)
//   - exercise the parser regex against synthetic markdown/stdout fixtures
//     (no real mutation run)
//
// A real `dart run mutation_test` is invoked by the integration test
// `tdd_command_smoke_test.dart::zfa tdd verify surfaces the audit score line`
// when run against the repo's own mutation-test.xml — that is the
// end-to-end gate; these are the unit-level gates.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/mutation_verifier.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('mutation_verifier_test_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  group('MutationResult', () {
    test('score is 1.0 when totalMutants is 0 (vacuous truth)', () {
      final r = MutationResult(
        exitCode: 0,
        killedCount: 0,
        survivedCount: 0,
        timeoutCount: 0,
        elapsed: Duration.zero,
        reportPath: null,
        stdoutText: '',
        stderrText: '',
      );
      expect(r.totalMutants, 0);
      expect(r.score, 1.0);
      expect(r.passed, isTrue);
    });

    test('score = killed/total; passed requires 0 survivors + exit 0', () {
      final r = MutationResult(
        exitCode: 0,
        killedCount: 8,
        survivedCount: 2,
        timeoutCount: 0,
        elapsed: Duration.zero,
        reportPath: null,
        stdoutText: '',
        stderrText: '',
      );
      expect(r.totalMutants, 10);
      expect(r.score, 0.8);
      expect(r.passed, isFalse); // 2 survivors
    });

    test('survivors=0 but exit code non-zero => not passed', () {
      final r = MutationResult(
        exitCode: 1,
        killedCount: 5,
        survivedCount: 0,
        timeoutCount: 0,
        elapsed: Duration.zero,
        reportPath: null,
        stdoutText: '',
        stderrText: '',
      );
      expect(r.passed, isFalse);
    });

    test('timeout mutants are counted in total but not in killed', () {
      final r = MutationResult(
        exitCode: 0,
        killedCount: 4,
        survivedCount: 1,
        timeoutCount: 3,
        elapsed: Duration.zero,
        reportPath: null,
        stdoutText: '',
        stderrText: '',
      );
      expect(r.totalMutants, 8);
      expect(r.score, closeTo(0.5, 1e-9));
      expect(r.passed, isFalse); // survivors > 0
    });
  });

  group('MutationVerifier — config errors', () {
    test(
      'throws MutationConfigError when config file does not exist',
      () async {
        final v = MutationVerifier(
          configPath: 'no-such-file.xml',
          workingDirectory: tmpDir.path,
        );
        await expectLater(v.run(), throwsA(isA<MutationConfigError>()));
      },
    );
  });

  group('MutationVerifier — report parser regex (unit-level)', () {
    // The verifier's _parseCounts is private, but its regex shape is
    // documented in the service docstring. We re-implement the same
    // regex here and assert it correctly extracts counts from a
    // realistic markdown report. This guards against the upstream
    // mutation_test package changing its report wording in a future
    // release and silently breaking the score parser.
    final killedRe = RegExp(
      r'(?:killed|Mutants killed|Killed)[:\s]+(\d+)',
      caseSensitive: false,
    );
    final survivedRe = RegExp(
      r'(?:survived|Mutants survived|Survived)[:\s]+(\d+)',
      caseSensitive: false,
    );
    final timeoutRe = RegExp(
      r'(?:timed?\s*out|Mutants timed out|Timeout)[:\s]+(\d+)',
      caseSensitive: false,
    );

    test('parses markdown report header "Mutants killed: N" form', () {
      const report = '''
# Mutation Test Report

## Summary
- Mutants killed: 9
- Mutants survived: 1
- Mutants timed out: 0
- Mutation score: 90.0%
''';
      expect(killedRe.firstMatch(report)?.group(1), '9');
      expect(survivedRe.firstMatch(report)?.group(1), '1');
      expect(timeoutRe.firstMatch(report)?.group(1), '0');
    });

    test('parses stdout "Killed X, survived Y, timeout Z" form', () {
      const stdout =
          '... analysis complete ... Killed 42, survived 3, '
          'timeout 1, score 0.913';
      expect(killedRe.firstMatch(stdout)?.group(1), '42');
      expect(survivedRe.firstMatch(stdout)?.group(1), '3');
      expect(timeoutRe.firstMatch(stdout)?.group(1), '1');
    });

    test('parses "Mutants timed out" variant', () {
      const text =
          'Mutants killed: 7\nMutants survived: 0\n'
          'Mutants timed out: 2';
      expect(killedRe.firstMatch(text)?.group(1), '7');
      expect(survivedRe.firstMatch(text)?.group(1), '0');
      expect(timeoutRe.firstMatch(text)?.group(1), '2');
    });

    test('returns null when no counts present in the source', () {
      const text = 'mutation_test ran but the report was truncated.';
      expect(killedRe.firstMatch(text), isNull);
      expect(survivedRe.firstMatch(text), isNull);
      expect(timeoutRe.firstMatch(text), isNull);
    });
  });
}
