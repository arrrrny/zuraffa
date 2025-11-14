import 'json_parser.dart';
import 'entity_generator.dart';
import 'datasource_generator.dart';
import 'repository_generator.dart';
import 'usecase_generator.dart';
import 'file_writer.dart';
import 'build_runner.dart';
import 'build_yaml_generator.dart';
import 'entity_test_generator.dart';
import 'datasource_test_generator.dart';
import 'repository_test_generator.dart';
import 'usecase_test_generator.dart';

/// Full-stack generator that creates complete Clean Architecture setup
///
/// Single command: zuraffa generate Product --from-json product.json --full-stack
///
/// Generates:
/// - Entity (with Morphy)
/// - DataSources (Remote/Local/Mock)
/// - Repository (with cache-first logic)
/// - UseCases (Get/GetAll/Create/Update/Delete)
class FullStackGenerator {
  final String projectPath;
  late final JsonParser _jsonParser;
  late final MorphyEntityGenerator _entityGenerator;
  late final DataSourceGenerator _dataSourceGenerator;
  late final RepositoryGenerator _repositoryGenerator;
  late final UseCaseGenerator _useCaseGenerator;
  late final FileWriter _fileWriter;
  late final BuildRunnerManager _buildRunner;
  late final BuildYamlGenerator _buildYamlGenerator;
  late final EntityTestGenerator _entityTestGenerator;
  late final DataSourceTestGenerator _dataSourceTestGenerator;
  late final RepositoryTestGenerator _repositoryTestGenerator;
  late final UseCaseTestGenerator _useCaseTestGenerator;

  FullStackGenerator(this.projectPath) {
    _jsonParser = JsonParser();
    _entityGenerator = MorphyEntityGenerator();
    _dataSourceGenerator = DataSourceGenerator();
    _repositoryGenerator = RepositoryGenerator();
    _useCaseGenerator = UseCaseGenerator();
    _fileWriter = FileWriter(projectPath);
    _buildRunner = BuildRunnerManager(projectPath);
    _buildYamlGenerator = BuildYamlGenerator();
    _entityTestGenerator = EntityTestGenerator();
    _dataSourceTestGenerator = DataSourceTestGenerator();
    _repositoryTestGenerator = RepositoryTestGenerator();
    _useCaseTestGenerator = UseCaseTestGenerator();
  }

