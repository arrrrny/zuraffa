// Issue #1102 — typed anchor protocol: zfa: key mapping, the anchor
// registry, and the debugTapAnchor core (pilot lesson 6 + 7).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/skin/anchors.dart';

void main() {
  group('issue #1102 — ZfaAnchors (typed anchor protocol)', () {
    test('keyFor maps a contractId to its zfa: ValueKey string', () {
      expect(ZfaAnchors.keyFor('signin-guest'), 'zfa:signin-guest');
    });

    test('isAnchorKey recognizes the zfa: prefix', () {
      expect(ZfaAnchors.isAnchorKey('zfa:signin-guest'), isTrue);
      expect(ZfaAnchors.isAnchorKey('login-slot-mobile'), isFalse);
      expect(ZfaAnchors.isAnchorKey(''), isFalse);
    });

    test('contractIdOf strips the prefix (round trip)', () {
      expect(ZfaAnchors.contractIdOf('zfa:signin-guest'), 'signin-guest');
      expect(ZfaAnchors.contractIdOf('signin-guest'), 'signin-guest');
    });

    test('normalize accepts both the bare id and the zfa: key', () {
      expect(ZfaAnchors.normalize('zfa:signin-guest'), 'signin-guest');
      expect(ZfaAnchors.normalize('signin-guest'), 'signin-guest');
    });
  });

  group('issue #1102 — ZfaAnchorRegistry (debugTapAnchor core)', () {
    test('register + tap invokes the real onPressed (lesson 7)', () {
      final registry = ZfaAnchorRegistry();
      var tapped = 0;
      registry.register('signin-guest', () => tapped++);
      expect(registry.tap('signin-guest'), isTrue);
      expect(tapped, 1);
    });

    test('tap resolves a zfa:-prefixed key too (debugTapAnchor(zfaKey))', () {
      final registry = ZfaAnchorRegistry();
      var tapped = 0;
      registry.register('signin-guest', () => tapped++);
      // The VM-service seam is documented as debugTapAnchor('zfa:signin-guest').
      expect(registry.tap('zfa:signin-guest'), isTrue);
      expect(tapped, 1);
    });

    test('tapping an unknown anchor refuses honestly', () {
      final registry = ZfaAnchorRegistry();
      expect(registry.tap('nope'), isFalse);
    });

    test('unregister removes the handler', () {
      final registry = ZfaAnchorRegistry();
      var tapped = 0;
      registry
        ..register('signin-guest', () => tapped++)
        ..unregister('signin-guest');
      expect(registry.tap('signin-guest'), isFalse);
      expect(tapped, 0);
    });

    test('registered lists the anchor ids (driver diagnostics)', () {
      final registry = ZfaAnchorRegistry();
      registry
        ..register('b-anchor', () {})
        ..register('a-anchor', () {});
      expect(registry.registered, ['a-anchor', 'b-anchor']);
    });

    test('clear drops every handler (test-lane teardown)', () {
      final registry = ZfaAnchorRegistry();
      var tapped = 0;
      registry
        ..register('a', () => tapped++)
        ..clear();
      expect(registry.tap('a'), isFalse);
      expect(registry.registered, isEmpty);
    });

    test('re-registering replaces the handler (idempotent registration)', () {
      final registry = ZfaAnchorRegistry();
      var first = 0;
      var second = 0;
      registry
        ..register('a', () => first++)
        ..register('a', () => second++)
        ..tap('a');
      expect(first, 0);
      expect(second, 1);
    });
  });
}
