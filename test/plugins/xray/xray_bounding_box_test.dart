// Spec 036 — Track 4.2: XRayBoundingBox value-type tests.
//
// Behavior B12: immutable + toJson + fromNode factory.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/xray/xray_bounding_box.dart';
import 'package:zuraffa/src/plugins/xray/xray_node.dart';
import 'package:zuraffa/src/plugins/xray/xray_state_summary.dart';

void main() {
  group('XRayRect', () {
    test('stores left/top/width/height', () {
      const r = XRayRect(left: 10, top: 20, width: 100, height: 50);
      expect(r.left, 10);
      expect(r.top, 20);
      expect(r.width, 100);
      expect(r.height, 50);
    });

    test('toJson round-trips', () {
      const r = XRayRect(left: 1, top: 2, width: 3, height: 4);
      final j = r.toJson();
      expect(j['left'], 1);
      expect(j['top'], 2);
      expect(j['width'], 3);
      expect(j['height'], 4);
      final r2 = XRayRect.fromJson(j);
      expect(r2.left, r.left);
      expect(r2.top, r.top);
      expect(r2.width, r.width);
      expect(r2.height, r.height);
    });
  });

  group('XRayBoundingBox', () {
    test('constructor stores all fields', () {
      const box = XRayBoundingBox(
        nodeId: 'n1',
        viewType: 'ProfileView',
        rect: XRayRect(left: 10, top: 20, width: 100, height: 50),
        color: 0xFF00FF00, // neon green
        label: 'n1 | enabled | onTap | data✓',
      );
      expect(box.nodeId, 'n1');
      expect(box.viewType, 'ProfileView');
      expect(box.rect.width, 100);
      expect(box.color, 0xFF00FF00);
      expect(box.label, contains('enabled'));
    });

    test('toJson produces canonical shape', () {
      const box = XRayBoundingBox(
        nodeId: 'n1',
        viewType: 'ProfileView',
        rect: XRayRect(left: 10, top: 20, width: 100, height: 50),
        color: 0xFF00FF00,
        label: 'hello',
      );
      final j = box.toJson();
      expect(j['nodeId'], 'n1');
      expect(j['viewType'], 'ProfileView');
      expect(j['color'], 0xFF00FF00);
      expect(j['label'], 'hello');
      expect(j['rect'], isA<Map<String, dynamic>>());
      expect((j['rect'] as Map)['width'], 100);
    });

    test('toJson is json-serializable', () {
      const box = XRayBoundingBox(
        nodeId: 'n1',
        viewType: 'HomeView',
        rect: XRayRect(left: 0, top: 0, width: 10, height: 10),
        color: 0xFFFF00FF,
        label: 'x',
      );
      expect(jsonEncode(box.toJson()), isA<String>());
    });

    test(
      'fromJson tolerates a partial box (missing rect fields default to 0)',
      () {
        // The MCP bridge (Track 4.4) may emit a box whose `rect` is absent or
        // partially populated. Deserialization must not throw — it should fall
        // back to the same zero-size placeholder used by
        // XRayOverlayState._emit().
        final partial = {
          'nodeId': 'n1',
          'viewType': 'HomeView',
          'color': 0xFFFF00FF,
          'label': 'x',
        };
        final box = XRayBoundingBox.fromJson(partial);
        expect(box.nodeId, 'n1');
        expect(box.rect.left, 0);
        expect(box.rect.width, 0);
        expect(box.rect.height, 0);
      },
    );

    test('fromNode factory derives label + color from node', () {
      const node = XRayNode(
        id: 'ProfileViewNode.editProfileButton',
        viewType: 'ProfileView',
        enabled: true,
        boundAction: 'onEditTapped',
        stateSummary: XRayStateSummary(
          hasData: true,
          hasError: false,
          isLoading: false,
        ),
      );
      const rect = XRayRect(left: 10, top: 20, width: 100, height: 50);
      final box = XRayBoundingBox.fromNode(node, rect: rect);
      expect(box.nodeId, node.id);
      expect(box.viewType, node.viewType);
      expect(box.rect, same(rect));
      expect(box.label, contains('ProfileViewNode.editProfileButton'));
      expect(box.label, contains('enabled'));
      expect(box.label, contains('onEditTapped'));
      // color should be deterministic for 'ProfileView'
      expect(box.color, isA<int>());
    });

    test('fromNode derives a different color for different view types', () {
      const nodeA = XRayNode(
        id: 'a',
        viewType: 'ProfileView',
        enabled: true,
        stateSummary: XRayStateSummary.empty(),
      );
      const nodeB = XRayNode(
        id: 'b',
        viewType: 'HomeView',
        enabled: true,
        stateSummary: XRayStateSummary.empty(),
      );
      const rect = XRayRect(left: 0, top: 0, width: 10, height: 10);
      final boxA = XRayBoundingBox.fromNode(nodeA, rect: rect);
      final boxB = XRayBoundingBox.fromNode(nodeB, rect: rect);
      expect(boxA.color, isNot(equals(boxB.color)));
    });
  });
}
