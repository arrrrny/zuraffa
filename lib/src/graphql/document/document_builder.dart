import '../schema/schema_parser.dart';

/// Builds GraphQL query/mutation/subscription documents from schema metadata.
///
/// ```dart
/// final builder = DocumentBuilder(schema: schema);
/// final doc = builder.buildQuery(
///   'GetProduct',
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
    final buffer = StringBuffer();
    buffer.writeln(
      'query $operationName${args != null && args.isNotEmpty ? _buildArgs(args) : ''} {',
    );
    buffer.writeln(
      '  $fieldName${args != null && args.isNotEmpty ? _buildArgValues(args) : ''} {',
    );
    for (final field in fields) {
      buffer.writeln('    $field');
    }
    buffer.writeln('  }');
    buffer.writeln('}');

    if (fragments != null) {
      for (final fragment in fragments) {
        buffer.writeln(fragment);
      }
    }

    return buffer.toString();
  }

  /// Build a mutation document string.
  String buildMutation({
    required String operationName,
    required String fieldName,
    required List<String> fields,
    required Map<String, String> inputVars,
  }) {
    final buffer = StringBuffer();
    final varDefs = inputVars.entries
        .map((e) => '\$${e.key}: ${e.value}')
        .join(', ');

    buffer.writeln('mutation $operationName($varDefs) {');
    buffer.writeln(
      '  $fieldName(${inputVars.keys.map((k) => '$k: \$$k').join(', ')}) {',
    );
    for (final field in fields) {
      buffer.writeln('    $field');
    }
    buffer.writeln('  }');
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Build a subscription document string.
  String buildSubscription({
    required String operationName,
    required String fieldName,
    required List<String> fields,
    Map<String, String>? args,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(
      'subscription $operationName${args != null && args.isNotEmpty ? _buildArgs(args) : ''} {',
    );
    buffer.writeln(
      '  $fieldName${args != null && args.isNotEmpty ? _buildArgValues(args) : ''} {',
    );
    for (final field in fields) {
      buffer.writeln('    $field');
    }
    buffer.writeln('  }');
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Build a fragment definition.
  String buildFragment({
    required String name,
    required String onType,
    required List<String> fields,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('fragment $name on $onType {');
    for (final field in fields) {
      buffer.writeln('  $field');
    }
    buffer.writeln('}');
    return buffer.toString();
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
