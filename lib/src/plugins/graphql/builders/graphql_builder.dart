import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/builder/shared/spec_library.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';

class GraphqlBuilder {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final SpecLibrary specLibrary;

  GraphqlBuilder({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    SpecLibrary? specLibrary,
  }) : specLibrary = specLibrary ?? const SpecLibrary();

  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    final files = <GeneratedFile>[];

    if (config.isEntityBased) {
      for (final method in config.methods) {
        final file = await _generateForMethod(config, method);
        files.add(file);
      }
    } else if (config.isCustomUseCase) {
      final file = await _generateForCustomUseCase(config);
      files.add(file);
    }

    return files;
  }

  Future<GeneratedFile> _generateForMethod(
    GeneratorConfig config,
    String method,
  ) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final operationType = _getOperationType(config, method);
    final operationName = _getOperationName(method, entityName);

    final fileName =
        '${StringUtils.camelToSnake(operationName)}_$operationType.dart';
    final filePath = path.join(
      outputDir,
      'data',
      'data_sources',
      entitySnake,
      'graphql',
      fileName,
    );

    final gqlString = _generateGraphQLString(
      config,
      method,
      entityName,
      operationType,
      operationName,
    );
    final content = _generateFileContent(
      operationName,
      operationType,
      gqlString,
    );

    return FileUtils.writeFile(
      filePath,
      content,
      'graphql_$operationType',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<GeneratedFile> _generateForCustomUseCase(
    GeneratorConfig config,
  ) async {
    final useCaseName = config.name;
    final domain = config.effectiveDomain;
    final operationType = _getCustomOperationType(config);
    final operationName = useCaseName.endsWith('UseCase')
        ? useCaseName.substring(0, useCaseName.length - 7)
        : useCaseName;

    final fileName =
        '${StringUtils.camelToSnake(operationName)}_$operationType.dart';
    final filePath = path.join(
      outputDir,
      'data',
      'data_sources',
      domain,
      'graphql',
      fileName,
    );

    final gqlString = _generateCustomGraphQLString(
      config,
      operationName,
      operationType,
    );
    final content = _generateFileContent(
      operationName,
      operationType,
      gqlString,
    );

    return FileUtils.writeFile(
      filePath,
      content,
      'graphql_$operationType',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  String _getOperationType(GeneratorConfig config, String method) {
    final gqlType = config.gqlType;
    if (gqlType != null) {
      return gqlType;
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

  String _getCustomOperationType(GeneratorConfig config) {
    final gqlType = config.gqlType;
    if (gqlType != null) {
      return gqlType;
    }

    throw ArgumentError(
      '--gql-type is required for custom UseCases when using --gql',
    );
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

  String _generateGraphQLString(
    GeneratorConfig config,
    String method,
    String entityName,
    String operationType,
    String operationName,
  ) {
    final returnFields = _getReturnFields(config, entityName);
    final inputType = config.gqlInputType ?? '${entityName}Input';
    final inputName = config.gqlInputName ?? 'input';
    final gqlOperationName = config.gqlName ?? operationName;
    final wrapperName = gqlOperationName;
    final camelCaseOpName = StringUtils.pascalToCamel(gqlOperationName);

    switch (method) {
      case 'get':
        return _lines([
          '  $operationType $wrapperName(\$${config.idField}: ${_getGraphQLType(config.idType)}!) {',
          '    $camelCaseOpName(${config.idField}: \$${config.idField}) {',
          returnFields,
          '    }',
          '  }',
        ]);

      case 'getList':
        if (config.gqlInputType != null) {
          return _lines([
            '  $operationType $wrapperName(\$$inputName: $inputType!) {',
            '    $camelCaseOpName($inputName: \$$inputName) {',
            returnFields,
            '    }',
            '  }',
          ]);
        } else {
          return _lines([
            '  $operationType $wrapperName {',
            '    $camelCaseOpName {',
            returnFields,
            '    }',
            '  }',
          ]);
        }

      case 'create':
        return _lines([
          '  $operationType $wrapperName(\$$inputName: ${inputType.startsWith('Create') ? inputType : 'Create$inputType'}!) {',
          '    $camelCaseOpName($inputName: \$$inputName) {',
          returnFields,
          '    }',
          '  }',
        ]);

      case 'update':
        return _lines([
          '  $operationType $wrapperName(\$${config.idField}: ${_getGraphQLType(config.idType)}!, \$$inputName: ${inputType.startsWith('Update') ? inputType : 'Update$inputType'}!) {',
          '    $camelCaseOpName(${config.idField}: \$${config.idField}, $inputName: \$$inputName) {',
          returnFields,
          '    }',
          '  }',
        ]);

      case 'delete':
        return _lines([
          '  $operationType $wrapperName(\$${config.idField}: ${_getGraphQLType(config.idType)}!) {',
          '    $camelCaseOpName(${config.idField}: \$${config.idField}) {',
          '      success',
          '    }',
          '  }',
        ]);

      default:
        return _lines([
          '  $operationType $wrapperName {',
          '    $camelCaseOpName {',
          returnFields,
          '    }',
          '  }',
        ]);
    }
  }

  String _generateCustomGraphQLString(
    GeneratorConfig config,
    String operationName,
    String operationType,
  ) {
    final paramsType = config.paramsType ?? 'NoParams';
    final returnsType = config.returnsType ?? 'void';
    final returnFields = _getCustomReturnFields(config, returnsType);
    final inputType = config.gqlInputType ?? '${paramsType}Input';
    final inputName = config.gqlInputName ?? 'input';
    final gqlOperationName = config.gqlName ?? operationName;
    final wrapperName = gqlOperationName;
    final camelCaseOpName = StringUtils.pascalToCamel(gqlOperationName);

    if (paramsType == 'NoParams' && config.gqlInputType == null) {
      return _lines([
        '  $operationType $wrapperName {',
        '    $camelCaseOpName {',
        returnFields,
        '    }',
        '  }',
      ]);
    } else {
      return _lines([
        '  $operationType $wrapperName(\$$inputName: $inputType!) {',
        '    $camelCaseOpName($inputName: \$$inputName) {',
        returnFields,
        '    }',
        '  }',
      ]);
    }
  }

  String _getReturnFields(GeneratorConfig config, String entityName) {
    final gqlReturns = config.gqlReturns;
    if (gqlReturns != null) {
      return _formatGraphQLFields(gqlReturns);
    }

    return _lines([
      '      ${config.idField}',
      '      createdAt',
      '      updatedAt',
    ]);
  }

  String _getCustomReturnFields(GeneratorConfig config, String returnsType) {
    final gqlReturns = config.gqlReturns;
    if (gqlReturns != null) {
      return _formatGraphQLFields(gqlReturns);
    }

    if (returnsType == 'void') {
      return '      success';
    }

    return _lines(['      id', '      createdAt', '      updatedAt']);
  }

  String _formatGraphQLFields(String fieldsStr) {
    final fields = fieldsStr.split(',').map((f) => f.trim()).toList();
    final result = StringBuffer();
    final fieldTree = <String, dynamic>{};

    for (final field in fields) {
      final parts = field.split('.');
      dynamic current = fieldTree;

      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];
        if (i == parts.length - 1) {
          if (current is Map) {
            current[part] = true;
          }
        } else {
          if (current is Map) {
            current.putIfAbsent(part, () => <String, dynamic>{});
            current = current[part];
          }
        }
      }
    }

    _writeGraphQLFields(fieldTree, result, 6);
    return result.toString().trimRight();
  }

  void _writeGraphQLFields(
    Map<String, dynamic> fields,
    StringBuffer buffer,
    int indent,
  ) {
    final spaces = ' ' * indent;

    for (final entry in fields.entries) {
      if (entry.value == true) {
        buffer.writeln('$spaces${entry.key}');
      } else if (entry.value is Map) {
        buffer.writeln('$spaces${entry.key}{');
        _writeGraphQLFields(
          entry.value as Map<String, dynamic>,
          buffer,
          indent + 2,
        );
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

  String _generateFileContent(
    String operationName,
    String operationType,
    String gqlString,
  ) {
    final constantName =
        StringUtils.pascalToCamel(operationName) +
        StringUtils.convertToPascalCase(operationType);

    final field = Field(
      (f) => f
        ..name = constantName
        ..type = refer('String')
        ..modifier = FieldModifier.constant
        ..assignment = _graphqlLiteral(gqlString),
    );
    return specLibrary.emitSpec(field);
  }

  String _lines(List<String> lines) => lines.join('\n');

  Code _graphqlLiteral(String gqlString) {
    final escaped = gqlString.replaceAll(r'$', r'\$');
    return Code('r"""$escaped"""');
  }
}
