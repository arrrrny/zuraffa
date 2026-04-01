import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../core/context/file_system.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/entity_analyzer.dart';
import '../../../utils/entity_utils.dart';
import 'mock_data_builder.dart';
import 'mock_datasource_builder.dart';
import 'mock_provider_builder.dart';
import 'mock_entity_graph_builder.dart';

/// Generates mock data builders for entities and their variants.
class MockBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;
  final MockDataBuilder dataBuilder;
  final MockDataSourceBuilder dataSourceBuilder;
  final MockProviderBuilder providerBuilder;
  final MockEntityGraphBuilder entityGraphBuilder;
  final FileSystem fileSystem;

  /// Creates a [MockBuilder].
  MockBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    SpecLibrary? specLibrary,
    MockDataBuilder? dataBuilder,
    MockDataSourceBuilder? dataSourceBuilder,
    MockProviderBuilder? providerBuilder,
    MockEntityGraphBuilder? entityGraphBuilder,
    FileSystem? fileSystem,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       fileSystem = fileSystem ?? FileSystem.create(root: outputDir),
       dataBuilder =
           dataBuilder ??
           MockDataBuilder(
             outputDir: outputDir,
             options: options,
             specLibrary: specLibrary ?? const SpecLibrary(),
             fileSystem: fileSystem ?? FileSystem.create(root: outputDir),
           ),
       dataSourceBuilder =
           dataSourceBuilder ??
           MockDataSourceBuilder(
             outputDir: outputDir,
             options: options,
             specLibrary: specLibrary ?? const SpecLibrary(),
             fileSystem: fileSystem ?? FileSystem.create(root: outputDir),
           ),
       providerBuilder =
           providerBuilder ??
           MockProviderBuilder(
             outputDir: outputDir,
             options: options,
             specLibrary: specLibrary ?? const SpecLibrary(),
             fileSystem: fileSystem ?? FileSystem.create(root: outputDir),
           ),
       entityGraphBuilder =
           entityGraphBuilder ??
           MockEntityGraphBuilder(
             outputDir: outputDir,
             options: options,
             fileSystem: fileSystem ?? FileSystem.create(root: outputDir),
           );

  /// Generates mock files for the given [config].
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    final files = <GeneratedFile>[];

    final targetEntity = config.isCustomUseCase && config.returnsType != null
        ? EntityUtils.extractEntityTypes(config.returnsType!).firstOrNull ??
              config.name
        : config.name;

    final subtypes = EntityAnalyzer.getPolymorphicSubtypes(
      targetEntity,
      outputDir,
      fileSystem: fileSystem,
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
