import 'dart:async';
import 'package:graphql/client.dart';
import 'package:zuraffa/zuraffa.dart';

/// Converts a GraphQL subscription [Stream] into a [SignalResult]-compatible
/// stream for use with [StreamToSignalResultAdapter].
///
/// ```dart
/// final stream = SubscriptionStream<Product>(
///   client: client,
///   document: subscriptionDocument,
///   parser: (data) => $Product.fromJson(data['productUpdated']),
/// );
///
/// final sr = StreamToSignalResultAdapter<Product>.adapt(stream.toResultStream());
/// ```
class SubscriptionStream<T> {
  SubscriptionStream({
    required this.client,
    required this.document,
    required this.parser,
    this.variables = const {},
  });

  final GraphQLClient client;
  final String document;
  final T Function(Map<String, dynamic> data) parser;
  final Map<String, dynamic> variables;

  /// The raw GraphQL subscription stream.
  Stream<QueryResult> get rawStream {
    return client.subscribe(
      SubscriptionOptions(document: gql(document), variables: variables),
    );
  }

  /// A parsed stream of [Result] values.
  Stream<Result<T, AppFailure>> toResultStream() {
    return rawStream.map((result) {
      if (result.hasException) {
        return Failure<T, AppFailure>(
          NetworkFailure(result.exception.toString()),
        );
      }
      final data = result.data;
      if (data == null) {
        return Failure<T, AppFailure>(
          const ServerFailure('No data in subscription'),
        );
      }
      try {
        return Success<T, AppFailure>(parser(data));
      } catch (e) {
        return Failure<T, AppFailure>(UnknownFailure('Parse error: $e'));
      }
    });
  }

  /// A [SignalResult] that updates on each subscription event.
  SignalResult<T> toSignalResult() {
    // Note: `StreamToSignalResultAdapter<T>.adapt` is invalid Dart —
    // statics are accessed via the raw class name, so `T` is inferred
    // from the stream type instead.
    return StreamToSignalResultAdapter.adapt(toResultStream());
  }
}

/// Extension for easy subscription-to-SignalResult conversion.
extension GraphQLClientSubscription on GraphQLClient {
  /// Subscribe to a document and return a [SignalResult].
  SignalResult<T> subscribeTo<T>({
    required String document,
    required T Function(Map<String, dynamic> data) parser,
    Map<String, dynamic> variables = const {},
  }) {
    return SubscriptionStream<T>(
      client: this,
      document: document,
      parser: parser,
      variables: variables,
    ).toSignalResult();
  }
}
