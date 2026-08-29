// Spec 035 — Track 4.4: XRayTreeResponse data class tests.
//
// Behaviors B01, B02.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/mcp/xray_bridge/xray_tree_response.dart';

void main() {
  group('XRayTreeResponse', () {
    test('B01 — toJson produces canonical shape', () {
      const r = XRayTreeResponse(
        activeView: 'ProfileView',
        nodes: [
          {'id': 'n1', 'viewType': 'ProfileView', 'enabled': true},
        ],
      );
      final j = r.toJson();
      expect(j['activeView'], 'ProfileView');
      expect(j['nodes'], isA<List>());
      expect((j['nodes'] as List).length, 1);
      expect((j['nodes'] as List).first['id'], 'n1');
    });

    test('B01 — round-trips through fromJson', () {
      const original = XRayTreeResponse(
        activeView: 'HomeView',
        nodes: [
          {'id': 'a'},
          {'id': 'b'},
        ],
      );
      final j = original.toJson();
      final reconstructed = XRayTreeResponse.fromJson(j);
      expect(reconstructed.activeView, original.activeView);
      expect(reconstructed.nodes.length, original.nodes.length);
    });

    test('B02 — empty factory produces activeView=null + nodes=[]', () {
      const r = XRayTreeResponse.empty();
      expect(r.activeView, isNull);
      expect(r.nodes, isEmpty);
    });

    test('B02 — empty toJson round-trips', () {
      const r = XRayTreeResponse.empty();
      final j = r.toJson();
      expect(j['activeView'], isNull);
      expect(j['nodes'], isEmpty);
      final reconstructed = XRayTreeResponse.fromJson(j);
      expect(reconstructed.activeView, isNull);
      expect(reconstructed.nodes, isEmpty);
    });

    test('toJson is json-serializable', () {
      const r = XRayTreeResponse(activeView: 'V', nodes: []);
      expect(jsonEncode(r.toJson()), isA<String>());
    });

    test('fromJson accepts missing nodes (defaults to empty list)', () {
      final r = XRayTreeResponse.fromJson({'activeView': 'V'});
      expect(r.nodes, isEmpty);
    });

    test('fromJson accepts missing activeView (defaults to null)', () {
      final r = XRayTreeResponse.fromJson({});
      expect(r.activeView, isNull);
      expect(r.nodes, isEmpty);
    });
  });
}
