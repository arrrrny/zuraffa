import 'package:code_builder/code_builder.dart';

import '../../../core/builder/patterns/common_patterns.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../models/generator_config.dart';
import '../../../utils/string_utils.dart';

class ServiceInterfaceBuilder {
  final SpecLibrary specLibrary;

  const ServiceInterfaceBuilder({this.specLibrary = const SpecLibrary()});

  String build(GeneratorConfig config) {
    final serviceName = config.effectiveService;
    if (serviceName == null) {
      throw ArgumentError(
        'Service name must be specified via --service or config.service',
      );
    }
    
    final methods = <Method>[];

    if (config.methods.isNotEmpty) {
      for (final method in config.methods) {
        methods.add(_buildEntityMethod(config, method));
      }
    } else {
      final paramsType = config.paramsType ?? 'NoParams';
      final returnsType = config.returnsType ?? 'void';
      final methodName = config.getServiceMethodName();

      final returnSignature = _returnSignature(config, returnsType);
      final params = [
        Parameter(
          (p) => p
            ..name = 'params'
            ..type = refer(paramsType),
        ),
      ];

      methods.add(
        CommonPatterns.abstractMethod(
          name: methodName,
          returnType: returnSignature,
          parameters: params,
        ),
      );
    }

    if (config.generateInit) {
      methods.add(
        Method(
          (m) => m
            ..name = 'isInitialized'
            ..type = MethodType.getter
            ..returns = refer('Stream<bool>'),
        ),
      );
      methods.add(
        Method(
          (m) => m
            ..name = 'initialize'
            ..returns = refer('Future<void>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('InitializationParams'),
              ),
            ),
        ),
      );
      methods.add(
        Method(
          (m) => m
            ..name = 'dispose'
            ..returns = refer('Future<void>'),
        ),
      );
    }

    final clazz = Class(
      (b) => b
        ..name = serviceName
        ..abstract = true
        ..docs.add('/// Service interface for $serviceName')
        ..methods.addAll(methods),
    );

    final imports = <String>['package:zuraffa/zuraffa.dart'];
    if (config.isEntityBased) {
      // For entity methods, we definitely need the entity import
      final entityName = config.name;
      final entitySnake = StringUtils.camelToSnake(entityName);
      imports.add('../../entities/$entitySnake/$entitySnake.dart');
    } else {
      final paramsType = config.paramsType ?? 'NoParams';
      final returnsType = config.returnsType ?? 'void';
      imports.addAll(
        CommonPatterns.entityImports(
          [paramsType, returnsType],
          config,
          depth: 1,
          includeDomain: false,
        ),
      );
    }

    final directives = imports.toSet().map((path) => Directive.import(path)).toList();

    return specLibrary.emitSpec(clazz, directives: directives);
  }

  Method _buildEntityMethod(GeneratorConfig config, String method) {
    final entityName = config.name;
    String name = method;
    String returnType;
    List<Parameter> parameters = [];

    switch (method) {
      case 'get':
        returnType = 'Future<$entityName>';
        parameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer('QueryParams<$entityName>'),
          ),
        );
        break;
      case 'getList':
      case 'list':
        name = 'getList';
        returnType = 'Future<List<$entityName>>';
        parameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer('ListQueryParams<$entityName>'),
          ),
        );
        break;
      case 'create':
        returnType = 'Future<$entityName>';
        parameters.add(
          Parameter(
            (p) => p
              ..name = 'item'
              ..type = refer(entityName),
          ),
        );
        break;
      case 'update':
        returnType = 'Future<$entityName>';
        parameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer('UpdateParams<${config.idFieldType}, ${entityName}Patch>'),
          ),
        );
        break;
      case 'delete':
        returnType = 'Future<void>';
        parameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer('DeleteParams<${config.idFieldType}>'),
          ),
        );
        break;
      case 'watch':
        returnType = 'Stream<$entityName>';
        parameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer('QueryParams<$entityName>'),
          ),
        );
        break;
      case 'watchList':
        returnType = 'Stream<List<$entityName>>';
        parameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer('ListQueryParams<$entityName>'),
          ),
        );
        break;
      default:
        throw ArgumentError('Unknown entity method: $method');
    }

    return CommonPatterns.abstractMethod(
      name: name,
      returnType: returnType,
      parameters: parameters,
    );
  }

  String _returnSignature(GeneratorConfig config, String returnsType) {
    switch (config.useCaseType) {
      case 'stream':
        return 'Stream<$returnsType>';
      case 'completable':
        return 'Future<void>';
      case 'sync':
        return returnsType;
      default:
        return 'Future<$returnsType>';
    }
  }
}
