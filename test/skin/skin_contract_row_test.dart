// Issue #1102 — SkinContractRow: one row of the runtime skin contract,
// evaluated against TreeFacts every audited frame.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/skin/skin_contract_row.dart';
import 'package:zuraffa/src/skin/tree_facts.dart';

void main() {
  group('issue #1102 — SkinContractRow', () {
    test('id + requirement + check: a passing row evaluates true', () {
      final row = SkinContractRow(
        id: 'heading',
        requirement: 'the Sign in heading renders',
        check: (facts) => facts.texts.contains('Sign in'),
      );
      expect(row.evaluate(TreeFacts(texts: const ['Sign in'])), isTrue);
    });

    test('the pilot chaos edit fails a textRenders row on the spot', () {
      // Chaos edit 'Continue with Google' -> 'Continue with Goggle'
      // must be caught on the FIRST audited frame.
      final row = SkinContractRow.textRenders(
        id: 'google-text',
        text: 'Continue with Google',
      );
      expect(
        row.evaluate(TreeFacts(texts: const ['Continue with Goggle'])),
        isFalse,
      );
      expect(
        row.evaluate(TreeFacts(texts: const ['Continue with Google'])),
        isTrue,
      );
    });

    test('textRenders exposes the requirement for the banner', () {
      final row = SkinContractRow.textRenders(
        id: 'google-text',
        text: 'Continue with Google',
      );
      expect(row.id, 'google-text');
      expect(row.requirement, contains('Continue with Google'));
    });

    test('anchorExists checks the typed zfa: anchor protocol', () {
      final row = SkinContractRow.anchorExists(
        id: 'guest-anchor',
        anchor: 'signin-guest',
      );
      expect(
        row.evaluate(TreeFacts(anchors: const {'zfa:signin-guest'})),
        isTrue,
      );
      expect(
        row.evaluate(TreeFacts(anchors: const {'zfa:signin-google'})),
        isFalse,
      );
    });

    test('progressIndicator checks the loading-scrim contract (lesson 1)', () {
      // The pilot caught the real bug: macOS layout had NO loading scrim.
      // A row must be able to require a progress indicator.
      final row = SkinContractRow.progressIndicator(id: 'loading-scrim');
      expect(row.evaluate(TreeFacts(hasProgressIndicator: true)), isTrue);
      expect(row.evaluate(TreeFacts(hasProgressIndicator: false)), isFalse);
    });

    group('platform gating (lesson 8 — same source the layout gates on)', () {
      test('a row gated to macos passes only on macos facts', () {
        final row = SkinContractRow.textRenders(
          id: 'macos-scrim',
          text: 'Loading…',
          platform: SkinTargetPlatform.macos,
        );
        expect(
          row.evaluate(
            TreeFacts(
              texts: const ['Loading…'],
              platform: SkinTargetPlatform.macos,
            ),
          ),
          isTrue,
        );
        expect(
          row.evaluate(
            TreeFacts(
              texts: const ['Loading…'],
              platform: SkinTargetPlatform.ios,
            ),
          ),
          isFalse,
        );
      });

      test('a gated row skips (passes) when facts carry no platform', () {
        // Unknown platform = do not flag — the auditor must not
        // hallucinate a platform the Theme did not report.
        final row = SkinContractRow.textRenders(
          id: 'macos-scrim',
          text: 'Loading…',
          platform: SkinTargetPlatform.macos,
        );
        expect(row.evaluate(TreeFacts(texts: const ['Loading…'])), isTrue);
      });
    });
  });
}
