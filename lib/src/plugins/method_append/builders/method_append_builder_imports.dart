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
    final paramsType = config.paramsType;
    if (paramsType != null && paramsType != 'NoParams') {
      final entity = _extractEntityName(paramsType);
      if (entity != null) entities.add(entity);
    }
    final returnsType = config.returnsType;
    if (returnsType != null && returnsType != 'void') {
      final entity = _extractEntityName(returnsType);
      if (entity != null) entities.add(entity);
    }
    return entities;
  }

  String? _extractEntityName(String type) {
    final genericMatch = RegExp(r'^\w+<([^>]+)>').firstMatch(type);
    if (genericMatch != null) {
      final innerType = genericMatch.group(1);
      if (innerType == null) {
        return null;
      }
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
