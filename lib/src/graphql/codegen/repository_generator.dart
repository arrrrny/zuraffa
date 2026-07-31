import 'package:code_builder/code_builder.dart' as cb;
import 'package:dart_style/dart_style.dart';
import 'package:zuraffa/zuraffa.dart';

import 'codegen_types.dart';

/// Generates repository interfaces and implementations.
///
/// Creates:
/// - `{Name}Repository` — abstract interface
/// - `{Name}RepositoryImpl` — implementation delegating to datasource
///
/// ```dart
/// final gen = RepositoryGenerator(typeMapper: mapper);
/// final code = gen.generate(name: 'Product', methods: [...]);
/// ```
class RepositoryGenerator {
  RepositoryGenerator({required this.typeMapper});

  final TypeMapper typeMapper;
  static final _formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );

  String generate({required String name, required List<RepoMethod> methods}) {
    final interfaceName = '${name}Repository';
    final implName = '${name}RepositoryImpl';
    final datasourceName = '\$${name}Datasource';

    final library = cb.Library((b) {
      b.directives.add(cb.Directive.import('package:zuraffa/zuraffa.dart'));

      // Interface
      b.body.add(
        cb.Class((c) {
          c
            ..name = interfaceName
            ..abstract = true;

          for (final method in methods) {
            c.methods.add(
              cb.Method((m) {
                m
                  ..name = method.name
                  ..returns = cb.refer(
                    'SignalResult<${zorphyType(typeMapper, method.returnType)}>',
                  )
                  ..requiredParameters.addAll(
                    method.args.map(
                      (arg) => cb.Parameter((p) {
                        p
                          ..name = TypeMapper.fieldName(arg.name)
                          ..type = cb.refer(typeMapper.mapType(arg.type));
                      }),
                    ),
                  );
              }),
            );
          }
        }),
      );

      // Implementation
      b.body.add(
        cb.Class((c) {
          c
            ..name = implName
            ..implements.add(cb.refer(interfaceName));

          c.fields.add(
            cb.Field((f) {
              f
                ..name = '_datasource'
                ..modifier = cb.FieldModifier.final$
                ..type = cb.refer(datasourceName);
            }),
          );

          c.constructors.add(
            cb.Constructor((ctor) {
              ctor.requiredParameters.add(
                cb.Parameter((p) {
                  p
                    ..name = 'datasource'
                    ..toThis = true;
                }),
              );
            }),
          );

          for (final method in methods) {
            c.methods.add(
              cb.Method((m) {
                m
                  ..name = method.name
                  ..returns = cb.refer(
                    'SignalResult<${zorphyType(typeMapper, method.returnType)}>',
                  )
                  ..requiredParameters.addAll(
                    method.args.map(
                      (arg) => cb.Parameter((p) {
                        p
                          ..name = TypeMapper.fieldName(arg.name)
                          ..type = cb.refer(typeMapper.mapType(arg.type));
                      }),
                    ),
                  )
                  ..body = cb.Block((bl) {
                    final argNames = method.args
                        .map((a) => TypeMapper.fieldName(a.name))
                        .join(', ');
                    bl.statements.add(
                      cb.Code('return _datasource.${method.name}($argNames);'),
                    );
                  });
              }),
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
}

/// Configuration for a generated repository method.
class RepoMethod {
  RepoMethod({
    required this.name,
    required this.returnType,
    required this.args,
  });
  final String name;
  final GraphQLType returnType;
  final List<GraphQLInputField> args;
}
