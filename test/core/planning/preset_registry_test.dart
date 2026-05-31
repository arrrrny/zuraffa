import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/planning/plugin_alias_resolver.dart';
import 'package:zuraffa/src/core/planning/preset_registry.dart';

void main() {
  group('PresetRegistry', () {
    test('returns expected plugin ids for feature preset', () {
      expect(PresetRegistry.hasPreset('feature'), isTrue);
      expect(
        PresetRegistry.pluginIdsFor('feature'),
        containsAll([
          'usecase',
          'repository',
          'datasource',
          'view',
          'presenter',
          'controller',
          'state',
          'di',
          'test',
        ]),
      );
    });

    test('returns empty list for unknown preset', () {
      expect(PresetRegistry.hasPreset('unknown'), isFalse);
      expect(PresetRegistry.pluginIdsFor('unknown'), isEmpty);
    });
  });

  group('PluginAliasResolver', () {
    test('expands aliases to canonical plugin ids with deduplication', () {
      expect(
        PluginAliasResolver.expandAll(['data', 'vpc', 'repository']),
        equals(['repository', 'datasource', 'view', 'presenter', 'controller']),
      );
    });
  });
}
