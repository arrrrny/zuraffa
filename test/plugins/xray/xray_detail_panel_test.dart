// Spec 036 — Track 4.2: XRayDetailPanel full-state-JSON tests.
//
// Behavior B13: fromNode produces valid JSON with full state.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/xray/xray_detail_panel.dart';
import 'package:zuraffa/src/plugins/xray/xray_node.dart';
import 'package:zuraffa/src/plugins/xray/xray_state_summary.dart';

void main() {
  group('XRayDetailPanel', () {
    test('constructor stores nodeId + fullStateJson', () {
      const panel = XRayDetailPanel(nodeId: 'n1', fullStateJson: '{"a":1}');
      expect(panel.nodeId, 'n1');
      expect(panel.fullStateJson, '{"a":1}');
    });

    test('toJson round-trips', () {
      const panel = XRayDetailPanel(nodeId: 'n1', fullStateJson: '{"a":1}');
      final j = panel.toJson();
      expect(j['nodeId'], 'n1');
      expect(j['fullStateJson'], '{"a":1}');
      final r = XRayDetailPanel.fromJson(j);
      expect(r.nodeId, panel.nodeId);
      expect(r.fullStateJson, panel.fullStateJson);
    });

    test('fromNode produces valid JSON string', () {
      const node = XRayNode(
        id: 'ProfileNode.editButton',
        viewType: 'ProfileView',
        enabled: true,
        boundAction: 'onEditTapped',
        stateSummary: XRayStateSummary(
          hasData: true,
          hasError: false,
          isLoading: false,
          dataPreview: 'Product(id=42)',
        ),
      );
      final panel = XRayDetailPanel.fromNode(node);
      // MUST parse without throwing.
      final parsed = jsonDecode(panel.fullStateJson);
      expect(parsed, isA<Map<String, dynamic>>());
      expect(parsed['nodeId'], 'ProfileNode.editButton');
      expect(parsed['enabled'], isTrue);
      expect(parsed['boundAction'], 'onEditTapped');
      expect(parsed['state'], isA<Map>());
      expect(parsed['state']['data'], isNotNull);
    });

    test('fromNode with empty state summary emits canonical "idle" state', () {
      const node = XRayNode(
        id: 'n1',
        viewType: 'HomeView',
        enabled: false,
        stateSummary: XRayStateSummary.empty(),
      );
      final panel = XRayDetailPanel.fromNode(node);
      final parsed = jsonDecode(panel.fullStateJson) as Map<String, dynamic>;
      expect(parsed['state']['data'], isNull);
      expect(parsed['state']['error'], isNull);
      expect(parsed['state']['loading'], isFalse);
    });

    test('fromNode includes children recursively', () {
      const child = XRayNode(
        id: 'child1',
        viewType: 'ParentView',
        enabled: true,
        stateSummary: XRayStateSummary.empty(),
      );
      const parent = XRayNode(
        id: 'parent',
        viewType: 'ParentView',
        enabled: true,
        boundAction: 'onParent',
        stateSummary: XRayStateSummary.empty(),
        children: [child],
      );
      final panel = XRayDetailPanel.fromNode(parent);
      final parsed = jsonDecode(panel.fullStateJson) as Map<String, dynamic>;
      expect(parsed['children'], isA<List>());
      expect((parsed['children'] as List).length, 1);
      // The recursive child is serialized as a nested object with its own
      // `nodeId` key (mirroring the parent's shape).
      expect((parsed['children'] as List).first['nodeId'], 'child1');
    });

    test('fromNode omits boundAction from JSON when null', () {
      const node = XRayNode(
        id: 'n1',
        viewType: 'HomeView',
        enabled: true,
        stateSummary: XRayStateSummary.empty(),
      );
      final panel = XRayDetailPanel.fromNode(node);
      final parsed = jsonDecode(panel.fullStateJson) as Map<String, dynamic>;
      expect(parsed.containsKey('boundAction'), isFalse);
    });
  });
}
