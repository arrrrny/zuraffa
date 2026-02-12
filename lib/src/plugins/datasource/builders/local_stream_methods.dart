part of 'local_generator.dart';

extension LocalDataSourceBuilderStreams on LocalDataSourceBuilder {
  Block _buildWatchBody(String entityName) {
    final existingExpression = refer(
      '_box',
    ).property('values').property('query').call([refer('params')]);
    final streamExpression = refer('Stream<$entityName>')
        .property('multi')
        .call([
          Method(
            (m) => m
              ..requiredParameters.add(Parameter((p) => p..name = 'controller'))
              ..modifier = MethodModifier.async
              ..body = Block(
                (bb) => bb
                  ..statements.add(
                    refer(
                      'controller',
                    ).property('add').call([refer('existing')]).statement,
                  )
                  ..statements.add(
                    refer('controller')
                        .property('addStream')
                        .call([
                          refer(
                            '_box',
                          ).property('watch').call([]).property('map').call([
                            Method(
                              (mm) => mm
                                ..requiredParameters.add(
                                  Parameter((p) => p..name = '_'),
                                )
                                ..lambda = true
                                ..body = existingExpression.code,
                            ).closure,
                          ]),
                        ])
                        .awaited
                        .statement,
                  ),
              ),
          ).closure,
        ]);
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('existing').assign(existingExpression).statement,
        )
        ..statements.add(
          declareFinal('stream').assign(streamExpression).statement,
        )
        ..statements.add(refer('stream').returned.statement),
    );
  }

  Block _buildWatchListBody(String entityName) {
    final existingExpression = refer('_box')
        .property('values')
        .property('filter')
        .call([refer('params').property('filter')])
        .property('orderBy')
        .call([refer('params').property('sort')]);
    final streamExpression = refer('Stream<List<$entityName>>')
        .property('multi')
        .call([
          Method(
            (m) => m
              ..requiredParameters.add(Parameter((p) => p..name = 'controller'))
              ..modifier = MethodModifier.async
              ..body = Block(
                (bb) => bb
                  ..statements.add(
                    refer(
                      'controller',
                    ).property('add').call([refer('existing')]).statement,
                  )
                  ..statements.add(
                    refer('controller')
                        .property('addStream')
                        .call([
                          refer(
                            '_box',
                          ).property('watch').call([]).property('map').call([
                            Method(
                              (mm) => mm
                                ..requiredParameters.add(
                                  Parameter((p) => p..name = '_'),
                                )
                                ..lambda = true
                                ..body = existingExpression.code,
                            ).closure,
                          ]),
                        ])
                        .awaited
                        .statement,
                  ),
              ),
          ).closure,
        ]);
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('existing').assign(existingExpression).statement,
        )
        ..statements.add(
          declareFinal('stream').assign(streamExpression).statement,
        )
        ..statements.add(refer('stream').returned.statement),
    );
  }
}
