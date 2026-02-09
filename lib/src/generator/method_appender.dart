import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/generator_config.dart';
import '../models/generated_file.dart';
import '../utils/file_utils.dart';
import '../utils/string_utils.dart';

class MethodAppender {
  final GeneratorConfig config;
  final String outputDir;
  final bool verbose;
  final bool dryRun;

  MethodAppender({
    required this.config,
    required this.outputDir,
    this.verbose = false,
    this.dryRun = false,
  });

  Future<void> _writeFile(String filePath, String content, String type) async {
    await FileUtils.writeFile(
      filePath,
      content,
      type,
      force: true,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  /// Extracts entity name from a type string (e.g., `&lt;Customer&gt;`, `List&lt;Customer&gt;`, `Stream&lt;Customer&gt;`)
  String? _extractEntityName(String type) {
    // Handle generic types like List<T>, Stream<T>, Future<T>, Result<T, E>
    final genericMatch = RegExp(r'^\w+<([^>]+)>').firstMatch(type);
    if (genericMatch != null) {
      final innerType = genericMatch.group(1)!;
      // Handle Result<T, E> - return the first type parameter
      if (innerType.contains(',')) {
        return innerType.split(',').first.trim();
      }
      return innerType;
    }
    // Handle simple types
    if (type.isNotEmpty && _isEntityLike(type)) {
      return type;
    }
    return null;
  }

  /// Checks if a type name looks like an entity (starts with uppercase, not a primitive)
  bool _isEntityLike(String typeName) {
    if (typeName.isEmpty) return false;
    // Not an entity if it's a common Dart type
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
    // Entity names typically start with uppercase
    return typeName[0].toUpperCase() == typeName[0];
  }

  /// Collects all entity types referenced in params and return types
  Set<String> _collectEntityTypes() {
    final entities = <String>{};

    // Check params type
    if (config.paramsType != null && config.paramsType != 'NoParams') {
      final entity = _extractEntityName(config.paramsType!);
      if (entity != null) entities.add(entity);
    }

    // Check returns type
    if (config.returnsType != null && config.returnsType != 'void') {
      final entity = _extractEntityName(config.returnsType!);
      if (entity != null) entities.add(entity);
    }

    return entities;
  }

  /// Checks if an import for the entity already exists in the file content
  bool _hasEntityImport(String content, String entityName, String entitySnake) {
    // Check for various import patterns
    // Build patterns as strings first with variable interpolation
    final pattern1 = RegExp(
      "import\\s+['\\\"]([^'\\\"]*/entities/$entitySnake/[^'\\\"]*)['\\\"]",
    );
    final pattern2 = RegExp(
      "import\\s+['\\\"]([^'\\\"]*$entityName\\.dart)['\\\"]",
    );
    // Don't use a generic "entities" pattern - it causes false positives

    final patterns = [pattern1, pattern2];

    for (final pattern in patterns) {
      if (pattern.hasMatch(content)) {
        return true;
      }
    }

    // Don't check if entity class is referenced - that will match the method we're about to add!
    // Only check for actual import statements
    return false;
  }

  /// Adds missing entity imports to a file's content
  Future<String> _addMissingImports(String content, String filePath) async {
    final entities = _collectEntityTypes();
    if (entities.isEmpty) return content;

    var modifiedContent = content;
    var hasChanges = false;

    for (final entityName in entities) {
      final entitySnake = StringUtils.camelToSnake(entityName);

      // Check if import already exists (check modifiedContent to avoid duplicates)
      if (_hasEntityImport(modifiedContent, entityName, entitySnake)) {
        continue;
      }

      // Find the last import statement in current modified content
      final importMatches = RegExp(
        r'''import\s+['"][^'"]*['"];''',
      ).allMatches(modifiedContent).toList();
      final lastImportEnd = importMatches.isEmpty ? 0 : importMatches.last.end;

      // Determine relative path from file location
      final relativePath = _getRelativeImportPath(filePath, entitySnake);
      var importStatement = "import '$relativePath';\n";

      // Add import after the last import
      if (lastImportEnd > 0) {
        // Find where the last import line actually ends (including its newline)
        final importLineEnd = modifiedContent.indexOf('\n', lastImportEnd);
        // Insert AFTER the newline (if found), otherwise at end of import
        final insertPosition = importLineEnd == -1
            ? lastImportEnd
            : importLineEnd + 1;

        // Check if there's already a newline after the last import line
        final textAfterImport = modifiedContent.substring(insertPosition);
        if (!textAfterImport.startsWith('\n')) {
          // No newline, add one before the import
          importStatement = '\n$importStatement';
        }
        modifiedContent =
            modifiedContent.substring(0, insertPosition) +
            importStatement +
            modifiedContent.substring(insertPosition);
        hasChanges = true;
      } else {
        // No imports exist, add at the beginning after potential comments
        final lines = modifiedContent.split('\n');
        var insertIndex = 0;
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].trim().startsWith('//')) {
            insertIndex = i + 1;
          } else if (lines[i].trim().isNotEmpty) {
            break;
          }
        }
        lines.insert(insertIndex, importStatement.trimRight());
        modifiedContent = lines.join('\n');
        hasChanges = true;
      }
    }

