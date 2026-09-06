// Issue #1112 — the typed TapResult: the verdict vocabulary of the
// debugTapAnchor seam (found | disabled | notFound | error(String)),
// with the canonical JSON contract the `zfa skin drive` CLI prints —
// {"result":"found","tapped":true} — identical on every host OS.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/skin/anchors.dart';
import 'package:zuraffa/src/skin/tap_result.dart';

void main() {
  group('issue #1112 — TapResult JSON contract (sub-agent friendly)', () {
    test('found prints {"result":"found","tapped":true}', () {
      const result = TapFound();
      expect(result.toJson(), {'result': 'found', 'tapped': true});
      expect(jsonDecode(result.toJsonString()), {
        'result': 'found',
        'tapped': true,
      });
    });

    test('disabled prints {"result":"disabled","tapped":false}', () {
      const result = TapDisabled();
      expect(result.toJson(), {'result': 'disabled', 'tapped': false});
    });

    test('notFound prints {"result":"notFound","tapped":false}', () {
      const result = TapNotFound();
      expect(result.toJson(), {'result': 'notFound', 'tapped': false});
    });

    test('error carries the message: {"result":"error",...,"message"}', () {
      const result = TapError('cannot connect to ws://127.0.0.1:1/ws');
      final json = result.toJson();
      expect(json['result'], 'error');
      expect(json['tapped'], false);
      expect(json['message'], 'cannot connect to ws://127.0.0.1:1/ws');
    });

    test('the labels are the issue vocabulary', () {
      expect(const TapFound().label, 'found');
      expect(const TapDisabled().label, 'disabled');
      expect(const TapNotFound().label, 'notFound');
      expect(const TapError('x').label, 'error');
    });

    test('fromJson restores every variant (round trip)', () {
      expect(
        TapResult.fromJson({'result': 'found', 'tapped': true}),
        const TapFound(),
      );
      expect(
        TapResult.fromJson({'result': 'disabled', 'tapped': false}),
        const TapDisabled(),
      );
      expect(
        TapResult.fromJson({'result': 'notFound', 'tapped': false}),
        const TapNotFound(),
      );
      expect(
        TapResult.fromJson({
          'result': 'error',
          'tapped': false,
          'message': 'boom',
        }),
        const TapError('boom'),
      );
    });

    test('fromJson on an unknown shape refuses honestly (error)', () {
      final result = TapResult.fromJson({'result': 'wat'});
      expect(result, isA<TapError>());
      expect((result as TapError).message, contains('wat'));
    });

    test('equality is structural (driver tests can assert verdicts)', () {
      expect(const TapFound(), const TapFound());
      expect(const TapFound(), isNot(const TapDisabled()));
      expect(const TapError('a'), const TapError('a'));
      expect(const TapError('a'), isNot(const TapError('b')));
    });
  });

  group('issue #1112 — anchor vocabulary backs the seam', () {
    test('the CLI and the kit agree on normalization', () {
      // The driver normalizes 'zfa:signin-guest' and 'signin-guest' to
      // the same handle before evaluate (pilot lesson 6).
      expect(ZfaAnchors.normalize('zfa:signin-guest'), 'signin-guest');
      expect(ZfaAnchors.keyFor('signin-guest'), 'zfa:signin-guest');
    });
  });
}
