part of 'custom_usecase_generator.dart';

extension CustomUseCaseGeneratorMethods on CustomUseCaseGenerator {
  List<Method> _buildMethods(
    GeneratorConfig config,
    String paramsType,
    String returnsType,
    List<Field> dependencyFields,
  ) {
    final methodName = config.hasService
        ? config.getServiceMethodName()
        : config.getRepoMethodName();

    // Prefer service over repo if both exist
    final depField = dependencyFields.isNotEmpty
        ? (config.hasService
              ? dependencyFields
                    .firstWhere(
                      (f) => f.name.endsWith('Service'),
                      orElse: () => dependencyFields.first,
                    )
                    .name
              : dependencyFields.first.name)
        : '';

    if (config.useCaseType == 'stream') {
      final dependencyCall = depField.isEmpty
          ? null
          : refer(depField)
                .property(methodName)
                .call(
                  config.hasMultipleParams
                      ? config.multipleParams
                            .map(
                              (p) => refer(
                                'intent',
                              ).property('params').property(p.name),
                            )
                            .toList()
                      : [refer('intent').property('params')],
                );
      return _buildWatchMethods(paramsType, returnsType, dependencyCall);
    }

    if (config.useCaseType == 'sync') {
      final executeBody = depField.isEmpty
          ? Block(
              (b) => b
                ..statements.add(Code('// TODO: Implement usecase logic'))
                ..statements.add(
                  refer('UnimplementedError').call([]).thrown.statement,
                ),
            )
          : refer(depField)
                .property(methodName)
                .call(
                  config.hasMultipleParams
                      ? config.multipleParams
                            .map((p) => refer('params').property(p.name))
                            .toList()
                      : [refer('params')],
                )
                .code;
      return [
        Method(
          (b) => b
            ..name = 'execute'
            ..returns = refer(returnsType)
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer(paramsType),
              ),
            )
            ..annotations.add(CodeExpression(Code('override')))
            ..lambda = depField.isNotEmpty
            ..body = executeBody,
        ),
      ];
    }
    final executeBody = depField.isEmpty
        ? Block((b) {
            b.statements.add(Code('cancelToken?.throwIfCancelled();'));
            b.statements.add(Code('// TODO: Implement usecase logic'));
            b.statements.add(
              refer('UnimplementedError').call([]).thrown.statement,
            );
          })
        : Block((b) {
            b.statements.add(Code('cancelToken?.throwIfCancelled();'));
            b.statements.add(
              refer(depField)
                  .property(methodName)
                  .call(
                    config.hasMultipleParams
                        ? config.multipleParams
                              .map((p) => refer('params').property(p.name))
                              .toList()
                        : [refer('params')],
                  )
                  .awaited
                  .returned
                  .statement,
            );
          });

    final returnTypeRef = config.useCaseType == 'completable'
        ? 'Future<void>'
        : 'Future<$returnsType>';

    return [
      Method(
        (b) => b
          ..name = 'execute'
          ..returns = refer(returnTypeRef)
          ..modifier = MethodModifier.async
          ..requiredParameters.add(
            Parameter(
              (p) => p
                ..name = 'params'
                ..type = refer(paramsType),
            ),
          )
          ..optionalParameters.add(
            Parameter(
              (p) => p
                ..name = 'cancelToken'
                ..type = refer('CancelToken?'),
            ),
          )
          ..annotations.add(CodeExpression(Code('override')))
          ..body = executeBody,
      ),
    ];
  }

  List<Method> _buildWatchMethods(
    String paramsType,
    String returnsType,
    Expression? dependencyCall,
  ) {
    final intentType = 'WatchUseCaseIntent<$paramsType>';
    final resultType = TypeReference(
      (t) => t
        ..symbol = 'Result'
        ..types.addAll([refer(returnsType), refer('AppFailure')]),
    );
    final readMethod = Method(
      (b) => b
        ..name = 'read'
        ..returns = resultType
        ..requiredParameters.addAll([
          Parameter(
            (p) => p
              ..name = 'intent'
              ..type = refer(intentType),
          ),
          Parameter(
            (p) => p
              ..name = 'ctx'
              ..type = refer('ZfaContext'),
          ),
        ])
        ..annotations.add(CodeExpression(Code('override')))
        ..body = Block(
          (bb) => bb
            ..statements.add(
              refer(
                'UnimplementedError',
              ).call([literalString('Implement read')]).thrown.statement,
            ),
        ),
    );
    final executeBody = Block((b) {
      b.statements.add(
        refer('ctx').property('throwIfCancelled').call([]).statement,
      );
      if (dependencyCall == null) {
        b.statements.add(
          refer(
            'UnimplementedError',
          ).call([literalString('Implement execute')]).thrown.statement,
        );
      } else {
        b.statements.add(
          refer('Result')
              .property('success')
              .call([dependencyCall.property('first').awaited])
              .returned
              .statement,
        );
      }
    });
    final executeMethod = Method(
      (b) => b
        ..name = 'execute'
        ..returns = TypeReference(
          (t) => t
            ..symbol = 'Future'
            ..types.add(resultType),
        )
        ..modifier = MethodModifier.async
        ..requiredParameters.addAll([
          Parameter(
            (p) => p
              ..name = 'intent'
              ..type = refer(intentType),
          ),
          Parameter(
            (p) => p
              ..name = 'ctx'
              ..type = refer('ZfaContext'),
          ),
        ])
        ..annotations.add(CodeExpression(Code('override')))
        ..body = executeBody,
    );
    return [readMethod, executeMethod];
  }

  List<Method> _buildOrchestratorExecute(
    GeneratorConfig config,
    String paramsType,
    String returnsType,
  ) {
    if (config.useCaseType == 'stream') {
      return _buildWatchMethods(paramsType, returnsType, null);
    }
    final signature = config.useCaseType == 'completable'
        ? 'Future<void>'
        : config.useCaseType == 'sync'
        ? returnsType
        : 'Future<$returnsType>';
    final isAsync = config.useCaseType != 'sync';
    final executeBody = Block((b) {
      if (config.useCaseType == 'sync') {
        b.statements.add(Code('// TODO: Implement orchestration logic'));
        b.statements.add(
          refer('UnimplementedError')
              .call([literalString('Implement orchestration logic')])
              .thrown
              .statement,
        );
      } else {
        b.statements.add(Code('cancelToken?.throwIfCancelled();'));
        b.statements.add(Code('// TODO: Implement orchestration logic'));
        b.statements.add(
          refer('UnimplementedError')
              .call([literalString('Implement orchestration logic')])
              .thrown
              .statement,
        );
      }
    });

    return [
      Method((b) {
        b
          ..name = 'execute'
          ..returns = refer(signature)
          ..modifier = isAsync ? MethodModifier.async : null
          ..requiredParameters.add(
            Parameter(
              (p) => p
                ..name = 'params'
                ..type = refer(paramsType),
            ),
          )
          ..annotations.add(CodeExpression(Code('override')))
          ..body = executeBody;
        if (config.useCaseType != 'sync') {
          b.optionalParameters.add(
            Parameter(
              (p) => p
                ..name = 'cancelToken'
                ..type = refer('CancelToken?'),
            ),
          );
        }
      }),
    ];
  }

  List<Method> _buildPolymorphicExecute(
    GeneratorConfig config,
    String paramsType,
    String returnsType,
    String variant,
  ) {
    if (config.useCaseType == 'stream') {
      return _buildWatchMethods(paramsType, returnsType, null);
    }
    final signature = config.useCaseType == 'completable'
        ? 'Future<void>'
        : config.useCaseType == 'sync'
        ? returnsType
        : 'Future<$returnsType>';
    final isAsync = config.useCaseType != 'sync';
    final executeBody = Block((b) {
      if (config.useCaseType == 'sync') {
        b.statements.add(Code('// TODO: Implement $variant variant'));
        b.statements.add(
          refer('UnimplementedError')
              .call([literalString('Implement $variant variant')])
              .thrown
              .statement,
        );
      } else {
        b.statements.add(Code('cancelToken?.throwIfCancelled();'));
        b.statements.add(Code('// TODO: Implement $variant variant'));
        b.statements.add(
          refer('UnimplementedError')
              .call([literalString('Implement $variant variant')])
              .thrown
              .statement,
        );
      }
    });

    return [
      Method((b) {
        b
          ..name = 'execute'
          ..returns = refer(signature)
          ..modifier = isAsync ? MethodModifier.async : null
          ..requiredParameters.add(
            Parameter(
              (p) => p
                ..name = 'params'
                ..type = refer(paramsType),
            ),
          )
          ..annotations.add(CodeExpression(Code('override')))
          ..body = executeBody;
        if (config.useCaseType != 'sync') {
          b.optionalParameters.add(
            Parameter(
              (p) => p
                ..name = 'cancelToken'
                ..type = refer('CancelToken?'),
            ),
          );
        }
      }),
    ];
  }

  _FactoryClassParts _buildPolymorphicFactory(
    GeneratorConfig config,
    String baseClassName,
    String factoryClassName,
    String paramsType,
  ) {
    final fields = <Field>[];
    final constructorParams = <Parameter>[];
    for (final variant in config.variants) {
      // Issue #1723 review: derive variant refs from the normalized
      // baseClassName param, not raw config.name.
      final className = '$variant$baseClassName';
      final fieldName = '_${StringUtils.pascalToCamel(variant)}';
      fields.add(
        Field(
          (b) => b
            ..name = fieldName
            ..type = refer(className)
            ..modifier = FieldModifier.final$,
        ),
      );
      constructorParams.add(
        Parameter(
          (p) => p
            ..name = fieldName
            ..toThis = true,
        ),
      );
    }

    final variantMap = <Expression, Expression>{
      for (final variant in config.variants)
        refer('$variant$paramsType'): refer(
          '_${StringUtils.pascalToCamel(variant)}',
        ),
    };
    final selection = literalMap(variantMap)
        .index(refer('params').property('runtimeType'))
        .ifNullThen(
          refer(
            'UnimplementedError',
          ).call([literalString('Unknown params type')]).thrown,
        );

    final forParamsMethod = Method(
      (b) => b
        ..name = 'forParams'
        ..returns = refer(baseClassName)
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer(paramsType),
          ),
        )
        ..body = Block((b) => b..statements.add(selection.returned.statement)),
    );

    final factorySpec = UseCaseClassSpec(
      className: factoryClassName,
      fields: fields,
      constructors: [
        Constructor((b) => b..requiredParameters.addAll(constructorParams)),
      ],
      methods: [forParamsMethod],
    );

    return _FactoryClassParts(
      fields: factorySpec.fields,
      constructors: factorySpec.constructors,
      methods: factorySpec.methods,
    );
  }
}

class _FactoryClassParts {
  final List<Field> fields;
  final List<Constructor> constructors;
  final List<Method> methods;

  const _FactoryClassParts({
    required this.fields,
    required this.constructors,
    required this.methods,
  });
}
