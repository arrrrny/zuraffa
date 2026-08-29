// Spec 035 — Track 4.4: XRay Bridge release-mode strip regression.
// Issue #184 — SC-004: Zero X-Ray endpoints reachable in release.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/core/xray_config.dart';
import 'package:zuraffa/src/mcp/xray_bridge/xray_bridge_handlers.dart';
import 'package:zuraffa/src/mcp/xray_bridge/xray_diff.dart';

void main() {
  group('SC-004 — X-Ray Bridge release-mode strip (issue #184)', () {
    test('kXrayReleaseMode is compile-time constant (false in tests)', () {
      expect(kXrayReleaseMode, isFalse);
    });

    test('B14 — release-mode handleTreeGet returns 404', () {
      final h = XRayBridgeHandlers(
        overlayState: _FakeOverlay(),
        controlDeck: _FakeDeck(),
        isReleaseMode: true,
      );
      final r = h.handleTreeGet();
      expect(r.statusCode, 404);
      expect(r.body['error'], contains('release'));
    });

    test('B15 — release-mode handleActionPost returns 404', () {
      final h = XRayBridgeHandlers(
        overlayState: _FakeOverlay(),
        controlDeck: _FakeDeck(),
        isReleaseMode: true,
      );
      final r = h.handleActionPost({'targetNode': 'n1'});
      expect(r.statusCode, 404);
    });

    test('B16 — release-mode handleControlDeckPost returns 404', () {
      final h = XRayBridgeHandlers(
        overlayState: _FakeOverlay(),
        controlDeck: _FakeDeck(),
        isReleaseMode: true,
      );
      final r = h.handleControlDeckPost({'mockName': 'A'});
      expect(r.statusCode, 404);
    });

    test('B21 — release-mode diff stream is empty + emit* no-op', () async {
      final s = XRayBridgeDiffStream(isReleaseMode: true);
      var received = false;
      final sub = s.stream.listen((_) => received = true);
      s.emitAdd(nodeId: 'n1', node: {});
      s.emitRemove(nodeId: 'n1');
      s.emitUpdate(nodeId: 'n1', before: {}, after: {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(received, isFalse);
      await sub.cancel();
    });
  });
}

class _FakeOverlay {
  Map<String, dynamic> toJson() => {'activeView': null, 'nodes': <Map>[]};
}
class _FakeDeck {
  List<String> get mockNames => const [];
  String? inject(String name) => null;
}
