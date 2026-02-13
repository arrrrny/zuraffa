import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/entity_analyzer.dart';
import 'mock_data_builder.dart';
import 'mock_data_source_builder.dart';
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
  final bool dryRun;
  final bool force;
  final bool verbose;
  final SpecLibrary specLibrary;
  final MockDataBuilder dataBuilder;
  final MockDataSourceBuilder dataSourceBuilder;
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
  /// @param entityGraphBuilder Optional mock entity graph builder override.
  MockBuilder({
    required this.outputDir,
    GeneratorOptions options = const GeneratorOptions(),
    @Deprecated('Use options.dryRun') bool? dryRun,
    @Deprecated('Use options.force') bool? force,
    @Deprecated('Use options.verbose') bool? verbose,
    SpecLibrary? specLibrary,
    MockDataBuilder? dataBuilder,
    MockDataSourceBuilder? dataSourceBuilder,
    MockEntityGraphBuilder? entityGraphBuilder,
  }) : options = options.copyWith(
         dryRun: dryRun ?? options.dryRun,
         force: force ?? options.force,
         verbose: verbose ?? options.verbose,
       ),
       dryRun = dryRun ?? options.dryRun,
       force = force ?? options.force,
       verbose = verbose ?? options.verbose,
       specLibrary = specLibrary ?? const SpecLibrary(),
       dataBuilder =
           dataBuilder ??
           MockDataBuilder(
             outputDir: outputDir,
             dryRun: dryRun ?? options.dryRun,
             force: force ?? options.force,
             verbose: verbose ?? options.verbose,
             specLibrary: specLibrary ?? const SpecLibrary(),
           ),
       dataSourceBuilder =
           dataSourceBuilder ??
           MockDataSourceBuilder(
             outputDir: outputDir,
             dryRun: dryRun ?? options.dryRun,
             force: force ?? options.force,
             verbose: verbose ?? options.verbose,
             specLibrary: specLibrary ?? const SpecLibrary(),
           ),
       entityGraphBuilder =
           entityGraphBuilder ?? MockEntityGraphBuilder(outputDir: outputDir);

  /// Generates mock files for the given [config].
  ///
  /// @param config Generator configuration describing the entity and options.
  /// @returns List of generated mock files.
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    final files = <GeneratedFile>[];

    final subtypes = EntityAnalyzer.getPolymorphicSubtypes(
      config.name,
      outputDir,
    );
    final isPolymorphic = subtypes.isNotEmpty;

    if (!isPolymorphic) {
      files.add(await dataBuilder.generateMockDataFile(config));
    }

    files.addAll(
      await entityGraphBuilder.generateNestedEntityMockFiles(
        config: config,
        generateMockDataFile: dataBuilder.generateMockDataFile,
      ),
    );

    if (!config.generateMockDataOnly) {
      files.add(await dataSourceBuilder.generateMockDataSource(config));
    }

    return files;
  }
}
