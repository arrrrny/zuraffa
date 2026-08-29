/// Throwing GraphQL introspection client with detailed, actionable errors.
///
/// Spec 037 (FR-002): introspection failures must NEVER surface as a silent
/// `null` — the caller gets an [IntrospectionException] naming the HTTP
/// status, the GraphQL error message + path (the specific field/type that
/// failed), or the structural problem with the response.
///
/// The transport is injectable ([IntrospectionTransport]) so tests (and the
/// schema cache) can serve committed fixtures without network access.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// One HTTP round-trip result of an introspection POST.
class IntrospectionHttpResponse {
  const IntrospectionHttpResponse(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

/// Performs the introspection POST for [endpoint].
///
/// [headers] always contains at least `Content-Type: application/json`;
/// [query] is the introspection document text.
typedef IntrospectionTransport = Future<IntrospectionHttpResponse> Function(
  Uri endpoint,
  Map<String, String> headers,
  String query,
);

/// Raised for every introspection failure mode with a human-actionable
/// message. Carries the HTTP status (when transport-level) and the raw
/// GraphQL error objects (when the server reported errors).
class IntrospectionException implements Exception {
  IntrospectionException(
    this.message, {
    this.statusCode,
    this.graphqlErrors,
  });

  /// Human-readable, actionable description of the failure.
  final String message;

  /// HTTP status code when the failure was transport-level.
  final int? statusCode;

  /// Raw GraphQL error objects reported by the server, if any.
  final List<Map<String, dynamic>>? graphqlErrors;

  @override
  String toString() => 'IntrospectionException: $message';
}

class IntrospectionClient {
  IntrospectionClient({IntrospectionTransport? transport})
    : _transport = transport ?? _defaultHttpTransport;

  final IntrospectionTransport _transport;

  static const Set<String> _knownKinds = {
    'SCALAR',
    'OBJECT',
    'INTERFACE',
    'UNION',
    'ENUM',
    'INPUT_OBJECT',
    'LIST',
    'NON_NULL',
  };

  /// The standard introspection document. Unlike the legacy
  /// `GraphQLIntrospectionService.introspectionQuery`, this asks for
  /// `interfaces`, `possibleTypes` and input field defaults so the SDL
  /// printer and the diff engine see the full type graph.
  static const String introspectionQuery = '''
query IntrospectionQuery {
  __schema {
    queryType { name }
    mutationType { name }
    subscriptionType { name }
    types { ...FullType }
    directives {
      name
      description
      locations
      args { ...InputValue }
    }
  }
}

fragment TypeRef on __Type {
  kind
  name
  ofType {
    kind
    name
    ofType {
      kind
      name
      ofType {
        kind
        name
        ofType {
          kind
          name
          ofType {
            kind
            name
            ofType {
              kind
              name
              ofType {
                kind
                name
              }
            }
          }
        }
      }
    }
  }
}

fragment InputValue on __InputValue {
  name
  description
  type { ...TypeRef }
  defaultValue
}

fragment FullType on __Type {
  kind
  name
  description
  fields(includeDeprecated: true) {
    name
    description
    args { ...InputValue }
    type { ...TypeRef }
    isDeprecated
    deprecationReason
  }
  inputFields {
    name
    description
    type { ...TypeRef }
    defaultValue
  }
  interfaces { ...TypeRef }
  enumValues(includeDeprecated: true) {
    name
    description
    isDeprecated
    deprecationReason
  }
  possibleTypes { ...TypeRef }
}
''';

  /// Fetches and validates an introspection result for [endpoint].
  ///
  /// Returns the parsed `data` object (containing `__schema`).
  ///
  /// Throws [IntrospectionException] on every failure mode:
  /// network/transport errors, non-200 statuses, server-reported GraphQL
  /// errors (message + path), missing `__schema`, missing query root,
  /// malformed JSON, and unknown type kinds.
  Future<Map<String, dynamic>> fetch(
    Uri endpoint, {
    Map<String, String>? headers,
  }) async {
    final requestHeaders = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?headers,
    };

    final Map<String, dynamic> body;
    try {
      final response = await _transport(
        endpoint,
        requestHeaders,
        introspectionQuery,
      );
      if (response.statusCode != 200) {
        throw IntrospectionException(
          'Endpoint $endpoint returned HTTP ${response.statusCode} '
          '(body: ${_truncate(response.body)}). Verify the URL points at a '
          'GraphQL endpoint.',
          statusCode: response.statusCode,
        );
      }
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } on FormatException catch (e) {
        throw IntrospectionException(
          'Endpoint $endpoint returned a non-JSON body '
          '(${_truncate(response.body)}). Is this a GraphQL endpoint? '
          '(JSON parse error: ${e.message})',
          statusCode: response.statusCode,
        );
      }
    } on IntrospectionException {
      rethrow;
    } catch (e) {
      throw IntrospectionException(
        'Endpoint $endpoint is unreachable: $e. Check the URL, network '
        'connectivity, and that the server is running.',
      );
    }

    // Server-reported GraphQL errors — surface the first message and its
    // path so the user sees the specific field/type that failed.
    final rawErrors = body['errors'];
    if (rawErrors is List && rawErrors.isNotEmpty) {
      final errors = rawErrors
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final first = errors.first;
      final message = first['message']?.toString() ?? 'unknown error';
      final path = _formatPath(first['path']);
      throw IntrospectionException(
        'GraphQL introspection failed${path.isEmpty ? '' : ' at $path'}: '
        '$message'
        '${errors.length > 1 ? ' (+${errors.length - 1} more errors)' : ''}',
        graphqlErrors: errors,
      );
    }

    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw IntrospectionException(
        'Introspection response has no data object '
        '(body: ${_truncate(jsonEncode(body))}).',
      );
    }

