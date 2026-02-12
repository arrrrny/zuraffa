part of 'test_builder.dart';

extension TestBuilderHelpers on TestBuilder {
  String _resolvePackageName(String projectRoot) {
    String packageName = 'your_app';
    try {
      final pubspecFile = File(path.join(projectRoot, 'pubspec.yaml'));
      if (pubspecFile.existsSync()) {
        final lines = pubspecFile.readAsLinesSync();
        for (final line in lines) {
          if (line.trim().startsWith('name:')) {
            packageName = line.split(':')[1].trim();
            break;
          }
        }
      }
    } catch (_) {}
    return packageName;
  }

  List<Expression> _getFallbackValues(
    GeneratorConfig config,
    String method,
    String mockEntityClass,
  ) {
    final entityName = config.name;
    final idType = config.idType;
    final idValue = idType == 'NoParams'
        ? refer('NoParams').constInstance([])
        : (idType == 'int' ? literalNum(1) : literalString('1'));

    switch (method) {
      case 'get':
      case 'watch':
        return [refer('QueryParams<$entityName>').constInstance([])];
      case 'getList':
      case 'watchList':
        return [refer('ListQueryParams<$entityName>').constInstance([])];
      case 'create':
        return [refer(mockEntityClass).call([])];
      case 'update':
        final dataType = config.useZorphy
            ? '${entityName}Patch'
            : 'Partial<$entityName>';
        final dataValue = config.useZorphy
            ? refer('${entityName}Patch').call([])
            : refer('Partial<$entityName>').call([]);
        return [
          refer(
            'UpdateParams<$idType, $dataType>',
          ).call([], {'id': idValue, 'data': dataValue}),
        ];
      case 'delete':
        return [
          refer('DeleteParams<$idType>').constInstance([], {'id': idValue}),
        ];
      default:
        return [];
    }
  }

  List<Code> _generateFutureTests(
    GeneratorConfig config,
    String method,
    String entityName,
    String returnConstructor,
    bool isCompletable,
  ) {
    final idType = config.idType;
    final idValue = idType == 'NoParams'
        ? refer('NoParams').constInstance([])
        : (idType == 'int' ? literalNum(1) : literalString('1'));

    Expression paramsExpr;
    Expression arrangeCall;
    Expression verifyCall;
    Expression failureArrangeCall;

    if (method == 'get') {
      if (idType == 'NoParams') {
        paramsExpr = refer('NoParams').call([]);
        arrangeCall = refer(
          'mockRepository',
        ).property('get').call([refer('QueryParams').constInstance([])]);
        verifyCall = refer(
          'mockRepository',
        ).property('get').call([refer('QueryParams').constInstance([])]);
      } else {
        paramsExpr = config.useZorphy
            ? refer('QueryParams<$entityName>').call([], {
                'filter': refer('Eq').call([
                  refer('${entityName}Fields').property(config.queryField),
                  literalString('1'),
                ]),
              })
            : refer('QueryParams<$entityName>').call([], {
                'params': refer('Params').call([
                  literalMap({config.queryField: literalString('1')}),
                ]),
              });
        arrangeCall = refer(
          'mockRepository',
        ).property('get').call([refer('any').call([])]);
        verifyCall = refer(
          'mockRepository',
        ).property('get').call([refer('any').call([])]);
      }
    } else if (method == 'getList') {
      paramsExpr = refer('ListQueryParams<$entityName>').call([]);
      arrangeCall = refer(
        'mockRepository',
      ).property('getList').call([refer('any').call([])]);
      verifyCall = refer(
        'mockRepository',
      ).property('getList').call([refer('any').call([])]);
    } else if (method == 'create') {
      paramsExpr = refer('t$entityName');
      arrangeCall = refer(
        'mockRepository',
      ).property('create').call([refer('any').call([])]);
      verifyCall = refer(
        'mockRepository',
      ).property('create').call([refer('any').call([])]);
    } else if (method == 'update') {
      final dataType = config.useZorphy
          ? '${entityName}Patch'
          : 'Partial<$entityName>';
      final dataValue = config.useZorphy
          ? refer('${entityName}Patch').call([])
          : refer('Partial<$entityName>').call([]);
      paramsExpr = refer(
        'UpdateParams<$idType, $dataType>',
      ).call([], {'id': idValue, 'data': dataValue});
      arrangeCall = refer(
        'mockRepository',
      ).property('update').call([refer('any').call([])]);
      verifyCall = refer(
        'mockRepository',
      ).property('update').call([refer('any').call([])]);
    } else if (method == 'delete') {
      paramsExpr = refer('DeleteParams<$idType>').call([], {'id': idValue});
      arrangeCall = refer(
        'mockRepository',
      ).property('delete').call([refer('any').call([])]);
      verifyCall = refer(
        'mockRepository',
      ).property('delete').call([refer('any').call([])]);
    } else {
      return [];
    }

    failureArrangeCall = arrangeCall;

    final successTest = Block((t) {
      t.statements.add(
        refer(
          'when',
        ).call([arrangeCall.toClosure()]).property('thenAnswer').call([
          Method(
            (m) => m
              ..requiredParameters.add(Parameter((p) => p..name = '_'))
              ..modifier = MethodModifier.async
              ..lambda = true
              ..body =
                  (method == 'delete'
                          ? literalMap({})
                          : refer(returnConstructor))
                      .code,
          ).closure,
        ]).statement,
      );
      t.statements.add(
        declareFinal(
          'result',
        ).assign(refer('useCase').call([paramsExpr]).awaited).statement,
      );
      t.statements.add(
        refer('verify').call([verifyCall.toClosure()]).property('called').call([
          literalNum(1),
        ]).statement,
      );
      t.statements.add(
        refer('expect').call([
          refer('result').property('isSuccess'),
          literalBool(true),
        ]).statement,
      );
      if (!isCompletable) {
        t.statements.add(
          refer('expect').call([
            refer('result').property('getOrElse').call([
              Method(
                (m) => m
                  ..lambda = true
                  ..body = refer(
                    'throw',
                  ).call([refer('Exception').call([])]).code,
              ).closure,
            ]),
            refer('equals').call([refer(returnConstructor)]),
          ]).statement,
        );
      }
    });

    final failureTest = Block((t) {
      t.statements.add(
        declareFinal(
          'exception',
        ).assign(refer('Exception').call([literalString('Error')])).statement,
      );
      t.statements.add(
        refer('when')
            .call([failureArrangeCall.toClosure()])
            .property('thenThrow')
            .call([refer('exception')])
            .statement,
      );
      t.statements.add(
        declareFinal(
          'result',
        ).assign(refer('useCase').call([paramsExpr]).awaited).statement,
      );
      t.statements.add(
        refer('verify').call([verifyCall.toClosure()]).property('called').call([
          literalNum(1),
        ]).statement,
      );
      t.statements.add(
        refer('expect').call([
          refer('result').property('isFailure'),
          literalBool(true),
        ]).statement,
      );
    });

    return [
      refer('test').call([
        literalString('should call repository.$method and return result'),
        successTest.toClosure(asAsync: true),
      ]).statement,
      refer('test').call([
        literalString('should return Failure when repository throws'),
        failureTest.toClosure(asAsync: true),
      ]).statement,
    ];
  }

