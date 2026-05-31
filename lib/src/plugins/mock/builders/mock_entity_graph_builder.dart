import '../../../core/generator_options.dart';
import '../../../core/context/file_system.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/entity_analyzer.dart';
import 'mock_entity_helper.dart';

class MockEntityGraphBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final MockEntityHelper entityHelper;
  final FileSystem fileSystem;

  MockEntityGraphBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    MockEntityHelper? entityHelper,
    FileSystem? fileSystem,
  }) : entityHelper = entityHelper ?? const MockEntityHelper(),
       fileSystem = fileSystem ?? FileSystem.create();

  Future<List<GeneratedFile>> generateNestedEntityMockFiles({
    required GeneratorConfig config,
    required Future<GeneratedFile> Function(GeneratorConfig)
    generateMockDataFile,
  }) async {
    final files = <GeneratedFile>[];
    final entityName = config.name;
    final entityFields = EntityAnalyzer.analyzeEntity(
      entityName,
      outputDir,
      fileSystem: fileSystem,
    );
    final processedEntities = <String>{entityName};

    final subtypes = EntityAnalyzer.getPolymorphicSubtypes(
      entityName,
      outputDir,
      fileSystem: fileSystem,
    );

    for (final subtype in subtypes) {
      if (!processedEntities.contains(subtype)) {
        processedEntities.add(subtype);

        final subtypeConfig = GeneratorConfig(
          name: subtype,
          generateMockDataOnly: true,
          outputDir: outputDir,
          revert: config.revert,
          force: config.force,
          verbose: config.verbose,
        );
        files.add(await generateMockDataFile(subtypeConfig));

        final subtypeFields = EntityAnalyzer.analyzeEntity(
          subtype,
          outputDir,
          fileSystem: fileSystem,
        );
        await _collectAndGenerateNestedEntities(
          subtypeFields,
          files,
          processedEntities,
          generateMockDataFile,
          revert: config.revert,
          force: config.force,
          verbose: config.verbose,
        );
      }
    }

    await _collectAndGenerateNestedEntities(
      entityFields,
      files,
      processedEntities,
      generateMockDataFile,
      revert: config.revert,
      force: config.force,
      verbose: config.verbose,
    );

    return files;
  }

  Future<void> _collectAndGenerateNestedEntities(
    Map<String, String> fields,
    List<GeneratedFile> files,
    Set<String> processedEntities,
    Future<GeneratedFile> Function(GeneratorConfig) generateMockDataFile, {
    required bool revert,
    required bool force,
    required bool verbose,
  }) async {
    for (final entry in fields.entries) {
      final fieldType = entry.value;
      final baseTypes = entityHelper.extractEntityTypesFromField(fieldType);

      for (final baseType in baseTypes) {
        if (baseType.isNotEmpty &&
            baseType[0] == baseType[0].toUpperCase() &&
            ![
              'String',
              'int',
              'double',
              'bool',
              'DateTime',
              'Object',
              'dynamic',
            ].contains(baseType) &&
            !processedEntities.contains(baseType)) {
          try {
            final subtypes = EntityAnalyzer.getPolymorphicSubtypes(
              baseType,
              outputDir,
              fileSystem: fileSystem,
            );
            if (subtypes.isNotEmpty) {
              processedEntities.add(baseType);

              for (final subtype in subtypes) {
                if (!processedEntities.contains(subtype)) {
                  processedEntities.add(subtype);

                  final subtypeConfig = GeneratorConfig(
                    name: subtype,
                    generateMockDataOnly: true,
                    outputDir: outputDir,
                    revert: revert,
                    force: force,
                    verbose: verbose,
                  );
                  files.add(await generateMockDataFile(subtypeConfig));

                  final subtypeFields = EntityAnalyzer.analyzeEntity(
                    subtype,
                    outputDir,
                    fileSystem: fileSystem,
                  );
                  await _collectAndGenerateNestedEntities(
                    subtypeFields,
                    files,
                    processedEntities,
                    generateMockDataFile,
                    revert: revert,
                    force: force,
                    verbose: verbose,
                  );
                }
              }
              continue;
            }

            final isEnum = EntityAnalyzer.isEnum(
              baseType,
              outputDir,
              fileSystem: fileSystem,
            );
            if (!isEnum &&
                !EntityAnalyzer.entityFileExists(
                  baseType,
                  outputDir,
                  fileSystem: fileSystem,
                )) {
              throw StateError('Entity file not found');
            }

            final entityFields = EntityAnalyzer.analyzeEntity(
              baseType,
              outputDir,
              fileSystem: fileSystem,
            );
            if ((entityFields.isNotEmpty &&
                    !entityHelper.isDefaultFields(entityFields)) ||
                isEnum) {
              processedEntities.add(baseType);

              final nestedConfig = GeneratorConfig(
                name: baseType,
                generateMockDataOnly: true,
                outputDir: outputDir,
                revert: revert,
                force: force,
                verbose: verbose,
              );
              files.add(await generateMockDataFile(nestedConfig));

              if (!isEnum) {
                await _collectAndGenerateNestedEntities(
                  entityFields,
                  files,
                  processedEntities,
                  generateMockDataFile,
                  revert: revert,
                  force: force,
                  verbose: verbose,
                );
              }
            }
          } catch (error) {
            print(
              '⚠️  Unable to resolve nested entity type $baseType '
              'for field ${entry.key}: $error',
            );
            continue;
          }
        }
      }
    }
  }
}
