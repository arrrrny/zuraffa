import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/generator_config.dart';
import '../utils/string_utils.dart';

class MethodAppender {
  final GeneratorConfig config;
  final String outputDir;
  final bool verbose;

  MethodAppender({
    required this.config,
    required this.outputDir,
    this.verbose = false,
  });

  Future<List<String>> appendMethod() async {
    final messages = <String>[];

    if (config.repo == null) {
      messages.add('⚠️  --append requires --repo flag');
      return messages;
    }

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
    } else {
      returnSignature = 'Future<$returnsType>';
    }

    // 1. Append to Repository interface
    final repoPath = path.join(
        outputDir, 'domain', 'repositories', '${repoSnake}_repository.dart');
    if (await _appendToRepository(
        repoPath, methodName, returnSignature, paramsType)) {
      messages.add('✓ Appended to ${repoSnake}_repository.dart');
    } else {
      messages.add('⚠️  Repository not found: ${repoSnake}_repository.dart');
    }

    // 2. Append to DataRepository
    final dataRepoPath = path.join(
        outputDir, 'data', 'repositories', 'data_${repoSnake}_repository.dart');
    if (await _appendToDataRepository(
        dataRepoPath, methodName, returnSignature, paramsType, repoSnake)) {
      messages.add('✓ Appended to data_${repoSnake}_repository.dart');
    } else {
      messages.add(
          '⚠️  DataRepository not found: data_${repoSnake}_repository.dart');
    }

    // 3. Append to DataSource interface
    final dataSourcePath = await _findDataSource(repoSnake);
    if (dataSourcePath != null) {
      if (await _appendToDataSource(
          dataSourcePath, methodName, returnSignature, paramsType)) {
        messages.add('✓ Appended to ${path.basename(dataSourcePath)}');
      }
    } else {
      messages.add('⚠️  DataSource not found for $repoSnake');
    }

    // 4. Append to RemoteDataSource
    final remoteDataSourcePath = await _findRemoteDataSource(repoSnake);
    if (remoteDataSourcePath != null) {
      if (await _appendToRemoteDataSource(
          remoteDataSourcePath, methodName, returnSignature, paramsType)) {
        messages.add('✓ Appended to ${path.basename(remoteDataSourcePath)}');
      }
    } else {
      messages.add('⚠️  RemoteDataSource not found for $repoSnake');
    }

    // 5. Append to MockDataSource (if exists)
    final mockDataSourcePath = await _findMockDataSource(repoSnake);
    if (mockDataSourcePath != null) {
      if (await _appendToMockDataSource(
          mockDataSourcePath, methodName, returnSignature, paramsType)) {
        messages.add('✓ Appended to ${path.basename(mockDataSourcePath)}');
      }
    }

    return messages;
  }

  Future<bool> _appendToRepository(String filePath, String methodName,
      String returnSignature, String paramsType) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    final content = await file.readAsString();
    final lastBrace = content.lastIndexOf('}');
    if (lastBrace == -1) return false;

    final methodSignature =
        '  $returnSignature $methodName($paramsType params);\n';
    final newContent = content.substring(0, lastBrace) +
        methodSignature +
        content.substring(lastBrace);

    await file.writeAsString(newContent);
    return true;
  }

  Future<bool> _appendToDataRepository(String filePath, String methodName,
      String returnSignature, String paramsType, String repoSnake) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    final content = await file.readAsString();
    final lastBrace = content.lastIndexOf('}');
    if (lastBrace == -1) return false;

    // Detect datasource field name from existing content
    final dataSourceFieldMatch =
        RegExp(r'final \w+ (_\w+);').firstMatch(content);
    final dataSourceField = dataSourceFieldMatch?.group(1) ?? '_dataSource';

    final isStream = config.useCaseType == 'stream';
    final methodImpl = '''
  @override
  $returnSignature $methodName($paramsType params) ${isStream ? '' : 'async '}{\n    ${isStream ? 'return' : 'return await'} $dataSourceField.$methodName(params);
  }

''';

    final newContent = content.substring(0, lastBrace) +
        methodImpl +
        content.substring(lastBrace);

    await file.writeAsString(newContent);
    return true;
  }

  Future<bool> _appendToDataSource(String filePath, String methodName,
      String returnSignature, String paramsType) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    final content = await file.readAsString();
    final lastBrace = content.lastIndexOf('}');
    if (lastBrace == -1) return false;

    final methodSignature =
        '  $returnSignature $methodName($paramsType params);\n';
    final newContent = content.substring(0, lastBrace) +
        methodSignature +
        content.substring(lastBrace);

    await file.writeAsString(newContent);
    return true;
  }

  Future<bool> _appendToRemoteDataSource(String filePath, String methodName,
      String returnSignature, String paramsType) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    final content = await file.readAsString();
    final lastBrace = content.lastIndexOf('}');
    if (lastBrace == -1) return false;

    final methodImpl = '''
  @override
  $returnSignature $methodName($paramsType params) ${config.useCaseType == 'stream' ? '' : 'async '}{\n    // TODO: Implement remote $methodName
    throw UnimplementedError('Implement remote $methodName');
  }

''';

    final newContent = content.substring(0, lastBrace) +
        methodImpl +
        content.substring(lastBrace);

    await file.writeAsString(newContent);
    return true;
  }

  Future<bool> _appendToMockDataSource(String filePath, String methodName,
      String returnSignature, String paramsType) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    final content = await file.readAsString();
    final lastBrace = content.lastIndexOf('}');
    if (lastBrace == -1) return false;

    final isStream = config.useCaseType == 'stream';
    final methodImpl = '''
  @override
  $returnSignature $methodName($paramsType params) ${isStream ? '' : 'async '}{\n    // TODO: Return mock data
    throw UnimplementedError('Return mock data for $methodName');
  }

''';

    final newContent = content.substring(0, lastBrace) +
        methodImpl +
        content.substring(lastBrace);

    await file.writeAsString(newContent);
    return true;
  }

  Future<String?> _findDataSource(String repoSnake) async {
    // Try direct path first
    final directPath = path.join(outputDir, 'data', 'data_sources', repoSnake,
        '${repoSnake}_data_source.dart');
    if (File(directPath).existsSync()) return directPath;

    // Fallback: search in domain folder
    if (config.domain != null) {
      final domainPath = path.join(outputDir, 'data', 'data_sources',
          config.domain, '${repoSnake}_data_source.dart');
      if (File(domainPath).existsSync()) return domainPath;
    }

    return null;
  }

  Future<String?> _findRemoteDataSource(String repoSnake) async {
    // Try direct path first
    final directPath = path.join(outputDir, 'data', 'data_sources', repoSnake,
        '${repoSnake}_remote_data_source.dart');
    if (File(directPath).existsSync()) return directPath;

    // Fallback: search in domain folder
    if (config.domain != null) {
      final domainPath = path.join(outputDir, 'data', 'data_sources',
          config.domain, '${repoSnake}_remote_data_source.dart');
      if (File(domainPath).existsSync()) return domainPath;
    }

    return null;
  }

  Future<String?> _findMockDataSource(String repoSnake) async {
    // Try direct path first
    final directPath = path.join(outputDir, 'data', 'data_sources', repoSnake,
        '${repoSnake}_mock_data_source.dart');
    if (File(directPath).existsSync()) return directPath;

    // Fallback: search in domain folder
    if (config.domain != null) {
      final domainPath = path.join(outputDir, 'data', 'data_sources',
          config.domain, '${repoSnake}_mock_data_source.dart');
      if (File(domainPath).existsSync()) return domainPath;
    }

    return null;
  }
}
