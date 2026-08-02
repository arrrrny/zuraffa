import 'package:code_builder/code_builder.dart' as cb;
import 'package:dart_style/dart_style.dart';
import 'package:zuraffa/zuraffa.dart';

import '../gql/naming_utils.dart';
import 'codegen_types.dart';

/// Generates fully implemented remote datasource classes.
///
/// Creates a datasource with `query`, `mutation`, and `subscription` methods
/// using `package:graphql` client. Union-returning operations are handled
/// through [UnionResultHandler] when an [errorConfig] is provided.
/// ```dart
/// final gen = DatasourceGenerator(typeMapper: mapper);
/// final code = gen.generate(
///   name: 'Product',
///   queries: [QueryConfig(fieldName: 'product', ...)],
///   mutations: [],
/// );
/// ```
class DatasourceGenerator {
  DatasourceGenerator({
    required this.typeMapper,
    this.enableSubscriptions = false,
    this.errorConfig,
    this.documentsImportPath = 'graphql/documents.dart',
  });

  final TypeMapper typeMapper;

  /// Whether to generate subscription/watch methods backed by the
  /// [GraphQLClientSubscription] runtime (requires `subscriptions: true`
  /// and a `wsEndpoint` in `.zfa.json`). When false, watch methods are
  /// generated as stubs that report subscriptions are disabled.
  final bool enableSubscriptions;

  /// Optional error mapping table for union-returning operations. When set,
  /// union results are dispatched on `__typename` and error variants are
  /// mapped to [AppFailure] via the generated `_mapError` helper.
  final ErrorMappingConfig? errorConfig;

