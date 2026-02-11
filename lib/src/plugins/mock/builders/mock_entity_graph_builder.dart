import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/entity_analyzer.dart';
import 'mock_entity_helper.dart';

class MockEntityGraphBuilder {
  final String outputDir;
  final MockEntityHelper entityHelper;

  MockEntityGraphBuilder({
    required this.outputDir,
    MockEntityHelper? entityHelper,
  }) : entityHelper = entityHelper ?? const MockEntityHelper();

  Future<List<GeneratedFile>> generateNestedEntityMockFiles({
    required GeneratorConfig config,
    required Future<GeneratedFile> Function(GeneratorConfig) generateMockDataFile,
  }) async {
    final files = <GeneratedFile>[];
    final entityName = config.name;
    final entityFields = EntityAnalyzer.analyzeEntity(entityName, outputDir);
    final processedEntities = <String>{entityName};

    final subtypes = EntityAnalyzer.getPolymorphicSubtypes(
      entityName,
      outputDir,
    );

    for (final subtype in subtypes) {
      if (!processedEntities.contains(subtype)) {
        processedEntities.add(subtype);

        final subtypeConfig = GeneratorConfig(
          name: subtype,
          generateMockDataOnly: true,
        );
        files.add(await generateMockDataFile(subtypeConfig));

        final subtypeFields = EntityAnalyzer.analyzeEntity(subtype, outputDir);
        await _collectAndGenerateNestedEntities(
          subtypeFields,
          files,
          processedEntities,
          generateMockDataFile,
        );
      }
    }

    await _collectAndGenerateNestedEntities(
      entityFields,
      files,
      processedEntities,
      generateMockDataFile,
    );

    return files;
  }

  Future<void> _collectAndGenerateNestedEntities(
    Map<String, String> fields,
    List<GeneratedFile> files,
    Set<String> processedEntities,
    Future<GeneratedFile> Function(GeneratorConfig) generateMockDataFile,
  ) async {
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
          final subtypes = EntityAnalyzer.getPolymorphicSubtypes(
            baseType,
            outputDir,
          );
          if (subtypes.isNotEmpty) {
            processedEntities.add(baseType);

            for (final subtype in subtypes) {
              if (!processedEntities.contains(subtype)) {
                processedEntities.add(subtype);

                final subtypeConfig = GeneratorConfig(
                  name: subtype,
                  generateMockDataOnly: true,
                );
                files.add(await generateMockDataFile(subtypeConfig));

                final subtypeFields =
                    EntityAnalyzer.analyzeEntity(subtype, outputDir);
                await _collectAndGenerateNestedEntities(
                  subtypeFields,
                  files,
                  processedEntities,
                  generateMockDataFile,
                );
              }
            }
            continue;
          }

          final entityFields = EntityAnalyzer.analyzeEntity(
            baseType,
            outputDir,
          );
          if (entityFields.isNotEmpty &&
              !entityHelper.isDefaultFields(entityFields)) {
            processedEntities.add(baseType);

            final nestedConfig = GeneratorConfig(
              name: baseType,
              generateMockDataOnly: true,
            );
            files.add(await generateMockDataFile(nestedConfig));

            await _collectAndGenerateNestedEntities(
              entityFields,
              files,
              processedEntities,
              generateMockDataFile,
            );
          }
        }
      }
    }
  }
}
