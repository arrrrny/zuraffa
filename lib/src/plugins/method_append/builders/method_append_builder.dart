import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
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

/// Generates and appends method implementations to existing files.
///
/// Builds the method AST and uses [AppendExecutor] to insert it into
/// the target class while maintaining imports and formatting.
///
/// Example:
/// ```dart
/// final builder = MethodAppendBuilder(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final result = await builder.appendMethod(GeneratorConfig(name: 'Product'));
/// ```
class MethodAppendBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final AppendExecutor appendExecutor;
  final SpecLibrary specLibrary;

  MethodAppendBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    AppendExecutor? appendExecutor,
    SpecLibrary? specLibrary,
  }) : appendExecutor = appendExecutor ?? AppendExecutor(),
       specLibrary = specLibrary ?? const SpecLibrary();

  Future<MethodAppendResult> appendMethod(GeneratorConfig config) async {
    if (config.revert) {
      final files = <GeneratedFile>[];
      final serviceName = config.service;
      if (serviceName != null) {
        final baseName = serviceName.endsWith('Service')
            ? serviceName.substring(0, serviceName.length - 7)
            : serviceName;
        final serviceSnake = StringUtils.camelToSnake(baseName);
        final servicePath = path.join(
          outputDir,
          'domain',
          'services',
          '${serviceSnake}_service.dart',
        );
        if (File(servicePath).existsSync()) {
          files.add(
            await FileUtils.deleteFile(
              servicePath,
              'service',
              dryRun: options.dryRun,
              verbose: options.verbose,
            ),
          );
        }
      }

      final repoBase = config.repo;
      if (repoBase != null) {
        final repoName = repoBase.endsWith('Repository')
            ? repoBase.replaceAll('Repository', '')
            : repoBase;
        final repoSnake = StringUtils.camelToSnake(repoName);
        final repoPath = path.join(
          outputDir,
          'domain',
          'repositories',
          '${repoSnake}_repository.dart',
        );
        if (File(repoPath).existsSync()) {
          files.add(
            await FileUtils.deleteFile(
              repoPath,
              'repository',
              dryRun: options.dryRun,
              verbose: options.verbose,
            ),
          );
        }
      }

      return MethodAppendResult(files, [
        'Note: Revert only deletes files created by append, it does not undo code appends to existing files.',
      ]);
    }

    final updatedFiles = <GeneratedFile>[];
    final warnings = <String>[];

    // Orchestrators use composed UseCases, not repo/service
    if (config.isOrchestrator) {
      return MethodAppendResult(updatedFiles, warnings);
    }

    if (config.repo == null && config.service == null) {
      warnings.add('⚠️  --append requires --repo or --service flag');
      return MethodAppendResult(updatedFiles, warnings);
    }

    if (config.hasService) {
      return _appendServiceMethod(config);
    }

    final repoBase = config.repo;
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
    final returnsType = config.returnsType ?? 'void';

    final returnRef = _returnType(config.useCaseType, returnsType);

    final repoPath = path.join(
      outputDir,
      'domain',
      'repositories',
      '${repoSnake}_repository.dart',
    );
    final repoExists = File(repoPath).existsSync();

    if (!repoExists) {
      await _createRepository(
        config,
        repoPath,
        repoName,
        methodName,
        returnRef,
        paramsType,
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
        paramsType,
      );
      if (result != null) {
        updatedFiles.add(result);
      }
      // Don't warn if method already exists - that's expected behavior
    }

    final dataRepoPath = path.join(
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
      paramsType,
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
        paramsType,
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
        paramsType,
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
        paramsType,
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
        paramsType,
      );
      if (result != null) {
        updatedFiles.add(result);
      }
    }

    return MethodAppendResult(updatedFiles, warnings);
  }
}
