import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:zuraffa/src/models/generator_config.dart';

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
  Future<ValidationResult> validate(GeneratorConfig config) async {
    return ValidationResult.failure(['invalid config']);
  }
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
        GeneratorConfig(name: 'Product'),
      );

      expect(result.isValid, isFalse);
      expect(result.reasons, contains('invalid config'));
    });
  });
}