  /// Path to the generated `documents.dart` file holding parsed
  /// [DocumentNode] constants. Generated datasources import this instead of
  /// inlining `gql(r'''...''')` strings.
  final String documentsImportPath;
  static final _formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );

  String generate({
    required String name,
    required List<QueryConfig> queries,
    required List<MutationConfig> mutations,
    List<SubscriptionConfig> subscriptions = const [],
    List<SubscriptionConfig> watches = const [],
  }) {
    final className = '\$${name}Datasource';

    // Check if any union operation exists
    final hasUnionOperation =
        queries.any(
          (q) =>
              q.returnType.innerType is GraphQLUnionType &&
              !q.returnType.isList,
        ) ||
        mutations.any(
          (m) =>
              m.returnType.innerType is GraphQLUnionType &&
              !m.returnType.isList,
        );

    // Check if any operation actually references a document constant
    // (watch-only stubs don't reference documents when subscriptions disabled)
    final hasDocumentReferences = queries.isNotEmpty ||
        mutations.isNotEmpty ||
        (enableSubscriptions && subscriptions.isNotEmpty) ||
        (enableSubscriptions && watches.isNotEmpty);

    final library = cb.Library((b) {
      b.directives.add(cb.Directive.import('package:zuraffa/zuraffa.dart'));
      b.directives.add(
        cb.Directive.import(
          'package:graphql/client.dart',
          show: [
            'GraphQLClient',
            'QueryOptions',
            'MutationOptions',
            'SubscriptionOptions',
            'WatchQueryOptions',
          ],
        ),
      );

      // Generated documents.dart with DocumentNode constants.
      // Only import when at least one method references a document.
      if (hasDocumentReferences) {
        b.directives.add(cb.Directive.import(documentsImportPath));
      }

      b.body.add(
        cb.Class((c) {
          c
            ..name = className
            ..fields.add(
              cb.Field((f) {
                f
                  ..name = '_client'
                  ..modifier = cb.FieldModifier.final$
                  ..type = cb.refer('GraphQLClient');
              }),
            );

          // Error config field + mapping helper when unions are enabled and union operations exist
          if (errorConfig != null && hasUnionOperation) {
            final handler = UnionResultHandler(errorConfig: errorConfig!);
            c.fields.add(handler.buildErrorConfigField());
          }

          c.constructors.add(
            cb.Constructor((ctor) {
              ctor.requiredParameters.add(
                cb.Parameter((p) {
                  p
                    ..name = 'client'
                    ..toThis = true;
                }),
              );
            }),
          );

          // Query methods
          for (final query in queries) {
            c.methods.add(_buildQueryMethod(query));
          }

          // Mutation methods
          for (final mutation in mutations) {
            c.methods.add(_buildMutationMethod(mutation));
          }

          // Subscription methods (only when subscriptions are enabled)
          if (enableSubscriptions) {
            for (final sub in subscriptions) {
              c.methods.add(_buildSubscriptionMethod(sub));
            }
          }

          // Watch methods: live subscription queries when enabled, stubs
          // that report subscriptions-disabled otherwise.
          if (enableSubscriptions) {
            for (final watch in watches) {
              c.methods.add(_buildWatchMethod(watch));
            }
          } else {
            for (final watch in watches) {
              c.methods.add(_buildWatchStub(watch));
            }
          }

          // _mapError helper if union error mapping is enabled and union operations exist
          if (errorConfig != null && hasUnionOperation) {
            c.methods.add(
              UnionResultHandler(
                errorConfig: errorConfig!,
              ).buildMapErrorMethod(),
            );
          }
        }),
      );
    });

    final emitter = cb.DartEmitter();
    final raw = library.accept(emitter).toString();
    var formatted = raw;
    try {
      formatted = _formatter.format(raw);
    } on FormatterException {
      // Fallback: unformatted code is better than a crash.
    }
    return formatted;
  }

  cb.Method _buildQueryMethod(QueryConfig query) {
    final returnType = zorphyType(typeMapper, query.returnType);
    final methodName = _camelCase(query.fieldName);
    final documentVar = _documentVarName(query.fieldName);
    final isUnion = query.returnType.innerType is GraphQLUnionType;

    return cb.Method((m) {
      m
        ..name = methodName
        ..returns = cb.refer('Future<SignalResult<$returnType>>')
        ..modifier = cb.MethodModifier.async;

      // Parameters
      for (final arg in query.args) {
        m.requiredParameters.add(
          cb.Parameter((p) {
            p
              ..name = TypeMapper.fieldName(arg.name)
              ..type = cb.refer(typeMapper.mapType(arg.type));
          }),
        );
      }

      m.body = cb.Block((bl) {
        bl.statements.add(
          cb.Code('final result = await _client.query(QueryOptions('),
        );
        bl.statements.add(cb.Code('  document: $documentVar,'));
        bl.statements.add(cb.Code('  variables: {'));
        for (final arg in query.args) {
          final fieldName = TypeMapper.fieldName(arg.name);
          bl.statements.add(cb.Code("    '${arg.name}': $fieldName,"));
        }
        bl.statements.add(cb.Code('  },'));
        bl.statements.add(cb.Code('));'));
        bl.statements.add(cb.Code(''));
        bl.statements.add(cb.Code('if (result.hasException) {'));
        bl.statements.add(
          cb.Code('  return SignalResult<$returnType>.failure('),
        );
        bl.statements.add(
          cb.Code('    NetworkFailure(result.exception.toString()),'),
        );
        bl.statements.add(cb.Code('  );'));
        bl.statements.add(cb.Code('}'));
        bl.statements.add(cb.Code(''));
        if (isUnion && !query.returnType.isList) {
          _buildUnionHandler(bl, query, isMutation: false);
        } else if (query.returnType.isList) {
          bl.statements.add(
            cb.Code(
              'final data = result.data?[\'${query.fieldName}\'] as List<dynamic>?;',
            ),
          );
          bl.statements.add(cb.Code('if (data == null) {'));
          bl.statements.add(
            cb.Code('  return SignalResult<$returnType>.failure('),
          );
          bl.statements.add(
            cb.Code("    const ServerFailure('No data returned'),"),
          );
          bl.statements.add(cb.Code('  );'));
          bl.statements.add(cb.Code('}'));
          bl.statements.add(cb.Code(''));
          bl.statements.add(
            cb.Code(
              'final entity = data.map((e) => \$${query.returnType.innerType.name}.fromJson(e as Map<String, dynamic>)).toList();',
            ),
          );
          bl.statements.add(
            cb.Code('return SignalResult<$returnType>.success(entity);'),
          );
        } else {
          bl.statements.add(
            cb.Code(
              'final data = result.data?[\'${query.fieldName}\'] as Map<String, dynamic>?;',
            ),
          );
          bl.statements.add(cb.Code('if (data == null) {'));
          bl.statements.add(
            cb.Code('  return SignalResult<$returnType>.failure('),
          );
          bl.statements.add(
            cb.Code("    const ServerFailure('No data returned'),"),
          );
          bl.statements.add(cb.Code('  );'));
          bl.statements.add(cb.Code('}'));
          bl.statements.add(cb.Code(''));
          bl.statements.add(
            cb.Code(
              'final entity = \$${query.returnType.innerType.name}.fromJson(data);',
            ),
          );
          bl.statements.add(
            cb.Code('return SignalResult<$returnType>.success(entity);'),
          );
        }
      });
    });
  }

  cb.Method _buildMutationMethod(MutationConfig mutation) {
    final returnType = zorphyType(typeMapper, mutation.returnType);
    final methodName = _camelCase(mutation.fieldName);
    final documentVar = _documentVarName(mutation.fieldName);
    final isUnion = mutation.returnType.innerType is GraphQLUnionType;

    return cb.Method((m) {
      m
        ..name = methodName
        ..returns = cb.refer('Future<SignalResult<$returnType>>')
        ..modifier = cb.MethodModifier.async;

      for (final arg in mutation.args) {
        m.requiredParameters.add(
          cb.Parameter((p) {
            p
              ..name = TypeMapper.fieldName(arg.name)
              ..type = cb.refer(typeMapper.mapType(arg.type));
          }),
        );
      }

      m.body = cb.Block((bl) {
        bl.statements.add(
          cb.Code('final result = await _client.mutate(MutationOptions('),
        );
        bl.statements.add(cb.Code('  document: $documentVar,'));
        bl.statements.add(cb.Code('  variables: {'));
        for (final arg in mutation.args) {
          final fieldName = TypeMapper.fieldName(arg.name);
          bl.statements.add(cb.Code("    '${arg.name}': $fieldName,"));
        }
        bl.statements.add(cb.Code('  },'));
        bl.statements.add(cb.Code('));'));
        bl.statements.add(cb.Code(''));
        bl.statements.add(cb.Code('if (result.hasException) {'));
        bl.statements.add(
          cb.Code('  return SignalResult<$returnType>.failure('),
        );
        bl.statements.add(
          cb.Code('    NetworkFailure(result.exception.toString()),'),
        );
        bl.statements.add(cb.Code('  );'));
        bl.statements.add(cb.Code('}'));
        bl.statements.add(cb.Code(''));
        if (isUnion && !mutation.returnType.isList) {
          _buildUnionHandler(bl, mutation, isMutation: true);
        } else if (mutation.returnType.isList) {
          bl.statements.add(
            cb.Code(
              'final data = result.data?[\'${mutation.fieldName}\'] as List<dynamic>?;',
            ),
          );
          bl.statements.add(cb.Code('if (data == null) {'));
          bl.statements.add(
            cb.Code('  return SignalResult<$returnType>.failure('),
          );
          bl.statements.add(
            cb.Code("    const ServerFailure('No data returned'),"),
          );
          bl.statements.add(cb.Code('  );'));
          bl.statements.add(cb.Code('}'));
          bl.statements.add(cb.Code(''));
          bl.statements.add(
            cb.Code(
              'final entity = data.map((e) => \$${mutation.returnType.innerType.name}.fromJson(e as Map<String, dynamic>)).toList();',
            ),
          );
          bl.statements.add(
            cb.Code('return SignalResult<$returnType>.success(entity);'),
          );
        } else {
          bl.statements.add(
            cb.Code(
              'final data = result.data?[\'${mutation.fieldName}\'] as Map<String, dynamic>?;',
            ),
          );
          bl.statements.add(cb.Code('if (data == null) {'));
          bl.statements.add(
            cb.Code('  return SignalResult<$returnType>.failure('),
          );
          bl.statements.add(
            cb.Code("    const ServerFailure('No data returned'),"),
          );
          bl.statements.add(cb.Code('  );'));
          bl.statements.add(cb.Code('}'));
          bl.statements.add(cb.Code(''));
          bl.statements.add(
            cb.Code(
              'final entity = \$${mutation.returnType.innerType.name}.fromJson(data);',
            ),
          );
          bl.statements.add(
            cb.Code('return SignalResult<$returnType>.success(entity);'),
          );
        }
      });
    });
  }

  /// Generate statements that handle a union-returning operation.
  ///
  /// With an [errorConfig], the result is dispatched on `__typename` and
  /// error variants map to [AppFailure]; otherwise the sealed union object
  /// is unwrapped directly.
  void _buildUnionHandler(
    cb.BlockBuilder bl,
    Object config, {
    required bool isMutation,
  }) {
    final fieldName = config is QueryConfig
        ? config.fieldName
        : (config as MutationConfig).fieldName;
    final returnType = config is QueryConfig
        ? config.returnType
        : (config as MutationConfig).returnType;
    final signalType = isMutation
        ? zorphyType(typeMapper, (config as MutationConfig).returnType)
        : zorphyType(typeMapper, (config as QueryConfig).returnType);
    final unionType = returnType.innerType as GraphQLUnionType;
    final unionClass = cb.refer('\$\$${unionType.name}');

    if (errorConfig == null) {
      // No error mapping: unwrap the sealed union directly.
      bl.statements.add(
        cb.Code(
          'final data = result.data?[\'$fieldName\'] as Map<String, dynamic>?;',
        ),
      );
      bl.statements.add(cb.Code('if (data == null) {'));
      bl.statements.add(cb.Code('  return SignalResult<$signalType>.failure('));
      bl.statements.add(
        cb.Code("    const ServerFailure('No data returned'),"),
      );
      bl.statements.add(cb.Code('  );'));
      bl.statements.add(cb.Code('}'));
      bl.statements.add(cb.Code(''));
      bl.statements.add(
        cb.Code("final typename = data['__typename'] as String?;"),
      );
      bl.statements.add(cb.Code('if (typename == null) {'));
      bl.statements.add(cb.Code('  return SignalResult<$signalType>.failure('));
      bl.statements.add(
        cb.Code(
          "    const ServerFailure('Missing __typename in union result'),",
        ),
      );
      bl.statements.add(cb.Code('  );'));
      bl.statements.add(cb.Code('}'));
      bl.statements.add(cb.Code(''));
      bl.statements.add(
        cb.Code('final entity = ${unionClass.symbol}.fromJson(data);'),
      );
      bl.statements.add(
        cb.Code('return SignalResult<$signalType>.success(entity);'),
      );
      return;
    }

    final handler = UnionResultHandler(
      errorConfig: errorConfig!,
      operationName: fieldName,
    );
    bl.statements.add(
      handler.buildHandler(
        unionType: unionClass,
        fieldName: fieldName,
        returnType: signalType,
      ),
    );
  }

  cb.Method _buildSubscriptionMethod(SubscriptionConfig sub) {
    final returnType = zorphyType(typeMapper, sub.returnType);
    final methodName = _camelCase(sub.fieldName);
    final documentVar = _documentVarName(sub.fieldName);

    return cb.Method((m) {
      m
        ..name = methodName
        ..returns = cb.refer('SignalResult<$returnType>');

      for (final arg in sub.args) {
        m.requiredParameters.add(
          cb.Parameter((p) {
            p
              ..name = TypeMapper.fieldName(arg.name)
              ..type = cb.refer(typeMapper.mapType(arg.type));
          }),
        );
      }

      m.body = cb.Block((bl) {
        bl.statements.add(cb.Code('return _client.subscribeTo<$returnType>('));
        bl.statements.add(cb.Code('  document: $documentVar,'));
        bl.statements.add(
          cb.Code(
            '  parser: (data) => \$${sub.returnType.innerType.name}.fromJson(data[\'${sub.fieldName}\'] as Map<String, dynamic>),',
          ),
        );
        bl.statements.add(cb.Code('  variables: {'));
        for (final arg in sub.args) {
          final fieldName = TypeMapper.fieldName(arg.name);
          bl.statements.add(cb.Code("    '${arg.name}': $fieldName,"));
        }
        bl.statements.add(cb.Code('  },'));
        bl.statements.add(cb.Code(');'));
      });
    });
  }

  cb.Method _buildWatchMethod(SubscriptionConfig watch) {
    final returnType = zorphyType(typeMapper, watch.returnType);
    final methodName = 'watch${_pascalCase(watch.fieldName)}';
    final documentVar = _documentVarName(watch.fieldName);

    return cb.Method((m) {
      m
        ..name = methodName
        ..returns = cb.refer('SignalResult<$returnType>');

      for (final arg in watch.args) {
        m.requiredParameters.add(
          cb.Parameter((p) {
            p
              ..name = TypeMapper.fieldName(arg.name)
              ..type = cb.refer(typeMapper.mapType(arg.type));
          }),
        );
      }

      m.body = cb.Block((bl) {
        bl.statements.add(
          cb.Code('// Live subscription: emits updates on every change'),
        );
        bl.statements.add(cb.Code('return _client.subscribeTo<$returnType>('));
        bl.statements.add(cb.Code('  document: $documentVar,'));
        bl.statements.add(
          cb.Code(
            '  parser: (data) => \$${watch.returnType.innerType.name}.fromJson(data[\'${watch.fieldName}\'] as Map<String, dynamic>),',
          ),
        );
        bl.statements.add(cb.Code('  variables: {'));
        for (final arg in watch.args) {
          final fieldName = TypeMapper.fieldName(arg.name);
          bl.statements.add(cb.Code("    '${arg.name}': $fieldName,"));
        }
        bl.statements.add(cb.Code('  },'));
        bl.statements.add(cb.Code(');'));
      });
    });
  }

  cb.Method _buildWatchStub(SubscriptionConfig watch) {
    final returnType = zorphyType(typeMapper, watch.returnType);
    final methodName = 'watch${_pascalCase(watch.fieldName)}';

    return cb.Method((m) {
      m
        ..name = methodName
        ..returns = cb.refer('SignalResult<$returnType>');

      for (final arg in watch.args) {
        m.requiredParameters.add(
          cb.Parameter((p) {
            p
              ..name = TypeMapper.fieldName(arg.name)
              ..type = cb.refer(typeMapper.mapType(arg.type));
          }),
        );
      }

      m.body = cb.Block((bl) {
        bl.statements.add(cb.Code('// ignore: avoid_print'));
        bl.statements.add(
          cb.Code(
            "print('[graphql] watch${_pascalCase(watch.fieldName)} skipped: subscriptions disabled in .zfa.json');",
          ),
        );
        bl.statements.add(cb.Code('return SignalResult<$returnType>.failure('));
        bl.statements.add(
          cb.Code("  const NetworkFailure('Subscriptions disabled'),"),
        );
        bl.statements.add(cb.Code(');'));
      });
    });
  }

  String _documentVarName(String fieldName) {
    return NamingUtils.documentVarName(fieldName);
  }

  String _camelCase(String name) {
    return name[0].toLowerCase() + name.substring(1);
  }

  String _pascalCase(String name) {
    return name[0].toUpperCase() + name.substring(1);
  }
}

/// Configuration for a generated query method.
class QueryConfig {
  QueryConfig({
    required this.fieldName,
    required this.returnType,
    required this.args,
    required this.document,
  });
  final String fieldName;
  final GraphQLType returnType;
  final List<GraphQLInputField> args;
  final String document;
}

/// Configuration for a generated mutation method.
class MutationConfig {
  MutationConfig({
    required this.fieldName,
    required this.returnType,
    required this.args,
    required this.document,
  });
  final String fieldName;
  final GraphQLType returnType;
  final List<GraphQLInputField> args;
  final String document;
}

/// Configuration for a generated subscription method.
class SubscriptionConfig {
  SubscriptionConfig({
    required this.fieldName,
    required this.returnType,
    required this.args,
    required this.document,
  });
  final String fieldName;
  final GraphQLType returnType;
  final List<GraphQLInputField> args;
  final String document;
}
