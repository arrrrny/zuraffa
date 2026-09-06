// Spec 1098 + 1115 — XRayNode.featureId tests.
//
// Gap 7 (#1098): XRayNode has no feature field — the deck knows file→layer
// but cannot answer file→feature. The node gained an optional featureId
// that round-trips through JSON (the MCP tree serialization).
//
// Spec 1115: the field is TYPED — `FeatureId`, not a raw string — so the
// deck can group nodes by feature contract, and a malformed id cannot ride
// the wire.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/domain/entities/feature_contract/feature_id.dart';
import 'package:zuraffa/src/plugins/xray/xray_node.dart';
import 'package:zuraffa/src/plugins/xray/xray_state_summary.dart';

void main() {
  XRayNode node({FeatureId? featureId, List<XRayNode> children = const []}) =>
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

  group('XRayNode.featureId (gap 7, typed by 1115)', () {
    test('featureId is optional and defaults to null', () {
      expect(node().featureId, isNull);
    });

    test('carries the owning feature id', () {
      expect(
        node(featureId: FeatureId.parse('login')).featureId!.value,
        'login',
      );
    });

    test('toJson includes featureId only when set', () {
      expect(node().toJson().containsKey('featureId'), isFalse);
      expect(
        node(featureId: FeatureId.parse('login')).toJson()['featureId'],
        'login',
      );
    });

    test('fromJson round-trips the feature id (typed)', () {
      final json = node(featureId: FeatureId.parse('login')).toJson();
      final restored = XRayNode.fromJson(json);
      expect(restored.featureId, FeatureId.parse('login'));
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
