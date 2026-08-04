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
  ///
  /// [fragmentSpreads] contains fragment spread names only.
  /// [fragmentDefinitions] contains the full fragment definition text to be
  /// parsed and included in the document.
  ast.DocumentNode buildQueryDocument({
    required String operationName,
    required String fieldName,
    required List<String> fields,
    Map<String, GraphQLType>? args,
    List<String>? fragmentSpreads,
    List<String>? fragmentDefinitions,
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

    final selectionSet = _buildSelectionSet(fields, fragmentSpreads);

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
    if (fragmentDefinitions != null) {
      for (final fragmentText in fragmentDefinitions) {
        // Parse fragment text into AST and extract definition
        final fragmentDoc = gql_lang.parseString(fragmentText);
        definitions.addAll(fragmentDoc.definitions);
      }
    }

    return ast.DocumentNode(definitions: definitions);
  }

  /// Build a mutation document AST.
  ///
  /// [fragmentSpreads] contains fragment spread names only.
  /// [fragmentDefinitions] contains the full fragment definition text to be
  /// parsed and included in the document.
  ast.DocumentNode buildMutationDocument({
    required String operationName,
    required String fieldName,
    required List<String> fields,
    required Map<String, GraphQLType> inputVars,
    List<String>? fragmentSpreads,
    List<String>? fragmentDefinitions,
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

    final selectionSet = _buildSelectionSet(fields, fragmentSpreads);

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
    if (fragmentDefinitions != null) {
      for (final fragmentText in fragmentDefinitions) {
        final fragmentDoc = gql_lang.parseString(fragmentText);
        definitions.addAll(fragmentDoc.definitions);
      }
    }

    return ast.DocumentNode(definitions: definitions);
  }

  /// Build a subscription document AST.
  ///
  /// [fragmentSpreads] contains fragment spread names only.
  /// [fragmentDefinitions] contains the full fragment definition text to be
  /// parsed and included in the document.
  ast.DocumentNode buildSubscriptionDocument({
    required String operationName,
    required String fieldName,
    required List<String> fields,
    Map<String, GraphQLType>? args,
    List<String>? fragmentSpreads,
    List<String>? fragmentDefinitions,
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

    final selectionSet = _buildSelectionSet(fields, fragmentSpreads);

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
    if (fragmentDefinitions != null) {
      for (final fragmentText in fragmentDefinitions) {
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
    List<String>? fragmentSpreads,
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

    if (fragmentSpreads != null) {
      for (final fragmentName in fragmentSpreads) {
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
    // Parse nested field specification using full GraphQL syntax.
    // For complex nesting, parse the entire field as a GraphQL selection.
    final trimmed = fieldSpec.trim();

    // Try to extract field name and content between braces
    final openBrace = trimmed.indexOf('{');
    if (openBrace == -1) {
      throw ArgumentError(
        'Malformed nested field specification: expected braces but found none in "$fieldSpec"',
      );
    }

    final fieldName = trimmed.substring(0, openBrace).trim();
    if (fieldName.isEmpty || !RegExp(r'^\w+$').hasMatch(fieldName)) {
      throw ArgumentError(
        'Malformed nested field specification: invalid field name in "$fieldSpec"',
      );
    }

    // Find matching closing brace, accounting for nested braces
    var depth = 0;
    var closeBrace = -1;
    for (var i = openBrace; i < trimmed.length; i++) {
      if (trimmed[i] == '{') {
        depth++;
      } else if (trimmed[i] == '}') {
        depth--;
        if (depth == 0) {
          closeBrace = i;
          break;
        }
      }
    }

    if (closeBrace == -1 || depth != 0) {
      throw ArgumentError(
        'Malformed nested field specification: unbalanced braces in "$fieldSpec"',
      );
    }

    final selectionContent = trimmed
        .substring(openBrace + 1, closeBrace)
        .trim();
    if (selectionContent.isEmpty) {
      throw ArgumentError(
        'Malformed nested field specification: empty selection set in "$fieldSpec"',
      );
    }

    // Parse sub-fields recursively if they contain braces, otherwise treat as simple fields
    final subFields = <String>[];
    var currentField = StringBuffer();
    depth = 0;

    for (var i = 0; i < selectionContent.length; i++) {
      final char = selectionContent[i];
      if (char == '{') {
        depth++;
        currentField.write(char);
      } else if (char == '}') {
        depth--;
        currentField.write(char);
      } else if (char == ' ' && depth == 0) {
        if (currentField.isNotEmpty) {
          subFields.add(currentField.toString().trim());
          currentField.clear();
        }
      } else {
        currentField.write(char);
      }
    }
    if (currentField.isNotEmpty) {
      subFields.add(currentField.toString().trim());
    }

    final selections = <ast.SelectionNode>[];
    for (final subField in subFields) {
      if (subField.isEmpty) continue;
      if (subField.contains('{')) {
        // Recursively parse nested field
        selections.add(_parseNestedField(subField));
      } else {
        selections.add(ast.FieldNode(name: ast.NameNode(value: subField)));
      }
    }

    return ast.FieldNode(
      name: ast.NameNode(value: fieldName),
      selectionSet: ast.SelectionSetNode(selections: selections),
    );
  }
}
