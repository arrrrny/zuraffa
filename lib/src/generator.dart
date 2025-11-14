import 'json_parser.dart';
import 'entity_generator.dart';
import 'build_runner.dart';
import 'file_writer.dart';

/// Main generator that orchestrates the entire code generation pipeline
///
/// JSON → EntitySchema → Morphy Entities → build_runner → Generated classes
class ZuraffaGenerator {
  final String projectPath;
  late final JsonParser _jsonParser;
  late final MorphyEntityGenerator _entityGenerator;
  late final BuildRunnerManager _buildRunner;
  late final FileWriter _fileWriter;

  ZuraffaGenerator(this.projectPath) {
    _jsonParser = JsonParser();
    _entityGenerator = MorphyEntityGenerator();
    _buildRunner = BuildRunnerManager(projectPath);
    _fileWriter = FileWriter(projectPath);
  }

  /// Generate entities from JSON file
  /// Full pipeline: JSON → Entities → build_runner → Done
  Future<GenerationResult> generateFromJson(
    Map<String, dynamic> json, {
    String? entityName,
    bool runBuildRunner = true,
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('📊 Parsing JSON...');

    // Step 1: Parse JSON to schema
    final schema = _jsonParser.parseJson(json, entityName: entityName);
    onProgress?.call('✓ Detected ${schema.nestedEntities.length + 1} entities');

    // Step 2: Generate entity files
    onProgress?.call('📝 Generating Morphy entities...');
    final entityFiles = _entityGenerator.generateAllEntities(schema);

    // Step 3: Write files
    onProgress?.call('💾 Writing files...');
    final writtenFiles = await _fileWriter.writeFiles(entityFiles);
    onProgress?.call('✓ Wrote ${writtenFiles.length} entity files');

    for (final file in writtenFiles) {
      onProgress?.call('  - $file');
    }

    // Step 4: Run build_runner if requested
    BuildRunnerResult? buildResult;
    if (runBuildRunner) {
      onProgress?.call('\n🔨 Running build_runner...');
      buildResult = await _buildRunner.runBuild(
        deleteConflictingOutputs: true,
        onProgress: onProgress,
      );

      if (buildResult.success) {
        onProgress?.call('✓ Generated ${buildResult.generatedFiles.length} .g.dart files\n');
        for (final file in buildResult.generatedFiles) {
          onProgress?.call('  - $file');
        }
      } else {
        onProgress?.call('❌ build_runner failed');
        onProgress?.call(buildResult.stderr);
      }
    }

    return GenerationResult(
      schema: schema,
      entityFiles: writtenFiles,
      buildRunnerResult: buildResult,
    );
  }

  /// Generate from JSON file path
  Future<GenerationResult> generateFromJsonFile(
    String jsonFilePath, {
    String? entityName,
    bool runBuildRunner = true,
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('📖 Reading JSON file: $jsonFilePath');
    final content = await _fileWriter.readFile(jsonFilePath);

    // Parse JSON string
    final json = _parseJsonString(content);

    return await generateFromJson(
      json,
      entityName: entityName,
      runBuildRunner: runBuildRunner,
      onProgress: onProgress,
    );
  }

  /// Simple JSON string parser (for now)
  Map<String, dynamic> _parseJsonString(String jsonString) {
    // This will be enhanced with proper JSON parsing
    // For now, assume valid JSON
    throw UnimplementedError('JSON string parsing not yet implemented');
  }
}

/// Result of the generation process
class GenerationResult {
  final EntitySchema schema;
  final List<String> entityFiles;
  final BuildRunnerResult? buildRunnerResult;

  GenerationResult({
    required this.schema,
    required this.entityFiles,
    this.buildRunnerResult,
  });

  bool get success =>
      entityFiles.isNotEmpty &&
      (buildRunnerResult == null || buildRunnerResult!.success);

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Generation Result:');
    buffer.writeln('  Entity: ${schema.name}');
    buffer.writeln('  Files Created: ${entityFiles.length}');
    buffer.writeln('  Build Runner: ${buildRunnerResult?.success ?? 'skipped'}');
    if (buildRunnerResult != null) {
      buffer.writeln('  Generated: ${buildRunnerResult!.generatedFiles.length} .g.dart files');
    }
    return buffer.toString();
  }
}
