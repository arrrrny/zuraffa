import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('GraphQLClientConfig', () {
    test('parses from JSON', () {
      final config = GraphQLClientConfig.fromJson({
        'graphql': {
          'endpoint': 'https://api.example.com/graphql',
          'subscriptions': true,
          'wsEndpoint': 'wss://api.example.com/graphql',
          'headers': {'vendure-token': 'abc123'},
        },
      });

      expect(config.endpoint, 'https://api.example.com/graphql');
      expect(config.subscriptions, true);
      expect(config.wsEndpoint, 'wss://api.example.com/graphql');
      expect(config.headers['vendure-token'], 'abc123');
    });

    test('defaults subscriptions to false', () {
      final config = GraphQLClientConfig.fromJson({
        'graphql': {'endpoint': 'https://api.example.com/graphql'},
      });

      expect(config.subscriptions, false);
      expect(config.wsEndpoint, null);
    });

    test('defaults headers to empty', () {
      final config = GraphQLClientConfig.fromJson({
        'graphql': {'endpoint': 'https://api.example.com/graphql'},
      });

      expect(config.headers, {});
    });
  });

  group('GraphQLClientProvider', () {
    tearDown(() => GraphQLClientProvider.instance.dispose());

    test('throws when not initialized', () {
      GraphQLClientProvider.instance.dispose();
      expect(
        () => GraphQLClientProvider.instance.client,
        throwsA(isA<StateError>()),
      );
    });

    test('initializes with config', () {
      GraphQLClientProvider.instance.initialize(
        const GraphQLClientConfig(endpoint: 'https://test.com/graphql'),
      );
      expect(GraphQLClientProvider.instance.isInitialized, true);
    });

    test('lazily builds client on first access', () {
      GraphQLClientProvider.instance.dispose();
      GraphQLClientProvider.instance.initialize(
        const GraphQLClientConfig(endpoint: 'https://test.com/graphql'),
      );

      final client1 = GraphQLClientProvider.instance.client;
      final client2 = GraphQLClientProvider.instance.client;
      expect(identical(client1, client2), true);
    });

    test('dispose rebuilds on next access', () {
      GraphQLClientProvider.instance.initialize(
        const GraphQLClientConfig(endpoint: 'https://old.com/graphql'),
      );
      final client1 = GraphQLClientProvider.instance.client;

      GraphQLClientProvider.instance.dispose();
      GraphQLClientProvider.instance.initialize(
        const GraphQLClientConfig(endpoint: 'https://new.com/graphql'),
      );
      final client2 = GraphQLClientProvider.instance.client;

      // Different config should produce different client
      expect(identical(client1, client2), false);
    });
  });
}
