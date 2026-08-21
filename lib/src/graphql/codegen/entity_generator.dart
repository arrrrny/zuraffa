import 'package:code_builder/code_builder.dart' as cb;
import 'package:dart_style/dart_style.dart';
import 'package:zuraffa/zuraffa.dart';

import 'codegen_types.dart';

/// Generates zorphy entity classes from GraphQL OBJECT types.
///
/// ```dart
/// final gen = EntityGenerator(typeMapper: mapper);
/// final code = gen.generate(schema.getType('Product') as GraphQLObjectType);
/// ```
class EntityGenerator {
  EntityGenerator({
    required this.typeMapper,
    this.includeFromJson = true,
    this.includeToJson = true,
  });

  final TypeMapper typeMapper;
  final bool includeFromJson;
  final bool includeToJson;

  static final _formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );

  /// Generate a complete entity file for [objectType].
  String generate(GraphQLObjectType objectType) {
    final className = '\$${objectType.name}';

    final library = cb.Library((b) {
      // Build fields
      final fields = <cb.Field>[];
      final constructorParams = <cb.Parameter>[];
      final fromJsonBody = <cb.Code>[];
      final toJsonEntries = <Object?, Object?>{};

      for (final field in objectType.fields) {
        if (field.isDeprecated) continue;

        final fieldName = TypeMapper.fieldName(field.name);
        final dartType = zorphyType(typeMapper, field.type);
        final isNullable = !field.type.isNonNull;

        // Field declaration
        fields.add(
          cb.Field((f) {
            f
              ..name = fieldName
              ..modifier = cb.FieldModifier.final$
              ..type = cb.refer(dartType);
          }),
        );

        // Constructor parameter
        constructorParams.add(
          cb.Parameter((p) {
            p
              ..name = fieldName
              ..named = true
              ..required = !isNullable
              ..toThis = true;
          }),
        );

        // fromJson parsing
        final jsonAccess = 'json[\'${field.name}\']';
        if (isListType(field.type)) {
          final elementType = listElementType(field.type);
          final isElementNullable = !isNonNullTop(elementType);
          // `as List<dynamic>` throws on null for non-null fields; nullable
          // fields cast to `List<dynamic>?` and guard with `?.`.
          final listCast = 'as List<dynamic>${isNullable ? '?' : ''}';
          final nullSafeMap = isNullable ? '?.' : '.';

          fromJsonBody.add(
            cb.Code(
              '$fieldName: ($jsonAccess $listCast)$nullSafeMap'
              'map((e) => ${_parseJsonExpression(elementType, 'e', isElementNullable)})'
              '.toList(),',
            ),
          );
        } else {
          fromJsonBody.add(
            cb.Code(
              '$fieldName: ${_parseJsonExpression(field.type, jsonAccess, isNullable)},',
            ),
          );
        }

        // toJson entry
        toJsonEntries[cb.literalString(field.name)] = _toJsonExpression(
          fieldName,
          field.type,
        );
      }

      // Class
      b.body.add(
        cb.Class((c) {
          c
            ..name = className
            ..constructors.add(
              cb.Constructor((ctor) {
                ctor.constant = true;
                ctor.optionalParameters.addAll(constructorParams);
              }),
            );

          c.fields.addAll(fields);

          // fromJson
          if (includeFromJson) {
            c.methods.add(
              cb.Method((m) {
                m
                  ..name = 'fromJson'
                  ..returns = cb.refer(className)
                  ..static = true
                  ..requiredParameters.add(
                    cb.Parameter((p) {
                      p
                        ..name = 'json'
                        ..type = cb.refer('Map<String, dynamic>');
                    }),
                  )
                  ..body = cb.Block((bl) {
                    bl.statements.add(cb.Code('return $className('));
                    for (final code in fromJsonBody) {
                      bl.statements.add(code);
                    }
                    bl.statements.add(cb.Code(');'));
                  });
              }),
            );
          }

          // toJson
          if (includeToJson) {
            c.methods.add(
              cb.Method((m) {
                m
                  ..name = 'toJson'
                  ..returns = cb.refer('Map<String, dynamic>')
                  ..body = cb.literalMap(toJsonEntries).returned.statement;
              }),
            );
          }

          // copyWith (optional but useful)
          c.methods.add(_buildCopyWith(className, objectType.fields));
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

  String _parseJsonExpression(
    GraphQLType type,
    String jsonExpr,
    bool isNullable,
  ) {
    final inner = type.innerType;

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

  cb.Expression _toJsonExpression(String fieldName, GraphQLType type) {
    final inner = type.innerType;
    final ref = cb.refer(fieldName);

    // Handle list types first
    if (isListType(type)) {
      final elementType = listElementType(type);
      final elementInner = elementType.innerType;

      if (elementInner is GraphQLEnumType) {
        // List of enums: map to name
        return cb
            .refer(fieldName)
            .nullSafeProperty('map')
            .call([
              cb.Method((m) {
                m
                  ..requiredParameters.add(cb.Parameter((p) => p..name = 'e'))
                  ..lambda = true
                  ..body = cb.refer('e').property('name').code;
              }).closure,
            ])
            .nullSafeProperty('toList')
            .call([]);
      } else if (elementInner is GraphQLObjectType ||
          elementInner is GraphQLInputObjectType) {
        // List of objects: map to toJson
        return ref
            .nullSafeProperty('map')
            .call([
              cb.Method((m) {
                m
                  ..requiredParameters.add(cb.Parameter((p) => p..name = 'e'))
                  ..lambda = true
                  ..body = cb.refer('e').property('toJson').call([]).code;
              }).closure,
            ])
            .nullSafeProperty('toList')
            .call([]);
      } else {
        // List of scalars
        return ref;
      }
    }

    if (inner is GraphQLScalarType) {
      // Scalars serialize as-is (Map<String, dynamic> accepts null).
      return ref;
    }

    if (inner is GraphQLEnumType) {
      return ref.nullSafeProperty('name');
    }

    // Object / InputObject: nested entities serialize via toJson().
    return ref.nullSafeProperty('toJson').call([]);
  }

  cb.Method _buildCopyWith(String className, List<GraphQLField> fields) {
    return cb.Method((m) {
      m
        ..name = 'copyWith'
        ..returns = cb.refer(className)
        ..optionalParameters.addAll(
          fields.where((f) => !f.isDeprecated).map((f) {
            final fieldName = TypeMapper.fieldName(f.name);
            return cb.Parameter((p) {
              p
                ..name = fieldName
                // Nullable param type so omitting a field keeps its value;
                // avoid doubling the `?` for already-nullable fields.
                ..type = cb.refer(_nullableType(zorphyType(typeMapper, f.type)))
                ..named = true;
            });
          }),
        )
        ..body = cb.Block((bl) {
          bl.statements.add(cb.Code('return $className('));
          for (final field in fields.where((f) => !f.isDeprecated)) {
            final fieldName = TypeMapper.fieldName(field.name);
            bl.statements.add(
              cb.Code('$fieldName: $fieldName ?? this.$fieldName,'),
            );
          }
          bl.statements.add(cb.Code(');'));
        });
    });
  }

  /// Append `?` to [type] unless it is already nullable.
  String _nullableType(String type) {
    return type.endsWith('?') ? type : '$type?';
  }
}
