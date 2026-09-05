// Spec 1002 — the `engine` preset entry + engine plan resolution.
//
// `zfa make engine <Entity>` (and `--preset=engine`) must expand to the
// engine-slice plugin chain: usecase, service, provider, repository,
// datasource, mock, di — with NO Flutter-importing plugins (no view,
// presenter, controller, state, route) and no test plugin.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/core/planning/preset_registry.dart';

void main() {
  group('PresetRegistry engine preset (spec 1002)', () {
    test('registers the engine preset', () {
      expect(PresetRegistry.hasPreset('engine'), isTrue);
    });

    test('engine preset chains the engine-slice generators', () {
      final pluginIds = PresetRegistry.pluginIdsFor('engine');

      expect(
        pluginIds,
        containsAll([
          'usecase',
          'service',
          'provider',
          'repository',
          'datasource',
          'mock',
          'di',
        ]),
      );
    });

    test('engine preset excludes every Flutter-importing plugin', () {
      final pluginIds = PresetRegistry.pluginIdsFor('engine').toSet();

      expect(pluginIds, isNot(contains('view')));
      expect(pluginIds, isNot(contains('presenter')));
      expect(pluginIds, isNot(contains('controller')));
      expect(pluginIds, isNot(contains('state')));
      expect(pluginIds, isNot(contains('route')));
    });

    test('the engine preset does not disturb the existing presets', () {
      expect(PresetRegistry.pluginIdsFor('crud'), [
        'usecase',
        'repository',
        'datasource',
        'di',
      ]);
      expect(PresetRegistry.pluginIdsFor('read-only'), [
        'usecase',
        'repository',
        'datasource',
        'di',
      ]);
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
  });
}
