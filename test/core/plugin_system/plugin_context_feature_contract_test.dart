// Spec 1114 — PluginContext carries the FeatureContract (per #1098 /
// #1114 item 5): the `plugin_context.dart` extension slice, xray and
// FeaturePlugin read the active contract FROM, not from raw args.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/core/plugin_system/discovery_engine.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_context.dart';
import 'package:zuraffa/src/domain/entities/feature_contract/feature_contract.dart';

void main() {
  PluginContext context({FeatureContract? feature}) => PluginContext(
    core: CoreConfig(name: 'login', projectRoot: '/probe', feature: feature),
    discovery: DiscoveryEngine(projectRoot: '/probe'),
  );

  group('PluginContext.activeFeatureContract (spec 1114 #5)', () {
    test(
      'carries the typed contract from core (the context is the carrier)',
      () {
        final contract = FeatureContract(
          id: 'login',
          displayName: 'Login',
          entities: ['User'],
          routes: {'/login'},
          xrayLayer: XRayLayer.presentation,
        );

        final ctx = context(feature: contract);
        expect(ctx.activeFeatureContract, same(contract));
        expect(ctx.activeFeatureContract!.id, 'login');
      },
    );

    test('null when no contract was resolved (unscoped run)', () {
      expect(context().activeFeatureContract, isNull);
    });
  });
}
