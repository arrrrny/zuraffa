import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/generator_options.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';

part 'local_crud_methods.dart';
part 'local_helper_methods.dart';
part 'local_stream_methods.dart';

/// Generates local data source implementations.
///
/// Builds local data source classes with CRUD and stream methods, optionally
/// backed by Hive when local caching is enabled.
///
/// Example:
/// ```dart
/// final builder = LocalDataSourceBuilder(
///   outputDir: 'lib/src',
///   dryRun: false,
///   force: true,
///   verbose: false,
/// );
/// final file = await builder.generate(GeneratorConfig(name: 'Product'));
/// ```
class LocalDataSourceBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;

  /// Creates a [LocalDataSourceBuilder].
  ///
  /// @param outputDir Target directory for generated files.
  /// @param options Generation flags for writing behavior and logging.
  /// @param dryRun Deprecated: use [options].
  /// @param force Deprecated: use [options].
  /// @param verbose Deprecated: use [options].
  /// @param specLibrary Optional spec library override.
  LocalDataSourceBuilder({
    required this.outputDir,
    GeneratorOptions options = const GeneratorOptions(),
    @Deprecated('Use options.dryRun') bool? dryRun,
    @Deprecated('Use options.force') bool? force,
    @Deprecated('Use options.verbose') bool? verbose,
    SpecLibrary? specLibrary,
  }) : options = options.copyWith(
         dryRun: dryRun ?? options.dryRun,
         force: force ?? options.force,
         verbose: verbose ?? options.verbose,
       ),
       specLibrary = specLibrary ?? const SpecLibrary();

  /// Generates a local data source file for the given [config].
  ///
  /// @param config Generator configuration describing the entity and options.
  /// @returns Generated data source file metadata.
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
            ..body = Block(
              (b) => b
                ..statements.add(
                  refer('Stream')
                      .property('value')
                      .call([literalBool(true)])
                      .returned
                      .statement,
                ),
            ),
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
          _buildMethodWithBody(
            name: 'save',
            returnType: 'Future<$entityName>',
            parameters: [_param(entityCamel, entityName)],
            body: _awaitThenReturn(
              refer('_box').property('put').call([
                literalString(entitySnake),
                refer(entityCamel),
              ]),
              refer(entityCamel),
            ),
            isAsync: true,
            override: false,
          ),
        );
      } else {
        methods.add(
          _buildMethodWithBody(
            name: 'save',
            returnType: 'Future<$entityName>',
            parameters: [_param(entityCamel, entityName)],
            body: _awaitThenReturn(
              refer('_box').property('put').call([
                refer(entityCamel).property(config.idField),
                refer(entityCamel),
              ]),
              refer(entityCamel),
            ),
            isAsync: true,
            override: false,
          ),
        );
        methods.add(
          _buildMethodWithBody(
            name: 'saveAll',
            returnType: 'Future<void>',
            parameters: [_param('items', 'List<$entityName>')],
            body: _buildSaveAllBody(config.idField),
            isAsync: true,
            override: false,
          ),
        );
      }

      methods.add(
        _buildMethodWithBody(
          name: 'clear',
          returnType: 'Future<void>',
          parameters: const [],
          body: _awaitBody(refer('_box').property('clear').call([])),
          isAsync: true,
          override: false,
        ),
      );

      for (final method in config.methods) {
        switch (method) {
          case 'get':
            methods.add(
              _buildMethodWithBody(
                name: 'get',
                returnType: 'Future<$entityName>',
                parameters: [_param('params', 'QueryParams<$entityName>')],
                body: _returnBody(
                  refer('_box').property('values').property('query').call([
                    refer('params'),
                  ]),
                ),
                isAsync: true,
              ),
            );
            break;
          case 'getList':
            methods.add(
              _buildMethodWithBody(
                name: 'getList',
                returnType: 'Future<List<$entityName>>',
                parameters: [_param('params', 'ListQueryParams<$entityName>')],
                body: _returnBody(
                  refer('_box')
                      .property('values')
                      .property('filter')
                      .call([refer('params').property('filter')])
                      .property('orderBy')
                      .call([refer('params').property('sort')]),
                ),
                isAsync: true,
              ),
            );
            break;
          case 'create':
            methods.add(
              _buildMethodWithBody(
                name: 'create',
                returnType: 'Future<$entityName>',
                parameters: [_param(entityCamel, entityName)],
                body: hasListMethods
                    ? _awaitThenReturn(
                        refer('_box').property('put').call([
                          refer(entityCamel).property(config.idField),
                          refer(entityCamel),
                        ]),
                        refer(entityCamel),
                      )
                    : _awaitThenReturn(
                        refer('_box').property('put').call([
                          literalString(entitySnake),
                          refer(entityCamel),
                        ]),
                        refer(entityCamel),
                      ),
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
                    : _awaitBody(
                        refer(
                          '_box',
                        ).property('delete').call([literalString(entitySnake)]),
                      ),
                isAsync: true,
              ),
            );
            break;
          case 'watch':
            methods.add(
              _buildMethodWithBody(
                name: 'watch',
                returnType: 'Stream<$entityName>',
                parameters: [_param('params', 'QueryParams<$entityName>')],
                body: _buildWatchBody(entityName),
                isAsync: false,
              ),
            );
            break;
          case 'watchList':
            methods.add(
              _buildMethodWithBody(
                name: 'watchList',
                returnType: 'Stream<List<$entityName>>',
                parameters: [_param('params', 'ListQueryParams<$entityName>')],
                body: _buildWatchListBody(entityName),
                isAsync: false,
              ),
            );
            break;
        }
      }
    } else {
      methods.add(
        _buildMethodWithBody(
          name: 'save',
          returnType: 'Future<$entityName>',
          parameters: [_param(entityCamel, entityName)],
          body: _throwBody('Implement local save'),
          isAsync: true,
          override: false,
        ),
      );
      if (config.idType != 'NoParams') {
        methods.add(
          _buildMethodWithBody(
            name: 'saveAll',
            returnType: 'Future<void>',
            parameters: [_param('items', 'List<$entityName>')],
            body: _throwBody('Implement local saveAll'),
            isAsync: true,
            override: false,
          ),
        );
      }
      methods.add(
        _buildMethodWithBody(
          name: 'clear',
          returnType: 'Future<void>',
          parameters: const [],
          body: _throwBody('Implement local clear'),
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
              _buildMethodWithBody(
                name: 'get',
                returnType: 'Future<$entityName>',
                parameters: [_param('params', 'QueryParams<$entityName>')],
                body: _throwBody('Implement local get'),
                isAsync: true,
              ),
            );
            break;
          case 'getList':
            methods.add(
              _buildMethodWithBody(
                name: 'getList',
                returnType: 'Future<List<$entityName>>',
                parameters: [_param('params', 'ListQueryParams<$entityName>')],
                body: _throwBody('Implement local getList'),
                isAsync: true,
              ),
            );
            break;
          case 'create':
            methods.add(
              _buildMethodWithBody(
                name: 'create',
                returnType: 'Future<$entityName>',
                parameters: [_param(entityCamel, entityName)],
                body: _throwBody('Implement local create'),
                isAsync: true,
              ),
            );
            break;
          case 'update':
            methods.add(
              _buildMethodWithBody(
                name: 'update',
                returnType: 'Future<${config.name}>',
                parameters: [
                  _param('params', 'UpdateParams<${config.idType}, $dataType>'),
                ],
                body: _throwBody('Implement local update'),
                isAsync: true,
              ),
            );
            break;
          case 'delete':
            methods.add(
              _buildMethodWithBody(
                name: 'delete',
                returnType: 'Future<void>',
                parameters: [
                  _param('params', 'DeleteParams<${config.idType}>'),
                ],
                body: _throwBody('Implement local delete'),
                isAsync: true,
              ),
            );
            break;
          case 'watch':
            methods.add(
              _buildMethodWithBody(
                name: 'watch',
                returnType: 'Stream<$entityName>',
                parameters: [_param('params', 'QueryParams<$entityName>')],
                body: _throwBody('Implement local watch'),
                isAsync: false,
              ),
            );
            break;
          case 'watchList':
            methods.add(
              _buildMethodWithBody(
                name: 'watchList',
                returnType: 'Stream<List<$entityName>>',
                parameters: [_param('params', 'ListQueryParams<$entityName>')],
                body: _throwBody('Implement local watchList'),
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
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
    );
  }
}
