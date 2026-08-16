import 'package:test/test.dart';
import 'package:zuraffa/src/config/zfa_config.dart';

void main() {
  group('ZfaConfig.xrayByDefault', () {
    test('defaults to false when xray is not in pluginDefaults', () {
      final config = ZfaConfig();
      expect(config.xrayByDefault, isFalse);
    });

    test('is true when xray: true is in pluginDefaults', () {
      final config = ZfaConfig(pluginDefaults: {'xray': true});
      expect(config.xrayByDefault, isTrue);
    });

    test('is false when xray: false is in pluginDefaults', () {
      final config = ZfaConfig(pluginDefaults: {'xray': false});
      expect(config.xrayByDefault, isFalse);
    });

    test('xray is in the builtin plugin defaults map', () {
      final config = ZfaConfig();
      expect(config.pluginDefaults, contains('xray'));
      expect(config.pluginDefaults['xray'], isFalse);
    });

    test('isPluginEnabledByDefault("xray") matches xrayByDefault', () {
      final config = ZfaConfig(pluginDefaults: {'xray': true});
      expect(
        config.isPluginEnabledByDefault('xray'),
        equals(config.xrayByDefault),
      );
    });

    test('fromJson reads xray from plugins.defaults', () {
      final config = ZfaConfig.fromJson({
        'plugins': {
          'defaults': {'xray': true},
        },
      });
      expect(config.xrayByDefault, isTrue);
    });

    test('toJson preserves xray default', () {
      final config = ZfaConfig(pluginDefaults: {'xray': true});
      final json = config.toJson();
      final plugins = json['plugins'] as Map<String, dynamic>;
      final defaults = plugins['defaults'] as Map<String, dynamic>;
      expect(defaults['xray'], isTrue);
    });
  });
}
