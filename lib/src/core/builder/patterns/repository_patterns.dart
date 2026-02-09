import 'package:code_builder/code_builder.dart';

import 'common_patterns.dart';

class RepositoryPatterns {
  static Method repositoryMethod({
    required String name,
    required String returnType,
    Iterable<Parameter> parameters = const [],
  }) {
    return CommonPatterns.abstractMethod(
      name: name,
      returnType: returnType,
      parameters: parameters,
    );
  }

  static Class repositoryInterface({
    required String className,
    required Iterable<Method> methods,
  }) {
    return Class(
      (b) => b
        ..name = className
        ..abstract = true
        ..methods.addAll(methods),
    );
  }
}
