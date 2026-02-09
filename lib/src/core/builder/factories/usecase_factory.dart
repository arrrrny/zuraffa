import 'package:code_builder/code_builder.dart';

import '../patterns/usecase_patterns.dart';
import '../shared/spec_library.dart';

class UseCaseSpecConfig {
  final String className;
  final String baseClass;
  final String repositoryType;
  final String repositoryField;
  final String returnType;
  final String paramsType;
  final String executeBody;
  final bool hasParams;
  final bool isAsync;
  final bool overrideMethod;
  final List<String> imports;

  const UseCaseSpecConfig({
    required this.className,
    required this.baseClass,
    required this.repositoryType,
    required this.repositoryField,
    required this.returnType,
    required this.paramsType,
    required this.executeBody,
    this.hasParams = true,
    this.isAsync = true,
    this.overrideMethod = true,
    this.imports = const [],
  });
}

class UseCaseFactory {
  final SpecLibrary specLibrary;

  const UseCaseFactory({this.specLibrary = const SpecLibrary()});

  Library build(UseCaseSpecConfig config) {
    final executeMethod = UseCasePatterns.executeMethod(
      returnType: config.returnType,
      paramsType: config.paramsType,
      body: config.executeBody,
      isAsync: config.isAsync,
      overrideMethod: config.overrideMethod,
      hasParams: config.hasParams,
    );

    final clazz = UseCasePatterns.useCaseClass(
      className: config.className,
      baseClass: config.baseClass,
      repositoryType: config.repositoryType,
      repositoryField: config.repositoryField,
      executeMethod: executeMethod,
    );

    return specLibrary.library(
      specs: [clazz],
      directives: config.imports.map(Directive.import),
    );
  }
}
