import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';

part 'method_append_builder_append.dart';
part 'method_append_builder_create.dart';
part 'method_append_builder_find.dart';
part 'method_append_builder_imports.dart';
part 'method_append_builder_types.dart';

class MethodAppendBuilder {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final AppendExecutor appendExecutor;
  final SpecLibrary specLibrary;

  MethodAppendBuilder({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    AppendExecutor? appendExecutor,
    SpecLibrary? specLibrary,
  })  : appendExecutor = appendExecutor ?? AppendExecutor(),
        specLibrary = specLibrary ?? const SpecLibrary();

  Future<MethodAppendResult> appendMethod(GeneratorConfig config) async {
    final updatedFiles = <GeneratedFile>[];
    final warnings = <String>[];

    if (config.repo == null && config.service == null) {
      warnings.add('⚠️  --append requires --repo or --service flag');
      return MethodAppendResult(updatedFiles, warnings);
    }

    if (config.hasService) {
      return _appendServiceMethod(config);
    }

    final repoName = config.repo!.endsWith('Repository')
        ? config.repo!.replaceAll('Repository', '')
        : config.repo!;
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
      } else {
        warnings.add('Failed to append to ${repoSnake}_repository.dart');
      }
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
    } else {
      warnings.add('DataSource not found for $repoSnake');
    }

    final remoteDataSourcePath = await _findRemoteDataSource(config, repoSnake);
    if (remoteDataSourcePath != null) {
      final result = await _appendToRemoteDataSource(
        config,
        remoteDataSourcePath,
        'Remote${repoName}DataSource',
        methodName,
        returnRef,
        paramsType,
      );
      if (result != null) {
        updatedFiles.add(result);
      }
    } else {
      warnings.add('RemoteDataSource not found for $repoSnake');
    }

    final localDataSourcePath = await _findLocalDataSource(config, repoSnake);
    if (localDataSourcePath != null) {
      final result = await _appendToLocalDataSource(
        config,
        localDataSourcePath,
        'Local${repoName}DataSource',
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
        'Mock${repoName}DataSource',
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
