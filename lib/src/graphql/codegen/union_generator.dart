import 'package:code_builder/code_builder.dart' as cb;
import 'package:dart_style/dart_style.dart';
import 'package:zuraffa/zuraffa.dart';

import 'codegen_types.dart';

/// Generates sealed class hierarchies from GraphQL UNION types.
///
/// Uses `__typename` JSON discriminator for factory constructors.
/// ```dart
/// final gen = UnionGenerator(typeMapper: mapper, schema: schema);
/// final code = gen.generate(schema.getType('AddItemToOrderResult') as GraphQLUnionType);
/// ```
class UnionGenerator {
  UnionGenerator({required this.typeMapper, required this.schema});

  final TypeMapper typeMapper;
  final GraphQLSchema schema;
  static final _formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );

  String generate(GraphQLUnionType unionType) {
    final baseName = '\$\$${unionType.name}';
    final library = cb.Library((b) {
      b.directives.add(cb.Directive.import('package:meta/meta.dart'));

      // Sealed base class
      b.body.add(
        cb.Class((c) {
          c
            ..name = baseName
            // code_builder 4.11.1's ClassModifier has no `sealed`, so the
            // base is declared abstract here and upgraded to `sealed` in the
            // raw output below.
            ..abstract = true;

          // fromJson factory
          c.constructors.add(
            cb.Constructor((ctor) {
              ctor
                ..name = 'fromJson'
                ..factory = true
                ..requiredParameters.add(
                  cb.Parameter((p) {
                    p
                      ..name = 'json'
                      ..type = cb.refer('Map<String, dynamic>');
                  }),
                )
                ..body = cb.Block((bl) {
                  bl.statements.add(
                    cb.Code('final typename = json[\'__typename\'] as String;'),
                  );
                  bl.statements.add(cb.Code('switch (typename) {'));
                  for (final typeName in unionType.possibleTypes) {
                    final entityName = '\$$typeName';
                    bl.statements.add(
                      cb.Code(
                        "  case '$typeName': return $entityName.fromJson(json);",
                      ),
                    );
                  }
                  bl.statements.add(
                    cb.Code(
                      "  default: throw ArgumentError('Unknown __typename: \$typename');",
                    ),
                  );
                  bl.statements.add(cb.Code('}'));
                });
            }),
          );
        }),
      );

      // Subclasses for each possible type
      for (final typeName in unionType.possibleTypes) {
        final objectType = schema.getType(typeName);
        if (objectType is! GraphQLObjectType) continue;

        final subclassName = '\$$typeName';
        final fields = objectType.fields.where((f) => !f.isDeprecated).toList();

        b.body.add(
          cb.Class((c) {
            c
              ..name = subclassName
              ..extend = cb.refer(baseName)
              ..constructors.add(
                cb.Constructor((ctor) {
                  ctor.constant = true;
                  for (final field in fields) {
                    final fieldName = TypeMapper.fieldName(field.name);
                    final isNullable = !field.type.isNonNull;
                    ctor.optionalParameters.add(
                      cb.Parameter((p) {
                        p
                          ..name = fieldName
                          ..named = true
                          ..required = !isNullable
                          ..toThis = true;
                      }),
                    );
                  }
                }),
              );

            for (final field in fields) {
              final fieldName = TypeMapper.fieldName(field.name);
              final dartType = zorphyType(typeMapper, field.type);
              c.fields.add(
                cb.Field((f) {
                  f
                    ..name = fieldName
                    ..modifier = cb.FieldModifier.final$
                    ..type = cb.refer(dartType);
                }),
              );
            }

            // fromJson
            c.methods.add(
              cb.Method((m) {
                m
                  ..name = 'fromJson'
                  ..returns = cb.refer(subclassName)
                  ..static = true
                  ..requiredParameters.add(
                    cb.Parameter((p) {
                      p
                        ..name = 'json'
                        ..type = cb.refer('Map<String, dynamic>');
                    }),
                  )
                  ..body = cb.Block((bl) {
                    bl.statements.add(cb.Code('return $subclassName('));
                    for (final field in fields) {
                      final fieldName = TypeMapper.fieldName(field.name);
                      final jsonExpr = 'json[\'${field.name}\']';
                      bl.statements.add(
                        cb.Code(
                          '$fieldName: ${_parseFieldFromJson(field.type, jsonExpr)},',
                        ),
                      );
                    }
                    bl.statements.add(cb.Code(');'));
                  });
              }),
            );
          }),
        );
      }
    });

    final emitter = cb.DartEmitter();
    final raw = library.accept(emitter).toString();
    // Upgrade the abstract base to a sealed class (see the declaration above).
    final withSealed = raw.replaceFirst(
      'abstract class \$\$${unionType.name}',
      'sealed class \$\$${unionType.name}',
    );
    var formatted = withSealed;
    try {
      formatted = _formatter.format(withSealed);
    } on FormatterException {
      // Fallback: unformatted code is better than a crash.
    }
    return formatted;
  }

  String _parseFieldFromJson(GraphQLType type, String jsonExpr) {
    final inner = type.innerType;
    final isNullable = !type.isNonNull;

    if (isListType(type)) {
      final elementType = listElementType(type);
      final listCast = 'as List<dynamic>${isNullable ? '?' : ''}';
      final nullSafeMap = isNullable ? '?.' : '.';
      return '($jsonExpr $listCast)$nullSafeMap'
          'map((e) => ${_parseFieldFromJson(elementType, 'e')}).toList()';
    }

    if (inner is GraphQLScalarType) {
      final cast = switch (inner.name) {
        'Int' => 'int',
        'Float' => 'double',
        'Boolean' => 'bool',
        'String' || 'ID' => 'String',
        _ => '',
      };
      if (cast.isEmpty) return jsonExpr;
      // `as T` throws on null (non-null field); `as T?` allows null
      // (nullable field). A bare `!` after `as` is not valid Dart.
      return '$jsonExpr as $cast${isNullable ? '?' : ''}';
    }

    if (inner is GraphQLObjectType || inner is GraphQLInputObjectType) {
      final entityName = '\$${inner.name}';
      if (isNullable) {
        return '$jsonExpr != null ? $entityName.fromJson($jsonExpr as Map<String, dynamic>) : null';
      }
      return '$entityName.fromJson($jsonExpr as Map<String, dynamic>)';
    }

    if (inner is GraphQLEnumType) {
      if (isNullable) {
        return '$jsonExpr != null ? ${inner.name}.values.byName($jsonExpr as String) : null';
      }
      return '${inner.name}.values.byName($jsonExpr as String)';
    }

    return jsonExpr;
  }
}
