import 'package:code_builder/code_builder.dart' as cb;
import 'package:dart_style/dart_style.dart';
import 'package:zuraffa/zuraffa.dart';

import 'codegen_types.dart';

/// Generates DTO classes from GraphQL INPUT_OBJECT types.
///
/// DTOs live in `dto/` directory and have `toJson` for serialization.
/// ```dart
/// final gen = DtoGenerator(typeMapper: mapper);
/// final code = gen.generate(schema.getType('ProductListOptions') as GraphQLInputObjectType);
/// ```
class DtoGenerator {
  DtoGenerator({required this.typeMapper});

  final TypeMapper typeMapper;
  static final _formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );

  String generate(GraphQLInputObjectType inputType) {
    final className = '\$${inputType.name}';

    final library = cb.Library((b) {
      b.directives.add(cb.Directive.import('package:meta/meta.dart'));

      final fields = <cb.Field>[];
      final constructorParams = <cb.Parameter>[];
      final toJsonEntries = <Object?, Object?>{};

      for (final field in inputType.inputFields) {
        final fieldName = TypeMapper.fieldName(field.name);
        final dartType = typeMapper.mapType(field.type);
        final isNullable = !field.type.isNonNull;

        fields.add(
          cb.Field((f) {
            f
              ..name = fieldName
              ..modifier = cb.FieldModifier.final$
              ..type = cb.refer(dartType);
          }),
        );

        constructorParams.add(
          cb.Parameter((p) {
            p
              ..name = fieldName
              ..named = true
              ..required = !isNullable
              ..toThis = true;
          }),
        );

        toJsonEntries[cb.literalString(field.name)] = _toJsonValue(
          fieldName,
          field.type,
        );
      }

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

          // toJson
          c.methods.add(
            cb.Method((m) {
              m
                ..name = 'toJson'
                ..returns = cb.refer('Map<String, dynamic>')
                ..body = cb.literalMap(toJsonEntries).returned.statement;
            }),
          );

          // copyWith
          c.methods.add(_buildCopyWith(className, inputType.inputFields));
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

  cb.Expression _toJsonValue(String fieldName, GraphQLType type) {
    final inner = type.innerType;

    if (inner is GraphQLScalarType) {
      return cb.refer(fieldName);
    }

    if (inner is GraphQLEnumType) {
      return cb.refer(fieldName).nullSafeProperty('name');
    }

    if (inner is GraphQLInputObjectType) {
      if (isListType(type)) {
        return cb
            .refer(fieldName)
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
      }
      return cb.refer(fieldName).nullSafeProperty('toJson').call([]);
    }

    return cb.refer(fieldName);
  }

  cb.Method _buildCopyWith(String className, List<GraphQLInputField> fields) {
    return cb.Method((m) {
      m
        ..name = 'copyWith'
        ..returns = cb.refer(className)
        ..optionalParameters.addAll(
          fields.map((f) {
            final fieldName = TypeMapper.fieldName(f.name);
            return cb.Parameter((p) {
              p
                ..name = fieldName
                // Nullable param type so omitting a field keeps its value;
                // avoid doubling the `?` for already-nullable fields.
                ..type = cb.refer(_nullableType(typeMapper.mapType(f.type)))
                ..named = true;
            });
          }),
        )
        ..body = cb.Block((bl) {
          bl.statements.add(cb.Code('return $className('));
          for (final field in fields) {
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