  List<Code> _generateStreamTests(
    GeneratorConfig config,
    String method,
    String entityName,
    String returnConstructor,
  ) {
    final idType = config.idType;

    Expression paramsExpr;
    Expression arrangeCall;
    Expression verifyCall;

    if (method == 'watch') {
      if (idType == 'NoParams') {
        paramsExpr = refer('NoParams').call([]);
        arrangeCall = refer(
          'mockRepository',
        ).property('watch').call([refer('QueryParams').constInstance([])]);
        verifyCall = refer(
          'mockRepository',
        ).property('watch').call([refer('QueryParams').constInstance([])]);
      } else {
        paramsExpr = config.useZorphy
            ? refer('QueryParams<$entityName>').call([], {
                'filter': refer('Eq').call([
                  refer('${entityName}Fields').property(config.queryField),
                  literalString('1'),
                ]),
              })
            : refer('QueryParams<$entityName>').call([], {
                'params': refer('Params').call([
                  literalMap({config.queryField: literalString('1')}),
                ]),
              });
        arrangeCall = refer(
          'mockRepository',
        ).property('watch').call([refer('any').call([])]);
        verifyCall = refer(
          'mockRepository',
        ).property('watch').call([refer('any').call([])]);
      }
    } else if (method == 'watchList') {
      paramsExpr = refer('ListQueryParams<$entityName>').call([]);
      arrangeCall = refer(
        'mockRepository',
      ).property('watchList').call([refer('any').call([])]);
      verifyCall = refer(
        'mockRepository',
      ).property('watchList').call([refer('any').call([])]);
    } else {
      return [];
    }

    final successTest = Block((t) {
      final arrangeCallExpr = refer('when')
          .call([arrangeCall.toClosure()])
          .property('thenAnswer')
          .call([
            Method(
              (m) => m
                ..requiredParameters.add(Parameter((p) => p..name = '_'))
                ..lambda = true
                ..body = refer(
                  'Stream',
                ).property('value').call([refer(returnConstructor)]).code,
            ).closure,
          ]);
      t.statements.add(arrangeCallExpr.statement);
      t.statements.add(
        declareFinal(
          'result',
        ).assign(refer('useCase').call([paramsExpr])).statement,
      );
      t.statements.add(
        refer('expectLater')
            .call([
              refer('result'),
              refer('emits').call([
                refer(
                  'isA',
                ).call([], {}, [refer('Success')]).property('having').call([
                  Method(
                    (m) => m
                      ..requiredParameters.add(Parameter((p) => p..name = 's'))
                      ..lambda = true
                      ..body = refer('s').property('value').code,
                  ).closure,
                  literalString('value'),
                  refer('equals').call([refer(returnConstructor)]),
                ]),
              ]),
            ])
            .awaited
            .statement,
      );
      t.statements.add(
        refer('verify').call([verifyCall.toClosure()]).property('called').call([
          literalNum(1),
        ]).statement,
      );
    });

    final failureTest = Block((t) {
      t.statements.add(
        declareFinal('exception')
            .assign(refer('Exception').call([literalString('Stream Error')]))
            .statement,
      );
      final arrangeCallExpr = refer('when')
          .call([arrangeCall.toClosure()])
          .property('thenAnswer')
          .call([
            Method(
              (m) => m
                ..requiredParameters.add(Parameter((p) => p..name = '_'))
                ..lambda = true
                ..body = refer(
                  'Stream',
                ).property('error').call([refer('exception')]).code,
            ).closure,
          ]);
      t.statements.add(arrangeCallExpr.statement);
      t.statements.add(
        declareFinal(
          'result',
        ).assign(refer('useCase').call([paramsExpr])).statement,
      );
      t.statements.add(
        refer('expectLater')
            .call([
              refer('result'),
              refer('emits').call([
                refer('isA').call([], {}, [refer('Failure')]),
              ]),
            ])
            .awaited
            .statement,
      );
      t.statements.add(
        refer('verify').call([verifyCall.toClosure()]).property('called').call([
          literalNum(1),
        ]).statement,
      );
    });

    return [
      refer('test').call([
        literalString('should emit values from repository stream'),
        successTest.toClosure(asAsync: true),
      ]).statement,
      refer('test').call([
        literalString('should emit Failure when repository stream errors'),
        failureTest.toClosure(asAsync: true),
      ]).statement,
    ];
  }

