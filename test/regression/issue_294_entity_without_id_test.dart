// Regression tests for issue #294.
//
// Gap 1: Generators hardcoded `EntityFields.id` regardless of the entity's
//        actual fields, breaking entities like `StorePrice` whose id field
//        is `depotId`. The fix wires `MakeCommand` to auto-resolve the
//        id-like field via `EntityFieldResolver` and feed the resolved
//        name through `context.data['id-field']` / `context.data['query-field']`.
//        Plugins already read those keys with `?? 'id'` so the resolved
//        name propagates without further plugin changes.
//
// Gap 2: `mock_plugin.dart` defaulted `methods` to `[]` (unlike the
//        di/usecase/test/state/controller/datasource/repository plugins,
//        which default to `['get', 'update', 'toggle']`). An empty methods
//        list produced an empty mock datasource class that failed
//        `implements` with `non_abstract_class_inherits_abstract_member`.
//        The fix mirrors the other plugins' default.

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_context.dart';
import 'package:zuraffa/src/core/plugin_system/discovery_engine.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';
import 'package:zuraffa/src/utils/entity_field_resolver.dart';

import '../regression/regression_test_utils.dart';

void main() {
  late RegressionWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('issue_294_entity_without_id');
    await writePubspec(workspace);
    await runFlutterPubGet(workspace);
    outputDir = workspace.outputDir;
  });

  // ---------------------------------------------------------------------------
  // Gap 1 regression: entity WITHOUT an `id` field
  // ---------------------------------------------------------------------------

  group('#294 Gap 1 — entity without `id` field', () {
    test(
      'resolver finds `depotId` for StorePrice (no `id` declared)',
      () async {
        await writeEntityStubWithoutId(
          workspace,
          name: 'StorePrice',
          fields: const [
            (name: 'depotId', type: 'String'),
            (name: 'storeName', type: 'String'),
            (name: 'price', type: 'double'),
          ],
        );

        final resolved = EntityFieldResolver.resolveIdField(
          entityName: 'StorePrice',
          projectRoot: workspace.directory.path,
        );

        expect(
          resolved,
          isNotNull,
          reason: 'Resolver should find depotId for StorePrice',
        );
        expect(resolved!.idField!.name, 'depotId');
        expect(resolved.idField!.type, 'String');
      },
    );

    test('generated presenter + test reference `StorePriceFields.depotId`, '
        'NOT `StorePriceFields.id`', () async {
      await writeEntityStubWithoutId(
        workspace,
        name: 'StorePrice',
        fields: const [
          (name: 'depotId', type: 'String'),
          (name: 'storeName', type: 'String'),
          (name: 'price', type: 'double'),
        ],
      );

      // Simulate what MakeCommand.run() does after the resolver
      // resolves `depotId`: feed the resolved name into GeneratorConfig.
      // This is exactly the shape the MakeCommand now produces.
      final generator = CodeGenerator(
        config: GeneratorConfig(
          name: 'StorePrice',
          methods: const ['get', 'update', 'toggle'],
          idField: 'depotId',
          idFieldType: 'String',
          queryField: 'depotId',
          generateData: true,
          generateLocal: true,
          generateUseCase: true,
          generateVpcs: true,
          generateState: true,
          generateDi: true,
          generateTest: true,
          outputDir: outputDir,
        ),
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );

      final result = await generator.generate();
      expect(
        result.success,
        isTrue,
        reason: 'Generation failed: ${result.errors.join('; ')}',
      );

      // The presenter's toggle method must reference the actual id field.
      final presenterFile = File(
        '$outputDir/presentation/pages/store_price/store_price_presenter.dart',
      );
      expect(
        presenterFile.existsSync(),
        isTrue,
        reason: 'store_price_presenter.dart should be generated',
      );
      final presenterContent = presenterFile.readAsStringSync();

      // Positive: the generated toggle code must use `StorePriceFields.depotId`
      expect(
        presenterContent,
        contains('StorePriceFields.depotId'),
        reason: 'Presenter should reference StorePriceFields.depotId',
      );

      // Negative: the generated code must NOT reference `StorePriceFields.id`
      // (which would be an undefined getter on the StorePriceFields class).
      expect(
        presenterContent,
        isNot(contains('StorePriceFields.id')),
        reason:
            'Presenter should NOT reference StorePriceFields.id '
            '(undefined getter on an entity without `id`)',
      );

      // Same check for the toggle usecase test file.
      final toggleTestFile = File(
        '${workspace.directory.path}/test/domain/usecases/store_price/'
        'toggle_store_price_usecase_test.dart',
      );
      expect(
        toggleTestFile.existsSync(),
        isTrue,
        reason: 'toggle_store_price_usecase_test.dart should be generated',
      );
      final testContent = toggleTestFile.readAsStringSync();

      expect(
        testContent,
        contains('StorePriceFields.depotId'),
        reason: 'Toggle test should reference StorePriceFields.depotId',
      );
      expect(
        testContent,
        isNot(contains('StorePriceFields.id')),
        reason: 'Toggle test should NOT reference StorePriceFields.id',
      );

      // Same check for the get usecase test file.
      final getTestFile = File(
        '${workspace.directory.path}/test/domain/usecases/store_price/'
        'get_store_price_usecase_test.dart',
      );
      expect(
        getTestFile.existsSync(),
        isTrue,
        reason: 'get_store_price_usecase_test.dart should be generated',
      );
      final getContent = getTestFile.readAsStringSync();

      expect(
        getContent,
        contains('StorePriceFields.depotId'),
        reason: 'Get test should reference StorePriceFields.depotId',
      );
      expect(
        getContent,
        isNot(contains('StorePriceFields.id')),
        reason: 'Get test should NOT reference StorePriceFields.id',
      );
    });

    test('resolver picks the first `*Id` field when multiple exist '
        '(GroceryPriceResult has storeId + itemName — storeId wins)', () async {
      await writeEntityStubWithoutId(
        workspace,
        name: 'GroceryPriceResult',
        fields: const [
          (name: 'storeId', type: 'String'),
          (name: 'itemName', type: 'String'),
          (name: 'price', type: 'double'),
        ],
      );

      final resolved = EntityFieldResolver.resolveIdField(
        entityName: 'GroceryPriceResult',
        projectRoot: workspace.directory.path,
      );

      expect(resolved, isNotNull);
      expect(resolved!.idField!.name, 'storeId');
    });
  });

  // ---------------------------------------------------------------------------
  // Gap 2 regression: mock plugin default methods
  // ---------------------------------------------------------------------------

  group('#294 Gap 2 — mock plugin default methods', () {
    test("mock_plugin.generateWithContext emits get/update/toggle methods when "
        "the user does NOT pass --methods (so the generated mock datasource "
        "is not an empty class)", () async {
      // Set up a Product entity file so the workspace looks like a
      // real `zfa make` invocation. The mock plugin itself does not
      // read the entity file, but the test is more realistic this way.
      await writeEntityStub(workspace, name: 'Product');

      // Build a plugin context with NO `methods` entry in `data`,
      // simulating `zfa make Product --preset=crud --with=mock` without
      // an explicit `--methods` flag.
      final context = _buildMockContext(
        workspace: workspace,
        entityName: 'Product',
        methods: null, // simulate "user did not pass --methods"
      );

      final plugin = MockPlugin(
        outputDir: workspace.outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final files = await plugin.generateWithContext(context);

      // The mock datasource file must be emitted.
      final mockDataSourceFile = files.firstWhere(
        (f) => f.path.contains('product_mock_datasource.dart'),
        orElse: () => throw StateError(
          'mock datasource file not generated; '
          'emitted files: ${files.map((f) => f.path).join(', ')}',
        ),
      );

      final content = mockDataSourceFile.content;

      // Positive: the class must implement get, update, AND toggle.
      // The mock datasource builder emits these as `Future<...> get(...)`,
      // `Future<...> update(...)`, `Future<...> toggle(...)`.
      expect(
        content,
        matches(RegExp(r'Future<\w+>\s+get\s*\(')),
        reason: 'Mock datasource must implement the `get` method',
      );
      expect(
        content,
        matches(RegExp(r'Future<\w+>\s+update\s*\(')),
        reason: 'Mock datasource must implement the `update` method',
      );
      expect(
        content,
        matches(RegExp(r'Future<\w+>\s+toggle\s*\(')),
        reason: 'Mock datasource must implement the `toggle` method',
      );
    });

    test('mock_plugin still respects an explicit `--methods` override '
        '(backwards compatibility)', () async {
      await writeEntityStub(workspace, name: 'Order');

      final context = _buildMockContext(
        workspace: workspace,
        entityName: 'Order',
        methods: ['get', 'getList'],
      );

      final plugin = MockPlugin(
        outputDir: workspace.outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final files = await plugin.generateWithContext(context);

      final mockDataSourceFile = files.firstWhere(
        (f) => f.path.contains('order_mock_datasource.dart'),
      );

      final content = mockDataSourceFile.content;

      // Positive: explicitly-requested methods must be present.
      expect(content, matches(RegExp(r'Future<\w+>\s+get\s*\(')));
      expect(content, matches(RegExp(r'Future<.+>\s+getList\s*\(')));

      // Negative: `toggle` was NOT in the explicit methods list, so the
      // mock datasource must NOT implement it (else `implements` would
      // require it to be present and we'd be back to the original bug).
      expect(
        content,
        isNot(matches(RegExp(r'Future<\w+>\s+toggle\s*\('))),
        reason: 'toggle should not be emitted when not requested',
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Writes an entity file WITHOUT an `id` field — mimics what
/// `zfa entity create -n X --field depotId:String` produces (a Zorphy
/// abstract class with `Type get fieldName;` getters). Also writes a
/// matching `<Name>Fields` class so the generated code can reference
/// `<Name>Fields.<fieldName>` constants.
Future<void> writeEntityStubWithoutId(
  RegressionWorkspace workspace, {
  required String name,
  required List<({String name, String type})> fields,
}) async {
  final entitySnake = _toSnake(name);
  final entityDir = Directory(
    path.join(workspace.outputDir, 'domain', 'entities', entitySnake),
  );
  await entityDir.create(recursive: true);
  final entityFile = File(path.join(entityDir.path, '$entitySnake.dart'));

  final buffer = StringBuffer()
    ..writeln('// Auto-generated entity stub for regression test (#294).')
    ..writeln()
    ..writeln('abstract class \$$name {');

  for (final f in fields) {
    buffer.writeln('  ${f.type} get ${f.name};');
  }
  buffer
    ..writeln('}')
    ..writeln();

  // Stub `<Name>Fields` class with Field constants for each declared field.
  // The mock datasource / presenter / test generators reference these.
  buffer.writeln('abstract final class ${name}Fields {');
  for (final f in fields) {
    buffer.writeln(
      "  static const Field<$name, ${f.type}> ${f.name} = "
      "Field<$name, ${f.type}>(name: '${f.name}');",
    );
  }
  buffer.writeln('}');

  await entityFile.writeAsString(buffer.toString());
}

/// Builds a minimal `PluginContext` for the mock plugin, mirroring what
/// `MakeCommand.buildContext` produces. Only the fields the mock plugin
/// actually reads are populated.
PluginContext _buildMockContext({
  required RegressionWorkspace workspace,
  required String entityName,
  required List<String>? methods,
}) {
  // Build the data map separately to keep the null-aware insert readable.
  final data = <String, dynamic>{
    'mock': true,
    'generate-mock': true,
    // #294: the mock plugin only emits a mock datasource when at least
    // one of data/datasource/repository is also requested (otherwise it
    // has nothing to mock). `--with=mock` in `zfa make` always co-occurs
    // with at least one of these via `--preset=crud`.
    'data': true,
    'datasource': true,
  };
  if (methods != null) {
    data['methods'] = methods;
  }

  return PluginContext(
    core: CoreConfig(
      name: entityName,
      projectRoot: workspace.directory.path,
      outputDir: workspace.outputDir,
      dryRun: false,
      force: true,
      verbose: false,
      revert: false,
    ),
    data: data,
    discovery: DiscoveryEngine(projectRoot: workspace.directory.path),
  );
}

String _toSnake(String input) {
  final result = <String>[];
  for (var i = 0; i < input.length; i += 1) {
    final char = input[i];
    if (i > 0 && char.toUpperCase() == char && char != '_') {
      result.add('_');
    }
    result.add(char.toLowerCase());
  }
  return result.join('');
}
