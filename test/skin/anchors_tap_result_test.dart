// Issue #1112 — the registry answers with RICH verdicts now: the
// driver harness must distinguish found (tapped) from disabled (present
// but inert) from notFound (absent) — never a silent no-op.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/skin/anchors.dart';

void main() {
  group('issue #1112 — ZfaAnchorRegistry.tapResult (rich verdicts)', () {
    test('T2.1 a registered enabled anchor taps: found + handler invoked', () {
      final registry = ZfaAnchorRegistry();
      var tapped = 0;
      registry.register('signin-guest', () => tapped++, enabled: true);
      final result = registry.tapResult('zfa:signin-guest');
      expect(result, TapResult.found);
      expect(result.tapped, isTrue);
      expect(tapped, 1);
    });

    test(
      'T2.2 a registered disabled anchor refuses: disabled, NOT invoked',
      () {
        final registry = ZfaAnchorRegistry();
        var tapped = 0;
        registry.register('signin-log-out', () => tapped++, enabled: false);
        final result = registry.tapResult('signin-log-out');
        expect(result, TapResult.disabled);
        expect(result.tapped, isFalse);
        expect(tapped, 0);
      },
    );

    test('T2.3 an unknown anchor is notFound', () {
      final registry = ZfaAnchorRegistry();
      expect(registry.tapResult('nope'), TapResult.notFound);
    });

    test('T2.4 the legacy 2-arg register stays enabled by default', () {
      final registry = ZfaAnchorRegistry();
      var tapped = 0;
      registry.register('signin-guest', () => tapped++);
      expect(registry.tapResult('signin-guest'), TapResult.found);
      expect(tapped, 1);
    });

    test('T2.5 tap() agrees with tapResult() (bool projection)', () {
      final registry = ZfaAnchorRegistry();
      var tapped = 0;
      registry
        ..register('a', () => tapped++)
        ..register('b', () => tapped++, enabled: false);
      expect(registry.tap('a'), isTrue);
      expect(tapped, 1);
      expect(registry.tap('b'), isFalse);
      expect(tapped, 1);
      expect(registry.tap('missing'), isFalse);
    });

    test('T2.6 re-registering with a new enabled state replaces cleanly', () {
      final registry = ZfaAnchorRegistry();
      var tapped = 0;
      registry
        ..register('signin-guest', () => tapped++, enabled: false)
        ..register('signin-guest', () => tapped++, enabled: true);
      expect(registry.tapResult('signin-guest'), TapResult.found);
      expect(tapped, 1);
    });

    test('T2.7 isAnchorKey needs BOTH length and the zfa: prefix', () {
      // Length alone must not satisfy the predicate (kills the &&->||
      // mutant and the negated-startsWith mutant).
      expect(ZfaAnchors.isAnchorKey('signinguest'), isFalse);
      expect(ZfaAnchors.isAnchorKey('zfa:'), isFalse);
      expect(
        ZfaAnchors.isAnchorKey('zfa:'),
        isFalse,
        reason: 'the bare prefix is not an anchor',
      );
      // Prefix without length still does not qualify alone.
      expect(ZfaAnchors.isAnchorKey('zfa:g'), isTrue);
    });

    test('T2.8 unregister removes the handler (the unmount half)', () {
      final registry = ZfaAnchorRegistry();
      var tapped = 0;
      registry
        ..register('signin-guest', () => tapped++, enabled: true)
        ..unregister('zfa:signin-guest');
      expect(registry.tapResult('signin-guest'), TapResult.notFound);
      expect(tapped, 0);
    });
  });
}