    return hasChanges ? modifiedContent : content;
  }

  /// Determines the relative import path for an entity
  String _getRelativeImportPath(String filePath, String entitySnake) {
    // Determine the relative path based on the file location
    // This matches the same logic used in the generators

    final normalizedPath = path.normalize(filePath);

    // Check if file is in data/data_sources
    if (normalizedPath.contains('/data/data_sources/') ||
        normalizedPath.contains('\\data\\data_sources\\')) {
      return '../../../domain/entities/$entitySnake/$entitySnake.dart';
    }

    // Check if file is in data/repositories
    if (normalizedPath.contains('/data/repositories/') ||
        normalizedPath.contains('\\data\\repositories\\')) {
      return '../domain/entities/$entitySnake/$entitySnake.dart';
    }

    // Check if file is in domain/repositories
    if (normalizedPath.contains('/domain/repositories/') ||
        normalizedPath.contains('\\domain\\repositories\\')) {
      return '../entities/$entitySnake/$entitySnake.dart';
    }

    // Check if file is in domain/usecases
    if (normalizedPath.contains('/domain/usecases/') ||
        normalizedPath.contains('\\domain\\usecases\\')) {
      return '../../entities/$entitySnake/$entitySnake.dart';
    }

    // Check if file is in data/providers
    if (normalizedPath.contains('/data/providers/') ||
        normalizedPath.contains('\\data\\providers\\')) {
      return '../../../domain/services/${entitySnake}_service.dart';
    }

    // Fallback: calculate based on path structure
    final parts = path.split(normalizedPath);

    // Find 'lib' if it exists, otherwise use 'data' or 'domain' as base
    var baseIndex = -1;
    for (var i = parts.length - 1; i >= 0; i--) {
      if (parts[i] == 'lib') {
        baseIndex = i;
        break;
      }
      if ((parts[i] == 'data' || parts[i] == 'domain') && baseIndex < 0) {
        baseIndex = i;
      }
    }

    if (baseIndex >= 0) {
      final depth = parts.length - baseIndex - 1;
      final relativePrefix = List.generate(depth, (_) => '..').join('/');
      return '$relativePrefix/domain/entities/$entitySnake/$entitySnake.dart';
    }

    // Last resort: assume 3 levels up
    return '../../../domain/entities/$entitySnake/$entitySnake.dart';
  }

  Future<AppendResult> appendMethod() async {
    final updatedFiles = <GeneratedFile>[];
    final warnings = <String>[];

    if (config.repo == null && config.service == null) {
      warnings.add('⚠️  --append requires --repo or --service flag');
      return AppendResult(updatedFiles, warnings);
    }

    // Handle service append
    if (config.hasService) {
      return _appendServiceMethod();
    }

    // Handle repository append (existing logic)
    final repoName = config.repo!.endsWith('Repository')
        ? config.repo!.replaceAll('Repository', '')
        : config.repo!;
    final repoSnake = StringUtils.camelToSnake(repoName);
    final methodName = config.getRepoMethodName();
    final paramsType = config.paramsType ?? 'NoParams';
    final returnsType = config.returnsType ?? 'void';

    // Determine return type based on UseCase type
    String returnSignature;
    if (config.useCaseType == 'stream') {
      // For stream, returnsType might already be Stream<T>, so check
      if (returnsType.startsWith('Stream<')) {
        returnSignature = returnsType;
      } else {
        returnSignature = 'Stream<$returnsType>';
      }
    } else if (config.useCaseType == 'completable') {
      returnSignature = 'Future<void>';
    } else if (config.useCaseType == 'sync') {
      returnSignature = returnsType;
    } else {
      returnSignature = 'Future<$returnsType>';
    }

    // 1. Append to Repository interface (create if doesn't exist)
    final repoPath = path.join(
      outputDir,
      'domain',
      'repositories',
      '${repoSnake}_repository.dart',
    );
    final repoExists = File(repoPath).existsSync();

    if (!repoExists) {
      // Create repository if it doesn't exist
      await _createRepository(
        repoPath,
        repoName,
        methodName,
        returnSignature,
        paramsType,
      );
      updatedFiles.add(
        GeneratedFile(path: repoPath, type: 'repository', action: 'created'),
      );
    } else if (await _appendToRepository(
      repoPath,
      methodName,
      returnSignature,
      paramsType,
    )) {
      updatedFiles.add(
        GeneratedFile(path: repoPath, type: 'repository', action: 'updated'),
      );
    } else {
      warnings.add('Failed to append to ${repoSnake}_repository.dart');
    }

    // 2. Append to DataRepository
    final dataRepoPath = path.join(
      outputDir,
      'data',
      'repositories',
      'data_${repoSnake}_repository.dart',
    );
    if (await _appendToDataRepository(
      dataRepoPath,
      methodName,
      returnSignature,
      paramsType,
      repoSnake,
    )) {
      updatedFiles.add(
        GeneratedFile(
          path: dataRepoPath,
          type: 'repository',
          action: 'updated',
        ),
      );
    } else {
      warnings.add(
        'DataRepository not found: data_${repoSnake}_repository.dart',
      );
    }

    // 3. Append to DataSource interface
    final dataSourcePath = await _findDataSource(repoSnake);
    if (dataSourcePath != null) {
      if (await _appendToDataSource(
        dataSourcePath,
        methodName,
        returnSignature,
        paramsType,
      )) {
        updatedFiles.add(
          GeneratedFile(
            path: dataSourcePath,
            type: 'datasource',
            action: 'updated',
          ),
        );
      }
    } else {
      warnings.add('DataSource not found for $repoSnake');
    }

    // 4. Append to RemoteDataSource
    final remoteDataSourcePath = await _findRemoteDataSource(repoSnake);
    if (remoteDataSourcePath != null) {
      if (await _appendToRemoteDataSource(
        remoteDataSourcePath,
        methodName,
        returnSignature,
        paramsType,
      )) {
        updatedFiles.add(
          GeneratedFile(
            path: remoteDataSourcePath,
            type: 'datasource',
            action: 'updated',
          ),
        );
      }
    } else {
      warnings.add('RemoteDataSource not found for $repoSnake');
    }

    // 5. Append to LocalDataSource (if exists)
    final localDataSourcePath = await _findLocalDataSource(repoSnake);
    if (localDataSourcePath != null) {
      if (await _appendToLocalDataSource(
        localDataSourcePath,
        methodName,
        returnSignature,
        paramsType,
      )) {
        updatedFiles.add(
          GeneratedFile(
            path: localDataSourcePath,
            type: 'datasource',
            action: 'updated',
          ),
        );
      }
    }

    // 6. Append to MockDataSource (if exists)
    final mockDataSourcePath = await _findMockDataSource(repoSnake);
    if (mockDataSourcePath != null) {
      if (await _appendToMockDataSource(
        mockDataSourcePath,
        methodName,
        returnSignature,
        paramsType,
      )) {
        updatedFiles.add(
          GeneratedFile(
            path: mockDataSourcePath,
            type: 'datasource',
            action: 'updated',
          ),
        );
      }
    }

    return AppendResult(updatedFiles, warnings);
  }

  Future<bool> _appendToRepository(
    String filePath,
    String methodName,
    String returnSignature,
    String paramsType,
  ) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    var content = await file.readAsString();

    // Add missing entity imports
    content = await _addMissingImports(content, filePath);

    final lastBrace = content.lastIndexOf('}');
    if (lastBrace == -1) return false;

    final methodSignature =
        '  $returnSignature $methodName($paramsType params);\n';
    final newContent =
        content.substring(0, lastBrace) +
        methodSignature +
        content.substring(lastBrace);

    await _writeFile(filePath, newContent, 'append');
    return true;
  }

  Future<bool> _appendToDataRepository(
    String filePath,
    String methodName,
    String returnSignature,
    String paramsType,
    String repoSnake,
  ) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    var content = await file.readAsString();

    // Add missing entity imports
    content = await _addMissingImports(content, filePath);

    final lastBrace = content.lastIndexOf('}');
    if (lastBrace == -1) return false;

    // Detect datasource field name from existing content
    final dataSourceFieldMatch = RegExp(
      r'final \w+ (_\w+);',
    ).firstMatch(content);
    final dataSourceField = dataSourceFieldMatch?.group(1) ?? '_dataSource';

    final isStream = config.useCaseType == 'stream';
    final isSync = config.useCaseType == 'sync';
    final methodImpl =
        '''
  @override
  $returnSignature $methodName($paramsType params) ${isStream || isSync ? '' : 'async '}{\n    ${isStream || isSync ? 'return' : 'return await'} $dataSourceField.$methodName(params);
  }

''';

    final newContent =
        content.substring(0, lastBrace) +
        methodImpl +
        content.substring(lastBrace);

    await _writeFile(filePath, newContent, 'append');
    return true;
  }

  Future<bool> _appendToDataSource(
    String filePath,
    String methodName,
    String returnSignature,
    String paramsType,
  ) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    var content = await file.readAsString();

    // Add missing entity imports
    content = await _addMissingImports(content, filePath);

    final lastBrace = content.lastIndexOf('}');
    if (lastBrace == -1) return false;

    final methodSignature =
        '  $returnSignature $methodName($paramsType params);\n';
    final newContent =
        content.substring(0, lastBrace) +
        methodSignature +
        content.substring(lastBrace);

    await _writeFile(filePath, newContent, 'append');
    return true;
  }

  Future<bool> _appendToRemoteDataSource(
    String filePath,
    String methodName,
    String returnSignature,
    String paramsType,
  ) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    var content = await file.readAsString();

    // Add missing entity imports
    content = await _addMissingImports(content, filePath);

    final lastBrace = content.lastIndexOf('}');
    if (lastBrace == -1) return false;

    final methodImpl =
        '''
  @override
  $returnSignature $methodName($paramsType params) ${config.useCaseType == 'stream' || config.useCaseType == 'sync' ? '' : 'async '}{\n    // TODO: Implement remote $methodName
    throw UnimplementedError('Implement remote $methodName');
  }

''';

    final newContent =
        content.substring(0, lastBrace) +
        methodImpl +
        content.substring(lastBrace);

    await _writeFile(filePath, newContent, 'append');
    return true;
  }

  Future<bool> _appendToMockDataSource(
    String filePath,
    String methodName,
    String returnSignature,
    String paramsType,
  ) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    var content = await file.readAsString();

    // Add missing entity imports
    content = await _addMissingImports(content, filePath);

    final lastBrace = content.lastIndexOf('}');
    if (lastBrace == -1) return false;

    final isStream = config.useCaseType == 'stream';
    final isSync = config.useCaseType == 'sync';
    final methodImpl =
        '''
  @override
  $returnSignature $methodName($paramsType params) ${isStream || isSync ? '' : 'async '}{\n    // TODO: Return mock data
    throw UnimplementedError('Return mock data for $methodName');
  }

''';

    final newContent =
        content.substring(0, lastBrace) +
        methodImpl +
        content.substring(lastBrace);

    await _writeFile(filePath, newContent, 'append');
    return true;
  }

  Future<bool> _appendToLocalDataSource(
    String filePath,
    String methodName,
    String returnSignature,
    String paramsType,
  ) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    var content = await file.readAsString();

    // Add missing entity imports
    content = await _addMissingImports(content, filePath);

    final lastBrace = content.lastIndexOf('}');
    if (lastBrace == -1) return false;

    final isStream = config.useCaseType == 'stream';
    final isSync = config.useCaseType == 'sync';
    final methodImpl =
        '''
  @override
  $returnSignature $methodName($paramsType params) ${isStream || isSync ? '' : 'async '}{\n    // TODO: Implement local storage $methodName
    throw UnimplementedError('Implement local storage $methodName');
  }

''';

    final newContent =
        content.substring(0, lastBrace) +
        methodImpl +
        content.substring(lastBrace);

    await _writeFile(filePath, newContent, 'append');
    return true;
  }

  Future<String?> _findDataSource(String repoSnake) async {
    // Try direct path first
    final directPath = path.join(
      outputDir,
      'data',
      'data_sources',
      repoSnake,
      '${repoSnake}_data_source.dart',
    );
    if (File(directPath).existsSync()) return directPath;

    // Fallback: search in domain folder
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

  Future<String?> _findRemoteDataSource(String repoSnake) async {
    // Try direct path first
    final directPath = path.join(
      outputDir,
      'data',
      'data_sources',
      repoSnake,
      '${repoSnake}_remote_data_source.dart',
    );
    if (File(directPath).existsSync()) return directPath;

    // Fallback: search in domain folder
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

  Future<String?> _findLocalDataSource(String repoSnake) async {
    // Try direct path first
    final directPath = path.join(
      outputDir,
      'data',
      'data_sources',
      repoSnake,
      '${repoSnake}_local_data_source.dart',
    );
    if (File(directPath).existsSync()) return directPath;

    // Fallback: search in domain folder
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

  Future<String?> _findMockDataSource(String repoSnake) async {
    // Try direct path first
    final directPath = path.join(
      outputDir,
      'data',
      'data_sources',
      repoSnake,
      '${repoSnake}_mock_data_source.dart',
    );
    if (File(directPath).existsSync()) return directPath;

    // Fallback: search in domain folder
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

  Future<void> _createRepository(
    String filePath,
    String repoName,
    String methodName,
    String returnSignature,
    String paramsType,
  ) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);

    final content =
        '''
// Generated by zfa
// Repository interface for $repoName

abstract class ${repoName}Repository {
  $returnSignature $methodName($paramsType params);
}
''';

    await _writeFile(filePath, content, 'append');
  }

  /// Append a method to an existing service interface
  Future<AppendResult> _appendServiceMethod() async {
    final updatedFiles = <GeneratedFile>[];
    final warnings = <String>[];

    final serviceName = config.effectiveService!;
    final serviceSnake = config.serviceSnake!;
    final methodName = config.getServiceMethodName();
    final paramsType = config.paramsType ?? 'NoParams';
    final returnsType = config.returnsType ?? 'void';

    // Determine return type based on UseCase type
    String returnSignature;
    if (config.useCaseType == 'stream') {
      if (returnsType.startsWith('Stream<')) {
        returnSignature = returnsType;
      } else {
        returnSignature = 'Stream<$returnsType>';
      }
    } else if (config.useCaseType == 'completable') {
      returnSignature = 'Future<void>';
    } else if (config.useCaseType == 'sync') {
      returnSignature = returnsType;
    } else {
      returnSignature = 'Future<$returnsType>';
    }

    // Find or create the service file
    final servicePath = path.join(
      outputDir,
      'domain',
      'services',
      '${serviceSnake}_service.dart',
    );
    final serviceExists = File(servicePath).existsSync();

    if (!serviceExists) {
      // Create service if it doesn't exist
      await _createService(
        servicePath,
        serviceName,
        methodName,
        returnSignature,
        paramsType,
      );
      updatedFiles.add(
        GeneratedFile(path: servicePath, type: 'service', action: 'created'),
      );
    } else if (await _appendToService(
      servicePath,
      methodName,
      returnSignature,
      paramsType,
    )) {
      updatedFiles.add(
        GeneratedFile(path: servicePath, type: 'service', action: 'updated'),
      );
    } else {
      warnings.add('Failed to append to ${serviceSnake}_service.dart');
    }

    // Append to provider if it exists
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
        if (await _appendToProvider(
          providerPath,
          methodName,
          returnSignature,
          paramsType,
        )) {
          updatedFiles.add(
            GeneratedFile(
              path: providerPath,
              type: 'provider',
              action: 'updated',
            ),
          );
        } else {
          warnings.add('Failed to append to ${serviceSnake}_provider.dart');
        }
      } else {
        // Create provider if it doesn't exist and --data is specified
        await _createProvider(
          providerPath,
          serviceName,
          methodName,
          returnSignature,
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

    return AppendResult(updatedFiles, warnings);
  }

  Future<bool> _appendToService(
    String filePath,
    String methodName,
    String returnSignature,
    String paramsType,
  ) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    var content = await file.readAsString();

    // Add missing entity imports
    content = await _addMissingImports(content, filePath);

    final lastBrace = content.lastIndexOf('}');
    if (lastBrace == -1) return false;

    final methodSignature =
        '  $returnSignature $methodName($paramsType params);\n';
    final newContent =
        content.substring(0, lastBrace) +
        methodSignature +
        content.substring(lastBrace);

    await _writeFile(filePath, newContent, 'append');
    return true;
  }

  Future<void> _createService(
    String filePath,
    String serviceName,
    String methodName,
    String returnSignature,
    String paramsType,
  ) async {
    final content =
        '''
// Generated by zfa
// Service interface for ${config.name}

import 'package:zuraffa/zuraffa.dart';

abstract class $serviceName {
  $returnSignature $methodName($paramsType params);
}
''';

    await _writeFile(filePath, content, 'append');
  }

  Future<bool> _appendToProvider(
    String filePath,
    String methodName,
    String returnSignature,
    String paramsType,
  ) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    var content = await file.readAsString();

    // Add missing entity imports
    content = await _addMissingImports(content, filePath);

    final lastBrace = content.lastIndexOf('}');
    if (lastBrace == -1) return false;

    final isStream = config.useCaseType == 'stream';
    final isSync = config.useCaseType == 'sync';
    final methodImpl =
        '''
  @override
  $returnSignature $methodName($paramsType params) ${isStream || isSync ? '' : 'async '}{
    // TODO: Implement $methodName
    throw UnimplementedError('Implement $methodName');
  }

''';

    final newContent =
        content.substring(0, lastBrace) +
        methodImpl +
        content.substring(lastBrace);

    await _writeFile(filePath, newContent, 'append');
    return true;
  }

  Future<void> _createProvider(
    String filePath,
    String serviceName,
    String methodName,
    String returnSignature,
    String paramsType,
  ) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);

    final serviceSnake = config.serviceSnake!;
    final providerName = config.effectiveProvider!;

    final isStream = config.useCaseType == 'stream';
    final isSync = config.useCaseType == 'sync';

    // Build imports
    final imports = <String>[
      "import 'package:zuraffa/zuraffa.dart';",
      "import '../../../domain/services/${serviceSnake}_service.dart';",
    ];

    final content =
        '''
// Generated by zfa
// Provider implementation for $serviceName

${imports.join('\n')}

class $providerName with Loggable, FailureHandler implements $serviceName {
  @override
  $returnSignature $methodName($paramsType params) ${isStream || isSync ? '' : 'async '}{
    // TODO: Implement $methodName
    throw UnimplementedError('Implement $methodName');
  }
}
''';

    await _writeFile(filePath, content, 'append');
  }
}

class AppendResult {
  final List<GeneratedFile> updatedFiles;
  final List<String> warnings;

  AppendResult(this.updatedFiles, this.warnings);
}
