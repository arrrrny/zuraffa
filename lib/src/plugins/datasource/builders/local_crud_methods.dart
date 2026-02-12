part of 'local_generator.dart';

extension LocalDataSourceBuilderCrud on LocalDataSourceBuilder {
  Block _buildSaveAllBody(String idField) {
    final mapExpression = refer('Map').property('fromEntries').call([
      refer('items').property('map').call([
        Method(
          (m) => m
            ..requiredParameters.add(Parameter((p) => p..name = 'item'))
            ..lambda = true
            ..body = refer(
              'MapEntry',
            ).call([refer('item').property(idField), refer('item')]).code,
        ).closure,
      ]),
    ]);
    return Block(
      (b) => b
        ..statements.add(declareFinal('map').assign(mapExpression).statement)
        ..statements.add(
          refer(
            '_box',
          ).property('putAll').call([refer('map')]).awaited.statement,
        ),
    );
  }

  Block _buildUpdateWithZorphyBody(GeneratorConfig config, String entityName) {
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('existing')
              .assign(
                refer('_box')
                    .property('values')
                    .property('firstWhere')
                    .call(
                      [
                        Method(
                          (m) => m
                            ..requiredParameters.add(
                              Parameter((p) => p..name = 'item'),
                            )
                            ..lambda = true
                            ..body = refer('item')
                                .property(config.idField)
                                .equalTo(refer('params').property('id'))
                                .code,
                        ).closure,
                      ],
                      {
                        'orElse': Method(
                          (m) => m
                            ..lambda = true
                            ..body = refer('notFoundFailure')
                                .call([
                                  literalString(
                                    '$entityName not found in cache',
                                  ),
                                ])
                                .thrown
                                .code,
                        ).closure,
                      },
                    ),
              )
              .statement,
        )
        ..statements.add(
          declareFinal('updated')
              .assign(
                refer('params').property('data').property('applyTo').call([
                  refer('existing'),
                ]),
              )
              .statement,
        )
        ..statements.add(
          refer('_box')
              .property('put')
              .call([
                refer('updated').property(config.idField),
                refer('updated'),
              ])
              .awaited
              .statement,
        )
        ..statements.add(refer('updated').returned.statement),
    );
  }

  Block _buildUpdateWithoutZorphyBody(
    GeneratorConfig config,
    String entityName,
  ) {
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('existing')
              .assign(
                refer('_box')
                    .property('values')
                    .property('firstWhere')
                    .call(
                      [
                        Method(
                          (m) => m
                            ..requiredParameters.add(
                              Parameter((p) => p..name = 'item'),
                            )
                            ..lambda = true
                            ..body = refer('item')
                                .property(config.idField)
                                .equalTo(refer('params').property('id'))
                                .code,
                        ).closure,
                      ],
                      {
                        'orElse': Method(
                          (m) => m
                            ..lambda = true
                            ..body = refer('notFoundFailure')
                                .call([
                                  literalString(
                                    '$entityName not found in cache',
                                  ),
                                ])
                                .thrown
                                .code,
                        ).closure,
                      },
                    ),
              )
              .statement,
        )
        ..statements.add(
          refer('_box')
              .property('put')
              .call([
                refer('existing').property(config.idField),
                refer('existing'),
              ])
              .awaited
              .statement,
        )
        ..statements.add(refer('existing').returned.statement),
    );
  }

  Block _buildUpdateSingleWithZorphyBody(
    GeneratorConfig config,
    String entityName,
    String entitySnake,
  ) {
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('existing')
              .assign(
                refer(
                  '_box',
                ).property('get').call([literalString(entitySnake)]),
              )
              .statement,
        )
        ..statements.add(
          Code(
            'if (existing == null) { throw notFoundFailure(\'$entityName not found in cache\'); }',
          ),
        )
        ..statements.add(
          declareFinal('updated')
              .assign(
                refer('params').property('data').property('applyTo').call([
                  refer('existing'),
                ]),
              )
              .statement,
        )
        ..statements.add(
          refer('_box')
              .property('put')
              .call([literalString(entitySnake), refer('updated')])
              .awaited
              .statement,
        )
        ..statements.add(refer('updated').returned.statement),
    );
  }

  Block _buildUpdateSingleWithoutZorphyBody(
    GeneratorConfig config,
    String entityName,
    String entitySnake,
  ) {
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('existing')
              .assign(
                refer(
                  '_box',
                ).property('get').call([literalString(entitySnake)]),
              )
              .statement,
        )
        ..statements.add(
          Code(
            'if (existing == null) { throw notFoundFailure(\'$entityName not found in cache\'); }',
          ),
        )
        ..statements.add(
          refer('_box')
              .property('put')
              .call([literalString(entitySnake), refer('existing')])
              .awaited
              .statement,
        )
        ..statements.add(refer('existing').returned.statement),
    );
  }

  Block _buildDeleteWithListBody(GeneratorConfig config, String entityName) {
    return Block(
      (b) => b
        ..statements.add(
          declareFinal('existing')
              .assign(
                refer('_box')
                    .property('values')
                    .property('firstWhere')
                    .call(
                      [
                        Method(
                          (m) => m
                            ..requiredParameters.add(
                              Parameter((p) => p..name = 'item'),
                            )
                            ..lambda = true
                            ..body = refer('item')
                                .property(config.idField)
                                .equalTo(refer('params').property('id'))
                                .code,
                        ).closure,
                      ],
                      {
                        'orElse': Method(
                          (m) => m
                            ..lambda = true
                            ..body = refer('notFoundFailure')
                                .call([
                                  literalString(
                                    '$entityName not found in cache',
                                  ),
                                ])
                                .thrown
                                .code,
                        ).closure,
                      },
                    ),
              )
              .statement,
        )
        ..statements.add(
          refer('_box')
              .property('delete')
              .call([refer('existing').property(config.idField)])
              .awaited
              .statement,
        ),
    );
  }
}
