/// The Zuraffa feature-flag gateway (spec 030, issue #2066).
///
/// Public barrel for the feature-flag system: the gate vocabulary
/// (`FeatureGate`, `FeatureGate.parse`, `FeatureGateType`), the runtime
/// (`FeatureFlagRuntime`, `Resolvers`, `ProviderContext`), and the
/// `.zfa.json` config layer. Consuming apps import
/// `package:zuraffa/feature_flags.dart` — never the `src/` paths.
///
/// Gate kinds: `membership:<tier>`, `locale:<l1>,<l2>`,
/// `variant:<a|b>`, `custom:<name>`, and — since issue #2066 —
/// `platform:<os[,os…]>`, which scopes a feature to the operating systems
/// the injected `Resolvers.platform` reports:
///
/// ```dart
/// import 'dart:io';
/// import 'package:zuraffa/feature_flags.dart';
///
/// final gateway = FeatureFlagRuntime(
///   enabled: {'agent-access', 'managed-proxy'},
///   gates: {
///     'agent-access': [FeatureGate.parse('platform:macos')],
///     'managed-proxy': [FeatureGate.parse('platform:ios')],
///   },
///   resolvers: Resolvers(platform: () => Platform.operatingSystem),
/// );
///
/// if (gateway.isEnabled('agent-access')) {
///   // wire the agent endpoint — macOS only.
/// }
/// ```
library;

export 'src/feature_flags/feature_flag.dart';
export 'src/feature_flags/feature_flag_config.dart'
    show FeatureConfigException, FeatureFlagConfig;
export 'src/feature_flags/runtime/feature_flag_provider.dart';
