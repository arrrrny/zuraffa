import 'package:test/test.dart';
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

    // #348: `crud` and `read-only` are the only data presets that previously
    // omitted `di`. They now bundle it so the canonical
    // `zfa make X --preset=crud` (or `--preset=read-only`) produces a
    // runnable app without the `--with=di` crutch.
    test('crud and read-only presets include di (issue #348)', () {
      expect(PresetRegistry.hasPreset('crud'), isTrue);
      expect(PresetRegistry.hasPreset('read-only'), isTrue);
      expect(
        PresetRegistry.pluginIdsFor('crud'),
        containsAll(['usecase', 'repository', 'datasource', 'di']),
      );
      expect(
        PresetRegistry.pluginIdsFor('read-only'),
        containsAll(['usecase', 'repository', 'datasource', 'di']),
      );
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
