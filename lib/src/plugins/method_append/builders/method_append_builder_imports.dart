part of 'method_append_builder.dart';

extension MethodAppendBuilderImports on MethodAppendBuilder {
  Future<String> _addMissingImports(
    GeneratorConfig config,
    String source,
    String filePath, {
    bool isMock = false,
  }) async {
    final entities = _collectEntityTypes(config);
    if (isMock) {
      final targetEntity = config.isCustomUseCase && config.returnsType != null
          ? EntityUtils.extractEntityTypes(config.returnsType!).firstOrNull ??
                config.name
          : config.name;
      entities.add('${targetEntity}MockData');
    }
    if (entities.isEmpty) return source;

    // Check if the source uses any of these types but doesn't have an import
    // Note: this is a simple check, could be improved with AST
    var content = source;
    for (final entityName in entities) {
      if (!content.contains(entityName)) continue;

      final entitySnake = StringUtils.camelToSnake(
        entityName.replaceAll('MockData', ''),
      );
      if (_hasEntityImport(content, entityName, entitySnake)) continue;

      final isEnum = EntityAnalyzer.isEnum(entityName, outputDir);
      final isMockData = entityName.endsWith('MockData');
      final relativePath = isEnum
          ? _getEnumImportPath(filePath, entitySnake)
          : isMockData
          ? _getMockDataImportPath(filePath, entitySnake)
          : _getRelativeImportPath(filePath, entitySnake);
      final request = AppendRequest.import(
        source: content,
        importPath: relativePath,
      );
      final result = appendExecutor.execute(request);
      content = result.source;
    }
    return content;
  }

  String _getMockDataImportPath(String filePath, String entitySnake) {
    final normalizedPath = path.normalize(filePath);
    if (normalizedPath.contains('/domain/services/') ||
        normalizedPath.contains('\\domain\\services\\')) {
      return '../../mock/${entitySnake}_mock_data.dart';
    }
    if (normalizedPath.contains('/data/providers/') ||
        normalizedPath.contains('\\data\\providers\\')) {
      return '../../mock/${entitySnake}_mock_data.dart';
    }
    if (normalizedPath.contains('/data/datasources/') ||
        normalizedPath.contains('\\data\\datasources\\')) {
      return '../../mock/${entitySnake}_mock_data.dart';
    }
    return '../../mock/${entitySnake}_mock_data.dart';
  }

  String _getEnumImportPath(String filePath, String entitySnake) {
    final normalizedPath = path.normalize(filePath);
    String relativeEnumPath = '../entities/enums/index.dart';

    final typeSnake = entitySnake;
    final enumDir = '$outputDir/domain/entities/enums';
    final specificEnumPath = '$enumDir/$typeSnake.dart';
    if (File(specificEnumPath).existsSync()) {
      relativeEnumPath = '../entities/enums/$typeSnake.dart';
    }

    if (normalizedPath.contains('/data/datasources/') ||
        normalizedPath.contains('\\data\\datasources\\')) {
      final parts = path.split(normalizedPath);
      final index = parts.lastIndexOf('datasources');
      if (index != -1 && index + 2 < parts.length) {
        return '../../../domain/${relativeEnumPath.replaceAll('../', '')}';
      }
      return '../../domain/${relativeEnumPath.replaceAll('../', '')}';
    }
    if (normalizedPath.contains('/data/repositories/') ||
        normalizedPath.contains('\\data\\repositories\\')) {
      return '../../domain/${relativeEnumPath.replaceAll('../', '')}';
    }
    if (normalizedPath.contains('/domain/repositories/') ||
        normalizedPath.contains('\\domain\\repositories\\')) {
      return relativeEnumPath;
    }
    if (normalizedPath.contains('/domain/services/') ||
        normalizedPath.contains('\\domain\\services\\')) {
      return relativeEnumPath;
    }
    if (normalizedPath.contains('/domain/usecases/') ||
        normalizedPath.contains('\\domain\\usecases\\')) {
      return '../$relativeEnumPath';
    }
    if (normalizedPath.contains('/data/providers/') ||
        normalizedPath.contains('\\data\\providers\\')) {
      return '../../../domain/${relativeEnumPath.replaceAll('../', '')}';
    }
    return '../../../domain/${relativeEnumPath.replaceAll('../', '')}';
  }

  Set<String> _collectEntityTypes(GeneratorConfig config) {
    final entities = <String>{};
    if (config.hasMultipleParams) {
      for (final p in config.multipleParams) {
        entities.addAll(EntityUtils.extractEntityTypes(p.type));
      }
    } else {
      final paramsType = config.paramsType;
      if (paramsType != null && paramsType != 'NoParams') {
        entities.addAll(EntityUtils.extractEntityTypes(paramsType));
      }
    }
    final returnsType = config.returnsType;
    if (returnsType != null && returnsType != 'void') {
      entities.addAll(EntityUtils.extractEntityTypes(returnsType));
    }
    return entities;
  }

  bool _hasEntityImport(String content, String entityName, String entitySnake) {
    final pattern1 = RegExp(
      "import\\s+['\\\"]([^'\\\"]*/entities/$entitySnake/[^'\\\"]*)['\\\"]",
    );
    final escapedEntityName = RegExp.escape(entityName);
    final pattern2 = RegExp(
      "import\\s+['\\\"]([^'\\\"]*$escapedEntityName\\.dart)['\\\"]",
    );
    return pattern1.hasMatch(content) || pattern2.hasMatch(content);
  }

  String _getRelativeImportPath(String filePath, String entitySnake) {
    final normalizedPath = path.normalize(filePath);
    if (normalizedPath.contains('/data/datasources/') ||
        normalizedPath.contains('\\data\\datasources\\')) {
      // Check if it's a domain-specific datasource
      final parts = path.split(normalizedPath);
      final index = parts.lastIndexOf('datasources');
      if (index != -1 && index + 2 < parts.length) {
        // e.g. lib/src/data/datasources/listing/listing_datasource.dart
        // path from listing/ to src: ../../../
        return '../../../domain/entities/$entitySnake/$entitySnake.dart';
      }
      return '../../domain/entities/$entitySnake/$entitySnake.dart';
    }
    if (normalizedPath.contains('/data/repositories/') ||
        normalizedPath.contains('\\data\\repositories\\')) {
      return '../../domain/entities/$entitySnake/$entitySnake.dart';
    }
    if (normalizedPath.contains('/domain/repositories/') ||
        normalizedPath.contains('\\domain\\repositories\\')) {
      return '../entities/$entitySnake/$entitySnake.dart';
    }
    if (normalizedPath.contains('/domain/services/') ||
        normalizedPath.contains('\\domain\\services\\')) {
      return '../entities/$entitySnake/$entitySnake.dart';
    }
    if (normalizedPath.contains('/domain/usecases/') ||
        normalizedPath.contains('\\domain\\usecases\\')) {
      return '../../entities/$entitySnake/$entitySnake.dart';
    }
    if (normalizedPath.contains('/data/providers/') ||
        normalizedPath.contains('\\data\\providers\\')) {
      return '../../../domain/entities/$entitySnake/$entitySnake.dart';
    }
    return '../../../domain/entities/$entitySnake/$entitySnake.dart';
  }
}
