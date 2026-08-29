import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/graphql/introspection/introspection_client.dart';

void main() {
  Map<String, dynamic> okBody() => {
    'data': {
      '__schema': {
        'queryType': {'name': 'Query'},
        'types': [
          {'kind': 'OBJECT', 'name': 'Query', 'fields': []},
        ],
      },
    },
  };

  group('IntrospectionClient', () {
    test('fetch returns parsed data on success', () async {
      final client = IntrospectionClient(
        transport: (endpoint, headers, query) async =>
            IntrospectionHttpResponse(200, jsonEncode(okBody())),
      );
      final data = await client.fetch(Uri.parse('https://api.test/graphql'));
      expect(data, isA<Map<String, dynamic>>());
      expect(data['__schema'], isA<Map<String, dynamic>>());
      expect((data['__schema'] as Map<String, dynamic>)['queryType'], {
        'name': 'Query',
      });
    });

    test('fetch posts the introspection query to the endpoint', () async {
      Uri? seenEndpoint;
      Map<String, String>? seenHeaders;
      String? seenQuery;
      final client = IntrospectionClient(
        transport: (endpoint, headers, query) async {
          seenEndpoint = endpoint;
          seenHeaders = headers;
          seenQuery = query;
          return IntrospectionHttpResponse(200, jsonEncode(okBody()));
        },
      );
      await client.fetch(
        Uri.parse('https://api.test/graphql'),
        headers: {'X-Custom': 'yes'},
      );
      expect(seenEndpoint.toString(), 'https://api.test/graphql');
      expect(seenHeaders?['X-Custom'], 'yes');
      // The introspection query asks for the standard shape.
      expect(seenQuery, contains('__schema'));
      expect(seenQuery, contains('possibleTypes'));
      expect(seenQuery, contains('interfaces'));
    });

    test(
      'non-200 status throws IntrospectionException with status code',
      () async {
        final client = IntrospectionClient(
          transport: (endpoint, headers, query) async =>
              IntrospectionHttpResponse(500, 'Internal Server Error'),
        );
        await expectLater(
          client.fetch(Uri.parse('https://api.test/graphql')),
          throwsA(
            isA<IntrospectionException>()
                .having((e) => e.statusCode, 'statusCode', 500)
                .having((e) => e.message, 'message', contains('500')),
          ),
        );
      },
    );

    test('transport error throws unreachable error', () async {
      final client = IntrospectionClient(
        transport: (endpoint, headers, query) async {
          throw const SocketFailureException('connection refused');
        },
      );
      await expectLater(
        client.fetch(Uri.parse('https://api.test/graphql')),
        throwsA(
          isA<IntrospectionException>().having(
            (e) => e.message,
            'message',
            allOf(contains('unreachable'), contains('connection refused')),
          ),
        ),
      );
    });

    test(
      'graphql errors surface message and path of the failing part',
      () async {
        final body = {
          'data': null,
          'errors': [
            {
              'message': 'Cannot query field "ghost" on type "__Schema".',
              'path': ['__schema', 'types', 'Product', 'fields', 'ghost'],
              'locations': [
                {'line': 3, 'column': 7},
              ],
            },
          ],
        };
        final client = IntrospectionClient(
          transport: (endpoint, headers, query) async =>
              IntrospectionHttpResponse(200, jsonEncode(body)),
        );
        await expectLater(
          client.fetch(Uri.parse('https://api.test/graphql')),
          throwsA(
            isA<IntrospectionException>()
                .having(
                  (e) => e.message,
                  'message',
                  contains('Cannot query field "ghost"'),
                )
                .having(
                  (e) => e.message,
                  'message',
                  contains('Product.fields.ghost'),
                )
                .having((e) => e.graphqlErrors?.length, 'graphqlErrors', 1),
          ),
        );
      },
    );

    test('missing __schema throws actionable error', () async {
      final client = IntrospectionClient(
        transport: (endpoint, headers, query) async =>
            IntrospectionHttpResponse(200, jsonEncode({'data': {}})),
      );
      await expectLater(
        client.fetch(Uri.parse('https://api.test/graphql')),
        throwsA(
          isA<IntrospectionException>().having(
            (e) => e.message,
            'message',
            allOf(contains('__schema'), contains('introspection')),
          ),
        ),
      );
    });

    test('null queryType throws missing query root error', () async {
      final client = IntrospectionClient(
        transport: (endpoint, headers, query) async =>
            IntrospectionHttpResponse(
              200,
              jsonEncode({
                'data': {
                  '__schema': {
                    'queryType': null,
                    'types': [
                      {'kind': 'OBJECT', 'name': 'Query', 'fields': []},
                    ],
                  },
                },
              }),
            ),
      );
      await expectLater(
        client.fetch(Uri.parse('https://api.test/graphql')),
        throwsA(
          isA<IntrospectionException>().having(
            (e) => e.message,
            'message',
            allOf(contains('query'), contains('root')),
          ),
        ),
      );
    });

    test('malformed JSON body throws parse error', () async {
      final client = IntrospectionClient(
        transport: (endpoint, headers, query) async =>
            IntrospectionHttpResponse(200, '<html>not json</html>'),
      );
      await expectLater(
        client.fetch(Uri.parse('https://api.test/graphql')),
        throwsA(
          isA<IntrospectionException>().having(
            (e) => e.message,
            'message',
            contains('JSON'),
          ),
        ),
      );
    });

    test('OBJECT without fields key is tolerated', () async {
      final body = {
        'data': {
          '__schema': {
            'queryType': {'name': 'Query'},
            'types': [
              {'kind': 'OBJECT', 'name': 'Query'},
            ],
          },
        },
      };
      final client = IntrospectionClient(
        transport: (endpoint, headers, query) async =>
            IntrospectionHttpResponse(200, jsonEncode(body)),
      );
      final data = await client.fetch(Uri.parse('https://api.test/graphql'));
      expect(data['__schema'], isNotNull);
    });

    test('unknown type kind is rejected loudly naming the type', () async {
      final body = {
        'data': {
          '__schema': {
            'queryType': {'name': 'Query'},
            'types': [
              {'kind': 'OBJECT', 'name': 'Query', 'fields': []},
              {'kind': 'WEIRD_KIND', 'name': 'Odd'},
            ],
          },
        },
      };
      final client = IntrospectionClient(
        transport: (endpoint, headers, query) async =>
            IntrospectionHttpResponse(200, jsonEncode(body)),
      );
      await expectLater(
        client.fetch(Uri.parse('https://api.test/graphql')),
        throwsA(
          isA<IntrospectionException>().having(
            (e) => e.message,
            'message',
            allOf(contains('WEIRD_KIND'), contains('Odd')),
          ),
        ),
      );
    });
  });
}

/// Local transport-thrown exception used to simulate socket failures.
class SocketFailureException implements Exception {
  const SocketFailureException(this.cause);
  final String cause;

  @override
  String toString() => 'SocketFailureException: $cause';
}
