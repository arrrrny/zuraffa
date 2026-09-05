// Issue #1102 — TreeFacts: the immutable snapshot of the live widget
// tree the runtime skin-contract auditor audits against.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/skin/tree_facts.dart';

void main() {
  group('issue #1102 — TreeFacts', () {
    test('empty facts have no texts, no anchors, no progress, no platform', () {
      final facts = TreeFacts.empty();
      expect(facts.texts, isEmpty);
      expect(facts.anchors, isEmpty);
      expect(facts.hasProgressIndicator, isFalse);
      expect(facts.platform, isNull);
    });

    test('carries rendered texts in insertion order', () {
      final facts = TreeFacts(
        texts: const ['Continue with Google', 'Sign in'],
        anchors: const {},
      );
      expect(facts.texts, ['Continue with Google', 'Sign in']);
    });

    test('carries zfa: anchors and the progress-indicator flag', () {
      final facts = TreeFacts(
        texts: const [],
        anchors: const {'zfa:signin-guest', 'zfa:signin-google'},
        hasProgressIndicator: true,
      );
      expect(
        facts.anchors,
        containsAll(['zfa:signin-guest', 'zfa:signin-google']),
      );
      expect(facts.hasProgressIndicator, isTrue);
    });

    test('platform is the override-aware gating source (lesson 8)', () {
      final facts = TreeFacts(
        texts: const [],
        anchors: const {},
        platform: SkinTargetPlatform.macos,
      );
      // The pilot proved the auditor and the skin must agree about
      // platform: both read Theme.of(context).platform, captured here.
      expect(facts.platform, SkinTargetPlatform.macos);
      expect(facts.platform!.label, 'macos');
    });

    test('SkinTargetPlatform labels are stable machine names', () {
      expect(SkinTargetPlatform.mobile.label, 'mobile');
      expect(SkinTargetPlatform.ios.label, 'ios');
      expect(SkinTargetPlatform.android.label, 'android');
      expect(SkinTargetPlatform.macos.label, 'macos');
      expect(SkinTargetPlatform.other.label, 'other');
    });

    test(
      'value equality: identical snapshots are equal (no-op audit skip)',
      () {
        final a = TreeFacts(
          texts: const ['Sign in'],
          anchors: const {'zfa:signin-guest'},
          hasProgressIndicator: false,
          platform: SkinTargetPlatform.ios,
        );
        final b = TreeFacts(
          texts: const ['Sign in'],
          anchors: const {'zfa:signin-guest'},
          hasProgressIndicator: false,
          platform: SkinTargetPlatform.ios,
        );
        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      },
    );

    test('value equality: differing texts break equality', () {
      final a = TreeFacts(texts: const ['Continue with Google']);
      final b = TreeFacts(texts: const ['Continue with Goggle']);
      // The pilot's chaos edit — one text changed — must be a NEW fact
      // set, so the scheduler can re-run the audit and the banner can
      // appear on the first audited frame.
      expect(a, isNot(equals(b)));
    });

    test('value equality: a new anchor breaks equality', () {
      final a = TreeFacts(anchors: const {'zfa:signin-guest'});
      final b = TreeFacts(anchors: const {'zfa:signin-guest', 'zfa:x'});
      expect(a, isNot(equals(b)));
    });

    test('texts list is defensively copied (immutability)', () {
      final mutable = <String>['Sign in'];
      final facts = TreeFacts(texts: mutable);
      mutable.add('Chaos edit');
      expect(facts.texts, ['Sign in']);
    });

    test('anchors set is defensively copied (immutability)', () {
      final mutable = <String>{'zfa:signin-guest'};
      final facts = TreeFacts(anchors: mutable);
      mutable.add('zfa:chaos');
      expect(facts.anchors, {'zfa:signin-guest'});
    });

    test('toJson round-trips the audit-relevant fields', () {
      final facts = TreeFacts(
        texts: const ['Sign in'],
        anchors: const {'zfa:signin-guest'},
        hasProgressIndicator: true,
        platform: SkinTargetPlatform.android,
      );
      final json = facts.toJson();
      expect(json['texts'], ['Sign in']);
      expect(json['anchors'], ['zfa:signin-guest']);
      expect(json['hasProgressIndicator'], isTrue);
      expect(json['platform'], 'android');
    });
  });
}