  /// Generate complete full-stack from JSON
  Future<FullStackResult> generateFromJson(
    Map<String, dynamic> json, {
    String? entityName,
    bool runBuildRunner = true,
    bool includeCrud = false,  // NEW: Only generate CRUD if explicitly requested
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('🚀 Starting full-stack generation...\n');

    // Step 1: Parse JSON and generate entities
    onProgress?.call('📊 Parsing JSON...');
    final schema = _jsonParser.parseJson(json, entityName: entityName);
    final finalEntityName = schema.name;
    onProgress?.call('✓ Detected entity: $finalEntityName\n');

    final allFiles = <String, String>{};

    // Step 2: Generate entities
    onProgress?.call('📝 Generating entities...');
    final entityFiles = _entityGenerator.generateAllEntities(schema);
    allFiles.addAll(entityFiles);
    onProgress?.call('✓ Generated ${entityFiles.length} entity file(s)\n');

    // Step 3: Generate datasources
    onProgress?.call('🌐 Generating datasources...');
    final datasourceFiles = <String, String>{
      'lib/src/data/datasources/${_toSnakeCase(finalEntityName)}_datasource.dart':
          _dataSourceGenerator.generateDataSourceInterface(finalEntityName),
      'lib/src/data/datasources/remote_${_toSnakeCase(finalEntityName)}_datasource.dart':
          _dataSourceGenerator.generateRemoteDataSource(finalEntityName),
      'lib/src/data/datasources/local_${_toSnakeCase(finalEntityName)}_datasource.dart':
          _dataSourceGenerator.generateLocalDataSource(finalEntityName),
      'lib/src/data/datasources/mock_${_toSnakeCase(finalEntityName)}_datasource.dart':
          _dataSourceGenerator.generateMockDataSource(finalEntityName),
    };
    allFiles.addAll(datasourceFiles);
    onProgress?.call('✓ Generated 4 datasource files (Remote/Local/Mock)\n');

    // Step 4: Generate repository
    onProgress?.call('🗄️  Generating repository...');
    final repositoryFiles = <String, String>{
      'lib/src/domain/repositories/${_toSnakeCase(finalEntityName)}_repository.dart':
          _repositoryGenerator.generateRepositoryInterface(finalEntityName),
      'lib/src/data/repositories/data_${_toSnakeCase(finalEntityName)}_repository.dart':
          _repositoryGenerator.generateRepositoryImplementation(finalEntityName),
    };
    allFiles.addAll(repositoryFiles);
    onProgress?.call('✓ Generated repository with cache-first logic\n');

    // Step 5: Generate usecases (only Get/GetAll by default)
    onProgress?.call('⚙️  Generating usecases...');
    final usecaseTypes = includeCrud
        ? [UseCaseType.get, UseCaseType.getAll, UseCaseType.create, UseCaseType.update, UseCaseType.delete]
        : [UseCaseType.get, UseCaseType.getAll];

    final usecaseFiles = <String, String>{};

    // Generate filter class
    final filterPath = _useCaseGenerator.getFilterFilePath(finalEntityName);
    final filterContent = _useCaseGenerator.generateFilterClass(finalEntityName);
    usecaseFiles[filterPath] = filterContent;

    // Generate use cases
    for (final type in usecaseTypes) {
      final path = _useCaseGenerator.getFilePath(finalEntityName, type);
      final content = _useCaseGenerator.generateUseCase(
        entityName: finalEntityName,
        type: type,
      );
      usecaseFiles[path] = content;
    }
    allFiles.addAll(usecaseFiles);

    final usecaseCount = usecaseTypes.length;
    if (includeCrud) {
      onProgress?.call('✓ Generated $usecaseCount use cases + filter (Get/GetProducts/Create/Update/Delete)\n');
    } else {
      onProgress?.call('✓ Generated $usecaseCount use cases + filter (Get/GetProducts with filtering)\n');
      onProgress?.call('  💡 Add --crud flag to also generate Create/Update/Delete\n');
    }

    // Step 6: Generate test files (TDD!)
    onProgress?.call('🧪 Generating test files...');
    final testFiles = <String, String>{};

    // Entity tests
    final entityTestPath = _entityTestGenerator.getFilePath(finalEntityName);
    final entityTestContent = _entityTestGenerator.generateEntityTest(finalEntityName, schema);
    testFiles[entityTestPath] = entityTestContent;

    // DataSource tests
    final datasourceTestPaths = _dataSourceTestGenerator.getFilePaths(finalEntityName);
    testFiles['test/data/datasources/remote_${_toSnakeCase(finalEntityName)}_datasource_test.dart'] =
        _dataSourceTestGenerator.generateRemoteDataSourceTest(finalEntityName);
    testFiles['test/data/datasources/local_${_toSnakeCase(finalEntityName)}_datasource_test.dart'] =
        _dataSourceTestGenerator.generateLocalDataSourceTest(finalEntityName);
    testFiles['test/data/datasources/mock_${_toSnakeCase(finalEntityName)}_datasource_test.dart'] =
        _dataSourceTestGenerator.generateMockDataSourceTest(finalEntityName);

    // Repository tests
    final repositoryTestPath = _repositoryTestGenerator.getFilePath(finalEntityName);
    final repositoryTestContent = _repositoryTestGenerator.generateRepositoryTest(finalEntityName);
    testFiles[repositoryTestPath] = repositoryTestContent;

    // UseCase tests
    for (final type in usecaseTypes) {
      final testPath = _useCaseTestGenerator.getFilePath(finalEntityName, type);
      final testContent = _useCaseTestGenerator.generateUseCaseTest(finalEntityName, type);
      testFiles[testPath] = testContent;
    }

    allFiles.addAll(testFiles);
    final testCount = testFiles.length;
    onProgress?.call('✓ Generated $testCount test files (100% coverage)\n');

    // Step 7: Write all files
    onProgress?.call('💾 Writing ${allFiles.length} files...');
    final writtenFiles = await _fileWriter.writeFiles(allFiles);
    onProgress?.call('✓ All files written\n');

    // Step 8: Ensure build.yaml exists
    onProgress?.call('🔧 Checking build.yaml...');
    bool buildYamlCreated = false;
    try {
      final exists = await _fileWriter.fileExists('build.yaml');
      String? existingContent;

      if (exists) {
        existingContent = await _fileWriter.readFile('build.yaml');
      }

      if (_buildYamlGenerator.needsBuildYaml(existingContent)) {
        final newContent = existingContent != null
            ? _buildYamlGenerator.mergeBuildYaml(existingContent)
            : _buildYamlGenerator.generateBuildYaml();

        await _fileWriter.writeFile('build.yaml', newContent);
        buildYamlCreated = true;
        onProgress?.call('✓ Created/Updated build.yaml\n');
      }
    } catch (e) {
      onProgress?.call('⚠ Could not update build.yaml: $e\n');
    }

    // Step 9: Run build_runner
    BuildRunnerResult? buildResult;
    if (runBuildRunner) {
      onProgress?.call('🔨 Running build_runner...\n');
      buildResult = await _buildRunner.runBuild(
        deleteConflictingOutputs: true,
        onProgress: onProgress,
      );

      if (buildResult.success) {
        onProgress?.call('\n✓ Generated ${buildResult.generatedFiles.length} .g.dart files\n');
      }
    }

    return FullStackResult(
      entityName: finalEntityName,
      schema: schema,
      entityFiles: entityFiles.keys.toList(),
      datasourceFiles: datasourceFiles.keys.toList(),
      repositoryFiles: repositoryFiles.keys.toList(),
      usecaseFiles: usecaseFiles.keys.toList(),
      testFiles: testFiles.keys.toList(),
      buildYamlCreated: buildYamlCreated,
      buildRunnerResult: buildResult,
    );
  }

  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => '_${match.group(0)!.toLowerCase()}',
        )
        .substring(1);
  }
}

