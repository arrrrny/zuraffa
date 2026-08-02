import 'package:gql/ast.dart' as ast;
import 'package:gql/language.dart' as gql_lang;
import 'package:zuraffa/zuraffa.dart';

/// Builds real `.graphql` files using `package:gql` AST nodes.
///
/// No string templates — every document is built from typed AST nodes
/// and serialized via `gql/language.dart` `printNode()`.
///
/// ```dart
/// final builder = GraphQLDocumentBuilder(schema: schema);
/// final doc = builder.buildQueryDocument(
///   operationName: 'GetProduct',
///   fieldName: 'product',
///   fields: ['id', 'name', 'price'],
///   args: {'id': GraphQLNonNullType(ofType: GraphQLScalarType(name: 'ID'))},
/// );
/// final graphqlText = builder.serialize(doc);
/// ```
class GraphQLDocumentBuilder {
  GraphQLDocumentBuilder({required this.schema, this.unvalidated = false});

  final GraphQLSchema schema;
  final bool unvalidated;

  /// Build a query document AST from schema metadata.
  ast.DocumentNode buildQueryDocument({
    required String operationName,
    required String fieldName,
    required List<String> fields,
    Map<String, GraphQLType>? args,
    List<String>? fragments,
  }) {
    final variableDefinitions = <ast.VariableDefinitionNode>[];
    final argumentNodes = <ast.ArgumentNode>[];

    if (args != null) {
      for (final entry in args.entries) {
        variableDefinitions.add(
          _buildVariableDefinition(entry.key, entry.value),
        );
        argumentNodes.add(
          ast.ArgumentNode(
            name: ast.NameNode(value: entry.key),
            value: ast.VariableNode(name: ast.NameNode(value: entry.key)),
          ),
        );
      }
    }

    final selectionSet = _buildSelectionSet(fields, fragments);

    final operation = ast.OperationDefinitionNode(
      type: ast.OperationType.query,
      name: ast.NameNode(value: operationName),
      variableDefinitions: variableDefinitions,
      selectionSet: ast.SelectionSetNode(
        selections: [
          ast.FieldNode(
            name: ast.NameNode(value: fieldName),
            arguments: argumentNodes,
            selectionSet: selectionSet,
          ),
        ],
      ),
    );

    final definitions = <ast.DefinitionNode>[operation];
    if (fragments != null) {
      for (final fragmentText in fragments) {
        // Parse fragment text into AST and extract definition
        final fragmentDoc = gql_lang.parseString(fragmentText);
        definitions.addAll(fragmentDoc.definitions);
      }
    }

    return ast.DocumentNode(definitions: definitions);
  }

  /// Build a mutation document AST.
  ast.DocumentNode buildMutationDocument({
    required String operationName,
    required String fieldName,
    required List<String> fields,
    required Map<String, GraphQLType> inputVars,
    List<String>? fragments,
  }) {
    final variableDefinitions = <ast.VariableDefinitionNode>[];
    final argumentNodes = <ast.ArgumentNode>[];

    for (final entry in inputVars.entries) {
      variableDefinitions.add(_buildVariableDefinition(entry.key, entry.value));
      argumentNodes.add(
        ast.ArgumentNode(
          name: ast.NameNode(value: entry.key),
          value: ast.VariableNode(name: ast.NameNode(value: entry.key)),
        ),
      );
    }

    final selectionSet = _buildSelectionSet(fields, fragments);

    final operation = ast.OperationDefinitionNode(
      type: ast.OperationType.mutation,
      name: ast.NameNode(value: operationName),
      variableDefinitions: variableDefinitions,
      selectionSet: ast.SelectionSetNode(
        selections: [
          ast.FieldNode(
            name: ast.NameNode(value: fieldName),
            arguments: argumentNodes,
            selectionSet: selectionSet,
          ),
        ],
      ),
    );

    final definitions = <ast.DefinitionNode>[operation];
    if (fragments != null) {
      for (final fragmentText in fragments) {
        final fragmentDoc = gql_lang.parseString(fragmentText);
        definitions.addAll(fragmentDoc.definitions);
      }
    }

    return ast.DocumentNode(definitions: definitions);
  }

