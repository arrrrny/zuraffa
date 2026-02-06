/// GraphQL introspection service for fetching and parsing schemas.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'graphql_schema.dart';

/// Service for fetching GraphQL schema via introspection.
class GraphQLIntrospectionService {
  /// Standard GraphQL introspection query.
  static const String introspectionQuery = '''
query IntrospectionQuery {
  __schema {
    queryType { name }
    mutationType { name }
    subscriptionType { name }
    types {
      kind
      name
      description
      fields(includeDeprecated: true) {
        name
        description
        type {
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
      inputFields {
        name
        description
        type {
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
      enumValues(includeDeprecated: true) {
        name
        description
      }
    }
  }
}
''';

  /// Fetches and parses a GraphQL schema from the given endpoint.
  ///
  /// Returns `null` on HTTP errors or GraphQL errors.
  static Future<GqlSchema?> introspect({
    required String url,
    Map<String, String>? headers,
  }) async {
    try {
      final requestHeaders = <String, String>{
        'Content-Type': 'application/json',
        ...?headers,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: requestHeaders,
        body: jsonEncode({'query': introspectionQuery}),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (json.containsKey('errors')) {
        return null;
      }

      final data = json['data'] as Map<String, dynamic>?;
      if (data == null) {
        return null;
      }

      return GqlSchema.fromIntrospection(data);
    } catch (_) {
      return null;
    }
  }
}
