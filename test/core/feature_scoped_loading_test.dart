// Spec 1098 — CoreConfig.feature + feature-scoped plugin loading tests.
//
// Gap 2: PluginContext/CoreConfig carry no feature field — inter-plugin
// feature identity can only travel through the untyped sharedData map.
// Gap 3: PluginLoader instantiates plugins globally, never per-feature.
// Gap 8: ZuraffaCapability has no feature hooks — the capability interface
// cannot declare or validate feature scope.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/plugin_loader.dart';
import 'package:zuraffa/src/core/plugin_system/capability.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_context.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_interface.dart';
import 'package:zuraffa/src/domain/entities/feature_contract/feature_contract.dart';
import 'package:zuraffa/src/models/generated_file.dart';
import 'package:zuraffa/src/models/generator_config.dart';

/// A capability that declares the feature-scoping protocol (spec 1098) and
/// serves only features listed in [_servedIds] — the opt-out contract the
/// feature-scoped loader consults.
class _FeatureScopedCapability
    implements ZuraffaCapability, FeatureScopedCapability {
  final Set<String> _servedIds;

  _FeatureScopedCapability(Set<String> servedIds) : _servedIds = servedIds;

  @override
  String get name => 'scoped';

  @override
  String get description => 'test capability scoped to specific features';

  @override
  JsonSchema get inputSchema => const {};

  @override
  JsonSchema get outputSchema => const {};

  @override
  bool supportsFeature(FeatureContract feature) =>
      _servedIds.contains(feature.id);

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) =>
      throw UnimplementedError();

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) =>
      throw UnimplementedError();
}

/// Capability that does NOT declare the scoping protocol — unscoped by
/// construction.
class _DefaultCapability implements ZuraffaCapability {
  @override
  String get name => 'default';

  @override
  String get description => 'capability with the default (unscoped) hook';

  @override
  JsonSchema get inputSchema => const {};

  @override
  JsonSchema get outputSchema => const {};

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) =>
      throw UnimplementedError();

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) =>
      throw UnimplementedError();
}

class _FakePlugin extends ZuraffaPlugin {
  @override
  final String id;

  @override
  final List<ZuraffaCapability> capabilities;

  _FakePlugin(this.id, [this.capabilities = const []]);

  @override
  String get name => id;

  @override
  String get version => '0.0.0';

  Future<List<GeneratedFile>> generate(GeneratorConfig config) async => [];
}

void main() {
  final login = FeatureContract(
    id: 'login',
    displayName: 'Login',
    routes: const {'/login'},
  );
  final checkout = FeatureContract(
    id: 'checkout',
    displayName: 'Checkout',
    routes: const {'/checkout'},
  );

  group('CoreConfig.feature (gap 2)', () {
    test('defaults to null — no behavior change without a contract', () {
      const config = CoreConfig(name: 'Login', projectRoot: '/tmp/project');
      expect(config.feature, isNull);
    });

    test('carries an optional typed FeatureContract', () {
      final withFeature = CoreConfig(
        name: 'Login',
        projectRoot: '/tmp/project',
        feature: login,
      );
      expect(withFeature.feature?.id, 'login');
      expect(withFeature.feature?.displayName, 'Login');
    });
  });

  group('capability feature-scope protocol (gap 8)', () {
    test(
      'a capability without the protocol is unscoped (serves every feature)',
      () {
        final capability = _DefaultCapability();
        // The protocol is opt-in: a plain capability is not even asked.
        expect(capability, isNot(isA<FeatureScopedCapability>()));
      },
    );

    test('a capability may scope itself to specific features', () {
      final capability = _FeatureScopedCapability({'login'});
      expect(capability, isA<FeatureScopedCapability>());
      expect(capability.supportsFeature(login), isTrue);
      expect(capability.supportsFeature(checkout), isFalse);
    });
  });

  group('feature-scoped plugin loading (gap 3)', () {
    test(
      'filterForFeature excludes plugins whose every capability refuses',
      () {
        final refuser = _FakePlugin('scoped-to-other-features', [
          _FeatureScopedCapability({'logout'}),
        ]);
        final supporter = _FakePlugin('scoped-to-login', [
          _FeatureScopedCapability({'login'}),
        ]);
        final unscoped = _FakePlugin('unscoped');

        final filtered = PluginLoader.filterForFeature([
          refuser,
          supporter,
          unscoped,
        ], login);
        final ids = filtered.map((plugin) => plugin.id).toSet();

        expect(ids, contains('scoped-to-login'));
        expect(
          ids,
          contains('unscoped'),
          reason:
              'plugins without feature-scoped capabilities serve every '
              'feature',
        );
        expect(ids, isNot(contains('scoped-to-other-features')));
      },
    );

    test('filterForFeature with an empty capability list keeps the plugin', () {
      final bare = _FakePlugin('bare');
      expect(PluginLoader.filterForFeature([bare], checkout).map((p) => p.id), [
        'bare',
      ]);
    });

    test(
      'buildRegistry without a feature registers everything (unchanged)',
      () {
        final registry = _loader().buildRegistry();
        expect(registry.plugins, isNotEmpty);
        expect(
          registry.plugins.map((p) => p.id),
          contains('repository'),
          reason: 'the global registry instantiates every plugin as before',
        );
      },
    );

    test('buildRegistry with a feature applies the feature filter', () {
      final registry = _loader(feature: login).buildRegistry();
      final ids = registry.plugins.map((p) => p.id).toSet();

      expect(
        ids.contains('repository'),
        isTrue,
        reason:
            'core generation plugins (no feature scoping declared) must '
            'keep loading for any active feature',
      );
      // No default plugin scopes itself away from anything yet — the
      // registry must stay populated for a well-formed contract.
      expect(ids, isNotEmpty);
    });
  });
}

PluginLoader _loader({FeatureContract? feature}) => PluginLoader(
  outputDir: 'lib/src',
  dryRun: true,
  force: false,
  verbose: false,
  config: PluginConfig(disabled: {}),
  feature: feature,
);
