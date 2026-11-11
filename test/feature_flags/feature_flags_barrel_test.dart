// Issue #2066 — the feature-flag system is importable from the public
// barrel `package:zuraffa/feature_flags.dart` without `src/` imports.
import 'package:zuraffa/feature_flags.dart';
import 'package:test/test.dart';

void main() {
  test('barrel exposes the feature-flag system', () {
    final gate = FeatureGate.parse('platform:macos');
    expect(gate.type, FeatureGateType.platform);

    final flag = FeatureFlag(name: 'agent-tools', enabled: true, gates: [gate]);
    expect(flag.pascalName, 'AgentTools');

    final runtime = FeatureFlagRuntime(
      enabled: {'agent-tools'},
      gates: {
        'agent-tools': [gate],
      },
      resolvers: Resolvers(platform: () => 'macos'),
    );
    expect(runtime.isEnabled('agent-tools'), isTrue);
    expect(runtime.enabledFeatures, ['agent-tools']);

    const context = ProviderContext(platform: 'macos');
    expect(context.platform, 'macos');
    expect(FeatureConfigException('x').message, 'x');
  });
}
