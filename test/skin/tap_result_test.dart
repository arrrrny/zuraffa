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

    test('T1.6 an unknown verdict decodes into an honest error', () {
      final result = TapResult.fromJson({'result': 'mystery', 'tapped': true});
      expect(result, isA<TapError>());
      expect(result.name, 'error');
      expect(result.tapped, isFalse);
      expect((result as TapError).message, contains('mystery'));
    });

    test('T1.7 the verdict names are the cross-surface vocabulary', () {
      expect(TapResult.found.name, 'found');
      expect(TapResult.disabled.name, 'disabled');
      expect(TapResult.notFound.name, 'notFound');
      expect(TapResult.error('x').name, 'error');
      // Only error carries a message; the others omit the key entirely.
      expect(TapResult.error('x').toJson()['message'], 'x');
      expect(TapResult.notFound.toJson().containsKey('message'), isFalse);
    });

    test('T1.8 toString names the verdict (diagnostics)', () {
      expect(TapResult.found.toString(), 'TapResult.found');
      expect(
        TapResult.error('boom').toString(),
        'TapResult.error(boom)',
      );
    });
  });
}
