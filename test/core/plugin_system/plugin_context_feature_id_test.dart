// Spec 1115 — PluginContext.featureId: the typed wire (issue #1115 item 5).
//
// Per #1098 the CoreConfig carries the active feature; xray, slice,
// FeaturePlugin and the auditor all read it from context. After 1115 that
// read is a typed FeatureId — parsed once, not a raw string passed around.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/core/plugin_system/discovery_engine.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_context.dart';
import 'package:zuraffa/src/domain/entities/feature_contract/feature_contract.dart';
import 'package:zuraffa/src/domain/entities/feature_contract/feature_id.dart';

void main() {
  PluginContext context({FeatureContract? feature}) => PluginContext(
    core: CoreConfig(name: 'login', projectRoot: '/probe', feature: feature),
    discovery: DiscoveryEngine(projectRoot: '/probe'),
  );

  group('PluginContext.featureId (spec 1115 #5)', () {
    test('exposes the active contract id as a typed FeatureId', () {
      final ctx = context(
        feature: FeatureContract(
          id: '004-login-ui',
          displayName: 'Login UI',
          entities: ['Login'],
          routes: {'/login'},
          xrayLayer: XRayLayer.presentation,
        ),
      );
      expect(ctx.featureId, FeatureId.parse('004-login-ui'));
    });

    test('null when no contract is active (unscoped run)', () {
      expect(context().featureId, isNull);
    });
  });
}
