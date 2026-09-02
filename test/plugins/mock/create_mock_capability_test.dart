import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/mock/capabilities/create_mock_capability.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;
  late MockPlugin plugin;
  late CreateMockCapability capability;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_mock_create_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
    final entityDir = Directory('$outputDir/domain/entities/product');
    entityDir.createSync(recursive: true);
    File('${entityDir.path}/product.dart').writeAsStringSync(
      'class Product { final String id; final String name; const Product(this.id, this.name); }',
    );
    plugin = MockPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(dryRun: false, force: true),
    );
    capability = CreateMockCapability(plugin);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.delete(recursive: true);
    }
  });

  // Issue #770: `zfa mock create --name X` (and the positional `zfa mock X`)
  // both funnel into MockPlugin with an explicit mock request
  // (`generateMock: true`) and no data-layer flags. The plugin's stale
  // presentation-only gate then returned [] — zero files, no warning, exit 0
  // — even though the user explicitly asked for mocks. The builder itself is
  // standalone-safe: since #417 the mock-datasource path emits the missing
  // datasource interface itself, and the data-only path has always
  // generated. An explicit mock request must always generate. And the
  // capability must default to the canonical CRUD method set (#294) so the
  // emitted mock datasource actually satisfies the interface it implements.
  group('issue #770 — explicit mock request is never a silent no-op', () {
    test(
        'capability: minimal invocation generates mock artifacts (canonical methods)',
        () async {
      final result = await capability.execute({'name': 'Product'});

      expect(result.success, isTrue);
      expect(result.files, isNotEmpty);
      expect(
        result.files
            .any((p) => p.endsWith('data/mock/product_mock_data.dart')),
        isTrue,
        reason: 'the mock data artifact for the entity is generated',
      );
      expect(
        result.files.any(
            (p) => p.endsWith('data/datasources/product/product_mock_datasource.dart') ||
                p.endsWith('data/mock/product_mock_provider.dart')),
        isTrue,
        reason: 'the mock datasource (or provider) artifact is generated',
      );
    });

    test(
        'capability: emitted mock datasource implements the interface members',
        () async {
      final result = await capability.execute({'name': 'Product'});
      final generated = result.data?['generatedFiles'] as List<dynamic>;

      final mockDatasources = generated
          .where(
            (f) => f.path
                .endsWith('data/datasources/product/product_mock_datasource.dart'),
          )
          .toList();
      if (mockDatasources.isNotEmpty) {
        final mockDatasource = mockDatasources.first;
        expect(mockDatasource.content, contains('get'));
        expect(mockDatasource.content, contains('update'),
            reason:
                'with the canonical method set the mock datasource must '
                'provide concrete implementations, otherwise analyze fails '
                'with non_abstract_class_inherits_abstract_member (#294)');
      }
    });

    test('capability: schema methods default is the canonical CRUD set', () {
      final props =
          capability.inputSchema['properties'] as Map<String, dynamic>;
      expect((props['methods'] as Map<String, dynamic>)['default'],
          ['get', 'update', 'toggle']);
    });

    test(
        'plugin: generateMock without any data-layer flags generates the mock artifacts',
        () async {
      final files = await plugin.generate(
        GeneratorConfig(
          name: 'Product',
          methods: const ['get', 'update', 'toggle'],
          generateMock: true,
          generateData: false,
          generateDataSource: false,
          generateRepository: false,
          appendToExisting: false,
          outputDir: outputDir,
        ),
      );

      expect(files, isNotEmpty,
          reason: 'an explicit mock request must not silently generate nothing');
      expect(
        files.any((f) => f.path.endsWith('data/mock/product_mock_data.dart')),
        isTrue,
      );
    });

    test('plugin: generateMockDataOnly keeps generating the standalone fixtures',
        () async {
      final files = await plugin.generate(
        GeneratorConfig(
          name: 'Product',
          methods: const [],
          generateMock: false,
          generateMockDataOnly: true,
          generateData: false,
          generateDataSource: false,
          generateRepository: false,
          appendToExisting: false,
          outputDir: outputDir,
        ),
      );

      expect(files, isNotEmpty);
      expect(
        files.any((f) => f.path.endsWith('data/mock/product_mock_data.dart')),
        isTrue,
      );
    });

    test('plugin: generated artifacts are written to disk', () async {
      final files = await plugin.generate(
        GeneratorConfig(
          name: 'Product',
          methods: const ['get', 'update', 'toggle'],
          generateMock: true,
          generateData: false,
          generateDataSource: false,
          generateRepository: false,
          appendToExisting: false,
          outputDir: outputDir,
        ),
      );

      expect(files, isNotEmpty);
      for (final file in files) {
        expect(File(file.path).existsSync(), isTrue,
            reason: '${file.path} must be written');
      }
    });
  });
}
