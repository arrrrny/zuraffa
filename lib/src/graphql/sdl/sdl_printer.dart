/// Renders a [GqlSchema] back to a GraphQL SDL document string.
///
/// Spec 037 (FR-001): `zfa graphql pull` persists the SDL artifact
/// (`.schema.graphql`) alongside the introspection JSON. The printer emits a
/// readable, deterministic document: schema header, custom scalars,
/// interfaces, unions, enums, objects and input objects, in the order the
/// types appear in the schema.
library;

import '../graphql_schema.dart';

class SdlPrinter {
  SdlPrinter(this._schema);

  static const List<String> _builtInScalars = [
    'String',
    'Boolean',
    'Int',
    'Float',
    'ID',
  ];

  final GqlSchema _schema;

  /// Renders the full SDL document.
  String printSchema() {
    final buffer = StringBuffer();

    _printSchemaHeader(buffer);

    for (final type in _schema.types.values) {
      if (type.isBuiltIn) continue;
      switch (type.kind) {
        case GqlTypeKind.scalar:
          if (!_builtInScalars.contains(type.name)) {
            _printScalar(buffer, type);
          }
        case GqlTypeKind.object:
          _printObject(buffer, type);
        case GqlTypeKind.interface_:
          _printInterface(buffer, type);
        case GqlTypeKind.union:
          _printUnion(buffer, type);
        case GqlTypeKind.enum_:
          _printEnum(buffer, type);
        case GqlTypeKind.inputObject:
          _printInputObject(buffer, type);
        case GqlTypeKind.list:
        case GqlTypeKind.nonNull:
          // Wrapper kinds never appear as top-level type definitions.
          break;
      }
    }

    return buffer.toString();
  }

  void _printSchemaHeader(StringBuffer buffer) {
    final query = _schema.queryTypeName;
    final mutation = _schema.mutationTypeName;
    final subscription = _schema.subscriptionTypeName;
    if (query == null && mutation == null && subscription == null) return;

    buffer.writeln('schema {');
    if (query != null) buffer.writeln('  query: $query');
    if (mutation != null) buffer.writeln('  mutation: $mutation');
    if (subscription != null) {
      buffer.writeln('  subscription: $subscription');
    }
    buffer.writeln('}');
    buffer.writeln();
  }

  void _printScalar(StringBuffer buffer, GqlTypeDef type) {
    buffer.writeln('scalar ${type.name}');
    buffer.writeln();
  }

  void _printObject(StringBuffer buffer, GqlTypeDef type) {
    final implements = type.interfaces;
    final clause = (implements == null || implements.isEmpty)
        ? ''
        : ' implements ${implements.join(' & ')}';
    buffer.writeln('type ${type.name}$clause {');
    _printFields(buffer, type.fields);
    buffer.writeln('}');
    buffer.writeln();
  }

  void _printInterface(StringBuffer buffer, GqlTypeDef type) {
    buffer.writeln('interface ${type.name} {');
    _printFields(buffer, type.fields);
    buffer.writeln('}');
    buffer.writeln();
  }

  void _printInputObject(StringBuffer buffer, GqlTypeDef type) {
    buffer.writeln('input ${type.name} {');
    _printFields(buffer, type.inputFields);
    buffer.writeln('}');
    buffer.writeln();
  }

  void _printUnion(StringBuffer buffer, GqlTypeDef type) {
    final members = type.possibleTypes ?? const <String>[];
    buffer.writeln('union ${type.name} = ${members.join(' | ')}');
    buffer.writeln();
  }

  void _printEnum(StringBuffer buffer, GqlTypeDef type) {
    buffer.writeln('enum ${type.name} {');
    for (final value in type.enumValues ?? const <GqlEnumValue>[]) {
      buffer.writeln('  ${value.name}');
    }
    buffer.writeln('}');
    buffer.writeln();
  }

  void _printFields(StringBuffer buffer, List<GqlField>? fields) {
    if (fields == null) return;
    for (final field in fields) {
      final args = _renderArgs(field.args);
      final renderedType = renderType(field.type);
      buffer.writeln('  ${field.name}$args: $renderedType');
    }
  }

  String _renderArgs(List<GqlArgument> args) {
    if (args.isEmpty) return '';
    final rendered = args
        .map((arg) {
          return '${arg.name}: ${renderType(arg.type)}';
        })
        .join(', ');
    return '($rendered)';
  }

  /// Renders a type reference chain into GraphQL type syntax, e.g.
  /// `Product`, `Product!`, `[Product!]!`, `[[Int!]!]!`.
  static String renderType(GqlTypeRef ref) {
    switch (ref.kind) {
      case GqlTypeKind.nonNull:
        return '${renderType(ref.ofType!)}!';
      case GqlTypeKind.list:
        return '[${renderType(ref.ofType!)}]';
      default:
        return ref.name ?? 'Unknown';
    }
  }
}
