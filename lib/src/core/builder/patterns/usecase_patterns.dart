import 'package:code_builder/code_builder.dart';

import 'common_patterns.dart';

class UseCasePatterns {
  static Method executeMethod({
    required String returnType,
    required String paramsType,
    required String body,
    String name = 'execute',
    bool isAsync = true,
    bool overrideMethod = true,
    bool hasParams = true,
  }) {
    return Method(
      (b) => b
        ..name = name
        ..returns = refer(returnType)
        ..modifier = isAsync ? MethodModifier.async : null
        ..requiredParameters.addAll(
          hasParams
              ? [
                Parameter(
                  (p) => p
                    ..name = 'params'
                    ..type = refer(paramsType),
                ),
              ]
              : const [],
        )
        ..annotations.addAll(
          overrideMethod ? [CodeExpression(Code('override'))] : const [],
        )
        ..body = Code(body),
    );
  }

  static Class useCaseClass({
    required String className,
    required String baseClass,
    required String repositoryType,
    required String repositoryField,
    required Method executeMethod,
    bool isAbstract = false,
  }) {
    return Class(
      (b) => b
        ..name = className
        ..extend = refer(baseClass)
        ..abstract = isAbstract
        ..fields.add(
          CommonPatterns.finalField(repositoryField, repositoryType),
        )
        ..constructors.add(
          CommonPatterns.constructor(
            parameters: [
              Parameter(
                (p) => p
                  ..name = repositoryField
                  ..toThis = true,
              ),
            ],
          ),
        )
        ..methods.add(executeMethod),
    );
  }
}
