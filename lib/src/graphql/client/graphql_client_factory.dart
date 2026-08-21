import 'package:gql/ast.dart';
import 'package:graphql/client.dart';
import 'package:http/http.dart' as http;

/// Configuration for assembling a [GraphQLClient].
///
/// ```json
/// // .zfa.json
/// {
///   "graphql": {
///     "endpoint": "https://api.example.com/graphql",
///     "subscriptions": true,
///     "wsEndpoint": "wss://api.example.com/graphql",
///     "headers": {
///       "vendure-token": "{{VENDURE_TOKEN}}"
///     }
///   }
/// }
/// ```
class GraphQLClientConfig {
  const GraphQLClientConfig({
    required this.endpoint,
    this.subscriptions = false,
    this.wsEndpoint,
    this.headers = const {},
    this.httpClient,
  });

  final String endpoint;
  final bool subscriptions;
  final String? wsEndpoint;
  final Map<String, String> headers;
  final http.Client? httpClient;

  factory GraphQLClientConfig.fromJson(Map<String, dynamic> json) {
    final graphql = json['graphql'] as Map<String, dynamic>? ?? {};
    return GraphQLClientConfig(
      endpoint: graphql['endpoint'] as String? ?? '',
      subscriptions: graphql['subscriptions'] as bool? ?? false,
      wsEndpoint: graphql['wsEndpoint'] as String?,
      headers: (graphql['headers'] as Map<String, dynamic>? ?? {})
          .cast<String, String>(),
    );
  }
}

/// Result of building a [GraphQLClient] with optional [WebSocketLink].
class GraphQLClientBuildResult {
  const GraphQLClientBuildResult({required this.client, this.wsLink});

  final GraphQLClient client;
  final WebSocketLink? wsLink;
}

/// Factory that assembles a [GraphQLClient] from [GraphQLClientConfig].
///
/// Links are chained in order:
/// 1. [HttpLink] — HTTP transport for queries and mutations (headers applied
///    via `defaultHeaders`).
/// 2. [WebSocketLink] — (optional) WebSocket transport for subscriptions,
///    routed via [Link.split] on subscription operations.
class GraphQLClientFactory {
  const GraphQLClientFactory();

  /// Build a [GraphQLClient] from [config].
  ///
  /// Returns a [GraphQLClientBuildResult] containing the client and an optional
  /// [WebSocketLink] that should be disposed when the client is replaced.
  GraphQLClientBuildResult build(GraphQLClientConfig config) {
    final httpLink = HttpLink(
      config.endpoint,
      defaultHeaders: config.headers,
      httpClient: config.httpClient,
    );

    final Link link;
    final WebSocketLink? wsLink;
    if (config.subscriptions && config.wsEndpoint != null) {
      wsLink = WebSocketLink(config.wsEndpoint!);
      // Split link: subscriptions go to WebSocket, everything else to HTTP.
      link = Link.split(
        (request) =>
            request.operation.getOperationType() == OperationType.subscription,
        wsLink,
        httpLink,
      );
    } else {
      wsLink = null;
      link = httpLink;
    }

    return GraphQLClientBuildResult(
      client: GraphQLClient(
        link: link,
        cache: GraphQLCache(),
        defaultPolicies: DefaultPolicies(
          query: Policies(fetch: FetchPolicy.noCache),
          mutate: Policies(fetch: FetchPolicy.noCache),
        ),
      ),
      wsLink: wsLink,
    );
  }
}
