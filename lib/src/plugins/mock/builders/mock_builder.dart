import 'package:path/path.dart' as path;

import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../core/context/file_system.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/entity_analyzer.dart';
import '../../../utils/entity_utils.dart';
import '../../../utils/string_utils.dart';
import '../../datasource/builders/interface_generator.dart';
import 'mock_data_builder.dart';
import 'mock_datasource_builder.dart';
import 'mock_provider_builder.dart';
import 'mock_entity_graph_builder.dart';
import 'mock_json_builder.dart';

/// Generates mock data builders for entities and their variants.
class MockBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;
  final MockDataBuilder dataBuilder;
  final MockDataSourceBuilder dataSourceBuilder;
  // #417: emits the `${entitySnake}_datasource.dart` interface file when
  // MockBuilder runs without the datasource plugin active. The mock
  // datasource file always imports + implements `${entityName}DataSource`;
  // without the interface file the generated code is broken
  // (uri_does_not_exist + implements_non_class).
  final DataSourceInterfaceBuilder interfaceBuilder;
  final MockProviderBuilder providerBuilder;
  final MockEntityGraphBuilder entityGraphBuilder;
  final MockJsonBuilder jsonBuilder;
  final FileSystem fileSystem;

  /// Creates a [MockBuilder].
  MockBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    SpecLibrary? specLibrary,
    MockDataBuilder? dataBuilder,
    MockDataSourceBuilder? dataSourceBuilder,
    DataSourceInterfaceBuilder? interfaceBuilder,
    MockProviderBuilder? providerBuilder,
    MockEntityGraphBuilder? entityGraphBuilder,
    MockJsonBuilder? jsonBuilder,
    FileSystem? fileSystem,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       fileSystem = fileSystem ?? FileSystem.create(),
       dataBuilder =
           dataBuilder ??
           MockDataBuilder(
             outputDir: outputDir,
             options: options,
             specLibrary: specLibrary ?? const SpecLibrary(),
             fileSystem: fileSystem ?? FileSystem.create(),
           ),
       dataSourceBuilder =
           dataSourceBuilder ??
           MockDataSourceBuilder(
             outputDir: outputDir,
             options: options,
             specLibrary: specLibrary ?? const SpecLibrary(),
             fileSystem: fileSystem ?? FileSystem.create(),
           ),
       interfaceBuilder =
           interfaceBuilder ??
           DataSourceInterfaceBuilder(
             outputDir: outputDir,
             options: options,
             fileSystem: fileSystem ?? FileSystem.create(),
           ),
       providerBuilder =
           providerBuilder ??
           MockProviderBuilder(
             outputDir: outputDir,
             options: options,
             specLibrary: specLibrary ?? const SpecLibrary(),
             fileSystem: fileSystem ?? FileSystem.create(),
           ),
       entityGraphBuilder =
           entityGraphBuilder ??
           MockEntityGraphBuilder(
             outputDir: outputDir,
             options: options,
             fileSystem: fileSystem ?? FileSystem.create(),
           ),
       jsonBuilder =
           jsonBuilder ??
           MockJsonBuilder(
             outputDir: outputDir,
             options: options,
             fileSystem: fileSystem ?? FileSystem.create(),
           );

  /// Generates mock files for the given [config].
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (config.generateMockJson) {
      return jsonBuilder.generate(config);
    }

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
    final entityExists = EntityAnalyzer.entityFileExists(
      targetEntity,
      outputDir,
      fileSystem: fileSystem,
    );

    if (!isPolymorphic) {
      final requiresConcreteEntity =
          config.generateMockDataOnly ||
          (config.name == targetEntity &&
              !config.isCustomUseCase &&
              !config.hasService);
      final dataConfig = config.name == targetEntity
          ? config
          : config.copyWith(name: targetEntity);

      if (!entityExists) {
        if (requiresConcreteEntity) {
          throw StateError(
            'Entity file not found for $targetEntity. '
            'Expected to find a Dart entity declaration under '
            '$outputDir/domain/entities.',
          );
        }

        files.add(await dataBuilder.generateMockDataFile(dataConfig));
      } else if (EntityAnalyzer.isSealedEntity(
        targetEntity,
        outputDir,
        fileSystem: fileSystem,
      )) {
        print(
          '⚠️  No concrete polymorphic subtypes found for sealed entity '
          '$targetEntity. Skipping mock data generation for the base type.',
        );
      } else {
        files.add(await dataBuilder.generateMockDataFile(dataConfig));
      }
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
      // Issue #1037: an enum entity is a value type — no id, no Patch, no
      // copyWithField — so the class-shaped CRUD datasource/provider
      // surface cannot compile against it (the entity lives under
      // entities/enums/, not the canonical class path). The mock-data
      // section above already emitted enum-value fixtures; emitting the
      // stack here produces the #1037 lie the `zfa build` analyzer gate
      // then correctly refuses, dead-ending every `zfa tdd` feature that
      // traces the enum as a Key Entity.
      if (EntityAnalyzer.isEnum(
        targetEntity,
        outputDir,
        fileSystem: fileSystem,
      )) {
        print(
          'ℹ️  $targetEntity is an enum entity — mock data generated; '
          'skipping the CRUD datasource/provider surface (issue #1037).',
        );
        return files;
      }
      if (!config.hasService) {
        // #417: ensure the datasource interface file exists before emitting
        // the mock_datasource that imports + implements
        // `${entityName}DataSource`. Without the interface file the
        // generated mock_datasource triggers uri_does_not_exist +
        // implements_non_class when the datasource plugin is NOT active
        // (e.g. `zfa make X mock repository` without `datasource`).
        //
        // The check is file-existence-based (not plugin-active-based) so it
        // works regardless of plugin execution order:
        //   * DataSourcePlugin ran first → file exists → skip (no conflict).
        //   * RepositoryPlugin's #406 fallback ran first → file exists → skip.
        //   * MockPlugin runs first / alone → file missing → MockBuilder
        //     emits it here.
        final interfaceEntityName = config.repo != null
            ? config.repo!.replaceAll('Repository', '')
            : config.name;
        final interfaceSnake = StringUtils.camelToSnake(interfaceEntityName);
        final interfacePath = path.join(
          outputDir,
          'data',
          'datasources',
          interfaceSnake,
          '${interfaceSnake}_datasource.dart',
        );
        if (!await fileSystem.exists(interfacePath)) {
          files.add(await interfaceBuilder.generate(config));
        }
        files.add(await dataSourceBuilder.generateMockDataSource(config));
      }
      if (config.hasService) {
        files.add(await providerBuilder.generateMockProvider(config));
      }
    }

    return files;
  }
}
