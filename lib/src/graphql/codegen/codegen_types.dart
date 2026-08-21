import 'package:zuraffa/zuraffa.dart';

/// Maps a GraphQL type to its Dart type for generated code, referencing
/// generated zorphy classes by their `$`-prefixed names.
///
/// [TypeMapper.mapType] returns bare names for object/input types (e.g.
/// `Product`), but the generators emit zorphy classes named `$Product`.
/// This helper upgrades object/input references to the generated class
/// name while keeping scalars, enums, lists, and nullability intact.
String zorphyType(TypeMapper mapper, GraphQLType type) {
  final mapped = mapper.mapType(type);
  final inner = type.innerType;
  if (inner is GraphQLObjectType || inner is GraphQLInputObjectType) {
    return mapped.replaceAll(inner.name, '\$${inner.name}');
  }
  // Sealed union bases are generated as `$$Union` classes.
  if (inner is GraphQLUnionType) {
    return mapped.replaceAll(inner.name, '\$\$${inner.name}');
  }
  return mapped;
}

/// Whether [type] is a list, unwrapping a top-level `NonNull` wrapper.
///
/// [GraphQLType.isList] is only true on a bare `GraphQLListType`, so a
/// `NonNull(List(...))` (the common introspection shape) would be missed.
bool isListType(GraphQLType type) {
  if (type is GraphQLListType) return true;
  if (type is GraphQLNonNullType) return isListType(type.ofType);
  return false;
}

/// The element type of a list [type], unwrapping only the top-level
/// `NonNull` wrapper so element nullability is preserved.
GraphQLType listElementType(GraphQLType type) {
  if (type is GraphQLNonNullType) return listElementType(type.ofType);
  return (type as GraphQLListType).ofType;
}

/// Whether [type] is a top-level `NonNull` wrapper.
bool isNonNullTop(GraphQLType type) => type is GraphQLNonNullType;
