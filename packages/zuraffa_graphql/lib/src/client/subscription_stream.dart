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
  ///
  /// The returned signal is resilient to transient errors: if the subscription
  /// stream emits an error, it will automatically retry by recreating the
  /// subscription, preserving the signal for long-lived watchXxx() usage.
  SignalResult<T> toSignalResult() {
    // Wrap the subscription stream with retry logic to handle transient errors.
    final resilientStream = _createResilientStream();
    return StreamToSignalResultAdapter.adapt(resilientStream);
  }

  /// Create a stream that automatically retries subscription on errors.
  Stream<Result<T, AppFailure>> _createResilientStream() {
    late StreamController<Result<T, AppFailure>> controller;
    StreamSubscription<Result<T, AppFailure>>? subscription;

    void subscribe() {
      subscription?.cancel();
      subscription = toResultStream().listen(
        (result) {
          if (!controller.isClosed) {
            controller.add(result);
          }
        },
        onError: (Object e, StackTrace st) {
          // Emit the error as a failure result, then retry the subscription.
          if (!controller.isClosed) {
            controller.add(Failure<T, AppFailure>(AppFailure.from(e, st)));
            // Recreate the subscription after a brief delay to avoid tight loops.
            Future.delayed(const Duration(milliseconds: 100), () {
              if (!controller.isClosed) {
                subscribe();
              }
            });
          }
        },
        onDone: () {
          // If the stream completes without error, recreate it to maintain
          // the long-lived subscription behavior.
          if (!controller.isClosed) {
            subscribe();
          }
        },
      );
    }

    controller = StreamController<Result<T, AppFailure>>(
      onListen: subscribe,
      onCancel: () {
        subscription?.cancel();
        subscription = null;
      },
    );

    return controller.stream;
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
