import 'package:graphql/client.dart';
import 'package:zuraffa/zuraffa.dart';

import 'graphql_client_factory.dart';

/// Singleton provider for the configured [GraphQLClient].
///
/// Registered in DI via `configureGraphqlDi()`:
/// ```dart
/// ZuraffaContainer.instance.registerSingleton<GraphQLClient>(
///   () => GraphQLClientProvider.instance.client,
/// );
/// ```
///
/// The provider lazily initializes the client on first access.
class GraphQLClientProvider {
  GraphQLClientProvider._();
  static final GraphQLClientProvider instance = GraphQLClientProvider._();

  GraphQLClientConfig? _config;
  GraphQLClient? _client;
  final _factory = const GraphQLClientFactory();

  /// Initialize with configuration. Must be called before [client].
  void initialize(GraphQLClientConfig config) {
    _config = config;
    _client = null; // Reset to rebuild with new config
  }

  /// Whether the provider has been initialized.
  bool get isInitialized => _config != null;

  /// The configured [GraphQLClient]. Lazily built on first access.
  GraphQLClient get client {
    if (_config == null) {
      throw StateError(
        'GraphQLClientProvider not initialized. '
        'Call initialize() with GraphQLClientConfig before accessing client.',
      );
    }
    _client ??= _factory.build(_config!);
    return _client!;
  }

  /// Dispose the current client. Next [client] access will rebuild.
  void dispose() {
    _client = null;
  }
}
