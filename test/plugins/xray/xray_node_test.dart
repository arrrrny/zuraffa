// Spec 036 — Track 4.2: XRayNode data model tests.
//
// Behavior B07: XRayNode immutable data + JSON round-trip.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/xray/xray_node.dart';
import 'package:zuraffa/src/plugins/xray/xray_state_summary.dart';

void main() {
  group('XRayNode', () {
    test('constructor accepts required fields + children default []', () {
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
      expect(node.id, 'ProfileViewNode.editProfileButton');
      expect(node.viewType, 'ProfileView');
      expect(node.enabled, isTrue);
      expect(node.boundAction, 'onEditTapped');
      expect(node.children, isEmpty);
    });

    test('toJson produces canonical shape', () {
      const node = XRayNode(
        id: 'n1',
        viewType: 'ProfileView',
        enabled: true,
        boundAction: 'onEditTapped',
        stateSummary: XRayStateSummary(
          hasData: true,
          hasError: false,
          isLoading: false,
        ),
      );
      final json = node.toJson();
      expect(json['id'], 'n1');
      expect(json['viewType'], 'ProfileView');
      expect(json['enabled'], isTrue);
      expect(json['boundAction'], 'onEditTapped');
      expect(json['stateSummary'], isA<Map<String, dynamic>>());
      expect(json['children'], isEmpty);
    });

    test('toJson omits boundAction when null', () {
      const node = XRayNode(
        id: 'n1',
        viewType: 'HomeView',
        enabled: false,
        stateSummary: XRayStateSummary.empty(),
      );
      final json = node.toJson();
      expect(
        json.containsKey('boundAction'),
        isFalse,
        reason: 'null boundAction MUST be omitted from JSON',
      );
    });

    test('toJson preserves children list (even empty)', () {
      const node = XRayNode(
        id: 'n1',
        viewType: 'HomeView',
        enabled: true,
        stateSummary: XRayStateSummary.empty(),
      );
      expect(node.toJson()['children'], isEmpty);
    });

    test('fromJson round-trips through toJson', () {
      const original = XRayNode(
        id: 'ProfileViewNode.editProfileButton',
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
      final json = original.toJson();
      final reconstructed = XRayNode.fromJson(json);
      expect(reconstructed.id, original.id);
      expect(reconstructed.viewType, original.viewType);
      expect(reconstructed.enabled, original.enabled);
      expect(reconstructed.boundAction, original.boundAction);
      expect(reconstructed.stateSummary.hasData, original.stateSummary.hasData);
      expect(reconstructed.children.length, original.children.length);
    });

    test('fromJson handles nested children', () {
      final json = {
        'id': 'parent',
        'viewType': 'ParentView',
        'enabled': true,
        'boundAction': 'onParent',
        'stateSummary': {
          'hasData': false,
          'hasError': false,
          'isLoading': true,
        },
        'children': [
          {
            'id': 'child1',
            'viewType': 'ParentView',
            'enabled': true,
            'stateSummary': {
              'hasData': false,
              'hasError': false,
              'isLoading': false,
            },
            'children': <Map<String, dynamic>>[],
          },
        ],
      };
      final node = XRayNode.fromJson(json);
      expect(node.id, 'parent');
      expect(node.children.length, 1);
      expect(node.children.first.id, 'child1');
      expect(node.children.first.boundAction, isNull);
    });

    test('toJson is json-serializable to string', () {
      const node = XRayNode(
        id: 'n1',
        viewType: 'HomeView',
        enabled: true,
        stateSummary: XRayStateSummary.empty(),
      );
      final encoded = jsonEncode(node.toJson());
      expect(encoded, isA<String>());
      expect(encoded, contains('"id":"n1"'));
    });
  });
}
