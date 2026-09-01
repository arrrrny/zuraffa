import 'package:code_builder/code_builder.dart';

import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../core/context/file_system.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';

/// Generates a SQLite-backed DataSource for an entity (issue #464).
///
/// The generated `<Entity>SqliteDataSource` implements the entity's
/// `<Entity>DataSource` interface on top of `package:sqlite3`:
///
/// - **Storage model**: one row per entity — `id` TEXT PRIMARY KEY +
///   `data` TEXT holding the entity's JSON (`toJson`/`fromJson`), uniform
///   across all field types. A `schema_version` table plus a constant in
///   the generated file is the migration scaffolding.
/// - **Durability**: `PRAGMA journal_mode=WAL` is applied when the schema
///   is ensured (constructor / `initialize`).
/// - **Reads** mirror the mock datasource semantics: rows are decoded and
///   filtered in memory via the `query` extension (`get`) and
///   offset/limit slicing (`getList`). SQL-level `Filter` translation is
///   deliberately out of scope for this generator.
/// - **Writes** are real SQL keyed by the entity's id field:
///   `INSERT OR REPLACE` (create), SELECT → `params.data.applyTo` →
///   `UPDATE ... WHERE id = ?` (update), SELECT → `copyWithField` →
///   UPDATE (toggle), `DELETE ... WHERE id = ?` (delete).
/// - **watch/watchList** are poll-based streams over the table, matching
///   the mock datasource's streaming contract.
///
/// The class takes an open `Database` in its constructor so callers own
/// the connection lifecycle (path, isolation, closing); `initialize`
/// ensures the schema and `dispose` closes the handle.
class SqliteDataSourceBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;
  final FileSystem fileSystem;

  SqliteDataSourceBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    SpecLibrary? specLibrary,
    FileSystem? fileSystem,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       fileSystem = fileSystem ?? FileSystem.create();

  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    final files = <GeneratedFile>[];
    files.add(await _generateSqliteDataSource(config));
    return files;
  }

  Future<GeneratedFile> _generateSqliteDataSource(
    GeneratorConfig config,
  ) async {
    final entityName = config.name;
    final entitySnake = StringUtils.camelToSnake(entityName);
    final entityCamel = StringUtils.pascalToCamel(entityName);
    final table = '${entitySnake}s';
    final idField = config.idField;
    final isNoParams = config.idFieldType == 'NoParams';
    final filePath =
        '$outputDir/data/datasources/$entitySnake/${entitySnake}_sqlite_datasource.dart';

    final directives = <Directive>[
      Directive.import('dart:async'),
      Directive.import('dart:convert'),
      Directive.import('package:sqlite3/sqlite3.dart'),
      Directive.import('package:zuraffa/zuraffa.dart'),
      Directive.import(
        '../../../domain/entities/$entitySnake/$entitySnake.dart',
      ),
      Directive.import('${entitySnake}_datasource.dart'),
    ];

    // ── fields ─────────────────────────────────────────────────────────
    final dbField = Field(
      (f) => f
        ..name = '_db'
        ..modifier = FieldModifier.final$
        ..type = refer('Database'),
    );

    final schemaVersionField = Field(
      (f) => f
        ..name = '_schemaVersion'
        ..static = true
        ..modifier = FieldModifier.constant
        ..type = refer('int')
        ..assignment = literalNum(1).code,
    );

    // ── constructor ────────────────────────────────────────────────────
    final constructor = Constructor(
      (c) => c
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = '_db'
              ..toThis = true,
          ),
        )
        ..body = refer('_ensureSchema').call([]).statement,
    );

    // ── methods ────────────────────────────────────────────────────────
    final methods = <Method>[];

    if (config.methods.contains('initialize')) {
      methods.addAll([
        Method(
          (m) => m
            ..name = 'initialize'
            ..annotations.add(refer('override'))
            ..returns = refer('Future<void>')
            ..modifier = MethodModifier.async
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('InitializationParams'),
              ),
            )
            ..body = refer('_ensureSchema').call([]).statement,
        ),
        Method(
          (m) => m
            ..name = 'dispose'
            ..annotations.add(refer('override'))
            ..returns = refer('Future<void>')
            ..modifier = MethodModifier.async
            ..body = refer('_db').property('dispose').call([]).statement,
        ),
      ]);
    }

    for (final method in config.methods) {
      switch (method) {
        case 'get':
          methods.add(
            Method(
              (m) => m
                ..name = 'get'
                ..annotations.add(refer('override'))
                ..returns = refer('Future<$entityName>')
                ..modifier = MethodModifier.async
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('QueryParams<$entityName>'),
                  ),
                )
                ..body = Block(
                  (b) => b.statements.addAll([
                    Code('return (await _selectAll()).query(params);'),
                  ]),
                ),
            ),
          );
          break;

        case 'getList':
          methods.add(
            Method(
              (m) => m
                ..name = 'getList'
                ..annotations.add(refer('override'))
                ..returns = refer('Future<List<$entityName>>')
                ..modifier = MethodModifier.async
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('ListQueryParams<$entityName>'),
                  ),
                )
                ..body = Block(
                  (b) => b.statements.addAll([
                    declareVar(
                      'items',
                    ).assign(refer('_selectAll').call([]).awaited).statement,
                    Code(
                      'if (params.offset != null && params.offset! > 0) '
                      '{ items = items.skip(params.offset!).toList(); }',
                    ),
                    Code(
                      'if (params.limit != null && params.limit! > 0) '
                      '{ items = items.take(params.limit!).toList(); }',
                    ),
                    refer('items').returned.statement,
                  ]),
                ),
            ),
          );
          break;

        case 'list':
          methods.add(
            Method(
              (m) => m
                ..name = 'list'
                ..annotations.add(refer('override'))
                ..returns = refer('Future<List<$entityName>>')
                ..modifier = MethodModifier.async
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('NoParams'),
                  ),
                )
                ..body = refer(
                  '_selectAll',
                ).call([]).awaited.returned.statement,
            ),
          );
          break;

        case 'create':
          methods.add(
            Method(
              (m) => m
                ..name = 'create'
                ..annotations.add(refer('override'))
                ..returns = refer('Future<$entityName>')
                ..modifier = MethodModifier.async
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = entityCamel
                      ..type = refer(entityName),
                  ),
                )
                ..body = Block(
                  (b) => b.statements.addAll([
                    Code(
                      "_db.execute('INSERT OR REPLACE INTO $table (id, data) "
                      "VALUES (?, ?)', [$entityCamel.$idField, "
                      "jsonEncode($entityCamel.toJson())]);",
                    ),
                    refer(entityCamel).returned.statement,
                  ]),
                ),
            ),
          );
          break;

        case 'update':
          final updateParamsType =
              'UpdateParams<${config.idFieldType}, ${entityName}Patch>';
          methods.add(
            Method(
              (m) => m
                ..name = 'update'
                ..annotations.add(refer('override'))
                ..returns = refer('Future<$entityName>')
                ..modifier = MethodModifier.async
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer(updateParamsType),
                  ),
                )
                ..body = Block(
                  (b) => b.statements.addAll([
                    if (isNoParams) ...[
                      declareFinal('existing')
                          .assign(
                            refer(
                              '_selectAll',
                            ).call([]).awaited.property('first'),
                          )
                          .statement,
                    ] else ...[
                      declareFinal('existing')
                          .assign(
                            refer(
                              '_selectById',
                            ).call([refer('params').property('id')]).awaited,
                          )
                          .statement,
                      Code(
                        'if (existing == null) { '
                        "throw notFoundFailure('$entityName not found in $table'); }",
                      ),
                    ],
                    declareFinal('updated')
                        .assign(
                          refer('params')
                              .property('data')
                              .property('applyTo')
                              .call([refer('existing')]),
                        )
                        .statement,
                    Code(
                      '_db.execute(\'UPDATE $table SET data = ? WHERE id = ?\', '
                      '[jsonEncode(updated.toJson()), updated.$idField]);',
                    ),
                    refer('updated').returned.statement,
                  ]),
                ),
            ),
          );
          break;

        case 'toggle':
          final toggleParamsType =
              'ToggleParams<${config.idFieldType}, Field<$entityName, dynamic>>';
          methods.add(
            Method(
              (m) => m
                ..name = 'toggle'
                ..annotations.add(refer('override'))
                ..returns = refer('Future<$entityName>')
                ..modifier = MethodModifier.async
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer(toggleParamsType),
                  ),
                )
                ..body = Block(
                  (b) => b.statements.addAll([
                    declareFinal('existing')
                        .assign(
                          refer(
                            '_selectById',
                          ).call([refer('params').property('id')]).awaited,
                        )
                        .statement,
                    Code(
                      'if (existing == null) { '
                      "throw notFoundFailure('$entityName not found in $table'); }",
                    ),
                    declareFinal('updated')
                        .assign(
                          refer('existing').property('copyWithField').call([
                            refer('params').property('field'),
                            refer('params').property('value'),
                          ]),
                        )
                        .statement,
                    Code(
                      '_db.execute(\'UPDATE $table SET data = ? WHERE id = ?\', '
                      '[jsonEncode(updated.toJson()), updated.$idField]);',
                    ),
                    refer('updated').returned.statement,
                  ]),
                ),
            ),
          );
          break;

        case 'delete':
          methods.add(
            Method(
              (m) => m
                ..name = 'delete'
                ..annotations.add(refer('override'))
                ..returns = refer('Future<void>')
                ..modifier = MethodModifier.async
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('DeleteParams<${config.idFieldType}>'),
                  ),
                )
                ..body = Code(
                  isNoParams
                      ? "_db.execute('DELETE FROM $table');"
                      : "_db.execute('DELETE FROM $table WHERE id = ?', "
                            '[params.id]);',
                ),
            ),
          );
          break;

        case 'watch':
          methods.add(
            Method(
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
                ..body = refer('Stream')
                    .property('periodic')
                    .call([
                      refer(
                        'Duration',
                      ).constInstance(const [], {'seconds': literalNum(2)}),
                    ])
                    .property('asyncMap')
                    .call([
                      Method(
                        (m) => m
                          ..modifier = MethodModifier.async
                          ..requiredParameters.add(
                            Parameter((p) => p..name = '_'),
                          )
                          ..body = Code(
                            'return (await _selectAll()).query(params);',
                          ),
                      ).closure,
                    ])
                    .returned
                    .statement,
            ),
          );
          break;

        case 'watchList':
          methods.add(
            Method(
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
                ..body = refer('Stream')
                    .property('periodic')
                    .call([
                      refer(
                        'Duration',
                      ).constInstance(const [], {'seconds': literalNum(2)}),
                    ])
                    .property('asyncMap')
                    .call([
                      Method(
                        (m) => m
                          ..modifier = MethodModifier.async
                          ..requiredParameters.add(
                            Parameter((p) => p..name = '_'),
                          )
                          ..body = refer(
                            '_selectAll',
                          ).call([]).awaited.returned.code,
                      ).closure,
                    ])
                    .returned
                    .statement,
            ),
          );
          break;
      }
    }

    // ── helpers (schema + row mapping) ─────────────────────────────────
    methods.addAll([
      Method(
        (m) => m
          ..name = '_ensureSchema'
          ..returns = refer('void')
          ..body = Block(
            (b) => b.statements.addAll([
              Code("_db.execute('PRAGMA journal_mode = WAL');"),
              Code(
                "_db.execute('CREATE TABLE IF NOT EXISTS $table "
                "(id TEXT PRIMARY KEY, data TEXT NOT NULL)');",
              ),
              Code(
                "_db.execute('CREATE TABLE IF NOT EXISTS schema_version "
                "(version INTEGER NOT NULL)');",
              ),
              Code(
                "final current = _db.select("
                "'SELECT COALESCE(MAX(version), 0) AS v FROM schema_version');",
              ),
              Code(
                "if (current.isEmpty || current.first['v'] as int < "
                "_schemaVersion) { "
                "_db.execute('INSERT OR REPLACE INTO schema_version "
                "(version) VALUES (?)', [_schemaVersion]); }",
              ),
            ]),
          ),
      ),
      Method(
        (m) => m
          ..name = '_selectAll'
          ..returns = refer('Future<List<$entityName>>')
          ..modifier = MethodModifier.async
          ..body = Block(
            (b) => b.statements.addAll([
              declareFinal('rows')
                  .assign(
                    refer('_db').property('select').call([
                      literalString('SELECT data FROM $table'),
                    ]),
                  )
                  .statement,
              refer('rows')
                  .property('map')
                  .call([
                    Method(
                      (m) => m
                        ..lambda = true
                        ..requiredParameters.add(
                          Parameter((p) => p..name = 'row'),
                        )
                        ..body = refer('$entityName.fromJson').call([
                          refer(
                            'jsonDecode',
                          ).call([refer("row['data'] as String")]),
                        ]).code,
                    ).closure,
                  ])
                  .property('toList')
                  .call([])
                  .returned
                  .statement,
            ]),
          ),
      ),
      Method(
        (m) => m
          ..name = '_selectById'
          ..returns = refer('Future<$entityName?>')
          ..modifier = MethodModifier.async
          ..requiredParameters.add(Parameter((p) => p..name = 'id'))
          ..body = Block(
            (b) => b.statements.addAll([
              declareFinal('rows')
                  .assign(
                    refer('_db').property('select').call([
                      literalString('SELECT data FROM $table WHERE id = ?'),
                      refer('[id]'),
                    ]),
                  )
                  .statement,
              Code(
                'if (rows.isEmpty) return null; '
                "return $entityName.fromJson(jsonDecode(rows.first['data'] as String));",
              ),
            ]),
          ),
      ),
    ]);

    final clazz = Class(
      (c) => c
        ..name = '${entityName}SqliteDataSource'
        ..docs.add(
          '/// SQLite-backed DataSource for $entityName (generated by '
          '`zfa sqlite adapter $entityName`).\n'
          '///\n'
          '/// Rows live in the `$table` table (`id` + JSON `data`); the\n'
          '/// schema is ensured with WAL journaling and a schema_version\n'
          '/// marker on construction. Reads decode and filter in memory\n'
          '/// (mock-datasource semantics); writes are keyed SQL statements.',
        )
        ..mixins.addAll([refer('Loggable'), refer('FailureHandler')])
        ..fields.addAll([dbField, schemaVersionField])
        ..constructors.add(constructor)
        ..methods.addAll(methods)
        ..implements.add(refer('${entityName}DataSource')),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [clazz], directives: directives),
      leadingComment: '// Generated by zfa for: $entityName (sqlite adapter)',
    );

    return FileUtils.writeFile(
      filePath,
      content,
      'sqlite_datasource',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      fileSystem: fileSystem,
    );
  }
}
