import '../types/graphql_type.dart';

/// Parses a GraphQL introspection JSON response into a [GraphQLSchema].
///
/// ```dart
/// final json = jsonDecode(await File('schema.json').readAsString());
/// final schema = SchemaParser.parse(json);
/// final productType = schema.getType('Product');
/// ```
class SchemaParser {
  SchemaParser._();

  static GraphQLSchema parse(Map<String, dynamic> introspectionJson) {
    final schemaData =
        introspectionJson['data']?['__schema'] as Map<String, dynamic>?;
    if (schemaData == null) {
      throw SchemaParseError('Invalid introspection JSON: missing __schema');
    }

    final types = <String, GraphQLType>{};
    final typesList = schemaData['types'] as List<dynamic>? ?? [];

    // First pass: create all types (without resolving references)
    for (final typeData in typesList) {
      final type = _parseTypeStub(typeData as Map<String, dynamic>);
      types[type.name] = type;
    }

    // Second pass: resolve field types and relationships
    for (final typeData in typesList) {
      _resolveType(typeData as Map<String, dynamic>, types);
    }

    final queryType = schemaData['queryType']?['name'] as String?;
    final mutationType = schemaData['mutationType']?['name'] as String?;
    final subscriptionType = schemaData['subscriptionType']?['name'] as String?;

    return GraphQLSchema(
      types: types,
      queryTypeName: queryType,
      mutationTypeName: mutationType,
      subscriptionTypeName: subscriptionType,
    );
  }

  static GraphQLType _parseTypeStub(Map<String, dynamic> data) {
    final kind = data['kind'] as String;
    final name = data['name'] as String?;

    // Named types (SCALAR, OBJECT, INPUT_OBJECT, UNION, ENUM, INTERFACE) must have non-empty names
    if (kind != 'LIST' && kind != 'NON_NULL') {
      if (name == null || name.isEmpty) {
        throw SchemaParseError(
          'Named type of kind $kind has null or empty name',
        );
      }
    }

    switch (kind) {
      case 'SCALAR':
        return GraphQLScalarType(name: name!);
      case 'OBJECT':
        return GraphQLObjectType(
          name: name!,
          fields: const [],
          interfaces: const [],
        );
      case 'INPUT_OBJECT':
        return GraphQLInputObjectType(name: name!, inputFields: const []);
      case 'UNION':
        return GraphQLUnionType(name: name!, possibleTypes: const []);
      case 'ENUM':
        return GraphQLEnumType(name: name!, values: const []);
      case 'INTERFACE':
        return GraphQLInterfaceType(name: name!, fields: const []);
      case 'LIST':
        // Will be resolved in second pass
        return GraphQLListType(
          ofType: const GraphQLScalarType(name: 'Unknown'),
        );
      case 'NON_NULL':
        return GraphQLNonNullType(
          ofType: const GraphQLScalarType(name: 'Unknown'),
        );
      default:
        throw SchemaParseError('Unknown type kind: $kind');
    }
  }

  static void _resolveType(
    Map<String, dynamic> data,
    Map<String, GraphQLType> types,
  ) {
    final kind = data['kind'] as String;
    final name = data['name'] as String?;
    if (name == null) return; // LIST and NON_NULL don't have names at top level

    final type = types[name];
    if (type == null) return;

    switch (kind) {
      case 'OBJECT':
        final fields = _parseFields(
          data['fields'] as List<dynamic>? ?? [],
          types,
        );
        final interfaces = (data['interfaces'] as List<dynamic>? ?? [])
            .map((i) => (i as Map<String, dynamic>)['name'] as String)
            .toList();
        types[name] = GraphQLObjectType(
          name: name,
          fields: fields,
          interfaces: interfaces,
        );
        break;
      case 'INPUT_OBJECT':
        final inputFields = _parseInputFields(
          data['inputFields'] as List<dynamic>? ?? [],
          types,
        );
        types[name] = GraphQLInputObjectType(
          name: name,
          inputFields: inputFields,
        );
        break;
      case 'UNION':
        final possibleTypes = (data['possibleTypes'] as List<dynamic>? ?? [])
            .map((t) => (t as Map<String, dynamic>)['name'] as String)
            .toList();
        types[name] = GraphQLUnionType(
          name: name,
          possibleTypes: possibleTypes,
        );
        break;
      case 'ENUM':
        final values = (data['enumValues'] as List<dynamic>? ?? [])
            .map((v) => (v as Map<String, dynamic>)['name'] as String)
            .toList();
        types[name] = GraphQLEnumType(name: name, values: values);
        break;
      case 'INTERFACE':
        final fields = _parseFields(
          data['fields'] as List<dynamic>? ?? [],
          types,
        );
        final possibleTypes = (data['possibleTypes'] as List<dynamic>? ?? [])
            .map((t) => (t as Map<String, dynamic>)['name'] as String)
            .toList();
        types[name] = GraphQLInterfaceType(
          name: name,
          fields: fields,
          possibleTypes: possibleTypes,
        );
        break;
    }
  }

