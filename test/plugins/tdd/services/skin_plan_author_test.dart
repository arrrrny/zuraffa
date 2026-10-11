// Issue #1405 — the skin plan author's format contract: strict `^W\d+$`
// emission plus the plan-time id validator.
//
// RED phase: `SkinPlanAuthor` does not exist yet — this file fails to
// compile against the unfixed tree (recorded red evidence), and every row
// below pins one acceptance/unit behavior of
// specs/1405-skin-plan-author-ids/tdd/test-list.md.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/skin_plan_author.dart';

void main() {
  group('U-1405-1 — strict tokens pass through (FR-001)', () {
    test('W2 → (W2, empty prose)', () {
      final r = SkinPlanAuthor.sanitizeDeclaredSkinToken('W2');
      expect(r, isNotNull);
      expect(r!.id, 'W2');
      expect(r.prose, isEmpty);
    });

    test('W12 → (W12, empty prose)', () {
      final r = SkinPlanAuthor.sanitizeDeclaredSkinToken('W12');
      expect(r, isNotNull);
      expect(r!.id, 'W12');
      expect(r.prose, isEmpty);
    });

    test('surrounding whitespace is trimmed on the strict path', () {
      final r = SkinPlanAuthor.sanitizeDeclaredSkinToken('  W7  ');
      expect(r, isNotNull);
      expect(r!.id, 'W7');
      expect(r.prose, isEmpty);
    });
  });

  group('U-1405-2 — leading-id rescue moves prose to the behavior column '
      '(FR-002)', () {
    test('unmatched paren: the issue\'s truncated token', () {
      final r = SkinPlanAuthor.sanitizeDeclaredSkinToken(
        'W1 (renders the login screen pixel-perfect',
      );
      expect(r, isNotNull);
      expect(r!.id, 'W1');
      expect(r.prose, 'renders the login screen pixel-perfect');
    });

    test('bare prose after the id', () {
      final r = SkinPlanAuthor.sanitizeDeclaredSkinToken(
        'W1 renders the login screen',
      );
      expect(r, isNotNull);
      expect(r!.id, 'W1');
      expect(r.prose, 'renders the login screen');
    });

    test('closed paren prose unwraps into the behavior column', () {
      final r = SkinPlanAuthor.sanitizeDeclaredSkinToken(
        'W3 (binds each button)',
      );
      expect(r, isNotNull);
      expect(r!.id, 'W3');
      expect(r.prose, 'binds each button');
    });

    test('balanced interior parens are preserved verbatim', () {
      final r = SkinPlanAuthor.sanitizeDeclaredSkinToken('W5 (a) and (b)');
      expect(r, isNotNull);
      expect(r!.id, 'W5');
      expect(r.prose, '(a) and (b)');
    });
  });

  group('U-1405-3 — no guesses out of mid-sentence prose (FR-002, FR-003)', () {
    test('prose-only fragment → null', () {
      expect(
        SkinPlanAuthor.sanitizeDeclaredSkinToken('Sign In header and subtitle'),
        isNull,
      );
    });

    test('another prose-only fragment → null', () {
      expect(
        SkinPlanAuthor.sanitizeDeclaredSkinToken('a full-width guest outline'),
        isNull,
      );
    });

    test('mid-token W mention → null', () {
      expect(SkinPlanAuthor.sanitizeDeclaredSkinToken('the W1 button'), isNull);
    });

    test('empty token → null', () {
      expect(SkinPlanAuthor.sanitizeDeclaredSkinToken(''), isNull);
      expect(SkinPlanAuthor.sanitizeDeclaredSkinToken('   '), isNull);
    });
  });

  group('U-1405-4 — malformedIdReason diagnoses the AC classes (FR-003)', () {
    test('null for a strict id', () {
      expect(SkinPlanAuthor.malformedIdReason('W2'), isNull);
      expect(SkinPlanAuthor.malformedIdReason('W10'), isNull);
    });

    test('spaces (prose leaked into the id column)', () {
      expect(
        SkinPlanAuthor.malformedIdReason('W1 renders'),
        contains('spaces'),
      );
    });

    test('unmatched paren (truncated mid-sentence)', () {
      final reason = SkinPlanAuthor.malformedIdReason('W1 (renders');
      expect(reason, isNotNull);
      expect(reason, contains('unmatched paren'));
    });

    test('no W-digits pattern', () {
      final reason = SkinPlanAuthor.malformedIdReason(
        'Sign In header and subtitle',
      );
      expect(reason, isNotNull);
      expect(reason, contains('W<digits>'));
    });

    test('precedence: a missing pattern outranks spaces', () {
      // 'Sign In header' has spaces AND no pattern — the pattern
      // diagnosis is named first (it is the fundamental one: the token
      // is not a W-behavior at all).
      final reason = SkinPlanAuthor.malformedIdReason('Sign In header');
      expect(reason, contains('W<digits>'));
    });

    test('precedence: an unmatched paren outranks spaces', () {
      // 'W1 (renders' carries a space too, but the issue's own language
      // for that row is a truncated mid-sentence id — the paren
      // diagnosis is the precise one.
      final reason = SkinPlanAuthor.malformedIdReason('W1 (renders');
      expect(reason, contains('unmatched paren'));
    });

    test('trailing orphan paren', () {
      final reason = SkinPlanAuthor.malformedIdReason('W1)');
      expect(reason, contains('unmatched paren'));
    });
  });

  group('U-1405-5 — validateSkinPlanWIds refusal lines (FR-003)', () {
    test('clean id list → no refusals', () {
      expect(
        SkinPlanAuthor.validateSkinPlanWIds([
          'W1',
          'W2',
          'W3',
          'W4',
          'W5',
          'W6',
          'W7',
          'W8',
          'W9',
        ]),
        isEmpty,
      );
    });

    test('one refusal per malformed id, naming the token and the fix', () {
      final refusals = SkinPlanAuthor.validateSkinPlanWIds([
        'Sign In header and subtitle',
        'a full-width guest outline button',
        'an or divider',
      ]);
      expect(refusals, hasLength(3));
      expect(refusals.first, contains('Sign In header and subtitle'));
      expect(refusals.first, contains('--> fix:'));
      expect(refusals[1], contains('a full-width guest outline button'));
      expect(refusals[2], contains('an or divider'));
    });
  });
}
