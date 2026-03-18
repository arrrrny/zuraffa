import '../../../core/generator_options.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/entity_analyzer.dart';
import 'mock_entity_helper.dart';

class MockEntityGraphBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final MockEntityHelper entityHelper;

  MockEntityGraphBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    MockEntityHelper? entityHelper,
  }) : entityHelper = entityHelper ?? const MockEntityHelper();

  Future<List<GeneratedFile>> generateNestedEntityMockFiles({
    required GeneratorConfig config,
    required Future<GeneratedFile> Function(GeneratorConfig)
    generateMockDataFile,
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
          outputDir: outputDir,
          revert: config.revert,
          force: config.force,
          verbose: config.verbose,
        );
        files.add(await generateMockDataFile(subtypeConfig));

        final subtypeFields = EntityAnalyzer.analyzeEntity(subtype, outputDir);
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
                  outputDir: outputDir,
                  revert: revert,
                  force: force,
                  verbose: verbose,
                );
                files.add(await generateMockDataFile(subtypeConfig));

                final subtypeFields = EntityAnalyzer.analyzeEntity(
                  subtype,
                  outputDir,
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

          final entityFields = EntityAnalyzer.analyzeEntity(
            baseType,
            outputDir,
          );
          if ((entityFields.isNotEmpty &&
                  !entityHelper.isDefaultFields(entityFields)) ||
              EntityAnalyzer.isEnum(baseType, outputDir)) {
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

            if (!EntityAnalyzer.isEnum(baseType, outputDir)) {
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
        }
      }
    }
  }
}
