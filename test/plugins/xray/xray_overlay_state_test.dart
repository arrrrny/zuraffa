// Spec 036 — Track 4.2: X-Ray Visual Overlay with Bounding Boxes.
// TDD tests for the pure-Dart XRayOverlayState (registry + subscription
// + release-mode strip).
//
// Behaviors covered (see specs/036-xray-visual-overlay/tdd/test-list.md):
//   B01 activate sets isActive true
//   B02 deactivate sets isActive false
//   B03 activate is no-op when isReleaseMode true
//   B04 register adds node to snapshot
//   B05 unregister removes node by id
//   B06 changes stream emits new snapshot after register/unregister
//   B14 inspect returns panel for registered node, null for unknown
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/xray/xray_node.dart';
import 'package:zuraffa/src/plugins/xray/xray_overlay_state.dart';
import 'package:zuraffa/src/plugins/xray/xray_state_summary.dart';
import 'package:zuraffa/src/plugins/xray/xray_bounding_box.dart';

void main() {
  group('XRayOverlayState', () {
    late XRayOverlayState state;

    setUp(() {
      state = XRayOverlayState(isReleaseMode: false);
    });

    test('B01 — activate sets isActive true (non-release)', () {
      expect(state.isActive, isFalse);
      state.activate();
      expect(state.isActive, isTrue);
    });

    test('B02 — deactivate sets isActive false', () {
      state.activate();
      expect(state.isActive, isTrue);
      state.deactivate();
      expect(state.isActive, isFalse);
    });

    test('B03 — activate is no-op when isReleaseMode true', () {
      final release = XRayOverlayState(isReleaseMode: true);
      expect(release.isActive, isFalse);
      release.activate();
      expect(
        release.isActive,
        isFalse,
        reason: 'release builds MUST NOT activate the overlay',
      );
    });

    test('B03b — register is no-op when isReleaseMode true', () {
      final release = XRayOverlayState(isReleaseMode: true);
      release.register(_sampleNode('n1'));
      expect(release.nodes, isEmpty);
    });

    test('B03c — unregister is no-op when isReleaseMode true', () {
      final release = XRayOverlayState(isReleaseMode: true);
      release.unregister('n1'); // must not throw
    });

    test('B04 — register adds node to snapshot', () {
      final node = _sampleNode('n1');
      state.register(node);
      expect(state.nodes.length, 1);
      expect(state.nodes.first.id, 'n1');
    });

    test('B05 — unregister removes node by id', () {
      state.register(_sampleNode('n1'));
      state.register(_sampleNode('n2'));
      state.unregister('n1');
      expect(state.nodes.length, 1);
      expect(state.nodes.first.id, 'n2');
    });

    test('B06 — changes stream emits new snapshot after register', () async {
      final completer = Completer<List<XRayBoundingBox>>();
      final sub = state.changes.listen(completer.complete);
      // ignore: unawaited_futures
      state.register(_sampleNode('n1'));
      final snapshot = await completer.future.timeout(
        const Duration(seconds: 1),
      );
      expect(snapshot.length, 1);
      expect(snapshot.first.nodeId, 'n1');
      await sub.cancel();
    });

    test('B06b — changes stream emits empty list after unregister', () async {
      state.register(_sampleNode('n1'));
      final completer = Completer<List<XRayBoundingBox>>();
      final sub = state.changes.listen(completer.complete);
      state.unregister('n1');
      final snapshot = await completer.future.timeout(
        const Duration(seconds: 1),
      );
      expect(snapshot, isEmpty);
      await sub.cancel();
    });

    test('B06c — changes stream does not emit when release-mode', () async {
      final release = XRayOverlayState(isReleaseMode: true);
      var emitted = false;
      final sub = release.changes.listen((_) => emitted = true);
      release.register(_sampleNode('n1'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emitted, isFalse, reason: 'release builds MUST NOT emit changes');
      await sub.cancel();
    });

    test('B14 — inspect returns XRayDetailPanel for registered node, '
        'null for unknown', () {
      state.register(_sampleNode('n1'));
      final panel = state.inspect('n1');
      expect(panel, isNotNull);
      expect(panel!.nodeId, 'n1');
      expect(panel.fullStateJson, isNotEmpty);

      final unknown = state.inspect('does-not-exist');
      expect(unknown, isNull);
    });

    test('B14b — inspect returns null in release mode', () {
      final release = XRayOverlayState(isReleaseMode: true);
      release.register(_sampleNode('n1')); // no-op
      expect(release.inspect('n1'), isNull);
    });
  });
}

XRayNode _sampleNode(String id) {
  return XRayNode(
    id: id,
    viewType: 'ProfileView',
    enabled: true,
    boundAction: 'onEditTapped',
    stateSummary: const XRayStateSummary(
      hasData: true,
      hasError: false,
      isLoading: false,
      dataPreview: 'Product(id=42)',
    ),
  );
}
