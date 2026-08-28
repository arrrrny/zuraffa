import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tui/tui_plugin.dart';
import 'package:zuraffa/src/plugins/tui/generator/capabilities/create_tui_screens_capability.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_interface.dart';

void main() {
  group('ZuraffaTuiPlugin registration (FR-010, FR-011)', () {
    test('A21: ZuraffaTuiPlugin is a ZuraffaPlugin that exposes the TUI '
        'capability', () {
      final plugin = ZuraffaTuiPlugin();
      expect(plugin, isA<ZuraffaPlugin>());
      expect(plugin.id, 'tui');
      expect(plugin.name, 'TUI');
      expect(plugin.version, isNotEmpty);

      // The plugin contributes the CreateTuiScreensCapability (FR-011).
      final tuiCapabilities = plugin.capabilities
          .whereType<CreateTuiScreensCapability>()
          .toList();
      expect(
        tuiCapabilities,
        hasLength(1),
        reason: 'TUI plugin must register CreateTuiScreensCapability',
      );

      // The capability has the correct id and description.
      final cap = tuiCapabilities.single;
      expect(cap.name, 'create-tui-screens');
      expect(cap.description, contains('FR-011'));
    });

    test('A23: the create-tui-screens capability is discovered by zfa make '
        '--with=tui and emits list+detail screen source', () async {
      final plugin = ZuraffaTuiPlugin();
      final cap = plugin.capabilities
          .whereType<CreateTuiScreensCapability>()
          .single;

      // The input schema requires name + fields + useCases — this is what
      // `zfa make --with=tui` would pass when scaffolding a TUI for an
      // existing entity.
      final files = cap.generateFiles({
        'name': 'Product',
        'fields': [
          {'name': 'id', 'type': 'String'},
          {'name': 'name', 'type': 'String'},
          {'name': 'price', 'type': 'double'},
        ],
        'useCases': [
          {'name': 'get', 'returnsType': 'Product', 'paramsType': 'String'},
          {'name': 'getList', 'returnsType': 'List<Product>', 'isStream': true},
        ],
        'repositoryName': 'ProductRepository',
      });

      // Two files are emitted: the list screen and the detail screen.
      expect(files, hasLength(2));
      final paths = files.map((f) => f.path).toList();
      expect(paths.any((p) => p.contains('product_list_screen')), isTrue);
      expect(paths.any((p) => p.contains('product_detail_screen')), isTrue);

      // Both files contain the canonical TUI plugin imports — no Flutter.
      for (final file in files) {
        expect(file.content, isNotNull);
        expect(file.content!, contains('package:nocterm/nocterm.dart'));
        expect(file.content!, contains('package:zuraffa/src/plugins/tui/'));
        expect(
          file.content!.contains('package:flutter'),
          isFalse,
          reason: 'FR-012: generated TUI screens must be pure-Dart',
        );
      }

      // The capability also implements the strict execute() contract
      // (returns ExecutionResult with the generated file paths).
      final result = await cap.execute({
        'name': 'Product',
        'fields': [
          {'name': 'id', 'type': 'String'},
        ],
        'useCases': [
          {'name': 'get', 'returnsType': 'Product'},
          {'name': 'getList', 'returnsType': 'List<Product>'},
        ],
      });
      expect(result.success, isTrue);
      expect(result.files, hasLength(2));
    });
  });
}
