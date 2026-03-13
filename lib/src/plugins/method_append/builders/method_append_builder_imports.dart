part of 'method_append_builder.dart';

extension MethodAppendBuilderImports on MethodAppendBuilder {
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

      final isEnum = EntityAnalyzer.isEnum(entityName, outputDir);
      final relativePath = isEnum
          ? _getEnumImportPath(filePath)
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

  String _getEnumImportPath(String filePath) {
    final normalizedPath = path.normalize(filePath);
    if (normalizedPath.contains('/data/datasources/') ||
        normalizedPath.contains('\\data\\datasources\\')) {
      final parts = path.split(normalizedPath);
      final index = parts.lastIndexOf('datasources');
      if (index != -1 && index + 2 < parts.length) {
        return '../../../domain/entities/enums/index.dart';
      }
      return '../../domain/entities/enums/index.dart';
    }
    if (normalizedPath.contains('/data/repositories/') ||
        normalizedPath.contains('\\data\\repositories\\')) {
      return '../../domain/entities/enums/index.dart';
    }
    if (normalizedPath.contains('/domain/repositories/') ||
        normalizedPath.contains('\\domain\\repositories\\')) {
      return '../entities/enums/index.dart';
    }
    if (normalizedPath.contains('/domain/usecases/') ||
        normalizedPath.contains('\\domain\\usecases\\')) {
      return '../../entities/enums/index.dart';
    }
    if (normalizedPath.contains('/data/providers/') ||
        normalizedPath.contains('\\data\\providers\\')) {
      return '../../../domain/entities/enums/index.dart';
    }
    return '../../../domain/entities/enums/index.dart';
  }

  Set<String> _collectEntityTypes(GeneratorConfig config) {
    final entities = <String>{};
    final paramsType = config.paramsType;
    if (paramsType != null && paramsType != 'NoParams') {
      entities.addAll(EntityUtils.extractEntityTypes(paramsType));
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
    final pattern2 = RegExp(
      "import\\s+['\\\"]([^'\\\"]*$entityName\\.dart)['\\\"]",
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
}
