import '../schema/schema_parser.dart';

/// Builds GraphQL query/mutation/subscription documents from schema metadata.
///
/// ```dart
/// final builder = DocumentBuilder(schema: schema);
/// final doc = builder.buildQuery(
///   operationName: 'GetProduct',
///   fieldName: 'product',
///   fields: ['id', 'name', 'price'],
///   args: {'id': 'String!'},
/// );
/// ```
class DocumentBuilder {
  DocumentBuilder({required this.schema});

  final GraphQLSchema schema;

  /// Build a query document string.
  String buildQuery({
    required String operationName,
    required String fieldName,
    required List<String> fields,
    Map<String, String>? args,
    List<String>? fragments,
  }) {
    final lines = <String>[
      'query $operationName${args != null && args.isNotEmpty ? _buildArgs(args) : ''} {',
      '  $fieldName${args != null && args.isNotEmpty ? _buildArgValues(args) : ''} {',
      ...fields.map((field) => '    $field'),
      '  }',
      '}',
      ...?fragments,
    ];
    return '${lines.join('\n')}\n';
  }

  /// Build a mutation document string.
  String buildMutation({
    required String operationName,
    required String fieldName,
    required List<String> fields,
    required Map<String, String> inputVars,
  }) {
    final hasVars = inputVars.isNotEmpty;
    final lines = <String>[
      'mutation $operationName${hasVars ? '(${inputVars.entries.map((e) => '\$${e.key}: ${e.value}').join(', ')})' : ''} {',
      '  $fieldName${hasVars ? '(${inputVars.keys.map((k) => '$k: \$$k').join(', ')})' : ''} {',
      ...fields.map((field) => '    $field'),
      '  }',
      '}',
    ];
    return '${lines.join('\n')}\n';
  }

  /// Build a subscription document string.
  String buildSubscription({
    required String operationName,
    required String fieldName,
    required List<String> fields,
    Map<String, String>? args,
  }) {
    final lines = <String>[
      'subscription $operationName${args != null && args.isNotEmpty ? _buildArgs(args) : ''} {',
      '  $fieldName${args != null && args.isNotEmpty ? _buildArgValues(args) : ''} {',
      ...fields.map((field) => '    $field'),
      '  }',
      '}',
    ];
    return '${lines.join('\n')}\n';
  }

  /// Build a fragment definition.
  String buildFragment({
    required String name,
    required String onType,
    required List<String> fields,
  }) {
    final lines = <String>[
      'fragment $name on $onType {',
      ...fields.map((field) => '  $field'),
      '}',
    ];
    return '${lines.join('\n')}\n';
  }

  String _buildArgs(Map<String, String> args) {
    final defs = args.entries.map((e) => '\$${e.key}: ${e.value}').join(', ');
    return '($defs)';
  }

  String _buildArgValues(Map<String, String> args) {
    final values = args.keys.map((k) => '$k: \$$k').join(', ');
    return '($values)';
  }
}
