import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/entity_analyzer.dart';
import '../../../utils/entity_utils.dart';
import 'mock_data_builder.dart';
import 'mock_datasource_builder.dart';
import 'mock_provider_builder.dart';
import 'mock_entity_graph_builder.dart';

/// Generates mock data builders for entities and their variants.
///
/// Creates realistic mock data for:
/// - Entity instances with randomized fields
/// - Entity lists with configurable sizes
/// - Polymorphic variant factories
///
/// Example:
/// ```dart
/// final mockProduct = MockProductBuilder()
///   .withName('Test Product')
///   .withPrice(99.99)
///   .build();
/// ```
class MockBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;
  final MockDataBuilder dataBuilder;
  final MockDataSourceBuilder dataSourceBuilder;
  final MockProviderBuilder providerBuilder;
  final MockEntityGraphBuilder entityGraphBuilder;

  /// Creates a [MockBuilder].
  ///
  /// @param outputDir Target directory for generated files.
  /// @param options Generation flags for writing behavior and logging.
  /// @param dryRun Deprecated: use [options].
  /// @param force Deprecated: use [options].
  /// @param verbose Deprecated: use [options].
  /// @param specLibrary Optional spec library override.
  /// @param dataBuilder Optional mock data builder override.
  /// @param dataSourceBuilder Optional mock data source builder override.
  /// @param providerBuilder Optional mock provider builder override.
  /// @param entityGraphBuilder Optional mock entity graph builder override.
  MockBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    SpecLibrary? specLibrary,
    MockDataBuilder? dataBuilder,
    MockDataSourceBuilder? dataSourceBuilder,
    MockProviderBuilder? providerBuilder,
    MockEntityGraphBuilder? entityGraphBuilder,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       dataBuilder =
           dataBuilder ??
           MockDataBuilder(
             outputDir: outputDir,
             options: options,
             specLibrary: specLibrary ?? const SpecLibrary(),
           ),
       dataSourceBuilder =
           dataSourceBuilder ??
           MockDataSourceBuilder(
             outputDir: outputDir,
             options: options,
             specLibrary: specLibrary ?? const SpecLibrary(),
           ),
       providerBuilder =
           providerBuilder ??
           MockProviderBuilder(
             outputDir: outputDir,
             options: options,
             specLibrary: specLibrary ?? const SpecLibrary(),
           ),
       entityGraphBuilder =
           entityGraphBuilder ??
           MockEntityGraphBuilder(outputDir: outputDir, options: options);

  /// Generates mock files for the given [config].
  ///
  /// @param config Generator configuration describing the entity and options.
  /// @returns List of generated mock files.
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    final files = <GeneratedFile>[];

    final targetEntity = config.isCustomUseCase && config.returnsType != null
        ? EntityUtils.extractEntityTypes(config.returnsType!).firstOrNull ??
              config.name
        : config.name;

    final subtypes = EntityAnalyzer.getPolymorphicSubtypes(
      targetEntity,
      outputDir,
    );
    final isPolymorphic = subtypes.isNotEmpty;

    if (!isPolymorphic) {
      final dataConfig = config.name == targetEntity
          ? config
          : config.copyWith(name: targetEntity);
      files.add(await dataBuilder.generateMockDataFile(dataConfig));
    }

    files.addAll(
      await entityGraphBuilder.generateNestedEntityMockFiles(
        config: config.name == targetEntity
            ? config
            : config.copyWith(name: targetEntity),
        generateMockDataFile: dataBuilder.generateMockDataFile,
      ),
    );

    if (!config.generateMockDataOnly) {
      if (!config.hasService) {
        files.add(await dataSourceBuilder.generateMockDataSource(config));
      }
      if (config.hasService) {
        files.add(await providerBuilder.generateMockProvider(config));
      }
    }

    return files;
  }
}
