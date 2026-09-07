import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/plugins/skin/skin_plugin.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_context.dart';
import 'package:zuraffa/src/core/plugin_system/discovery_engine.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_skin_test_');
    outputDir = path.join(tempDir.path, 'lib', 'src');
    await Directory(outputDir).create(recursive: true);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('SkinPlugin generates list widget with active discovery', () async {
    final plugin = SkinPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(dryRun: false, force: true),
    );

    // Create an entity in a non-standard deep directory to test Active Discovery
    final entityDir = Directory(
      path.join(outputDir, 'domain', 'entities', 'deep', 'nested', 'product'),
    );
    await entityDir.create(recursive: true);
    final entityFile = File(path.join(entityDir.path, 'product.dart'));
    await entityFile.writeAsString('''
class Product {
  final String id;
  final String name;
  final double price;

  Product({required this.id, required this.name, required this.price});
}
''');

    final context = PluginContext(
      core: CoreConfig(
        name: 'Product',
        projectRoot: tempDir.path,
        outputDir: 'lib/src',
      ),
      discovery: DiscoveryEngine(projectRoot: outputDir),
      data: {'layout': 'list', 'filter': true, 'sort': true},
    );

    final results = await plugin.generateWithContext(context);

    expect(results, isNotEmpty);
    final generatedFile = results.first;
    expect(generatedFile.path, contains('product_list_widget.dart'));

    final content = File(generatedFile.path).readAsStringSync();

    // Verify relative import found via Active Discovery
    // The widget is in lib/src/presentation/widgets/product/
    // The entity is in lib/src/domain/entities/deep/nested/product/
    // Relative path should be ../../../domain/entities/deep/nested/product/product.dart
    expect(
      content,
      contains(
        "import '../../../domain/entities/deep/nested/product/product.dart';",
      ),
    );

    // Verify skin components and logic (certified zuraffa_ui vocabulary)
    expect(
      content,
      contains('class ProductListWidget extends StatelessWidget'),
    );
    expect(content, contains('ZfaInput('));
    expect(content, contains('ZfaButton('));
    expect(content, contains('ZfaCard('));
    expect(content, contains("import 'package:zuraffa_ui/zuraffa_ui.dart';"));
    expect(content, isNot(contains('Shad')));
  });

  test('SkinPlugin generates form widget', () async {
    final plugin = SkinPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(dryRun: false, force: true),
    );

    // Create an entity
    final entityDir = Directory(
      path.join(outputDir, 'domain', 'entities', 'product'),
    );
    await entityDir.create(recursive: true);
    final entityFile = File(path.join(entityDir.path, 'product.dart'));
    await entityFile.writeAsString('''
class Product {
  final String id;
  final String name;
  final int stock;

  Product({required this.id, required this.name, required this.stock});
}
''');

    final context = PluginContext(
      core: CoreConfig(
        name: 'Product',
        projectRoot: tempDir.path,
        outputDir: 'lib/src',
      ),
      discovery: DiscoveryEngine(projectRoot: outputDir),
      data: {'layout': 'form'},
    );

    final results = await plugin.generateWithContext(context);

    expect(results, isNotEmpty);
    final content = File(results.first.path).readAsStringSync();

    expect(content, contains('class ProductFormWidget extends StatefulWidget'));
    expect(content, contains('ZfaInput('));
    expect(content, contains('ZfaButton('));
    expect(content, contains("placeholder: 'Id',"));
    expect(content, contains("placeholder: 'Name',"));
    expect(content, contains("placeholder: 'Stock',"));
    expect(
      content,
      contains("onChanged: (value) => _values['stock'] = value,"),
    );
    expect(
      content,
      contains('keyboardType: TextInputType.number'),
    ); // For int stock
    expect(content, isNot(contains('Shad')));
  });
}
