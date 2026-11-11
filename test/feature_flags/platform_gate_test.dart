import 'package:test/test.dart';
import 'package:zuraffa/src/feature_flags/feature_flag.dart';
import 'package:zuraffa/src/feature_flags/feature_flag_config.dart';
import 'package:zuraffa/src/feature_flags/runtime/feature_flag_provider.dart';

/// Issue #2066 — `platform:` gate kind: parse, runtime evaluation, and
/// the resolved OS landing on [ProviderContext].
void main() {
  group('parse (platform gate)', () {
    test('platform:macos yields a platform gate with values [macos]', () {
      final gate = FeatureGate.parse('platform:macos');
      expect(gate.type, FeatureGateType.platform);
      expect(gate.values, ['macos']);
      expect(gate.value, 'macos');
      expect(gate.raw, 'platform:macos');
    });

    test('platform:macos,ios splits the comma-separated allow-list', () {
      final gate = FeatureGate.parse('platform:macos,ios');
      expect(gate.type, FeatureGateType.platform);
      expect(gate.values, ['macos', 'ios']);
    });

    test('empty platform list throws FormatException naming the gate', () {
      expect(
        () => FeatureGate.parse('platform:'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('platform:'),
          ),
        ),
      );
    });

    test('whitespace-only platform list throws FormatException', () {
      expect(
        () => FeatureGate.parse('platform: , ,'),
        throwsA(isA<FormatException>()),
      );
    });

    test('config-level gate list accepts platform gates', () {
      final config = FeatureFlagConfig.fromJson({
        'features': [
          {
            'name': 'agent-tools',
            'enabled': true,
            'gates': ['platform:macos'],
          },
        ],
      });
      expect(
        config.flag('agent-tools')!.gates.single.type,
        FeatureGateType.platform,
      );
    });
  });

  group('runtime (platform gate)', () {
    FeatureFlagRuntime runtimeWith(String? os, {bool throwing = false}) =>
        FeatureFlagRuntime(
          enabled: {'agent-tools'},
          gates: {
            'agent-tools': [FeatureGate.parse('platform:macos')],
          },
          resolvers: Resolvers(
            platform: throwing ? () => throw StateError('down') : () => os,
          ),
          customGates: {},
        );

    FeatureFlagRuntime runtimeWithGates(List<String> rawGates, String? os) =>
        FeatureFlagRuntime(
          enabled: {'managed-proxy'},
          gates: {'managed-proxy': rawGates.map(FeatureGate.parse).toList()},
          resolvers: Resolvers(platform: () => os),
        );

    test('resolver returns macos -> enabled', () {
      expect(runtimeWith('macos').isEnabled('agent-tools'), isTrue);
    });

    test('resolver returns ios -> disabled', () {
      expect(runtimeWith('ios').isEnabled('agent-tools'), isFalse);
    });

    test('resolver returns linux -> disabled', () {
      expect(runtimeWith('linux').isEnabled('agent-tools'), isFalse);
    });

    test('resolver returns null -> fails closed', () {
      expect(runtimeWith(null).isEnabled('agent-tools'), isFalse);
    });

    test('resolver absent -> fails closed', () {
      final runtime = FeatureFlagRuntime(
        enabled: {'agent-tools'},
        gates: {
          'agent-tools': [FeatureGate.parse('platform:macos')],
        },
      );
      expect(runtime.isEnabled('agent-tools'), isFalse);
    });

    test('throwing resolver -> fails closed, never throws', () {
      expect(
        runtimeWith(null, throwing: true).isEnabled('agent-tools'),
        isFalse,
      );
    });

    test('multiple OS values pass for either listed OS', () {
      expect(
        runtimeWithGates([
          'platform:macos,ios',
        ], 'macos').isEnabled('managed-proxy'),
        isTrue,
      );
      expect(
        runtimeWithGates([
          'platform:macos,ios',
        ], 'ios').isEnabled('managed-proxy'),
        isTrue,
      );
      expect(
        runtimeWithGates([
          'platform:macos,ios',
        ], 'android').isEnabled('managed-proxy'),
        isFalse,
      );
    });

    test('platform gate combined with membership gate: both must pass', () {
      final runtime = FeatureFlagRuntime(
        enabled: {'agent-tools'},
        gates: {
          'agent-tools': [
            FeatureGate.parse('platform:macos'),
            FeatureGate.parse('membership:pro'),
          ],
        },
        resolvers: Resolvers(platform: () => 'macos', membership: () => 'free'),
      );
      expect(runtime.isEnabled('agent-tools'), isFalse);
    });
  });

  group('ProviderContext.platform', () {
    test('resolved OS lands on the context for custom handlers', () {
      String? seen;
      final runtime = FeatureFlagRuntime(
        enabled: {'agent-tools'},
        gates: {
          'agent-tools': [FeatureGate.parse('custom:os-check')],
        },
        resolvers: Resolvers(platform: () => 'macos'),
        customGates: {
          'os-check': (ctx) {
            seen = ctx.platform;
            return true;
          },
        },
      );
      expect(runtime.isEnabled('agent-tools'), isTrue);
      expect(seen, 'macos');
    });

    test('platform resolver absent -> context.platform is null', () {
      ProviderContext? seen;
      final runtime = FeatureFlagRuntime(
        enabled: {'agent-tools'},
        gates: {
          'agent-tools': [FeatureGate.parse('custom:capture')],
        },
        customGates: {
          'capture': (ctx) {
            seen = ctx;
            return true;
          },
        },
      );
      expect(runtime.isEnabled('agent-tools'), isTrue);
      expect(seen!.platform, isNull);
    });
  });
}
