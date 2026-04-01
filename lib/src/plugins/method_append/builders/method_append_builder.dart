import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/ast_helper.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/ast/augmentation_builder.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../core/context/file_system.dart';
import '../../../core/plugin_system/discovery_engine.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import '../../../utils/entity_utils.dart';
import '../../../utils/entity_analyzer.dart';

part 'method_append_builder_append.dart';
part 'method_append_builder_create.dart';
part 'method_append_builder_find.dart';
part 'method_append_builder_imports.dart';
part 'method_append_builder_types.dart';

/// Generates and appends method implementations using Augmentation Libraries.
///
/// Builds the method AST and uses [AugmentationBuilder] to create or update
/// an augmentation file for the target host class.
class MethodAppendBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final AppendExecutor appendExecutor;
  final SpecLibrary specLibrary;
  final AugmentationBuilder augmentationBuilder;
  final DiscoveryEngine discovery;
  final FileSystem fileSystem;

  MethodAppendBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    AppendExecutor? appendExecutor,
    SpecLibrary? specLibrary,
    AugmentationBuilder? augmentationBuilder,
    DiscoveryEngine? discovery,
    FileSystem? fileSystem,
  }) : appendExecutor = appendExecutor ?? AppendExecutor(),
       specLibrary = specLibrary ?? const SpecLibrary(),
       augmentationBuilder =
           augmentationBuilder ?? AugmentationBuilder(outputDir: outputDir),
       fileSystem = fileSystem ?? FileSystem.create(root: outputDir),
       discovery =
           discovery ??
           DiscoveryEngine(
             projectRoot: outputDir,
             fileSystem: fileSystem ?? FileSystem.create(root: outputDir),
           );

  Future<MethodAppendResult> appendMethod(GeneratorConfig config) async {
    final updatedFiles = <GeneratedFile>[];
    final warnings = <String>[];

    // Orchestrators use composed UseCases, not repo/service
    if (config.isOrchestrator) {
      return MethodAppendResult(updatedFiles, warnings);
    }

    if (!config.hasRepo && !config.hasService) {
      warnings.add('⚠️  --append requires --repo or --service flag');
      return MethodAppendResult(updatedFiles, warnings);
    }

    if (config.hasService) {
      return _appendServiceMethod(config);
    }

    final repoBase = config.effectiveRepos.firstOrNull;
    if (repoBase == null) {
      warnings.add('Repository name required for method append operations');
      return MethodAppendResult(updatedFiles, warnings);
    }
    final repoName = repoBase.endsWith('Repository')
        ? repoBase.replaceAll('Repository', '')
        : repoBase;
    final repoSnake = StringUtils.camelToSnake(repoName);
    final methodName = config.getRepoMethodName();
    final paramsType = config.paramsType ?? 'NoParams';
    final multipleParams = config.multipleParams;
    final returnsType = config.returnsType ?? 'void';

    final returnRef = _returnType(config.useCaseType, returnsType);

    // Use DiscoveryEngine to find the repository interface
    final repoFile = discovery.findFileSync('${repoSnake}_repository.dart');
    final repoPath =
        repoFile?.path ??
        path.join(
          outputDir,
          'domain',
          'repositories',
          '${repoSnake}_repository.dart',
        );
    final repoExists = repoFile != null && (await fileSystem.exists(repoPath));

    final effectiveParams = multipleParams.isNotEmpty
        ? multipleParams
        : paramsType;

    if (!repoExists) {
      await _createRepository(
        config,
        repoPath,
        repoName,
        methodName,
        returnRef,
        effectiveParams,
      );
      updatedFiles.add(
        GeneratedFile(path: repoPath, type: 'repository', action: 'created'),
      );
    } else {
      final result = await _appendToInterface(
        config,
        repoPath,
        '${repoName}Repository',
        methodName,
        returnRef,
        effectiveParams,
      );
      if (result != null) {
        updatedFiles.add(result);
      }
    }

    // Use DiscoveryEngine to find the data repository implementation
    final dataRepoFile = discovery.findFileSync(
      'data_${repoSnake}_repository.dart',
    );
    final dataRepoPath =
        dataRepoFile?.path ??
        path.join(
          outputDir,
          'data',
          'repositories',
          'data_${repoSnake}_repository.dart',
        );

    final dataRepoResult = await _appendToDataRepository(
      config,
      dataRepoPath,
      methodName,
      returnRef,
      effectiveParams,
      repoSnake,
    );
    if (dataRepoResult != null) {
      updatedFiles.add(dataRepoResult);
    } else {
      warnings.add(
        'DataRepository not found: data_${repoSnake}_repository.dart',
      );
    }

    final dataSourcePath = await _findDataSource(config, repoSnake);
    if (dataSourcePath != null) {
      final result = await _appendToInterface(
        config,
        dataSourcePath,
        '${repoName}DataSource',
        methodName,
        returnRef,
        effectiveParams,
        type: 'datasource',
      );
      if (result != null) {
        updatedFiles.add(result);
      }
    }

    final remoteDataSourcePath = await _findRemoteDataSource(config, repoSnake);
    if (remoteDataSourcePath != null) {
      final result = await _appendToRemoteDataSource(
        config,
        remoteDataSourcePath,
        '${repoName}RemoteDataSource',
        methodName,
        returnRef,
        effectiveParams,
      );
      if (result != null) {
        updatedFiles.add(result);
      }
    }

    final localDataSourcePath = await _findLocalDataSource(config, repoSnake);
    if (localDataSourcePath != null) {
      final result = await _appendToLocalDataSource(
        config,
        localDataSourcePath,
        '${repoName}LocalDataSource',
        methodName,
        returnRef,
        effectiveParams,
      );
      if (result != null) {
        updatedFiles.add(result);
      }
    }

    final mockDataSourcePath = await _findMockDataSource(config, repoSnake);
    if (mockDataSourcePath != null) {
      final result = await _appendToMockDataSource(
        config,
        mockDataSourcePath,
        '${repoName}MockDataSource',
        methodName,
        returnRef,
        effectiveParams,
      );
      if (result != null) {
        updatedFiles.add(result);
      }
    }

    return MethodAppendResult(updatedFiles, warnings);
  }
}
