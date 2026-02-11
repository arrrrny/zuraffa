import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/builder/shared/spec_library.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';

class LocalDataSourceBuilder {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final SpecLibrary specLibrary;

  LocalDataSourceBuilder({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    SpecLibrary? specLibrary,
  }) : specLibrary = specLibrary ?? const SpecLibrary();

  Future<GeneratedFile> generate(GeneratorConfig config) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final entityCamel = config.nameCamel;
    final dataSourceName = '${entityName}LocalDataSource';
    final fileName = '${entitySnake}_local_data_source.dart';

    final dataSourceDirPath = path.join(
      outputDir,
      'data',
      'data_sources',
      entitySnake,
    );
    final filePath = path.join(dataSourceDirPath, fileName);

    final useHive = config.generateLocal || config.cacheStorage == 'hive';
    final methods = <Method>[];
    final fields = <Field>[];
    final constructors = <Constructor>[];

    if (config.generateInit) {
      methods.add(
        Method(
          (m) => m
            ..name = 'initialize'
            ..annotations.add(CodeExpression(Code('override')))
            ..returns = refer('Future<void>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('InitializationParams'),
              ),
            )
            ..modifier = MethodModifier.async
            ..body = Block(
              (b) => b
                ..statements.add(
                  refer('logger').property('info').call([
                    literalString('Initializing $dataSourceName'),
                  ]).statement,
                )
                ..statements.add(
                  refer('logger').property('info').call([
                    literalString('$dataSourceName initialized'),
                  ]).statement,
                ),
            ),
        ),
      );
      methods.add(
        Method(
          (m) => m
            ..name = 'isInitialized'
            ..type = MethodType.getter
            ..annotations.add(CodeExpression(Code('override')))
            ..returns = refer('Stream<bool>')
            ..body = Code('return Stream.value(true);'),
        ),
      );
    }

    if (useHive) {
      final hasListMethods = config.methods.any(
        (m) => m == 'getList' || m == 'watchList',
      );

      fields.add(
        Field(
          (f) => f
            ..modifier = FieldModifier.final$
            ..type = refer('Box<$entityName>')
            ..name = '_box',
        ),
      );
      constructors.add(
        Constructor(
          (c) => c.requiredParameters.add(
            Parameter(
              (p) => p
                ..name = '_box'
                ..toThis = true,
            ),
          ),
        ),
      );

      if (!hasListMethods) {
        methods.add(
          _buildMethod(
            name: 'save',
            returnType: 'Future<$entityName>',
            parameters: [_param(entityCamel, entityName)],
            body:
                "await _box.put('$entitySnake', $entityCamel);\nreturn $entityCamel;",
            isAsync: true,
            override: false,
          ),
        );
      } else {
        methods.add(
          _buildMethod(
            name: 'save',
            returnType: 'Future<$entityName>',
            parameters: [_param(entityCamel, entityName)],
            body:
                'await _box.put($entityCamel.${config.idField}, $entityCamel);\nreturn $entityCamel;',
            isAsync: true,
            override: false,
          ),
        );
        methods.add(
          _buildMethod(
            name: 'saveAll',
            returnType: 'Future<void>',
            parameters: [_param('items', 'List<$entityName>')],
            body:
                'final map = {for (var item in items) item.${config.idField}: item};\nawait _box.putAll(map);',
            isAsync: true,
            override: false,
          ),
        );
      }

      methods.add(
        _buildMethod(
          name: 'clear',
          returnType: 'Future<void>',
          parameters: const [],
          body: 'await _box.clear();',
          isAsync: true,
          override: false,
        ),
      );

      for (final method in config.methods) {
        switch (method) {
          case 'get':
            methods.add(
              _buildMethod(
                name: 'get',
                returnType: 'Future<$entityName>',
                parameters: [_param('params', 'QueryParams<$entityName>')],
                body: 'return _box.values.query(params);',
                isAsync: true,
              ),
            );
            break;
          case 'getList':
            methods.add(
              _buildMethod(
                name: 'getList',
                returnType: 'Future<List<$entityName>>',
                parameters: [_param('params', 'ListQueryParams<$entityName>')],
                body:
                    'return _box.values.filter(params.filter).orderBy(params.sort);',
                isAsync: true,
              ),
            );
            break;
          case 'create':
            methods.add(
              _buildMethod(
                name: 'create',
                returnType: 'Future<$entityName>',
                parameters: [_param(entityCamel, entityName)],
                body: hasListMethods
                    ? 'await _box.put($entityCamel.${config.idField}, $entityCamel);\nreturn $entityCamel;'
                    : "await _box.put('$entitySnake', $entityCamel);\nreturn $entityCamel;",
                isAsync: true,
              ),
            );
            break;
          case 'update':
            final dataType = config.useZorphy
                ? '${config.name}Patch'
                : 'Partial<${config.name}>';
            if (hasListMethods) {
              methods.add(
                _buildMethodWithBody(
                  name: 'update',
                  returnType: 'Future<${config.name}>',
                  parameters: [
                    _param(
                      'params',
                      'UpdateParams<${config.idType}, $dataType>',
                    ),
                  ],
                  body: config.useZorphy
                      ? _buildUpdateWithZorphyBody(config, entityName)
                      : _buildUpdateWithoutZorphyBody(config, entityName),
                  isAsync: true,
                ),
              );
            } else {
              methods.add(
                _buildMethodWithBody(
                  name: 'update',
                  returnType: 'Future<${config.name}>',
                  parameters: [
                    _param(
                      'params',
                      'UpdateParams<${config.idType}, $dataType>',
                    ),
                  ],
                  body: config.useZorphy
                      ? _buildUpdateSingleWithZorphyBody(
                          config,
                          entityName,
                          entitySnake,
                        )
                      : _buildUpdateSingleWithoutZorphyBody(
                          config,
                          entityName,
                          entitySnake,
                        ),
                  isAsync: true,
                ),
              );
            }
            break;
          case 'delete':
            methods.add(
              _buildMethodWithBody(
                name: 'delete',
                returnType: 'Future<void>',
                parameters: [
                  _param('params', 'DeleteParams<${config.idType}>'),
                ],
                body: hasListMethods
                    ? _buildDeleteWithListBody(config, entityName)
                    : Code("await _box.delete('$entitySnake');"),
                isAsync: true,
              ),
            );
            break;
          case 'watch':
            methods.add(
              _buildMethod(
                name: 'watch',
                returnType: 'Stream<$entityName>',
                parameters: [_param('params', 'QueryParams<$entityName>')],
                body: 'yield _box.values.query(params);',
                isAsync: false,
                modifier: MethodModifier.asyncStar,
              ),
            );
            break;
          case 'watchList':
            methods.add(
              _buildMethodWithBody(
                name: 'watchList',
                returnType: 'Stream<List<$entityName>>',
                parameters: [_param('params', 'ListQueryParams<$entityName>')],
                body: _buildWatchListBody(),
                isAsync: false,
                modifier: MethodModifier.asyncStar,
              ),
            );
            break;
        }
      }
    } else {
      methods.add(
        _buildMethod(
          name: 'save',
          returnType: 'Future<$entityName>',
          parameters: [_param(entityCamel, entityName)],
          body: "throw UnimplementedError('Implement local save');",
          isAsync: true,
          override: false,
        ),
      );
      if (config.idType != 'NoParams') {
        methods.add(
          _buildMethod(
            name: 'saveAll',
            returnType: 'Future<void>',
            parameters: [_param('items', 'List<$entityName>')],
            body: "throw UnimplementedError('Implement local saveAll');",
            isAsync: true,
            override: false,
          ),
        );
      }
      methods.add(
        _buildMethod(
          name: 'clear',
          returnType: 'Future<void>',
          parameters: const [],
          body: "throw UnimplementedError('Implement local clear');",
          isAsync: true,
          override: false,
        ),
      );

      for (final method in config.methods) {
        final dataType = config.useZorphy
            ? '${config.name}Patch'
            : 'Partial<${config.name}>';
        switch (method) {
          case 'get':
            methods.add(
              _buildMethod(
                name: 'get',
                returnType: 'Future<$entityName>',
                parameters: [_param('params', 'QueryParams<$entityName>')],
                body: "throw UnimplementedError('Implement local get');",
                isAsync: true,
              ),
            );
            break;
          case 'getList':
            methods.add(
              _buildMethod(
                name: 'getList',
                returnType: 'Future<List<$entityName>>',
                parameters: [_param('params', 'ListQueryParams<$entityName>')],
                body: "throw UnimplementedError('Implement local getList');",
                isAsync: true,
              ),
            );
            break;
          case 'create':
            methods.add(
              _buildMethod(
                name: 'create',
                returnType: 'Future<$entityName>',
                parameters: [_param(entityCamel, entityName)],
                body: "throw UnimplementedError('Implement local create');",
                isAsync: true,
              ),
            );
            break;
          case 'update':
            methods.add(
              _buildMethod(
                name: 'update',
                returnType: 'Future<${config.name}>',
                parameters: [
                  _param('params', 'UpdateParams<${config.idType}, $dataType>'),
                ],
                body: "throw UnimplementedError('Implement local update');",
                isAsync: true,
              ),
            );
            break;
          case 'delete':
            methods.add(
              _buildMethod(
                name: 'delete',
                returnType: 'Future<void>',
                parameters: [
                  _param('params', 'DeleteParams<${config.idType}>'),
                ],
                body: "throw UnimplementedError('Implement local delete');",
                isAsync: true,
              ),
            );
            break;
          case 'watch':
            methods.add(
              _buildMethod(
                name: 'watch',
                returnType: 'Stream<$entityName>',
                parameters: [_param('params', 'QueryParams<$entityName>')],
                body: "throw UnimplementedError('Implement local watch');",
                isAsync: false,
              ),
            );
            break;
          case 'watchList':
            methods.add(
              _buildMethod(
                name: 'watchList',
                returnType: 'Stream<List<$entityName>>',
                parameters: [_param('params', 'ListQueryParams<$entityName>')],
                body: "throw UnimplementedError('Implement local watchList');",
                isAsync: false,
              ),
            );
            break;
        }
      }
    }

    final clazz = Class(
      (b) => b
        ..name = dataSourceName
        ..mixins.addAll([refer('Loggable'), refer('FailureHandler')])
        ..implements.add(refer('${entityName}DataSource'))
        ..fields.addAll(fields)
        ..constructors.addAll(constructors)
        ..methods.addAll(methods),
    );

    final directives = <Directive>[
      if (useHive)
        Directive.import('package:hive_ce_flutter/hive_ce_flutter.dart'),
      Directive.import('package:zuraffa/zuraffa.dart'),
      Directive.import(
        '../../../domain/entities/$entitySnake/$entitySnake.dart',
      ),
      Directive.import('${entitySnake}_data_source.dart'),
    ];

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [clazz], directives: directives),
    );

    return FileUtils.writeFile(
      filePath,
      content,
      'local_datasource',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Method _buildMethod({
    required String name,
    required String returnType,
    required List<Parameter> parameters,
    required String body,
    required bool isAsync,
    bool override = true,
    MethodModifier? modifier,
  }) {
    return Method(
      (m) => m
        ..name = name
        ..annotations.addAll(override ? [CodeExpression(Code('override'))] : [])
        ..returns = refer(returnType)
        ..requiredParameters.addAll(parameters)
        ..modifier = modifier ?? (isAsync ? MethodModifier.async : null)
        ..body = Code(body),
    );
  }

  Method _buildMethodWithBody({
    required String name,
    required String returnType,
    required List<Parameter> parameters,
    required Code body,
    required bool isAsync,
    bool override = true,
    MethodModifier? modifier,
  }) {
    return Method(
      (m) => m
        ..name = name
        ..annotations.addAll(override ? [CodeExpression(Code('override'))] : [])
        ..returns = refer(returnType)
        ..requiredParameters.addAll(parameters)
        ..modifier = modifier ?? (isAsync ? MethodModifier.async : null)
        ..body = body,
    );
  }

  Block _buildUpdateWithZorphyBody(GeneratorConfig config, String entityName) {
    return Block(
      (b) => b
        ..statements.add(
          Code(
            "final existing = _box.values.firstWhere((item) => item.${config.idField} == params.id, orElse: () => throw notFoundFailure('$entityName not found in cache'),);",
          ),
        )
        ..statements.add(Code('final updated = params.data.applyTo(existing);'))
        ..statements.add(
          Code('await _box.put(updated.${config.idField}, updated);'),
        )
        ..statements.add(Code('return updated;')),
    );
  }

  Block _buildUpdateWithoutZorphyBody(
    GeneratorConfig config,
    String entityName,
  ) {
    return Block(
      (b) => b
        ..statements.add(
          Code(
            "final existing = _box.values.firstWhere((item) => item.${config.idField} == params.id, orElse: () => throw notFoundFailure('$entityName not found in cache'),);",
          ),
        )
        ..statements.add(
          Code('await _box.put(existing.${config.idField}, existing);'),
        )
        ..statements.add(Code('return existing;')),
    );
  }

  Block _buildUpdateSingleWithZorphyBody(
    GeneratorConfig config,
    String entityName,
    String entitySnake,
  ) {
    return Block(
      (b) => b
        ..statements.add(Code("final existing = _box.get('$entitySnake');"))
        ..statements.add(
          Code(
            "if (existing == null) { throw notFoundFailure('$entityName not found in cache'); }",
          ),
        )
        ..statements.add(Code('final updated = params.data.applyTo(existing);'))
        ..statements.add(Code("await _box.put('$entitySnake', updated);"))
        ..statements.add(Code('return updated;')),
    );
  }

  Block _buildUpdateSingleWithoutZorphyBody(
    GeneratorConfig config,
    String entityName,
    String entitySnake,
  ) {
    return Block(
      (b) => b
        ..statements.add(Code("final existing = _box.get('$entitySnake');"))
        ..statements.add(
          Code(
            "if (existing == null) { throw notFoundFailure('$entityName not found in cache'); }",
          ),
        )
        ..statements.add(Code("await _box.put('$entitySnake', existing);"))
        ..statements.add(Code('return existing;')),
    );
  }

  Block _buildDeleteWithListBody(GeneratorConfig config, String entityName) {
    return Block(
      (b) => b
        ..statements.add(
          Code(
            "final existing = _box.values.firstWhere((item) => item.${config.idField} == params.id, orElse: () => throw notFoundFailure('$entityName not found in cache'),);",
          ),
        )
        ..statements.add(
          Code('await _box.delete(existing.${config.idField});'),
        ),
    );
  }

  Block _buildWatchListBody() {
    return Block(
      (b) => b
        ..statements.add(
          Code(
            'final existing = _box.values.filter(params.filter).orderBy(params.sort);',
          ),
        )
        ..statements.add(Code('yield existing;'))
        ..statements.add(
          Code(
            'yield* _box.watch().map((_) => _box.values.filter(params.filter).orderBy(params.sort),);',
          ),
        ),
    );
  }

  Parameter _param(String name, String type) {
    return Parameter(
      (p) => p
        ..name = name
        ..type = refer(type),
    );
  }
}
