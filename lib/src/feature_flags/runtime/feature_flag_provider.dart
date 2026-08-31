/// Runtime feature-flag contracts (spec 030 FR-005..FR-010).
///
/// The generated `feature_flags.g.dart` registry in a zuraffa app
/// delegates to [FeatureFlagRuntime]; the runtime resolves features
/// against injectable providers with fail-safe fallbacks:
/// - the whole-feature [FeatureFlagProvider] failing or returning null
///   falls back to the build-time static default (US6.AC3);
/// - an individual gate resolver failing/throwing fails CLOSED (a
///   membership/locale/custom gate must not fail open for paid or
///   restricted features — design decision recorded in plan.md).
library;

import '../feature_flag.dart';

/// A pluggable whole-feature resolver (FR-009). Return `null` to express
/// "no opinion" — the runtime then falls back to the build-time default.
abstract interface class FeatureFlagProvider {
  bool? isEnabled(String feature, ProviderContext context);
}

/// Context handed to providers: user tier, locale, and the resolved
/// variant for the feature when a variant gate is declared.
class ProviderContext {
  final String? membershipTier;
  final String? locale;
  final String? variant;

  const ProviderContext({this.membershipTier, this.locale, this.variant});
}

/// Membership entitlement resolver (FR-006). Returns the current tier
/// (e.g. `free`, `pro`) or null when unavailable. Apps wire their
/// entitlements/subscription backend here.
typedef MembershipResolver = String? Function();

/// Locale resolver (FR-007). Returns e.g. `en-US` or null when
/// unavailable.
typedef LocaleResolver = String? Function();

/// A/B variant picker (FR-008): given the feature and its declared
/// variants, return the active variant for this session.
typedef VariantResolver =
    String Function(String feature, List<String> variants);

/// Custom gate handler: receives a [ProviderContext] and decides the gate.
typedef CustomGateHandler = bool Function(ProviderContext context);

/// Injectable resolver bundle.
class Resolvers {
  final MembershipResolver? membership;
  final LocaleResolver? locale;
  final VariantResolver? variants;

  const Resolvers({this.membership, this.locale, this.variants});
}

/// The runtime behind the generated `FeatureFlags` registry. Static by
/// default (build-time enabled set), dynamic through gates and providers.
class FeatureFlagRuntime {
  final Set<String> _enabled;
  final Map<String, List<FeatureGate>> _gates;
  final Resolvers? _resolvers;
  final Map<String, CustomGateHandler> _customGates;
  final FeatureFlagProvider? _provider;

  FeatureFlagRuntime({
    required Set<String> enabled,
    Set<String> disabled = const {},
    Map<String, List<FeatureGate>> gates = const {},
    Resolvers? resolvers,
    Map<String, CustomGateHandler> customGates = const {},
    FeatureFlagProvider? provider,
  }) : _enabled = Set.of(enabled),
       _gates = gates,
       _resolvers = resolvers,
       _customGates = customGates,
       _provider = provider {
    // Disabled features can never be enabled by gates; keep them out of
    // the enabled set even if a caller overlaps the sets.
    _enabled.removeAll(disabled);
  }

  /// Provider short-circuit, then static set membership, then gate
  /// evaluation (SC-003).
  bool isEnabled(String name) {
    final context = _currentContext(name);

    // 1. Pluggable whole-feature provider (US6) — its answer wins; a
    //    throw or a null answer falls back to the static path (FR-010).
    final provider = _provider;
    if (provider != null) {
      try {
        final answer = provider.isEnabled(name, context);
        if (answer != null) return answer;
      } catch (_) {
        // fail-safe: fall through to build-time defaults
      }
    }

    // 2. Build-time static default: a feature disabled at build time is
    //    disabled, period. Unknown names are disabled too (US3.AC4).
    if (!_enabled.contains(name)) return false;

    // 3. Gates: ALL must pass (US4.AC5). Any failing/unavailable gate
    //    fails closed.
    final gates = _gates[name];
    if (gates == null || gates.isEmpty) return true;
    for (final gate in gates) {
      if (!_gateSatisfied(name, gate, context)) return false;
    }
    return true;
  }

  /// The features enabled for this build (static set — US3.AC3).
  List<String> get enabledFeatures {
    final names = _enabled.toList()..sort();
    return List.unmodifiable(names);
  }

  /// Active variant for [feature]: `a` when no variant gate is declared
  /// (single default variant, US5.AC3), otherwise the variant resolver's
  /// pick (default resolver: first declared variant).
  String resolveVariant(String feature) {
    final gates = _gates[feature] ?? const [];
    for (final gate in gates) {
      if (gate.type == FeatureGateType.variant) {
        final variants = gate.values;
        if (variants.isEmpty) return 'a';
        final picker = _resolvers?.variants;
        if (picker == null) return variants.first;
        try {
          final picked = picker(feature, variants);
          return variants.contains(picked) ? picked : variants.first;
        } catch (_) {
          return variants.first;
        }
      }
    }
    return 'a';
  }

  ProviderContext _currentContext(String feature) {
    final resolvers = _resolvers;
    String? tier;
    String? locale;
    if (resolvers != null) {
      tier = _safe(() => resolvers.membership?.call());
      locale = _safe(() => resolvers.locale?.call());
    }
    return ProviderContext(
      membershipTier: tier,
      locale: locale,
      variant: resolveVariant(feature),
    );
  }

  bool _gateSatisfied(
    String feature,
    FeatureGate gate,
    ProviderContext context,
  ) {
    switch (gate.type) {
      case FeatureGateType.membership:
        final tier = context.membershipTier;
        return tier != null && tier == gate.value;

      case FeatureGateType.locale:
        final locale = context.locale;
        if (locale == null) return false;
        for (final allowed in gate.values) {
          if (locale.toLowerCase() == allowed.toLowerCase()) return true;
          // language-prefix match: context 'en' matches gate 'en-US'
          if (allowed.toLowerCase().startsWith('${locale.toLowerCase()}-')) {
            return true;
          }
        }
        return false;

      case FeatureGateType.variant:
        // An undeclared pick from the resolver must NOT pass the gate —
        // the resolver's raw answer decides.
        final picker = _resolvers?.variants;
        if (picker == null) return gate.values.isNotEmpty;
        try {
          final picked = picker(feature, gate.values);
          return gate.values.contains(picked);
        } catch (_) {
          return false;
        }

      case FeatureGateType.custom:
        final handler = _customGates[gate.value];
        if (handler == null) return false;
        try {
          return handler(context);
        } catch (_) {
          return false;
        }
    }
  }

  static T? _safe<T>(T? Function() body) {
    try {
      return body();
    } catch (_) {
      return null;
    }
  }
}
