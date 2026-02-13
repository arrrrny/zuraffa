part of 'implementation_generator.dart';

extension RepositoryImplementationGeneratorSimple
    on RepositoryImplementationGenerator {
  Method _generateSimpleMethod(
    GeneratorConfig config,
    String method,
    String entityName,
    String entityCamel,
  ) {
    switch (method) {
      case 'get':
        return Method(
          (m) => m
            ..name = 'get'
            ..annotations.add(refer('override'))
            ..returns = refer('Future<$entityName>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('QueryParams<$entityName>'),
              ),
            )
            ..body = Block(
              (b) => b
                ..statements.add(
                  refer(
                    '_dataSource',
                  ).property('get').call([refer('params')]).returned.statement,
                ),
            ),
        );
      case 'getList':
        return Method(
          (m) => m
            ..name = 'getList'
            ..annotations.add(refer('override'))
            ..returns = refer('Future<List<$entityName>>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('ListQueryParams<$entityName>'),
              ),
            )
            ..body = Block(
              (b) => b
                ..statements.add(
                  refer('_dataSource')
                      .property('getList')
                      .call([refer('params')])
                      .returned
                      .statement,
                ),
            ),
        );
      case 'create':
        return Method(
          (m) => m
            ..name = 'create'
            ..annotations.add(refer('override'))
            ..returns = refer('Future<$entityName>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = entityCamel
                  ..type = refer(entityName),
              ),
            )
            ..body = Block(
              (b) => b
                ..statements.add(
                  refer('_dataSource')
                      .property('create')
                      .call([refer(entityCamel)])
                      .returned
                      .statement,
                ),
            ),
        );
      case 'update':
        final dataType = config.useZorphy
            ? '${config.name}Patch'
            : 'Partial<${config.name}>';
        return Method(
          (m) => m
            ..name = 'update'
            ..annotations.add(refer('override'))
            ..returns = refer('Future<${config.name}>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('UpdateParams<${config.idType}, $dataType>'),
              ),
            )
            ..body = Block(
              (b) => b
                ..statements.add(
                  refer('_dataSource')
                      .property('update')
                      .call([refer('params')])
                      .returned
                      .statement,
                ),
            ),
        );
      case 'delete':
        return Method(
          (m) => m
            ..name = 'delete'
            ..annotations.add(refer('override'))
            ..returns = refer('Future<void>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('DeleteParams<${config.idType}>'),
              ),
            )
            ..body = Block(
              (b) => b
                ..statements.add(
                  refer('_dataSource')
                      .property('delete')
                      .call([refer('params')])
                      .returned
                      .statement,
                ),
            ),
        );
      case 'watch':
        return Method(
          (m) => m
            ..name = 'watch'
            ..annotations.add(refer('override'))
            ..returns = refer('Stream<$entityName>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('QueryParams<$entityName>'),
              ),
            )
            ..body = Block(
              (b) => b
                ..statements.add(
                  refer('_dataSource')
                      .property('watch')
                      .call([refer('params')])
                      .returned
                      .statement,
                ),
            ),
        );
      case 'watchList':
        return Method(
          (m) => m
            ..name = 'watchList'
            ..annotations.add(refer('override'))
            ..returns = refer('Stream<List<$entityName>>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('ListQueryParams<$entityName>'),
              ),
            )
            ..body = Block(
              (b) => b
                ..statements.add(
                  refer('_dataSource')
                      .property('watchList')
                      .call([refer('params')])
                      .returned
                      .statement,
                ),
            ),
        );
      default:
        return Method((m) => m..name = '_noop');
    }
  }
}
