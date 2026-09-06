import 'dart:io';

import 'package:test/test.dart';

import 'run_zfa_source.dart';

/// Bug #1187 — `ZFA_TEST_TIMEOUT_SCALE` env multiplier for slow machines.
///
/// The 2019 Intel Mac baseline reported in issue #1187: the feature_flags
/// suite failed 9+ tests purely on timeouts because the helper's budgets
/// (75s child guard, 100s AOT compile) are hard-coded and the cold
/// frontend-server compile cost on that hardware eats both. The scale lets
/// an operator stretch every budget proportionally without touching test
/// semantics.
///
/// These are fast-tier, subprocess-free unit tests of the scale mechanism
/// itself: parsing/clamping, the process-wide scale read from the
/// environment, and the derived budgets. The same file doubles as the
/// end-to-end env plumbing proof — run it once with the variable unset
/// (scale 1.0) and once with `ZFA_TEST_TIMEOUT_SCALE=4` (scale 4.0); both
/// runs must be green because every expectation is computed from the
/// environment the test process actually started with.
void main() {
  final envRaw = Platform.environment['ZFA_TEST_TIMEOUT_SCALE'];
  final processScale = parseTimeoutScale(envRaw);

  group('parseTimeoutScale', () {
    test('missing variable parses to the 1.0 identity scale', () {
      expect(parseTimeoutScale(null), 1.0);
    });

    test('blank values parse to the 1.0 identity scale', () {
      expect(parseTimeoutScale(''), 1.0);
      expect(parseTimeoutScale('   '), 1.0);
    });

    test('integer and decimal strings parse to their numeric value', () {
      expect(parseTimeoutScale('3'), 3.0);
      expect(parseTimeoutScale('2.5'), 2.5);
      expect(parseTimeoutScale(' 1.5 '), 1.5, reason: 'trims whitespace');
    });

    test('values below 1.0 clamp up to 1.0 (never tighten budgets)', () {
      expect(parseTimeoutScale('0.5'), 1.0);
      expect(parseTimeoutScale('0'), 1.0);
      expect(parseTimeoutScale('-2'), 1.0);
    });

    test('invalid values fall back to the 1.0 identity scale', () {
      expect(parseTimeoutScale('abc'), 1.0);
      expect(parseTimeoutScale('2x'), 1.0);
      expect(parseTimeoutScale('NaN'), 1.0, reason: 'NaN would poison budgets');
      expect(
        parseTimeoutScale('Infinity'),
        1.0,
        reason: 'infinite budgets would hang the suite',
      );
    });
  });

  group('process-wide scale', () {
    test('matches the environment the test process started with', () {
      expect(
        zfaTestTimeoutScale,
        parseTimeoutScale(envRaw),
        reason:
            'the top-level scale must be read once from '
            'ZFA_TEST_TIMEOUT_SCALE at isolate start',
      );
    });
  });

  group('scaled budgets', () {
    test('default child timeout is 75s stretched by the process scale', () {
      final expected = Duration(
        milliseconds: (75 * 1000 * processScale).round(),
      );
      expect(zfaDefaultChildTimeout, expected);
      expect(
        zfaDefaultChildTimeout,
        greaterThanOrEqualTo(const Duration(seconds: 75)),
        reason: 'scale can only relax, never tighten, the validated budget',
      );
    });

    test('AOT compile budget is 100s stretched by the process scale', () {
      final expected = Duration(
        milliseconds: (100 * 1000 * processScale).round(),
      );
      expect(zfaCompileTimeout, expected);
      expect(
        zfaCompileTimeout,
        greaterThanOrEqualTo(const Duration(seconds: 100)),
      );
    });

    test('scaleDuration stretches an arbitrary base proportionally', () {
      expect(
        scaleDuration(const Duration(minutes: 3)),
        Duration(milliseconds: (3 * 60 * 1000 * processScale).round()),
      );
    });
  });
}