  Expression _generateCustomTestBody(
    GeneratorConfig config,
    String paramsType,
    String useCaseType,
  ) {
    final callArgs = paramsType == 'NoParams'
        ? refer('NoParams').constInstance([])
        : <Expression>[];

    final testContent = Block((t) {
      if (useCaseType == 'background') {
        final args = callArgs is List<Expression>
            ? callArgs
            : [callArgs as Expression];
        t.statements.add(
          declareFinal(
            'result',
          ).assign(refer('useCase').property('buildTask').call(args)).statement,
        );
        t.statements.add(
          refer('expect').call([
            refer('result'),
            refer('isA').call([], {}, [refer('BackgroundTask')]),
          ]).statement,
        );
      } else if (useCaseType == 'stream') {
        final args = callArgs is List<Expression>
            ? callArgs
            : [callArgs as Expression];
        t.statements.add(
          declareFinal('result').assign(refer('useCase').call(args)).statement,
        );
        t.statements.add(
          refer('expectLater')
              .call([
                refer('result'),
                refer('emits').call([
                  refer('isA').call([], {}, [refer('Success')]),
                ]),
              ])
              .awaited
              .statement,
        );
      } else {
        final args = callArgs is List<Expression>
            ? callArgs
            : [callArgs as Expression];
        t.statements.add(
          declareFinal(
            'result',
          ).assign(refer('useCase').call(args).awaited).statement,
        );
        t.statements.add(
          refer('expect').call([
            refer('result').property('isSuccess'),
            literalBool(true),
          ]).statement,
        );
      }
    });

    return refer('test').call([
      literalString(
        useCaseType == 'stream'
            ? 'should emit values from stream'
            : 'should return Success',
      ),
      testContent.toClosure(asAsync: true),
    ]);
  }
}

extension ExpressionClosure on Expression {
  Expression toClosure({bool asAsync = false}) {
    return Method(
      (m) => m
        ..body = code
        ..modifier = asAsync ? MethodModifier.async : null,
    ).closure;
  }
}

extension CodeClosure on Code {
  Expression toClosure({bool asAsync = false}) {
    return Method(
      (m) => m
        ..body = this
        ..modifier = asAsync ? MethodModifier.async : null,
    ).closure;
  }
}
