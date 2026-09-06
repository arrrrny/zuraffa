// Issue #1112 — TapResult: the driver verdict contract. The JSON shape
// {"result":"found","tapped":true} is THE cross-surface contract: the
// live-app driver (zfa skin drive), the widget-test bridge
// (zfaAnchorTapped), and the simulator (zfa skin sim) all print it.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/skin/anchors.dart';

void main() {
  group('issue #1112 — TapResult (the driver verdict contract)', () {
    test('T1.1 found carries the success-criteria JSON shape', () {
      final json = TapResult.found.toJson();
      expect(json['result'], 'found');
      expect(json['tapped'], isTrue);
      expect(json.containsKey('message'), isFalse);
    });

    test('T1.2 disabled and notFound are honest non-taps', () {
      expect(TapResult.disabled.toJson(), {
        'result': 'disabled',
        'tapped': false,
      });
      expect(TapResult.notFound.toJson(), {
        'result': 'notFound',
        'tapped': false,
      });
    });

    test('T1.3 error carries the message', () {
      final json = TapResult.error('no theme ancestor').toJson();
      expect(json['result'], 'error');
      expect(json['tapped'], isFalse);
      expect(json['message'], 'no theme ancestor');
    });

    test('T1.4 fromJson round-trips every verdict', () {
      for (final result in [
        TapResult.found,
        TapResult.disabled,
        TapResult.notFound,
        TapResult.error('boom'),
      ]) {
        expect(TapResult.fromJson(result.toJson()), result);
      }
    });

    test('T1.5 equality is verdict+message identity', () {
      expect(TapResult.found, TapResult.found);
      expect(TapResult.error('a'), TapResult.error('a'));
      expect(TapResult.error('a'), isNot(TapResult.error('b')));
      expect(TapResult.found, isNot(TapResult.disabled));
      expect(TapResult.found.hashCode, TapResult.found.hashCode);
    });
  });
}
