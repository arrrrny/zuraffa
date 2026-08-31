import 'package:test/test.dart';
import 'package:zuraffa/src/feature_flags/feature_flag.dart';
import 'package:zuraffa/src/feature_flags/runtime/feature_flag_provider.dart';

/// A13-A17 (gates), A19-A23 (variants + pluggable provider + fail-safe),
/// U8, U9, U10 — runtime resolution against injectable providers.
void main() {
  group('static defaults (no providers)', () {
    test('A22: no custom provider -> build-time static default', () {
      final runtime = FeatureFlagRuntime(
        enabled: {'pro-analytics'},
        disabled: {'beta-scheduler'},
      );
      expect(runtime.isEnabled('pro-analytics'), isTrue);
      expect(runtime.isEnabled('beta-scheduler'), isFalse);
    });

    test('A12: unknown feature answers false', () {
      final runtime = FeatureFlagRuntime(enabled: {'pro-analytics'});
      expect(runtime.isEnabled('nonexistent'), isFalse);
    });

    test('A11: enabledFeatures returns exactly the enabled set', () {
      final runtime = FeatureFlagRuntime(enabled: {'pro-analytics', 'notes'});
      // sorted for stable output
      expect(runtime.enabledFeatures, ['notes', 'pro-analytics']);
    });
  });

  group('membership gate (U8)', () {
    FeatureFlagRuntime runtimeWith(ResolverContext ctx) => FeatureFlagRuntime(
      enabled: {'pro-analytics'},
      disabled: {},
      gates: {
        'pro-analytics': [FeatureGate.parse('membership:pro')],
      },
      resolvers: Resolvers(
        membership: () => ctx.tier,
        locale: () => ctx.locale,
      ),
    );

    test('A13: tier free -> disabled', () {
      expect(
        runtimeWith(ResolverContext(tier: 'free', locale: 'en-US'))
            .isEnabled('pro-analytics'),
        isFalse,
      );
    });

    test('A14: tier pro -> enabled', () {
      expect(
        runtimeWith(ResolverContext(tier: 'pro', locale: 'en-US'))
            .isEnabled('pro-analytics'),
        isTrue,
      );
    });

    test('unavailable tier fails closed (membership provider missing)', () {
      expect(
        runtimeWith(ResolverContext(tier: null, locale: 'en-US'))
            .isEnabled('pro-analytics'),
        isFalse,
      );
    });

    test('throwing membership resolver fails closed, never throws', () {
      final runtime = FeatureFlagRuntime(
        enabled: {'pro-analytics'},
        gates: {
          'pro-analytics': [FeatureGate.parse('membership:pro')],
        },
        resolvers: Resolvers(membership: () => throw StateError('down')),
      );
      expect(runtime.isEnabled('pro-analytics'), isFalse);
    });
  });

  group('locale gate (U9)', () {
    FeatureFlagRuntime runtimeWith(String? locale) => FeatureFlagRuntime(
      enabled: {'regional-welcome'},
      gates: {
        'regional-welcome': [FeatureGate.parse('locale:en-US,en-GB')],
      },
      resolvers: Resolvers(locale: () => locale),
    );

    test('A15: fr-FR -> disabled', () {
      expect(runtimeWith('fr-FR').isEnabled('regional-welcome'), isFalse);
    });

    test('A16: en-US -> enabled', () {
      expect(runtimeWith('en-US').isEnabled('regional-welcome'), isTrue);
    });

    test('language-only context locale matches a full gate entry', () {
      // 'en' context locale is a prefix of en-US — language-prefix match
      expect(runtimeWith('en').isEnabled('regional-welcome'), isTrue);
    });

    test('unavailable locale fails closed', () {
      expect(runtimeWith(null).isEnabled('regional-welcome'), isFalse);
    });
  });

  group('multiple gates (A17)', () {
    test('all gates must pass: pro tier but ja-JP locale -> disabled', () {
      final runtime = FeatureFlagRuntime(
        enabled: {'gated-bundle'},
        gates: {
          'gated-bundle': [
            FeatureGate.parse('membership:pro'),
            FeatureGate.parse('locale:en-US'),
          ],
        },
        resolvers: Resolvers(membership: () => 'pro', locale: () => 'ja-JP'),
      );
      expect(runtime.isEnabled('gated-bundle'), isFalse);
    });

    test('all gates passing -> enabled', () {
      final runtime = FeatureFlagRuntime(
        enabled: {'gated-bundle'},
        gates: {
          'gated-bundle': [
            FeatureGate.parse('membership:pro'),
            FeatureGate.parse('locale:en-US'),
          ],
        },
        resolvers: Resolvers(membership: () => 'pro', locale: () => 'en-US'),
      );
      expect(runtime.isEnabled('gated-bundle'), isTrue);
    });
  });

  group('variant gate (A19, A20, U10)', () {
    test('A19: resolver returning b activates variant b', () {
      final resolvedFeatures = <String>[];
      final runtime = FeatureFlagRuntime(
        enabled: {'experiment'},
        gates: {
          'experiment': [FeatureGate.parse('variant:a|b')],
        },
        resolvers: Resolvers(
          variants: (feature, variants) {
            resolvedFeatures.add(feature);
            return 'b';
          },
        ),
      );
      expect(runtime.isEnabled('experiment'), isTrue);
      expect(runtime.resolveVariant('experiment'), 'b');
      expect(resolvedFeatures, isNotEmpty);
      expect(resolvedFeatures, everyElement('experiment'));
    });

    test('A20: feature without variant gate has a single default variant', () {
      final runtime = FeatureFlagRuntime(enabled: {'plain'});
      expect(runtime.resolveVariant('plain'), 'a');
    });

    test('variant resolver returning an undeclared variant fails the gate', () {
      final runtime = FeatureFlagRuntime(
        enabled: {'experiment'},
        gates: {
          'experiment': [FeatureGate.parse('variant:a|b')],
        },
        resolvers: Resolvers(variants: (feature, variants) => 'z'),
      );
      expect(runtime.isEnabled('experiment'), isFalse);
    });
  });

  group('custom gate', () {
    test('registered handler decides the gate', () {
      final runtime = FeatureFlagRuntime(
        enabled: {'heavy-export'},
        gates: {
          'heavy-export': [FeatureGate.parse('custom:power-user')],
        },
        customGates: {'power-user': (ctx) => ctx.membershipTier == 'pro'},
        resolvers: Resolvers(membership: () => 'pro'),
      );
      expect(runtime.isEnabled('heavy-export'), isTrue);
    });

    test('unregistered custom gate fails closed', () {
      final runtime = FeatureFlagRuntime(
        enabled: {'heavy-export'},
        gates: {
          'heavy-export': [FeatureGate.parse('custom:power-user')],
        },
      );
      expect(runtime.isEnabled('heavy-export'), isFalse);
    });

    test('handler context contains the resolved feature variant', () {
      String? contextVariant;
      final runtime = FeatureFlagRuntime(
        enabled: {'heavy-export'},
        gates: {
          'heavy-export': [
            FeatureGate.parse('variant:a|b'),
            FeatureGate.parse('custom:power-user'),
          ],
        },
        resolvers: Resolvers(variants: (feature, variants) => 'b'),
        customGates: {
          'power-user': (context) {
            contextVariant = context.variant;
            return true;
          },
        },
      );

      expect(runtime.isEnabled('heavy-export'), isTrue);
      expect(contextVariant, 'b');
    });
  });

  group('pluggable FeatureFlagProvider (A21, A23, U10)', () {
    test('A21: registered provider overrides build-time defaults', () {
      final runtime = FeatureFlagRuntime(
        enabled: {'pro-analytics'},
        disabled: {'beta-scheduler'},
        provider: _StaticProvider({'beta-scheduler': true}),
      );
      // provider says yes even though build-time says disabled
      expect(runtime.isEnabled('beta-scheduler'), isTrue);
      // provider with no opinion falls back to the build-time default
      expect(runtime.isEnabled('pro-analytics'), isTrue);
    });

    test('A23: throwing provider falls back to the build-time default', () {
      final runtime = FeatureFlagRuntime(
        enabled: {'pro-analytics'},
        disabled: {'beta-scheduler'},
        provider: _ThrowingProvider(),
      );
      expect(runtime.isEnabled('pro-analytics'), isTrue);
      expect(runtime.isEnabled('beta-scheduler'), isFalse);
    });

    test('provider context contains the resolved feature variant', () {
      final provider = _CapturingProvider();
      final runtime = FeatureFlagRuntime(
        enabled: {'experiment'},
        gates: {
          'experiment': [FeatureGate.parse('variant:a|b')],
        },
        resolvers: Resolvers(variants: (feature, variants) => 'b'),
        provider: provider,
      );

      expect(runtime.isEnabled('experiment'), isTrue);
      expect(provider.feature, 'experiment');
      expect(provider.context?.variant, 'b');
    });
  });
}

class ResolverContext {
  final String? tier;
  final String? locale;
  const ResolverContext({this.tier, this.locale});
}

class _StaticProvider implements FeatureFlagProvider {
  final Map<String, bool> answers;
  _StaticProvider(this.answers);

  @override
  bool? isEnabled(String feature, ProviderContext context) => answers[feature];
}

class _ThrowingProvider implements FeatureFlagProvider {
  @override
  bool? isEnabled(String feature, ProviderContext context) =>
      throw StateError('remote flag service down');
}

class _CapturingProvider implements FeatureFlagProvider {
  String? feature;
  ProviderContext? context;

  @override
  bool? isEnabled(String feature, ProviderContext context) {
    this.feature = feature;
    this.context = context;
    return null;
  }
}
