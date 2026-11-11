/// Public feature-flag gateway barrel (issue #2066).
///
/// The feature-flag system (spec 030) lives under
/// `src/feature_flags/` and is deliberately NOT part of the default
/// `package:zuraffa/zuraffa.dart` export surface — the same dedicated
/// import URI pattern as `agent.dart`, `mock.dart`, `skin.dart` and
/// `zap.dart`. Consumers import it explicitly:
///
/// ```dart
/// import 'package:zuraffa/feature_flags.dart';
/// ```
///
/// Exposed: the [FeatureFlag]/[FeatureGate] model and gate syntax
/// (`membership:`, `locale:`, `variant:`, `custom:`, `platform:`), the
/// runtime evaluator [FeatureFlagRuntime] with its injectable
/// [Resolvers] and [ProviderContext], the pluggable
/// [FeatureFlagProvider] contract, and the `.zfa.json`
/// [FeatureFlagConfig] parser.
library;

export 'src/feature_flags/feature_flag.dart';
export 'src/feature_flags/feature_flag_config.dart'
    show FeatureFlagConfig, ResolvedFeatureSet, configFileSync;
export 'src/feature_flags/runtime/feature_flag_provider.dart';
