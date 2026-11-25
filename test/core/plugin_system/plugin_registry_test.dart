import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart' hide ZuraffaPlugin;
import 'package:zuraffa/src/core/plugin_system/plugin_context.dart';
import 'package:zuraffa/src/core/plugin_system/discovery_engine.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_interface.dart'
    show ZuraffaPlugin;

class _ValidPlugin extends ZuraffaPlugin {
  @override
  String get id => 'valid';

  @override
  String get name => 'Valid Plugin';

  @override
  String get version => '1.0.0';
}

class _InvalidPlugin extends ZuraffaPlugin {
  @override
  String get id => 'invalid';

  @override
  String get name => 'Invalid Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<ValidationResult> validate(PluginContext context) async {
    return ValidationResult.failure(['invalid config']);
  }
}

/// A minimal plugin carrying only the ordering edges a `sortPlugins` test
/// needs — no generation, no capabilities.
class _StubPlugin extends ZuraffaPlugin {
  _StubPlugin(this.id, {this.runAfter = const []});

  @override
  final String id;

  @override
  String get name => id;

  @override
  String get version => '1.0.0';

  @override
  final List<String> runAfter;
}

void main() {
  group('PluginRegistry', () {
    test('registers and retrieves plugins', () {
      final registry = PluginRegistry();
      final plugin = _ValidPlugin();

      registry.register(plugin);

      expect(registry.getById('valid'), equals(plugin));
      expect(registry.plugins, contains(plugin));
    });

    test('discovers plugin factories', () {
      final registry = PluginRegistry();
      registry.discover([() => _ValidPlugin()]);

      expect(registry.getById('valid'), isNotNull);
    });

    test('validates all plugins', () async {
      final registry = PluginRegistry();
      registry.registerAll([_ValidPlugin(), _InvalidPlugin()]);

      final result = await registry.validateAll(
        PluginContext(
          core: const CoreConfig(name: 'Product', projectRoot: '.'),
          discovery: const DiscoveryEngine(projectRoot: '.'),
        ),
      );

      expect(result.isValid, isFalse);
      expect(result.reasons, contains('invalid config'));
    });
  });

  group('sortPlugins ordering (#2127)', () {
    // UseCasePlugin.runAfter => ['service'] must order the service stage
    // before the usecase stage when both are in the same make plan, while a
    // usecase-only plan stays untouched — the edge is inert without `service`
    // in the target set because sortPlugins only visits a dep that is also a
    // target (plugin_registry.dart). This protects the ordering contract
    // independently of the stream generator's interface-deferral path.
    test('orders service before usecase when both are targets', () {
      final registry = PluginRegistry();
      final usecase = _StubPlugin('usecase', runAfter: ['service']);
      final service = _StubPlugin('service');
      registry.registerAll([usecase, service]);

      final sorted = registry.sortPlugins([usecase, service]);

      expect(
        sorted.map((p) => p.id).toList(),
        equals(['service', 'usecase']),
        reason: 'the service stage must precede the usecase stage (#2127)',
      );
    });

    test('leaves a usecase-only plan unchanged', () {
      final registry = PluginRegistry();
      final usecase = _StubPlugin('usecase', runAfter: ['service']);
      final service = _StubPlugin('service');
      registry.registerAll([usecase, service]);

      final sorted = registry.sortPlugins([usecase]);

      expect(
        sorted.map((p) => p.id).toList(),
        equals(['usecase']),
        reason: 'runAfter is inert without `service` in the target set',
      );
    });
  });
}