    final schema = data['__schema'];
    if (schema is! Map<String, dynamic>) {
      throw IntrospectionException(
        'Introspection response has no __schema object. The endpoint may '
        'have introspection disabled, or it may not be a GraphQL endpoint.',
      );
    }

    final queryType = schema['queryType'];
    if (queryType is! Map<String, dynamic>) {
      throw IntrospectionException(
        'Introspection result has no query root type (__schema.queryType '
        'is null). A GraphQL schema must define a Query type.',
      );
    }
    if ((queryType['name'] as String?) == null) {
      throw IntrospectionException(
        'Introspection result has no query root type name. A GraphQL '
        'schema must define a Query type.',
      );
    }

    _validateTypes(schema['types']);

    return data;
  }

  /// Validates that every type entry has a known kind and, for named kinds,
  /// a non-empty name. FR-002: name the type that failed.
  void _validateTypes(dynamic types) {
    if (types is! List) {
      throw IntrospectionException(
        'Introspection result __schema.types is missing or not a list.',
      );
    }
    for (final entry in types) {
      if (entry is! Map) {
        throw IntrospectionException(
          'Introspection result contains a non-object type entry: $entry.',
        );
      }
      final kind = entry['kind'] as String?;
      final name = entry['name'] as String?;
      if (kind == null || !_knownKinds.contains(kind)) {
        throw IntrospectionException(
          'Introspection result contains type '
          '"${name ?? '<unnamed>'}" with unknown kind "$kind".',
        );
      }
      if (kind != 'LIST' && kind != 'NON_NULL' &&
          (name == null || name.isEmpty)) {
        throw IntrospectionException(
          'Introspection result contains a $kind type with a null or empty '
          'name.',
        );
      }
    }
  }

  /// Formats a GraphQL error path (['__schema', 'types', 'Product',
  /// 'fields', 'ghost']) into a compact location ('Product.fields.ghost').
  static String _formatPath(dynamic path) {
    if (path is! List) return '';
    final segments = path.map((s) => s.toString()).toList();
    // Drop the mechanical __schema/types prefix — what users need is the
    // failing type/field.
    if (segments.length >= 2 && segments[0] == '__schema') {
      if (segments[1] == 'types') {
        segments.removeRange(0, 2);
      } else {
        segments.removeAt(0);
      }
    }
    if (segments.isEmpty) return '';
    return segments.join('.');
  }

  static String _truncate(String text, [int max = 200]) {
    if (text.length <= max) return text;
    return '${text.substring(0, max)}...';
  }
}

Future<IntrospectionHttpResponse> _defaultHttpTransport(
  Uri endpoint,
  Map<String, String> headers,
  String query,
) async {
  final response = await http.post(
    endpoint,
    headers: headers,
    body: jsonEncode({'query': query}),
  );
  return IntrospectionHttpResponse(response.statusCode, response.body);
}
