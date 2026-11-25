import 'dart:async';
import '../failure.dart';
import '../result.dart';

/// Context passed along the middleware pipeline.
class ZfaContext {
  final String useCaseName;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  ZfaContext({
    required this.useCaseName,
    required this.timestamp,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};
}

/// Signature for the next use case execution step in the pipeline.
typedef NextUseCase<I, O> =
    Future<Result<O, AppFailure>> Function(I intent, ZfaContext ctx);

/// Pure-Dart typed onion middleware contract.
abstract class ZfaMiddleware<I, O> {
  Future<Result<O, AppFailure>> intercept(
    I intent,
    ZfaContext ctx,
    NextUseCase<I, O> next,
  );
}
