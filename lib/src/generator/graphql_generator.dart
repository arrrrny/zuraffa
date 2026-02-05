import 'package:path/path.dart' as path;
import '../models/generator_config.dart';
import '../models/generated_file.dart';
import '../utils/file_utils.dart';
import '../utils/string_utils.dart';

class GraphQLGenerator {
  final GeneratorConfig config;
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;

  GraphQLGenerator({
    required this.config,
    required this.outputDir,
    this.dryRun = false,
    this.force = false,
    this.verbose = false,
  });

  Future<List<GeneratedFile>> generate() async {
    final files = <GeneratedFile>[];

    if (config.isEntityBased) {
      for (final method in config.methods) {
        final file = await _generateForMethod(method);
        files.add(file);
      }
    } else if (config.isCustomUseCase) {
      final file = await _generateForCustomUseCase();
      files.add(file);
    }

    return files;
  }

  Future<GeneratedFile> _generateForMethod(String method) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final operationType = _getOperationType(method);
    final operationName = _getOperationName(method, entityName);
    
    final fileName = '${StringUtils.camelToSnake(operationName)}_$operationType.dart';
    final filePath = path.join(
      outputDir,
      'data',
      'data_sources',
      entitySnake,
      'graphql',
      fileName,
    );

    final gqlString = _generateGraphQLString(method, entityName, operationType, operationName);
    final content = _generateFileContent(operationName, operationType, gqlString);

