import 'package:meta/meta.dart';

/// Base class for all GraphQL types in the schema.
@immutable
abstract class GraphQLType {
  const GraphQLType({required this.name, required this.kind});

  final String name;
  final GraphQLTypeKind kind;

  /// Whether this type is non-null (wrapped in `!`).
  bool get isNonNull => false;

  /// Whether this type is a list (wrapped in `[]`).
  bool get isList => false;

  /// The inner type (unwrapped from List or NonNull).
  GraphQLType get innerType => this;

  /// Dart type string for code generation.
  String get dartType;

  @override
  String toString() => name;
}

enum GraphQLTypeKind {
  scalar,
  object,
  interface,
  union,
  enum$,
  inputObject,
  list,
  nonNull,
}

/// Scalar type (String, Int, Float, Boolean, ID, or custom).
class GraphQLScalarType extends GraphQLType {
  const GraphQLScalarType({required super.name})
    : super(kind: GraphQLTypeKind.scalar);

  @override
  String get dartType {
    // Scalars are nullable by default; a NonNull wrapper strips the `?`.
    switch (name) {
      case 'String':
      case 'ID':
        return 'String?';
      case 'Int':
        return 'int?';
      case 'Float':
        return 'double?';
      case 'Boolean':
        return 'bool?';
      default:
        return 'dynamic?'; // Custom scalars
    }
  }
}

/// Object type (e.g. Product, Order).
class GraphQLObjectType extends GraphQLType {
  const GraphQLObjectType({
    required super.name,
    required this.fields,
    this.interfaces = const [],
  }) : super(kind: GraphQLTypeKind.object);

  final List<GraphQLField> fields;
  final List<String> interfaces;

  @override
  String get dartType => name;
}

/// Input object type (e.g. ProductListOptions).
class GraphQLInputObjectType extends GraphQLType {
  const GraphQLInputObjectType({required super.name, required this.inputFields})
    : super(kind: GraphQLTypeKind.inputObject);

  final List<GraphQLInputField> inputFields;

  @override
  String get dartType => name;
}

/// Union type (e.g. AddItemToOrderResult).
class GraphQLUnionType extends GraphQLType {
  const GraphQLUnionType({required super.name, required this.possibleTypes})
    : super(kind: GraphQLTypeKind.union);

  final List<String> possibleTypes;

  @override
  String get dartType => name;
}

/// Enum type.
class GraphQLEnumType extends GraphQLType {
  const GraphQLEnumType({required super.name, required this.values})
    : super(kind: GraphQLTypeKind.enum$);

  final List<String> values;

  @override
  String get dartType => name;
}

/// Interface type.
class GraphQLInterfaceType extends GraphQLType {
  const GraphQLInterfaceType({
    required super.name,
    required this.fields,
    this.possibleTypes = const [],
  }) : super(kind: GraphQLTypeKind.interface);

  final List<GraphQLField> fields;
  final List<String> possibleTypes;

  @override
  String get dartType => name;
}

/// List wrapper type.
class GraphQLListType extends GraphQLType {
  const GraphQLListType({required this.ofType})
    : super(name: '', kind: GraphQLTypeKind.list);

  final GraphQLType ofType;

  /// Derived name — const constructors cannot reference [ofType] in the
  /// initializer list, so the getter computes it instead.
  @override
  String get name => '[${ofType.name}]';

  @override
  bool get isList => true;

  @override
  GraphQLType get innerType => ofType.innerType;

  @override
  String get dartType => 'List<${ofType.dartType}>';
}

/// Non-null wrapper type.
class GraphQLNonNullType extends GraphQLType {
  const GraphQLNonNullType({required this.ofType})
    : super(name: '', kind: GraphQLTypeKind.nonNull);

  final GraphQLType ofType;

  /// Derived name — see [GraphQLListType.name].
  @override
  String get name => '${ofType.name}!';

  @override
  bool get isNonNull => true;

  @override
  GraphQLType get innerType => ofType.innerType;

  @override
  String get dartType {
    final inner = ofType.dartType;
    // Non-null wrapper strips the nullable marker added by inner types.
    return inner.endsWith('?') ? inner.substring(0, inner.length - 1) : inner;
  }
}

/// Field on an object/interface type.
@immutable
class GraphQLField {
  const GraphQLField({
    required this.name,
    required this.type,
    this.args = const [],
    this.isDeprecated = false,
    this.deprecationReason,
  });

  final String name;
  final GraphQLType type;
  final List<GraphQLInputField> args;
  final bool isDeprecated;
  final String? deprecationReason;
}

/// Input field (for input objects and field arguments).
@immutable
class GraphQLInputField {
  const GraphQLInputField({
    required this.name,
    required this.type,
    this.defaultValue,
  });

  final String name;
  final GraphQLType type;
  final dynamic defaultValue;
}
