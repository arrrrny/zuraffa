// Spec 035 — Track 4.4: XRayDiff + diff-stream tests.
//
// Behaviors B19, B20, B21.
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:zuraffa/src/mcp/xray_bridge/xray_diff.dart';

void main() {
  group('XRayDiff', () {
    test('B19 — add factory round-trips', () {
      final d = XRayDiff.add(nodeId: 'n1', node: {'id': 'n1'});
      expect(d.type, XRayDiffType.add);
      expect(d.nodeId, 'n1');
      expect(d.node, isNotNull);
      final j = d.toJson();
      expect(j['type'], 'add');
      expect(j['nodeId'], 'n1');
      expect(j['node'], isNotNull);
      final r = XRayDiff.fromJson(j);
      expect(r.type, XRayDiffType.add);
      expect(r.nodeId, 'n1');
    });

    test('B19 — remove factory round-trips', () {
      final d = XRayDiff.remove(nodeId: 'n1');
      expect(d.type, XRayDiffType.remove);
      expect(d.nodeId, 'n1');
      expect(d.node, isNull);
      expect(d.before, isNull);
      expect(d.after, isNull);
      final j = d.toJson();
      expect(j['type'], 'remove');
      expect(j['nodeId'], 'n1');
      final r = XRayDiff.fromJson(j);
      expect(r.type, XRayDiffType.remove);
    });

    test('B19 — update factory round-trips', () {
      final d = XRayDiff.update(
        nodeId: 'n1',
        before: {'state': 'idle'},
        after: {'state': 'loading'},
      );
      expect(d.type, XRayDiffType.update);
      expect(d.before?['state'], 'idle');
      expect(d.after?['state'], 'loading');
      final j = d.toJson();
      expect(j['type'], 'update');
      expect(j['before']['state'], 'idle');
      expect(j['after']['state'], 'loading');
      final r = XRayDiff.fromJson(j);
      expect(r.type, XRayDiffType.update);
    });

    test('XRayDiffType has add/remove/update values', () {
      expect(XRayDiffType.values, contains(XRayDiffType.add));
      expect(XRayDiffType.values, contains(XRayDiffType.remove));
      expect(XRayDiffType.values, contains(XRayDiffType.update));
    });
  });

  group('XRayBridgeDiffStream', () {
    test('B20 — emitAdd pushes an add diff to subscribers', () async {
      final s = XRayBridgeDiffStream(isReleaseMode: false);
      final completer = Completer<XRayDiff>();
      final sub = s.stream.listen(completer.complete);
      s.emitAdd(nodeId: 'n1', node: {'id': 'n1'});
      final d = await completer.future.timeout(const Duration(seconds: 1));
      expect(d.type, XRayDiffType.add);
      expect(d.nodeId, 'n1');
      await sub.cancel();
    });

    test('B20 — emitRemove pushes a remove diff', () async {
      final s = XRayBridgeDiffStream(isReleaseMode: false);
      final completer = Completer<XRayDiff>();
      final sub = s.stream.listen(completer.complete);
      s.emitRemove(nodeId: 'n1');
      final d = await completer.future.timeout(const Duration(seconds: 1));
      expect(d.type, XRayDiffType.remove);
      expect(d.nodeId, 'n1');
      await sub.cancel();
    });

    test('B20 — emitUpdate pushes an update diff', () async {
      final s = XRayBridgeDiffStream(isReleaseMode: false);
      final completer = Completer<XRayDiff>();
      final sub = s.stream.listen(completer.complete);
      s.emitUpdate(
        nodeId: 'n1',
        before: {'state': 'idle'},
        after: {'state': 'loading'},
      );
      final d = await completer.future.timeout(const Duration(seconds: 1));
      expect(d.type, XRayDiffType.update);
      await sub.cancel();
    });

    test('B20 — multiple subscribers all receive the diff (broadcast)', () async {
      final s = XRayBridgeDiffStream(isReleaseMode: false);
      var received1 = false;
      var received2 = false;
      final sub1 = s.stream.listen((_) => received1 = true);
      final sub2 = s.stream.listen((_) => received2 = true);
      s.emitAdd(nodeId: 'n1', node: {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(received1, isTrue);
      expect(received2, isTrue);
      await sub1.cancel();
      await sub2.cancel();
    });

    test('B21 — release-mode stream is empty', () async {
      final s = XRayBridgeDiffStream(isReleaseMode: true);
      var received = false;
      final sub = s.stream.listen((_) => received = true);
      s.emitAdd(nodeId: 'n1', node: {});
      s.emitRemove(nodeId: 'n1');
      s.emitUpdate(nodeId: 'n1', before: {}, after: {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(received, isFalse,
          reason: 'release builds MUST NOT emit diffs');
      await sub.cancel();
    });
  });
}
