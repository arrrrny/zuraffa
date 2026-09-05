// Spec 1098 — XRayNode.featureId tests.
//
// Gap 7: XRayNode has no feature field — the deck knows file→layer but
// cannot answer file→feature. The node gains an optional featureId that
// round-trips through JSON (the MCP tree serialization).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/xray/xray_node.dart';
import 'package:zuraffa/src/plugins/xray/xray_state_summary.dart';

void main() {
  XRayNode node({String? featureId, List<XRayNode> children = const []}) =>
      XRayNode(
        id: 'LoginViewNode.loginButton',
        viewType: 'LoginView',
        enabled: true,
        stateSummary: const XRayStateSummary(
          hasData: false,
          hasError: false,
          isLoading: false,
        ),
        featureId: featureId,
        children: children,
      );

  group('XRayNode.featureId (gap 7)', () {
    test('featureId is optional and defaults to null', () {
      expect(node().featureId, isNull);
    });

    test('carries the owning feature id', () {
      expect(node(featureId: 'login').featureId, 'login');
    });

    test('toJson includes featureId only when set', () {
      expect(node().toJson().containsKey('featureId'), isFalse);
      expect(node(featureId: 'login').toJson()['featureId'], 'login');
    });

    test('fromJson round-trips the feature id', () {
      final json = node(featureId: 'login').toJson();
      final restored = XRayNode.fromJson(json);
      expect(restored.featureId, 'login');
    });

    test('fromJson tolerates legacy nodes without featureId', () {
      final restored = XRayNode.fromJson({
        'id': 'ProfileViewNode.editButton',
        'viewType': 'ProfileView',
        'enabled': true,
        'stateSummary': <String, dynamic>{},
        'children': <Map<String, dynamic>>[],
      });
      expect(restored.featureId, isNull);
    });
  });
}