  /// Build a subscription document AST.
  ast.DocumentNode buildSubscriptionDocument({
    required String operationName,
    required String fieldName,
    required List<String> fields,
    Map<String, GraphQLType>? args,
    List<String>? fragments,
  }) {
    final variableDefinitions = <ast.VariableDefinitionNode>[];
    final argumentNodes = <ast.ArgumentNode>[];

    if (args != null) {
      for (final entry in args.entries) {
        variableDefinitions.add(
          _buildVariableDefinition(entry.key, entry.value),
        );
        argumentNodes.add(
          ast.ArgumentNode(
            name: ast.NameNode(value: entry.key),
            value: ast.VariableNode(name: ast.NameNode(value: entry.key)),
          ),
        );
      }
    }

    final selectionSet = _buildSelectionSet(fields, fragments);

    final operation = ast.OperationDefinitionNode(
      type: ast.OperationType.subscription,
      name: ast.NameNode(value: operationName),
      variableDefinitions: variableDefinitions,
      selectionSet: ast.SelectionSetNode(
        selections: [
          ast.FieldNode(
            name: ast.NameNode(value: fieldName),
            arguments: argumentNodes,
            selectionSet: selectionSet,
          ),
        ],
      ),
    );

    final definitions = <ast.DefinitionNode>[operation];
    if (fragments != null) {
      for (final fragmentText in fragments) {
        final fragmentDoc = gql_lang.parseString(fragmentText);
        definitions.addAll(fragmentDoc.definitions);
      }
    }

    return ast.DocumentNode(definitions: definitions);
  }

  /// Build a fragment definition AST.
  ast.DocumentNode buildFragmentDocument({
    required String name,
    required String onType,
    required List<String> fields,
  }) {
    return ast.DocumentNode(
      definitions: [
        ast.FragmentDefinitionNode(
          name: ast.NameNode(value: name),
          typeCondition: ast.TypeConditionNode(
            on: ast.NamedTypeNode(name: ast.NameNode(value: onType)),
          ),
          selectionSet: _buildFieldSelectionSet(fields),
        ),
      ],
    );
  }

  /// Serialize an AST [DocumentNode] to GraphQL text.
  String serialize(ast.DocumentNode document) {
    final lines = <String>[];
    if (unvalidated) {
      lines.add('# UNVALIDATED — no schema cache available at generation time');
      lines.add('# Run `zfa graphql generate --schema=<endpoint>` to validate');
      lines.add('');
    }
    lines.add(gql_lang.printNode(document));
    return lines.join('\n');
  }

  // ── Internal helpers ──

  ast.VariableDefinitionNode _buildVariableDefinition(
    String name,
    GraphQLType type,
  ) {
    return ast.VariableDefinitionNode(
      variable: ast.VariableNode(name: ast.NameNode(value: name)),
      type: _buildTypeNode(type),
      // gql 1.0.1's printer null-asserts defaultValue, so it must be
      // non-null even when no default is provided.
      defaultValue: ast.DefaultValueNode(value: null),
    );
  }

  ast.TypeNode _buildTypeNode(GraphQLType type) {
    if (type is GraphQLNonNullType) {
      return _buildNullableTypeNode(type.ofType, isNonNull: true);
    }
    return _buildNullableTypeNode(type, isNonNull: false);
  }

  ast.TypeNode _buildNullableTypeNode(
    GraphQLType type, {
    required bool isNonNull,
  }) {
    if (type is GraphQLListType) {
      return ast.ListTypeNode(
        type: _buildTypeNode(type.ofType),
        isNonNull: isNonNull,
      );
    }
    return ast.NamedTypeNode(
      name: ast.NameNode(value: type.innerType.name),
      isNonNull: isNonNull,
    );
  }

  ast.SelectionSetNode _buildSelectionSet(
    List<String> fields,
    List<String>? fragments,
  ) {
    final selections = <ast.SelectionNode>[];

    for (final field in fields) {
      if (field.contains('{')) {
        // Nested field with sub-selection
        selections.add(_parseNestedField(field));
      } else {
        selections.add(ast.FieldNode(name: ast.NameNode(value: field)));
      }
    }

    if (fragments != null) {
      for (final fragmentName in fragments) {
        selections.add(
          ast.FragmentSpreadNode(name: ast.NameNode(value: fragmentName)),
        );
      }
    }

    return ast.SelectionSetNode(selections: selections);
  }

  ast.SelectionSetNode _buildFieldSelectionSet(List<String> fields) {
    return ast.SelectionSetNode(
      selections: fields
          .map((f) => ast.FieldNode(name: ast.NameNode(value: f)))
          .toList(),
    );
  }

  ast.FieldNode _parseNestedField(String fieldSpec) {
    // Simple nested field parser: "fieldName { sub1 sub2 }"
    final match = RegExp(r'(\w+)\s*\{\s*([^}]+)\s*\}').firstMatch(fieldSpec);
    if (match == null) {
      return ast.FieldNode(name: ast.NameNode(value: fieldSpec));
    }

    final fieldName = match.group(1)!;
    final subFields = match.group(2)!.trim().split(RegExp(r'\s+'));

    return ast.FieldNode(
      name: ast.NameNode(value: fieldName),
      selectionSet: ast.SelectionSetNode(
        selections: subFields
            .map((f) => ast.FieldNode(name: ast.NameNode(value: f.trim())))
            .toList(),
      ),
    );
  }
}
