import '../../../core/builder/shared/spec_library.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/entity_analyzer.dart';
import 'mock_data_builder.dart';
import 'mock_data_source_builder.dart';
import 'mock_entity_graph_builder.dart';

class MockBuilder {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final SpecLibrary specLibrary;
  final MockDataBuilder dataBuilder;
  final MockDataSourceBuilder dataSourceBuilder;
  final MockEntityGraphBuilder entityGraphBuilder;

  MockBuilder({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    SpecLibrary? specLibrary,
    MockDataBuilder? dataBuilder,
    MockDataSourceBuilder? dataSourceBuilder,
    MockEntityGraphBuilder? entityGraphBuilder,
  })  : specLibrary = specLibrary ?? const SpecLibrary(),
        dataBuilder = dataBuilder ??
            MockDataBuilder(
              outputDir: outputDir,
              dryRun: dryRun,
              force: force,
              verbose: verbose,
              specLibrary: specLibrary ?? const SpecLibrary(),
            ),
        dataSourceBuilder = dataSourceBuilder ??
            MockDataSourceBuilder(
              outputDir: outputDir,
              dryRun: dryRun,
              force: force,
              verbose: verbose,
              specLibrary: specLibrary ?? const SpecLibrary(),
            ),
        entityGraphBuilder = entityGraphBuilder ??
            MockEntityGraphBuilder(
              outputDir: outputDir,
            );

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