    return FileUtils.writeFile(
      filePath,
      content,
      'graphql_$operationType',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<GeneratedFile> _generateForCustomUseCase() async {
    final useCaseName = config.name;
    final domain = config.effectiveDomain;
    final operationType = _getCustomOperationType();
    final operationName = useCaseName.endsWith('UseCase') 
        ? useCaseName.substring(0, useCaseName.length - 7)
        : useCaseName;
    
    final fileName = '${StringUtils.camelToSnake(operationName)}_$operationType.dart';
    final filePath = path.join(
      outputDir,
      'data',
      'data_sources',
      domain,
      'graphql',
      fileName,
    );

    final gqlString = _generateCustomGraphQLString(operationName, operationType);
    final content = _generateFileContent(operationName, operationType, gqlString);

    return FileUtils.writeFile(
      filePath,
      content,
      'graphql_$operationType',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  String _getOperationType(String method) {
    if (config.gqlType != null) {
      return config.gqlType!;
    }
    
    switch (method) {
      case 'get':
      case 'getList':
        return 'query';
      case 'create':
      case 'update':
      case 'delete':
        return 'mutation';
      case 'watch':
      case 'watchList':
        return 'subscription';
      default:
        return 'query';
    }
  }

  String _getCustomOperationType() {
    if (config.gqlType != null) {
      return config.gqlType!;
    }
    
    // For custom UseCases, gql-type is mandatory when --gql is used
    throw ArgumentError('--gql-type is required for custom UseCases when using --gql');
  }

  String _getOperationName(String method, String entityName) {
    switch (method) {
      case 'get':
        return 'Get$entityName';
      case 'getList':
        return 'Get${entityName}List';
      case 'create':
        return 'Create$entityName';
      case 'update':
        return 'Update$entityName';
      case 'delete':
        return 'Delete$entityName';
      case 'watch':
        return 'Watch$entityName';
      case 'watchList':
        return 'Watch${entityName}List';
      default:
        return method + entityName;
    }
  }

  String _generateGraphQLString(String method, String entityName, String operationType, String operationName) {
    final entitySnake = StringUtils.camelToSnake(entityName);
    final returnFields = _getReturnFields(entityName);
    final inputType = config.gqlInputType ?? '${entityName}Input';
    final inputName = config.gqlInputName ?? 'input';
    final gqlOperationName = config.gqlName ?? operationName;
    final wrapperName = gqlOperationName; // PascalCase for wrapper
    final camelCaseOpName = StringUtils.pascalToCamel(gqlOperationName); // camelCase for inner

    switch (method) {
      case 'get':
        return '''
  $operationType $wrapperName(\$${config.idField}: ${_getGraphQLType(config.idType)}!) {
    $camelCaseOpName(${config.idField}: \$${config.idField}) {
$returnFields
    }
  }''';

      case 'getList':
        if (config.gqlInputType != null) {
          return '''
  $operationType $wrapperName(\$$inputName: $inputType!) {
    $camelCaseOpName($inputName: \$$inputName) {
$returnFields
    }
  }''';
        } else {
          return '''
  $operationType $wrapperName {
    $camelCaseOpName {
$returnFields
    }
  }''';
        }

      case 'create':
        return '''
  $operationType $wrapperName(\$$inputName: ${inputType.startsWith('Create') ? inputType : 'Create$inputType'}!) {
    $camelCaseOpName($inputName: \$$inputName) {
$returnFields
    }
  }''';

      case 'update':
        return '''
  $operationType $wrapperName(\$${config.idField}: ${_getGraphQLType(config.idType)}!, \$$inputName: ${inputType.startsWith('Update') ? inputType : 'Update$inputType'}!) {
    $camelCaseOpName(${config.idField}: \$${config.idField}, $inputName: \$$inputName) {
$returnFields
    }
  }''';

      case 'delete':
        return '''
  $operationType $wrapperName(\$${config.idField}: ${_getGraphQLType(config.idType)}!) {
    $camelCaseOpName(${config.idField}: \$${config.idField}) {
      success
    }
  }''';

      default:
        return '''
  $operationType $wrapperName {
    $camelCaseOpName {
$returnFields
    }
  }''';
    }
  }

  String _generateCustomGraphQLString(String operationName, String operationType) {
    final paramsType = config.paramsType ?? 'NoParams';
    final returnsType = config.returnsType ?? 'void';
    final returnFields = _getCustomReturnFields(returnsType);
    final inputType = config.gqlInputType ?? '${paramsType}Input';
    final inputName = config.gqlInputName ?? 'input';
    final gqlOperationName = config.gqlName ?? operationName;
    final wrapperName = gqlOperationName; // PascalCase for wrapper
    final camelCaseOpName = StringUtils.pascalToCamel(gqlOperationName); // camelCase for inner

    if (paramsType == 'NoParams' && config.gqlInputType == null) {
      return '''
  $operationType $wrapperName {
    $camelCaseOpName {
$returnFields
    }
  }''';
    } else {
      return '''
  $operationType $wrapperName(\$$inputName: $inputType!) {
    $camelCaseOpName($inputName: \$$inputName) {
$returnFields
    }
  }''';
    }
  }

  String _getReturnFields(String entityName) {
    if (config.gqlReturns != null) {
      return _formatGraphQLFields(config.gqlReturns!);
    }

    // Auto-generate common fields
    return '''      ${config.idField}
      createdAt
      updatedAt''';
  }

  String _getCustomReturnFields(String returnsType) {
    if (config.gqlReturns != null) {
      return _formatGraphQLFields(config.gqlReturns!);
    }

    if (returnsType == 'void') {
      return '      success';
    }

    // Auto-generate common fields for the return type
    return '''      id
      createdAt
      updatedAt''';
  }

  String _formatGraphQLFields(String fieldsStr) {
    final fields = fieldsStr.split(',').map((f) => f.trim()).toList();
    final result = StringBuffer();
    final fieldTree = <String, dynamic>{};
    
    // Build nested field tree
    for (final field in fields) {
      final parts = field.split('.');
      dynamic current = fieldTree;
      
      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];
        if (i == parts.length - 1) {
          // Leaf node
          if (current is Map) {
            current[part] = true;
          }
        } else {
          // Intermediate node
          if (current is Map) {
            current.putIfAbsent(part, () => <String, dynamic>{});
            current = current[part];
          }
        }
      }
    }
    
    // Convert tree to GraphQL format
    _writeGraphQLFields(fieldTree, result, 6);
    return result.toString().trimRight();
  }
  
  void _writeGraphQLFields(Map<String, dynamic> fields, StringBuffer buffer, int indent) {
    final spaces = ' ' * indent;
    
    for (final entry in fields.entries) {
      if (entry.value == true) {
        // Simple field
        buffer.writeln('$spaces${entry.key}');
      } else if (entry.value is Map) {
        // Nested field
        buffer.writeln('$spaces${entry.key}{');
        _writeGraphQLFields(entry.value as Map<String, dynamic>, buffer, indent + 2);
        buffer.writeln('$spaces}');
      }
    }
  }

  String _getGraphQLType(String dartType) {
    switch (dartType) {
      case 'String':
        return 'String';
      case 'int':
        return 'Int';
      case 'double':
        return 'Float';
      case 'bool':
        return 'Boolean';
      default:
        return 'ID';
    }
  }

  String _generateFileContent(String operationName, String operationType, String gqlString) {
    final constantName = StringUtils.pascalToCamel(operationName) + StringUtils.convertToPascalCase(operationType);
    
    return '''
// Generated GraphQL $operationType for $operationName
const String $constantName = r\'\'\'$gqlString
\'\'\';
''';
  }
}
