import 'package:code_builder/code_builder.dart' as cb;
import 'package:dart_style/dart_style.dart';
import 'package:zuraffa/zuraffa.dart';

import 'codegen_types.dart';

/// Generates fully implemented remote datasource classes.
///
/// Creates a datasource with `query`, `mutation`, and `subscription` methods
/// using `package:graphql` client.
/// ```dart
/// final gen = DatasourceGenerator(typeMapper: mapper);
/// final code = gen.generate(
///   name: 'Product',
///   queries: [QueryConfig(fieldName: 'product', ...)],
///   mutations: [],
/// );
/// ```
class DatasourceGenerator {
  DatasourceGenerator({required this.typeMapper});

  final TypeMapper typeMapper;
  static final _formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );

  String generate({
    required String name,
    required List<QueryConfig> queries,
    required List<MutationConfig> mutations,
    List<SubscriptionConfig> subscriptions = const [],
  }) {
    final className = '\$${name}Datasource';

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

          // Subscription methods
          for (final sub in subscriptions) {
            c.methods.add(_buildSubscriptionMethod(sub));
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
        bl.statements.add(cb.Code("  document: gql(r'''"));
        bl.statements.add(cb.Code(query.document));
        bl.statements.add(cb.Code("'''),"));
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
          cb.Code('    NetworkFailure(message: result.exception.toString()),'),
        );
        bl.statements.add(cb.Code('  );'));
        bl.statements.add(cb.Code('}'));
        bl.statements.add(cb.Code(''));
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
          cb.Code("    const ServerFailure(message: 'No data returned'),"),
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
      });
    });
  }

  cb.Method _buildMutationMethod(MutationConfig mutation) {
    final returnType = zorphyType(typeMapper, mutation.returnType);
    final methodName = _camelCase(mutation.fieldName);

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
        bl.statements.add(cb.Code("  document: gql(r'''"));
        bl.statements.add(cb.Code(mutation.document));
        bl.statements.add(cb.Code("'''),"));
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
          cb.Code('    NetworkFailure(message: result.exception.toString()),'),
        );
        bl.statements.add(cb.Code('  );'));
        bl.statements.add(cb.Code('}'));
        bl.statements.add(cb.Code(''));
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
          cb.Code("    const ServerFailure(message: 'No data returned'),"),
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
      });
    });
  }

  cb.Method _buildSubscriptionMethod(SubscriptionConfig sub) {
    final returnType = zorphyType(typeMapper, sub.returnType);
    final methodName = _camelCase(sub.fieldName);

    return cb.Method((m) {
      m
        ..name = methodName
        ..returns = cb.refer('Stream<SignalResult<$returnType>>');

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
        bl.statements.add(
          cb.Code('return _client.subscribe(SubscriptionOptions('),
        );
        bl.statements.add(cb.Code("  document: gql(r'''"));
        bl.statements.add(cb.Code(sub.document));
        bl.statements.add(cb.Code("'''),"));
        bl.statements.add(cb.Code('  variables: {'));
        for (final arg in sub.args) {
          final fieldName = TypeMapper.fieldName(arg.name);
          bl.statements.add(cb.Code("    '${arg.name}': $fieldName,"));
        }
        bl.statements.add(cb.Code('  },'));
        bl.statements.add(cb.Code(')).map((result) {'));
        bl.statements.add(cb.Code('  if (result.hasException) {'));
        bl.statements.add(
          cb.Code('    return SignalResult<$returnType>.failure('),
        );
        bl.statements.add(
          cb.Code(
            '      NetworkFailure(message: result.exception.toString()),',
          ),
        );
        bl.statements.add(cb.Code('    );'));
        bl.statements.add(cb.Code('  }'));
        bl.statements.add(
          cb.Code(
            '  final data = result.data?[\'${sub.fieldName}\'] as Map<String, dynamic>?;',
          ),
        );
        bl.statements.add(cb.Code('  if (data == null) {'));
        bl.statements.add(
          cb.Code('    return SignalResult<$returnType>.failure('),
        );
        bl.statements.add(
          cb.Code("      const ServerFailure(message: 'No data returned'),"),
        );
        bl.statements.add(cb.Code('    );'));
        bl.statements.add(cb.Code('  }'));
        bl.statements.add(
          cb.Code(
            '  final entity = \$${sub.returnType.innerType.name}.fromJson(data);',
          ),
        );
        bl.statements.add(
          cb.Code('  return SignalResult<$returnType>.success(entity);'),
        );
        bl.statements.add(cb.Code('});'));
      });
    });
  }

  String _camelCase(String name) {
    return name[0].toLowerCase() + name.substring(1);
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