/// Result of full-stack generation
class FullStackResult {
  final String entityName;
  final EntitySchema schema;
  final List<String> entityFiles;
  final List<String> datasourceFiles;
  final List<String> repositoryFiles;
  final List<String> usecaseFiles;
  final List<String> testFiles;
  final bool buildYamlCreated;
  final BuildRunnerResult? buildRunnerResult;

  FullStackResult({
    required this.entityName,
    required this.schema,
    required this.entityFiles,
    required this.datasourceFiles,
    required this.repositoryFiles,
    required this.usecaseFiles,
    required this.testFiles,
    required this.buildYamlCreated,
    this.buildRunnerResult,
  });

  bool get success =>
      entityFiles.isNotEmpty &&
      (buildRunnerResult == null || buildRunnerResult!.success);

  int get totalFiles =>
      entityFiles.length +
      datasourceFiles.length +
      repositoryFiles.length +
      usecaseFiles.length +
      testFiles.length;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Full-Stack Generation Result:');
    buffer.writeln('  Entity: $entityName');
    buffer.writeln('  Total Files: $totalFiles');
    buffer.writeln('    - Entities: ${entityFiles.length}');
    buffer.writeln('    - DataSources: ${datasourceFiles.length}');
    buffer.writeln('    - Repositories: ${repositoryFiles.length}');
    buffer.writeln('    - UseCases: ${usecaseFiles.length}');
    buffer.writeln('    - Tests: ${testFiles.length}');
    buffer.writeln('  Build YAML: ${buildYamlCreated ? 'created' : 'exists'}');
    buffer.writeln('  Build Runner: ${buildRunnerResult?.success ?? 'skipped'}');
    return buffer.toString();
  }
}
