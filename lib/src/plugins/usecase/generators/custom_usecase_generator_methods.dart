part of 'custom_usecase_generator.dart';

extension CustomUseCaseGeneratorMethods on CustomUseCaseGenerator {
  List<Method> _buildMethods(
    GeneratorConfig config,
    String paramsType,
    String returnsType,
    List<Field> dependencyFields,
  ) {
    if (config.useCaseType == 'background') {
      return _buildBackgroundMethods(paramsType, returnsType);
    }
    final methodName = config.hasService
        ? config.getServiceMethodName()
        : config.getRepoMethodName();
    final depField = dependencyFields.isNotEmpty
        ? dependencyFields.first.name
        : '';

    if (config.useCaseType == 'stream') {
      final executeBody = depField.isEmpty
              ? Block(
                  (b) => b
                    ..statements.add(Code('// TODO: Implement usecase logic'))
                    ..statements.add(
                      refer('UnimplementedError').call([]).thrown.statement,
                    ),
                )
              : Block(
              (b) => b
                ..statements.add(
                  refer(depField)
                      .property(methodName)
                      .call([refer('params')])
                      .returned
                      .statement,
                ),
            );
      return [
        Method(
          (b) => b
            ..name = 'execute'
            ..returns = refer('Stream<$returnsType>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer(paramsType),
              ),
            )
            ..requiredParameters.add(
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

    if (config.useCaseType == 'sync') {
      final executeBody = depField.isEmpty
          ? Block(
              (b) => b
                ..statements.add(Code('// TODO: Implement usecase logic'))
                ..statements.add(
                  refer('UnimplementedError').call([]).thrown.statement,
                ),
            )
          : Block(
              (b) => b
                ..statements.add(
                  refer(depField)
                      .property(methodName)
                      .call([refer('params')])
                      .returned
                      .statement,
                ),
            );
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
            ..body = executeBody,
        ),
      ];
    }
    final executeBody = Block(
      (b) {
        b.statements.add(Code('cancelToken?.throwIfCancelled();'));
        if (depField.isEmpty) {
          b.statements.add(Code('// TODO: Implement usecase logic'));
          b.statements.add(
            refer('UnimplementedError').call([]).thrown.statement,
          );
        } else {
          b.statements.add(
            refer(depField)
                .property(methodName)
                .call([refer('params')])
                .awaited
                .returned
                .statement,
          );
        }
      },
    );

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
          ..requiredParameters.add(
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

  List<Method> _buildBackgroundMethods(String paramsType, String returnsType) {
    final buildTask = Method(
      (b) => b
        ..name = 'buildTask'
        ..returns = refer('BackgroundTask<$paramsType>')
        ..annotations.add(CodeExpression(Code('override')))
        ..body = Block(
          (bb) => bb..statements.add(refer('_process').returned.statement),
        ),
    );

    final processMethod = Method(
      (b) => b
        ..name = '_process'
        ..static = true
        ..returns = refer('void')
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'context'
              ..type = refer('BackgroundTaskContext<$paramsType>'),
          ),
        )
        ..body = Block(
          (bb) => bb
            ..statements.add(
              declareFinal(
                'params',
              ).assign(refer('context').property('params')).statement,
            )
            ..statements.add(
              refer('Future')
                  .property('sync')
                  .call([
                    Method(
                      (m) => m
                        ..lambda = true
                        ..body = refer(
                          'processData',
                        ).call([refer('params')]).code,
                    ).closure,
                  ])
                  .property('then')
                  .call([
                    Method(
                      (m) => m
                        ..requiredParameters.add(
                          Parameter((p) => p..name = 'result'),
                        )
                        ..body = Block(
                          (bbb) => bbb
                            ..statements.add(
                              refer('context').property('sendData').call([
                                refer('result'),
                              ]).statement,
                            )
                            ..statements.add(
                              refer(
                                'context',
                              ).property('sendDone').call([]).statement,
                            ),
                        ),
                    ).closure,
                  ])
                  .property('catchError')
                  .call([
                    Method(
                      (m) => m
                        ..requiredParameters.addAll([
                          Parameter((p) => p..name = 'error'),
                          Parameter((p) => p..name = 'stackTrace'),
                        ])
                        ..body = Block(
                          (bbb) => bbb
                            ..statements.add(
                              refer('context').property('sendError').call([
                                refer('error'),
                                refer('stackTrace'),
                              ]).statement,
                            ),
                        ),
                    ).closure,
                  ])
                  .statement,
            ),
        ),
    );

    final processData = Method(
      (b) => b
        ..name = 'processData'
        ..static = true
        ..returns = refer(returnsType)
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer(paramsType),
          ),
        )
        ..body = Block(
          (bb) => bb
            ..statements.add(
              refer('UnimplementedError')
                  .call([
                    literalString('Implement your background processing logic'),
                  ])
                  .thrown
                  .statement,
            ),
        ),
    );

    return [buildTask, processMethod, processData];
  }

  Method _buildOrchestratorExecute(
    GeneratorConfig config,
    String paramsType,
    String returnsType,
  ) {
    final signature = config.useCaseType == 'stream'
        ? 'Stream<$returnsType>'
        : config.useCaseType == 'completable'
        ? 'Future<void>'
        : config.useCaseType == 'sync'
        ? returnsType
        : 'Future<$returnsType>';
    final isAsync = config.useCaseType != 'sync';
    final executeBody = Block(
      (b) {
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
      },
    );

    return Method((b) {
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
        b.requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'cancelToken'
              ..type = refer('CancelToken?'),
          ),
        );
      }
    });
  }

  Method _buildPolymorphicExecute(
    GeneratorConfig config,
    String paramsType,
    String returnsType,
    String variant,
  ) {
    final signature = config.useCaseType == 'stream'
        ? 'Stream<$returnsType>'
        : config.useCaseType == 'completable'
        ? 'Future<void>'
        : config.useCaseType == 'sync'
        ? returnsType
        : 'Future<$returnsType>';
    final isAsync = config.useCaseType != 'sync';
    final executeBody = Block(
      (b) {
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
      },
    );

    return Method((b) {
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
        b.requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'cancelToken'
              ..type = refer('CancelToken?'),
          ),
        );
      }
    });
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
      final className = '$variant${config.name}UseCase';
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
