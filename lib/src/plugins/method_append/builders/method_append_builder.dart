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
  }) : appendExecutor = appendExecutor ?? AppendExecutor(),
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

  Future<MethodAppendResult> _appendServiceMethod(
    GeneratorConfig config,
  ) async {
    final updatedFiles = <GeneratedFile>[];
    final warnings = <String>[];

    final serviceName = config.effectiveService!;
    final serviceSnake = config.serviceSnake!;
    final methodName = config.getServiceMethodName();
    final paramsType = config.paramsType ?? 'NoParams';
    final returnsType = config.returnsType ?? 'void';

    final returnRef = _returnType(config.useCaseType, returnsType);

    final servicePath = path.join(
      outputDir,
      'domain',
      'services',
      '${serviceSnake}_service.dart',
    );
    final serviceExists = File(servicePath).existsSync();

    if (!serviceExists) {
      await _createService(
        config,
        servicePath,
        serviceName,
        methodName,
        returnRef,
        paramsType,
      );
      updatedFiles.add(
        GeneratedFile(path: servicePath, type: 'service', action: 'created'),
      );
    } else {
      final result = await _appendToInterface(
        config,
        servicePath,
        serviceName,
        methodName,
        returnRef,
        paramsType,
      );
      if (result != null) {
        updatedFiles.add(result);
      } else {
        warnings.add('Failed to append to ${serviceSnake}_service.dart');
      }
    }

    if (config.generateData) {
      final domainSnake = StringUtils.camelToSnake(config.effectiveDomain);
      final providerPath = path.join(
        outputDir,
        'data',
        'providers',
        domainSnake,
        '${serviceSnake}_provider.dart',
      );

      if (File(providerPath).existsSync()) {
        final result = await _appendToProvider(
          config,
          providerPath,
          config.effectiveProvider!,
          methodName,
          returnRef,
          paramsType,
        );
        if (result != null) {
          updatedFiles.add(result);
        } else {
          warnings.add('Failed to append to ${serviceSnake}_provider.dart');
        }
      } else {
        await _createProvider(
          config,
          providerPath,
          serviceName,
          methodName,
          returnRef,
          paramsType,
        );
        updatedFiles.add(
          GeneratedFile(
            path: providerPath,
            type: 'provider',
            action: 'created',
          ),
        );
      }
    }

    return MethodAppendResult(updatedFiles, warnings);
  }

  Future<GeneratedFile?> _appendToInterface(
    GeneratorConfig config,
    String filePath,
    String className,
    String methodName,
    Reference returnType,
    String paramsType,
  ) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    var source = await file.readAsString();
    source = await _addMissingImports(config, source, filePath);

    final method = Method(
      (m) => m
        ..name = methodName
        ..returns = returnType
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer(paramsType),
          ),
        ),
    );

    final memberSource = specLibrary.emitSpec(method);
    final request = AppendRequest.method(
      source: source,
      className: className,
      memberSource: memberSource,
    );

    final result = appendExecutor.execute(request);
    if (result.changed) {
      await FileUtils.writeFile(
        filePath,
        result.source,
        'append',
        force: true,
        dryRun: dryRun,
        verbose: verbose,
      );
      return GeneratedFile(
        path: filePath,
        type: 'interface',
        action: 'updated',
      );
    }
    return null;
  }

  Future<GeneratedFile?> _appendToDataRepository(
    GeneratorConfig config,
    String filePath,
    String methodName,
    Reference returnType,
    String paramsType,
    String repoSnake,
  ) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    var source = await file.readAsString();
    source = await _addMissingImports(config, source, filePath);

    final dataSourceFieldMatch = RegExp(
      r'final \w+ (_\w+);',
    ).firstMatch(source);
    final dataSourceField = dataSourceFieldMatch?.group(1) ?? '_dataSource';

    final isStream = config.useCaseType == 'stream';
    final isSync = config.useCaseType == 'sync';

    final method = Method(
      (m) => m
        ..name = methodName
        ..returns = returnType
        ..annotations.add(refer('override'))
        ..modifier = isStream || isSync ? null : MethodModifier.async
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer(paramsType),
          ),
        )
        ..body = refer(dataSourceField)
            .property(methodName)
            .call([refer('params')])
            .maybeAwaited(!isStream && !isSync)
            .returned
            .statement,
    );

    final className =
        'Data${StringUtils.convertToPascalCase(repoSnake)}Repository';
    final memberSource = specLibrary.emitSpec(method);
    final request = AppendRequest.method(
      source: source,
      className: className,
      memberSource: memberSource,
    );

    final result = appendExecutor.execute(request);
    if (result.changed) {
      await FileUtils.writeFile(
        filePath,
        result.source,
        'append',
        force: true,
        dryRun: dryRun,
        verbose: verbose,
      );
      return GeneratedFile(
        path: filePath,
        type: 'repository',
        action: 'updated',
      );
    }
    return null;
  }

  Future<GeneratedFile?> _appendToRemoteDataSource(
    GeneratorConfig config,
    String filePath,
    String className,
    String methodName,
    Reference returnType,
    String paramsType,
  ) async {
    return _appendToDataSourceImpl(
      config,
      filePath,
      className,
      methodName,
      returnType,
      paramsType,
      'Implement remote $methodName',
    );
  }

  Future<GeneratedFile?> _appendToLocalDataSource(
    GeneratorConfig config,
    String filePath,
    String className,
    String methodName,
    Reference returnType,
    String paramsType,
  ) async {
    return _appendToDataSourceImpl(
      config,
      filePath,
      className,
      methodName,
      returnType,
      paramsType,
      'Implement local storage $methodName',
    );
  }

  Future<GeneratedFile?> _appendToMockDataSource(
    GeneratorConfig config,
    String filePath,
    String className,
    String methodName,
    Reference returnType,
    String paramsType,
  ) async {
    return _appendToDataSourceImpl(
      config,
      filePath,
      className,
      methodName,
      returnType,
      paramsType,
      'Return mock data for $methodName',
    );
  }

  Future<GeneratedFile?> _appendToProvider(
    GeneratorConfig config,
    String filePath,
    String className,
    String methodName,
    Reference returnType,
    String paramsType,
  ) async {
    return _appendToDataSourceImpl(
      config,
      filePath,
      className,
      methodName,
      returnType,
      paramsType,
      'Implement $methodName',
    );
  }

  Future<GeneratedFile?> _appendToDataSourceImpl(
    GeneratorConfig config,
    String filePath,
    String className,
    String methodName,
    Reference returnType,
    String paramsType,
    String errorMessage,
  ) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    var source = await file.readAsString();
    source = await _addMissingImports(config, source, filePath);

    final isStream = config.useCaseType == 'stream';
    final isSync = config.useCaseType == 'sync';

    final method = Method(
      (m) => m
        ..name = methodName
        ..returns = returnType
        ..annotations.add(refer('override'))
        ..modifier = isStream || isSync ? null : MethodModifier.async
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer(paramsType),
          ),
        )
        ..body = refer(
          'UnimplementedError',
        ).call([literalString(errorMessage)]).thrown.statement,
    );

    final memberSource = specLibrary.emitSpec(method);
    final request = AppendRequest.method(
      source: source,
      className: className,
      memberSource: memberSource,
    );

    final result = appendExecutor.execute(request);
    if (result.changed) {
      await FileUtils.writeFile(
        filePath,
        result.source,
        'append',
        force: true,
        dryRun: dryRun,
        verbose: verbose,
      );
      return GeneratedFile(
        path: filePath,
        type: 'datasource',
        action: 'updated',
      );
    }
    return null;
  }

  Future<void> _createRepository(
    GeneratorConfig config,
    String filePath,
    String repoName,
    String methodName,
    Reference returnType,
    String paramsType,
  ) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);

    final method = Method(
      (m) => m
        ..name = methodName
        ..returns = returnType
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer(paramsType),
          ),
        ),
    );

    final clazz = Class(
      (c) => c
        ..name = '${repoName}Repository'
        ..abstract = true
        ..docs.add('Repository interface for $repoName')
        ..methods.add(method),
    );

    final content = specLibrary.emitSpec(clazz);
    await FileUtils.writeFile(
      filePath,
      content,
      'repository',
      force: true,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<void> _createService(
    GeneratorConfig config,
    String filePath,
    String serviceName,
    String methodName,
    Reference returnType,
    String paramsType,
  ) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);

    final method = Method(
      (m) => m
        ..name = methodName
        ..returns = returnType
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer(paramsType),
          ),
        ),
    );

    final clazz = Class(
      (c) => c
        ..name = serviceName
        ..abstract = true
        ..docs.add('Service interface for ${config.name}')
        ..methods.add(method),
    );

    final library = specLibrary.library(
      specs: [clazz],
      directives: [Directive.import('package:zuraffa/zuraffa.dart')],
    );

    final content = specLibrary.emitLibrary(library);
    await FileUtils.writeFile(
      filePath,
      content,
      'service',
      force: true,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<void> _createProvider(
    GeneratorConfig config,
    String filePath,
    String serviceName,
    String methodName,
    Reference returnType,
    String paramsType,
  ) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);

    final serviceSnake = config.serviceSnake!;
    final providerName = config.effectiveProvider!;
    final isStream = config.useCaseType == 'stream';
    final isSync = config.useCaseType == 'sync';

    final method = Method(
      (m) => m
        ..name = methodName
        ..returns = returnType
        ..annotations.add(refer('override'))
        ..modifier = isStream || isSync ? null : MethodModifier.async
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer(paramsType),
          ),
        )
        ..body = Block(
          (b) => b
            ..statements.add(Code('// TODO: Implement $methodName'))
            ..statements.add(
              refer(
                'UnimplementedError',
              ).call([literalString('Implement $methodName')]).thrown.statement,
            ),
        ),
    );

    final clazz = Class(
      (c) => c
        ..name = providerName
        ..mixins.addAll([refer('Loggable'), refer('FailureHandler')])
        ..implements.add(refer(serviceName))
        ..docs.add('Provider implementation for $serviceName')
        ..methods.add(method),
    );

    final library = specLibrary.library(
      specs: [clazz],
      directives: [
        Directive.import('package:zuraffa/zuraffa.dart'),
        Directive.import(
          '../../../domain/services/${serviceSnake}_service.dart',
        ),
      ],
    );

    final content = specLibrary.emitLibrary(library);
    await FileUtils.writeFile(
      filePath,
      content,
      'provider',
      force: true,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<String> _addMissingImports(
    GeneratorConfig config,
    String source,
    String filePath,
  ) async {
    final entities = _collectEntityTypes(config);
    if (entities.isEmpty) return source;

    var content = source;
    for (final entityName in entities) {
      final entitySnake = StringUtils.camelToSnake(entityName);
      if (_hasEntityImport(content, entityName, entitySnake)) continue;

      final relativePath = _getRelativeImportPath(filePath, entitySnake);
      final request = AppendRequest.import(
        source: content,
        importPath: relativePath,
      );
      final result = appendExecutor.execute(request);
      content = result.source;
    }
    return content;
  }

  Set<String> _collectEntityTypes(GeneratorConfig config) {
    final entities = <String>{};
    if (config.paramsType != null && config.paramsType != 'NoParams') {
      final entity = _extractEntityName(config.paramsType!);
      if (entity != null) entities.add(entity);
    }
    if (config.returnsType != null && config.returnsType != 'void') {
      final entity = _extractEntityName(config.returnsType!);
      if (entity != null) entities.add(entity);
    }
    return entities;
  }

  String? _extractEntityName(String type) {
    final genericMatch = RegExp(r'^\w+<([^>]+)>').firstMatch(type);
    if (genericMatch != null) {
      final innerType = genericMatch.group(1)!;
      if (innerType.contains(',')) {
        return innerType.split(',').first.trim();
      }
      return innerType;
    }
    if (type.isNotEmpty && _isEntityLike(type)) {
      return type;
    }
    return null;
  }

  bool _isEntityLike(String typeName) {
    if (typeName.isEmpty) return false;
    final commonTypes = {
      'void',
      'String',
      'int',
      'double',
      'bool',
      'num',
      'dynamic',
      'NoParams',
      'Params',
      'QueryParams',
      'ListQueryParams',
      'UpdateParams',
      'DeleteParams',
      'InitializationParams',
      'AppFailure',
      'Filter',
    };
    if (commonTypes.contains(typeName)) return false;
    return typeName[0].toUpperCase() == typeName[0];
  }

  bool _hasEntityImport(String content, String entityName, String entitySnake) {
    final pattern1 = RegExp(
      "import\\s+['\\\"]([^'\\\"]*/entities/$entitySnake/[^'\\\"]*)['\\\"]",
    );
    final pattern2 = RegExp(
      "import\\s+['\\\"]([^'\\\"]*$entityName\\.dart)['\\\"]",
    );
    return pattern1.hasMatch(content) || pattern2.hasMatch(content);
  }

  String _getRelativeImportPath(String filePath, String entitySnake) {
    final normalizedPath = path.normalize(filePath);
    if (normalizedPath.contains('/data/data_sources/') ||
        normalizedPath.contains('\\data\\data_sources\\')) {
      return '../../../domain/entities/$entitySnake/$entitySnake.dart';
    }
    if (normalizedPath.contains('/data/repositories/') ||
        normalizedPath.contains('\\data\\repositories\\')) {
      return '../domain/entities/$entitySnake/$entitySnake.dart';
    }
    if (normalizedPath.contains('/domain/repositories/') ||
        normalizedPath.contains('\\domain\\repositories\\')) {
      return '../entities/$entitySnake/$entitySnake.dart';
    }
    if (normalizedPath.contains('/domain/usecases/') ||
        normalizedPath.contains('\\domain\\usecases\\')) {
      return '../../entities/$entitySnake/$entitySnake.dart';
    }
    if (normalizedPath.contains('/data/providers/') ||
        normalizedPath.contains('\\data\\providers\\')) {
      return '../../../domain/services/${entitySnake}_service.dart';
    }
    return '../../../domain/entities/$entitySnake/$entitySnake.dart';
  }

  Future<String?> _findDataSource(
    GeneratorConfig config,
    String repoSnake,
  ) async {
    final directPath = path.join(
      outputDir,
      'data',
      'data_sources',
      repoSnake,
      '${repoSnake}_data_source.dart',
    );
    if (File(directPath).existsSync()) return directPath;
    if (config.domain != null) {
      final domainPath = path.join(
        outputDir,
        'data',
        'data_sources',
        config.domain,
        '${repoSnake}_data_source.dart',
      );
      if (File(domainPath).existsSync()) return domainPath;
    }
    return null;
  }

  Future<String?> _findRemoteDataSource(
    GeneratorConfig config,
    String repoSnake,
  ) async {
    final directPath = path.join(
      outputDir,
      'data',
      'data_sources',
      repoSnake,
      '${repoSnake}_remote_data_source.dart',
    );
    if (File(directPath).existsSync()) return directPath;
    if (config.domain != null) {
      final domainPath = path.join(
        outputDir,
        'data',
        'data_sources',
        config.domain,
        '${repoSnake}_remote_data_source.dart',
      );
      if (File(domainPath).existsSync()) return domainPath;
    }
    return null;
  }

  Future<String?> _findLocalDataSource(
    GeneratorConfig config,
    String repoSnake,
  ) async {
    final directPath = path.join(
      outputDir,
      'data',
      'data_sources',
      repoSnake,
      '${repoSnake}_local_data_source.dart',
    );
    if (File(directPath).existsSync()) return directPath;
    if (config.domain != null) {
      final domainPath = path.join(
        outputDir,
        'data',
        'data_sources',
        config.domain,
        '${repoSnake}_local_data_source.dart',
      );
      if (File(domainPath).existsSync()) return domainPath;
    }
    return null;
  }

  Future<String?> _findMockDataSource(
    GeneratorConfig config,
    String repoSnake,
  ) async {
    final directPath = path.join(
      outputDir,
      'data',
      'data_sources',
      repoSnake,
      '${repoSnake}_mock_data_source.dart',
    );
    if (File(directPath).existsSync()) return directPath;
    if (config.domain != null) {
      final domainPath = path.join(
        outputDir,
        'data',
        'data_sources',
        config.domain,
        '${repoSnake}_mock_data_source.dart',
      );
      if (File(domainPath).existsSync()) return domainPath;
    }
    return null;
  }

  Reference _returnType(String useCaseType, String returnsType) {
    switch (useCaseType) {
      case 'stream':
        return TypeReference(
          (b) => b
            ..symbol = 'Stream'
            ..types.add(refer(returnsType)),
        );
      case 'completable':
        return TypeReference(
          (b) => b
            ..symbol = 'Future'
            ..types.add(refer('void')),
        );
      case 'sync':
        return refer(returnsType);
      default:
        return TypeReference(
          (b) => b
            ..symbol = 'Future'
            ..types.add(refer(returnsType)),
        );
    }
  }
}

class MethodAppendResult {
  final List<GeneratedFile> updatedFiles;
  final List<String> warnings;

  MethodAppendResult(this.updatedFiles, this.warnings);
}

extension on Expression {
  Expression maybeAwaited(bool condition) => condition ? awaited : this;
}
