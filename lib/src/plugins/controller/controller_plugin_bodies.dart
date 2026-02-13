part of 'controller_plugin.dart';

extension ControllerPluginBodies on ControllerPlugin {
  Block _buildGetWithStateBody(
    String entityName,
    String entityCamel,
    String args,
  ) {
    final resultCall = refer(
      '_presenter',
    ).property('get$entityName').call(_callArgsExpressions(args)).awaited;
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(
          _updateStateStatement({'isGetting': literalBool(true)}),
        )
        ..statements.add(declareFinal('result').assign(resultCall).statement)
        ..statements.add(
          _resultFold(
            resultVar: 'result',
            successParams: ['entity'],
            successBody: Block(
              (bb) => bb
                ..statements.add(
                  _updateStateStatement({
                    'isGetting': literalBool(false),
                    entityCamel: refer('entity'),
                  }),
                ),
            ),
            failureParams: ['failure'],
            failureBody: Block(
              (bb) => bb
                ..statements.add(
                  _updateStateStatement({
                    'isGetting': literalBool(false),
                    'error': refer('failure'),
                  }),
                ),
            ),
          ),
        ),
    );
  }

  Block _buildGetWithoutStateBody(String entityName, String args) {
    final resultCall = refer(
      '_presenter',
    ).property('get$entityName').call(_callArgsExpressions(args)).awaited;
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(declareFinal('result').assign(resultCall).statement)
        ..statements.add(
          _resultFold(
            resultVar: 'result',
            successParams: ['entity'],
            successBody: Block((bb) => bb),
            failureParams: ['failure'],
            failureBody: Block((bb) => bb),
          ),
        ),
    );
  }

  Block _buildGetListWithStateBody(String entityName, String entityCamel) {
    final resultCall = refer('_presenter')
        .property('get${entityName}List')
        .call(_callArgsExpressions('params'))
        .awaited;
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(
          _updateStateStatement({'isGettingList': literalBool(true)}),
        )
        ..statements.add(declareFinal('result').assign(resultCall).statement)
        ..statements.add(
          _resultFold(
            resultVar: 'result',
            successParams: ['list'],
            successBody: Block(
              (bb) => bb
                ..statements.add(
                  _updateStateStatement({
                    'isGettingList': literalBool(false),
                    '${entityCamel}List': refer('list'),
                  }),
                ),
            ),
            failureParams: ['failure'],
            failureBody: Block(
              (bb) => bb
                ..statements.add(
                  _updateStateStatement({
                    'isGettingList': literalBool(false),
                    'error': refer('failure'),
                  }),
                ),
            ),
          ),
        ),
    );
  }

  Block _buildGetListWithoutStateBody(String entityName) {
    final resultCall = refer('_presenter')
        .property('get${entityName}List')
        .call(_callArgsExpressions('params'))
        .awaited;
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(declareFinal('result').assign(resultCall).statement)
        ..statements.add(
          _resultFold(
            resultVar: 'result',
            successParams: ['list'],
            successBody: Block((bb) => bb),
            failureParams: ['failure'],
            failureBody: Block((bb) => bb),
          ),
        ),
    );
  }

  Block _buildCreateWithStateBody(
    String entityName,
    String entityCamel,
    bool hasListMethod,
    bool hasWatchList,
  ) {
    final resultCall = refer('_presenter')
        .property('create$entityName')
        .call(_callArgsExpressions(entityCamel))
        .awaited;
    final updateArgs = <String, Expression>{'isCreating': literalBool(false)};
    if (hasListMethod && !hasWatchList) {
      updateArgs['${entityCamel}List'] = refer('viewState')
          .property('${entityCamel}List')
          .property('followedBy')
          .call([
            literalList([refer('created')]),
          ])
          .property('toList')
          .call([]);
    }
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(
          _updateStateStatement({'isCreating': literalBool(true)}),
        )
        ..statements.add(declareFinal('result').assign(resultCall).statement)
        ..statements.add(
          _resultFold(
            resultVar: 'result',
            successParams: ['created'],
            successBody: Block(
              (bb) => bb..statements.add(_updateStateStatement(updateArgs)),
            ),
            failureParams: ['failure'],
            failureBody: Block(
              (bb) => bb
                ..statements.add(
                  _updateStateStatement({
                    'isCreating': literalBool(false),
                    'error': refer('failure'),
                  }),
                ),
            ),
          ),
        ),
    );
  }

  Block _buildCreateWithoutStateBody(String entityName, String entityCamel) {
    final resultCall = refer('_presenter')
        .property('create$entityName')
        .call(_callArgsExpressions(entityCamel))
        .awaited;
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(declareFinal('result').assign(resultCall).statement)
        ..statements.add(
          _resultFold(
            resultVar: 'result',
            successParams: ['created'],
            successBody: Block((bb) => bb),
            failureParams: ['failure'],
            failureBody: Block((bb) => bb),
          ),
        ),
    );
  }

  Block _buildUpdateWithStateBody(
    GeneratorConfig config,
    String entityName,
    String entityCamel,
    bool hasListMethod,
    bool hasWatchList,
  ) {
    final resultCall = refer('_presenter')
        .property('update$entityName')
        .call(_callArgsExpressions('${config.idField}, data'))
        .awaited;
    final isNoParams = config.idType == 'NoParams';
    final updateArgs = <String, Expression>{
      'isUpdating': literalBool(false),
      entityCamel: isNoParams
          ? refer('updated')
          : CodeExpression(
              Code(
                'viewState.$entityCamel?.${config.queryField} == updated.${config.queryField}',
              ),
            ).conditional(
              refer('updated'),
              refer('viewState').property(entityCamel),
            ),
    };
    if (hasListMethod && !hasWatchList) {
      final listUpdateClosure = Method(
        (m) => m
          ..requiredParameters.add(Parameter((p) => p..name = 'e'))
          ..lambda = true
          ..body = refer('e')
              .property(config.queryField)
              .equalTo(refer('updated').property(config.queryField))
              .conditional(refer('updated'), refer('e'))
              .code,
      ).closure;
      updateArgs['${entityCamel}List'] = refer('viewState')
          .property('${entityCamel}List')
          .property('map')
          .call([listUpdateClosure])
          .property('toList')
          .call([]);
    }
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(
          _updateStateStatement({'isUpdating': literalBool(true)}),
        )
        ..statements.add(declareFinal('result').assign(resultCall).statement)
        ..statements.add(
          _resultFold(
            resultVar: 'result',
            successParams: ['updated'],
            successBody: Block(
              (bb) => bb..statements.add(_updateStateStatement(updateArgs)),
            ),
            failureParams: ['failure'],
            failureBody: Block(
              (bb) => bb
                ..statements.add(
                  _updateStateStatement({
                    'isUpdating': literalBool(false),
                    'error': refer('failure'),
                  }),
                ),
            ),
          ),
        ),
    );
  }

  Block _buildUpdateWithoutStateBody(
    GeneratorConfig config,
    String entityName,
  ) {
    final resultCall = refer('_presenter')
        .property('update$entityName')
        .call(_callArgsExpressions('${config.idField}, data'))
        .awaited;
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(declareFinal('result').assign(resultCall).statement)
        ..statements.add(
          _resultFold(
            resultVar: 'result',
            successParams: ['updated'],
            successBody: Block((bb) => bb),
            failureParams: ['failure'],
            failureBody: Block((bb) => bb),
          ),
        ),
    );
  }

  Block _buildDeleteWithStateBody(
    GeneratorConfig config,
    String entityName,
    String entityCamel,
    bool hasListMethod,
  ) {
    final resultCall = refer('_presenter')
        .property('delete$entityName')
        .call(_callArgsExpressions(config.idField))
        .awaited;
    final deleteArgs = <String, Expression>{'isDeleting': literalBool(true)};
    if (hasListMethod) {
      final deleteFilterClosure = Method(
        (m) => m
          ..requiredParameters.add(Parameter((p) => p..name = 'e'))
          ..lambda = true
          ..body = refer('e')
              .property(config.queryField)
              .notEqualTo(refer(config.queryField))
              .code,
      ).closure;
      deleteArgs['${entityCamel}List'] = refer('viewState')
          .property('${entityCamel}List')
          .property('where')
          .call([deleteFilterClosure])
          .property('toList')
          .call([]);
    }
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(_updateStateStatement(deleteArgs))
        ..statements.add(declareFinal('result').assign(resultCall).statement)
        ..statements.add(
          _resultFold(
            resultVar: 'result',
            successParams: ['_'],
            successBody: Block(
              (bb) => bb
                ..statements.add(
                  _updateStateStatement({'isDeleting': literalBool(false)}),
                ),
            ),
            failureParams: ['failure'],
            failureBody: Block(
              (bb) => bb
                ..statements.add(
                  _updateStateStatement({
                    'isDeleting': literalBool(false),
                    'error': refer('failure'),
                  }),
                ),
            ),
          ),
        ),
    );
  }

  Block _buildDeleteWithoutStateBody(String entityName, String idField) {
    final resultCall = refer(
      '_presenter',
    ).property('delete$entityName').call(_callArgsExpressions(idField)).awaited;
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(declareFinal('result').assign(resultCall).statement)
        ..statements.add(
          _resultFold(
            resultVar: 'result',
            successParams: ['_'],
            successBody: Block((bb) => bb),
            failureParams: ['failure'],
            failureBody: Block((bb) => bb),
          ),
        ),
    );
  }

  Block _buildWatchWithStateBody(
    String entityName,
    String entityCamel,
    String args,
  ) {
    final foldStatement = _resultFold(
      resultVar: 'result',
      successParams: ['entity'],
      successBody: Block(
        (bb) => bb
          ..statements.add(
            _updateStateStatement({
              'isWatching': literalBool(false),
              entityCamel: refer('entity'),
            }),
          ),
      ),
      failureParams: ['failure'],
      failureBody: Block(
        (bb) => bb
          ..statements.add(
            _updateStateStatement({
              'isWatching': literalBool(false),
              'error': refer('failure'),
            }),
          ),
      ),
    );
    final listenBody = Block((bb) => bb..statements.add(foldStatement));
    final listenClosure = Method(
      (m) => m
        ..requiredParameters.add(Parameter((p) => p..name = 'result'))
        ..body = listenBody,
    ).closure;
    final subscriptionCall = refer('_presenter')
        .property('watch$entityName')
        .call(_callArgsExpressions(args))
        .property('listen')
        .call([listenClosure]);
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(
          _updateStateStatement({'isWatching': literalBool(true)}),
        )
        ..statements.add(
          declareFinal('subscription').assign(subscriptionCall).statement,
        )
        ..statements.add(
          refer('registerSubscription').call([refer('subscription')]).statement,
        ),
    );
  }

  Block _buildWatchWithoutStateBody(String entityName, String args) {
    final foldStatement = _resultFold(
      resultVar: 'result',
      successParams: ['entity'],
      successBody: Block((bb) => bb),
      failureParams: ['failure'],
      failureBody: Block((bb) => bb),
    );
    final listenBody = Block((bb) => bb..statements.add(foldStatement));
    final listenClosure = Method(
      (m) => m
        ..requiredParameters.add(Parameter((p) => p..name = 'result'))
        ..body = listenBody,
    ).closure;
    final subscriptionCall = refer('_presenter')
        .property('watch$entityName')
        .call(_callArgsExpressions(args))
        .property('listen')
        .call([listenClosure]);
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(
          declareFinal('subscription').assign(subscriptionCall).statement,
        )
        ..statements.add(
          refer('registerSubscription').call([refer('subscription')]).statement,
        ),
    );
  }

  Block _buildWatchListWithStateBody(String entityName, String entityCamel) {
    final foldStatement = _resultFold(
      resultVar: 'result',
      successParams: ['list'],
      successBody: Block(
        (bb) => bb
          ..statements.add(
            _updateStateStatement({
              'isWatchingList': literalBool(false),
              '${entityCamel}List': refer('list'),
            }),
          ),
      ),
      failureParams: ['failure'],
      failureBody: Block(
        (bb) => bb
          ..statements.add(
            _updateStateStatement({
              'isWatchingList': literalBool(false),
              'error': refer('failure'),
            }),
          ),
      ),
    );
    final listenBody = Block((bb) => bb..statements.add(foldStatement));
    final listenClosure = Method(
      (m) => m
        ..requiredParameters.add(Parameter((p) => p..name = 'result'))
        ..body = listenBody,
    ).closure;
    final subscriptionCall = refer('_presenter')
        .property('watch${entityName}List')
        .call(_callArgsExpressions('params'))
        .property('listen')
        .call([listenClosure]);
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(
          _updateStateStatement({'isWatchingList': literalBool(true)}),
        )
        ..statements.add(
          declareFinal('subscription').assign(subscriptionCall).statement,
        )
        ..statements.add(
          refer('registerSubscription').call([refer('subscription')]).statement,
        ),
    );
  }

  Block _buildWatchListWithoutStateBody(String entityName) {
    final foldStatement = _resultFold(
      resultVar: 'result',
      successParams: ['list'],
      successBody: Block((bb) => bb),
      failureParams: ['failure'],
      failureBody: Block((bb) => bb),
    );
    final listenBody = Block((bb) => bb..statements.add(foldStatement));
    final listenClosure = Method(
      (m) => m
        ..requiredParameters.add(Parameter((p) => p..name = 'result'))
        ..body = listenBody,
    ).closure;
    final subscriptionCall = refer('_presenter')
        .property('watch${entityName}List')
        .call(_callArgsExpressions('params'))
        .property('listen')
        .call([listenClosure]);
    return Block(
      (b) => b
        ..statements.add(_tokenStatement())
        ..statements.add(
          declareFinal('subscription').assign(subscriptionCall).statement,
        )
        ..statements.add(
          refer('registerSubscription').call([refer('subscription')]).statement,
        ),
    );
  }
}
