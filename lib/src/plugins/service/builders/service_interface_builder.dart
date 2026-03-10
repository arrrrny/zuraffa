import 'package:code_builder/code_builder.dart';

import '../../../core/builder/patterns/common_patterns.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../models/generator_config.dart';

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
    final params = [
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
        ..docs.add('/// Service interface for $serviceName')
        ..methods.add(method),
    );

    final directives = <Directive>[
      Directive.import('package:zuraffa/zuraffa.dart'),
      ...CommonPatterns.entityImports([
        paramsType,
        returnsType,
      ], config).map((path) => Directive.import(path)),
    ];

    return specLibrary.emitSpec(clazz, directives: directives);
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