  static List<GraphQLField> _parseFields(
    List<dynamic> fields,
    Map<String, GraphQLType> types,
  ) {
    return fields.map((f) {
      final data = f as Map<String, dynamic>;
      return GraphQLField(
        name: data['name'] as String,
        type: _resolveTypeRef(data['type'] as Map<String, dynamic>, types),
        args: _parseInputFields(data['args'] as List<dynamic>? ?? [], types),
        isDeprecated: data['isDeprecated'] as bool? ?? false,
        deprecationReason: data['deprecationReason'] as String?,
      );
    }).toList();
  }

  static List<GraphQLInputField> _parseInputFields(
    List<dynamic> fields,
    Map<String, GraphQLType> types,
  ) {
    return fields.map((f) {
      final data = f as Map<String, dynamic>;
      return GraphQLInputField(
        name: data['name'] as String,
        type: _resolveTypeRef(data['type'] as Map<String, dynamic>, types),
        defaultValue: data['defaultValue'],
      );
    }).toList();
  }

  static GraphQLType _resolveTypeRef(
    Map<String, dynamic> ref,
    Map<String, GraphQLType> types,
  ) {
    final kind = ref['kind'] as String;

    switch (kind) {
      case 'LIST':
        final ofType = _resolveTypeRef(
          ref['ofType'] as Map<String, dynamic>,
          types,
        );
        return GraphQLListType(ofType: ofType);
      case 'NON_NULL':
        final ofType = _resolveTypeRef(
          ref['ofType'] as Map<String, dynamic>,
          types,
        );
        return GraphQLNonNullType(ofType: ofType);
      case 'SCALAR':
        final name = ref['name'] as String?;
        if (name == null) throw SchemaParseError('Named type without name');
        // For scalars, allow fallback to unknown scalar (server-defined custom scalars)
        return types[name] ?? GraphQLScalarType(name: name);
      case 'OBJECT':
      case 'INPUT_OBJECT':
      case 'UNION':
      case 'ENUM':
      case 'INTERFACE':
        final name = ref['name'] as String?;
        if (name == null) throw SchemaParseError('Named type without name');
        final type = types[name];
        if (type == null) {
          throw SchemaParseError(
            'Type "$name" referenced but not found in schema',
          );
        }
        return type;
      default:
        throw SchemaParseError('Unknown type kind in ref: $kind');
    }
  }
}

/// Parsed GraphQL schema with type lookup.
class GraphQLSchema {
  GraphQLSchema({
    required this.types,
    this.queryTypeName,
    this.mutationTypeName,
    this.subscriptionTypeName,
  });

  final Map<String, GraphQLType> types;
  final String? queryTypeName;
  final String? mutationTypeName;
  final String? subscriptionTypeName;

  GraphQLType? getType(String name) => types[name];

  GraphQLObjectType? getQueryType() =>
      queryTypeName != null ? types[queryTypeName] as GraphQLObjectType? : null;

  GraphQLObjectType? getMutationType() => mutationTypeName != null
      ? types[mutationTypeName] as GraphQLObjectType?
      : null;

  GraphQLObjectType? getSubscriptionType() => subscriptionTypeName != null
      ? types[subscriptionTypeName] as GraphQLObjectType?
      : null;

  List<GraphQLObjectType> getObjectTypes() =>
      types.values.whereType<GraphQLObjectType>().toList();

  List<GraphQLInputObjectType> getInputTypes() =>
      types.values.whereType<GraphQLInputObjectType>().toList();

  List<GraphQLUnionType> getUnionTypes() =>
      types.values.whereType<GraphQLUnionType>().toList();

  List<GraphQLEnumType> getEnumTypes() =>
      types.values.whereType<GraphQLEnumType>().toList();
}

class SchemaParseError implements Exception {
  SchemaParseError(this.message);
  final String message;

  @override
  String toString() => 'SchemaParseError: $message';
}
