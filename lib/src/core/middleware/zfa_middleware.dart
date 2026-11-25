import 'dart:async';
import '../failure.dart';
import '../result.dart';

/// Context passed along the middleware pipeline.
class ZfaMiddlewareContext {
  final String useCaseName;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  ZfaMiddlewareContext({
    required this.useCaseName,
    required this.timestamp,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};
}

/// Signature for the next use case execution step in the pipeline.
typedef NextUseCase<I, O> =
    Future<Result<O, AppFailure>> Function(I intent, ZfaMiddlewareContext ctx);

/// Pure-Dart typed onion middleware contract.
abstract class ZfaMiddleware<I, O> {
  Future<Result<O, AppFailure>> intercept(
    I intent,
    ZfaMiddlewareContext ctx,
    NextUseCase<I, O> next,
  );
}
