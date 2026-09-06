// Issue #1149 (kill list, part of EPIC #1132 Machine Contract):
// tui/observer fate decision.
//
// TUI: `make --with=tui` was a SILENT NO-OP — TuiPlugin was not a
// FileGeneratorPlugin, so PluginManager.run skipped it entirely and the
// command printed "No files generated." with exit 0. Now it is wired as
// a FileGeneratorPlugin: the make pipeline derives entity fields (via
// EntityAnalyzer) and use cases (from --methods), emits both screens,
// and PERSISTS them.
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_interface.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_manager.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_registry.dart';
import 'package:zuraffa/src/plugins/tui/tui_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('tui_wiring_test_');
    outputDir = '${tempDir.path}/lib/src';
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('TuiPlugin is wired into the make pipeline', () {
    test('TuiPlugin is a FileGeneratorPlugin', () {
      final plugin = TuiPlugin();
      expect(
        plugin,
        isA<FileGeneratorPlugin>(),
        reason:
            'PluginManager.run only executes FileGeneratorPlugin instances '
            '— anything else makes --with=tui a silent no-op (issue #1149).',
      );
    });

    test('generateWithContext derives specs and PERSISTS both screens',
        () async {
      // A real entity so EntityAnalyzer can derive fields.
      final entityDir = Directory('$outputDir/domain/entities/product');
      entityDir.createSync(recursive: true);
      File('${entityDir.path}/product.dart').writeAsStringSync('''
class Product {
  final String id;
  final String name;
  Product({required this.id, required this.name});
}
''');

      final plugin = TuiPlugin(outputDir: outputDir);
      final manager = PluginManager(
        registry: PluginRegistry(),
        projectRoot: tempDir.path,
      );
      final context = manager.buildContext(
        name: 'Product',
        argResults: null,
        activePlugins: [plugin],
        overrideOutputDir: outputDir,
        overrideForce: true,
      );
      context.data['methods'] = ['get', 'getList'];

      final files = await plugin.generateWithContext(context);

      expect(
        files,
        hasLength(2),
        reason: 'list + detail screens must be emitted',
      );
      for (final file in files) {
        expect(
          File(file.path).existsSync(),
          isTrue,
          reason:
              '${file.path} must exist on disk — the pre-wiring plugin '
              'returned content nobody persisted (silent no-op).',
        );
      }
      expect(
        files.firstWhere((f) => f.path.contains('list_screen')).path,
        endsWith('product_list_screen.dart'),
      );
      expect(
        files.firstWhere((f) => f.path.contains('detail_screen')).path,
        endsWith('product_detail_screen.dart'),
      );
    });

    test('generated screens use relative entity/use-case imports', () async {
      final entityDir = Directory('$outputDir/domain/entities/product');
      entityDir.createSync(recursive: true);
      File('${entityDir.path}/product.dart').writeAsStringSync('''
class Product {
  final String id;
  Product({required this.id});
}
''');

      final plugin = TuiPlugin(outputDir: outputDir);
      final manager = PluginManager(
        registry: PluginRegistry(),
        projectRoot: tempDir.path,
      );
      final context = manager.buildContext(
        name: 'Product',
        argResults: null,
        activePlugins: [plugin],
        overrideOutputDir: outputDir,
        overrideForce: true,
      );
      context.data['methods'] = ['get', 'getList'];

      final files = await plugin.generateWithContext(context);
      final all = files.map((f) => File(f.path).readAsStringSync()).join('\n');

      expect(
        all,
        isNot(contains('package:zuraffa/domain/')),
        reason:
            'Screens must not import package:zuraffa/domain/... — that '
            'path cannot resolve inside a consumer app (issue #1149).',
      );
      expect(all, contains('../../domain/entities/product/product.dart'));
    });

    test('missing list use case fails loudly instead of silently', () async {
      final entityDir = Directory('$outputDir/domain/entities/product');
      entityDir.createSync(recursive: true);
      File('${entityDir.path}/product.dart').writeAsStringSync('''
class Product {
  final String id;
  Product({required this.id});
}
''');

      final plugin = TuiPlugin(outputDir: outputDir);
      final manager = PluginManager(
        registry: PluginRegistry(),
        projectRoot: tempDir.path,
      );
      final context = manager.buildContext(
        name: 'Product',
        argResults: null,
        activePlugins: [plugin],
        overrideOutputDir: outputDir,
        overrideForce: true,
      );
      // No getList/watchList — the TUI list screen cannot bind anything.
      context.data['methods'] = ['get'];

      await expectLater(
        plugin.generateWithContext(context),
        throwsArgumentError,
        reason:
            'A TUI scaffold without a list use case would generate '
            'uncompilable screens — fail loudly instead.',
      );
    });
  });
}
