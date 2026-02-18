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
    final paramsType = config.paramsType ?? 'NoParams';
    final returnsType = config.returnsType ?? 'void';
    final methodName = config.getServiceMethodName();

    final returnSignature = _returnSignature(config, returnsType);
    final params = paramsType == 'NoParams'
        ? const <Parameter>[]
        : [
            Parameter(
              (p) => p
                ..name = 'params'
                ..type = refer(paramsType),
            ),
          ];

    final method = CommonPatterns.abstractMethod(
      name: methodName,
      returnType: returnSignature,
      parameters: params,
    );

    final clazz = Class(
      (b) => b
        ..name = serviceName
        ..abstract = true
        ..methods.add(method),
    );

    final directives = <Directive>[
      Directive.import('package:zuraffa/zuraffa.dart'),
      ..._entityImports([paramsType, returnsType]).map(Directive.import),
    ];

    return specLibrary.emitLibrary(
      specLibrary.library(specs: [clazz], directives: directives),
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

  List<String> _entityImports(List<String> types) {
    final entities = <String>[];
    final primitives = {
      'void',
      'String',
      'int',
      'double',
      'bool',
      'dynamic',
      'Object',
      'NoParams',
      'Params',
      'QueryParams',
      'ListQueryParams',
      'UpdateParams',
      'DeleteParams',
      'CreateParams',
      'Map',
      'Set',
      'List',
      'Result',
      'AppFailure',
      'Duration',
      'DateTime',
    };

    for (final type in types) {
      final baseTypes = _extractBaseTypes(type);
      for (final baseType in baseTypes) {
        if (!primitives.contains(baseType) &&
            !baseType.startsWith('Map<') &&
            !baseType.startsWith('Set<')) {
          entities.add(baseType);
        }
      }
    }

    return entities.toSet().map((entity) {
      final entitySnake = StringUtils.camelToSnake(entity);
      return '../entities/$entitySnake/$entitySnake.dart';
    }).toList();
  }

  List<String> _extractBaseTypes(String type) {
    final results = <String>[];
    final genericMatch = RegExp(r'(\w+)<(.+)>').firstMatch(type);
    if (genericMatch != null) {
      final innerType = genericMatch.group(2);
      if (innerType != null) {
        results.addAll(_extractBaseTypes(innerType));
      }
    } else if (type.isNotEmpty && type != 'void') {
      results.add(type);
    }

    return results;
  }
}
