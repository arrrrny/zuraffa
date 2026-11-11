import 'package:test/test.dart';
import 'package:zuraffa/feature_flags.dart';

/// Issue #2066: the feature-flag system must be importable from the public
/// barrel — no `src/` imports in consuming apps.
void main() {
  test('exports the gate vocabulary and the runtime', () {
    final gate = FeatureGate.parse('platform:macos');
    expect(gate.type, FeatureGateType.platform);
    final runtime = FeatureFlagRuntime(
      enabled: {'x'},
      gates: {
        'x': [gate],
      },
      resolvers: Resolvers(platform: () => 'macos'),
    );
    expect(runtime.isEnabled('x'), isTrue);
  });

  test('exports the config layer', () {
    expect(FeatureConfigException, isNotNull);
  });
}
