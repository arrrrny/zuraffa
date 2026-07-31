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

      // Sealed base class
      b.body.add(
        cb.Class((c) {
          c
            ..name = baseName
            // code_builder 4.11.1's ClassModifier has no `sealed`, so the
            // base is declared abstract here and upgraded to `sealed` in the
            // raw output below.
            ..abstract = true;

          // Const generative constructor (for subclasses)
          c.constructors.add(
            cb.Constructor((ctor) {
              ctor.constant = true;
            }),
          );

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

      // Import directives for entity types (will be added before emitting)
      final entityImports = <String>[];

      // Subclasses for each possible type (reuse entity if it's an object type)
      for (final typeName in unionType.possibleTypes) {
        final possibleType = schema.getType(typeName);
        if (possibleType is GraphQLObjectType) {
          // Entity already exists; add import and skip duplicate class
          final snakeName = _snakeCase(typeName);
          entityImports.add('../entities/$snakeName.dart');
        } else {
          // Not an object type; generate inline (shouldn't happen in practice)
          final subclassName = '\$$typeName';
          b.body.add(
            cb.Class((c) {
              c
                ..name = subclassName
                ..extend = cb.refer(baseName);

              c.constructors.add(
                cb.Constructor((ctor) {
                  ctor.constant = true;
                }),
              );
            }),
          );
        }
      }

      // Add entity imports at the end
      for (final importPath in entityImports) {
        b.directives.add(cb.Directive.import(importPath));
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

  String _snakeCase(String name) {
    // Handle acronyms and consecutive uppercase letters properly:
    // ProductID -> product_id, SKU -> sku, HTTPRequest -> http_request
    return name
        .replaceAllMapped(
          // Insert underscore before uppercase that follows lowercase or digit,
          // or before the last uppercase in a sequence (e.g., HTTPRequest -> HTTP_Request)
          RegExp(r'([a-z0-9])([A-Z])|([A-Z])([A-Z][a-z])'),
          (m) => m.group(1) != null
              ? '${m.group(1)}_${m.group(2)}'
              : '${m.group(3)}_${m.group(4)}',
        )
        .toLowerCase();
  }
}
