import 'dart:async';
// Pure-Dart: PlatformException replaced with ZuraffaPlatformException (see below).

import 'package:zuraffa/zuraffa.dart';

/// Mixin that provides failure handling capabilities to a class.
///
/// This mixin provides convenient methods for creating and handling
/// different types of failures in data sources and repositories.
///
/// ## Example
/// ```dart
/// class MyDataSource with FailureHandler {
///   Future<Customer> getCustomer(String id) async {
///     try {
///       // ... fetch customer
///     } catch (e) {
///       throw handleError(e);
///     }
///   }
/// }
/// ```
mixin FailureHandler on Loggable {
  /// Handle any error and convert it to an appropriate AppFailure
  ///
  /// This method uses the AppFailure.from factory to intelligently
  /// classify the error based on its type and message.
  AppFailure handleError(Object error, [StackTrace? stackTrace]) {
    return switch (error) {
      // Validation Failures
      IndexError() => validationFailure(
        'Index out of bounds',
        cause: error,
        stackTrace: stackTrace,
      ),
      RangeError e => validationFailure(
        'Value out of range: ${e.message}',
        cause: error,
        stackTrace: stackTrace,
      ),
      ArgumentError e => validationFailure(
        e.message.toString(),
        cause: error,
        stackTrace: stackTrace,
      ),
      FormatException e => validationFailure(
        e.message,
        cause: error,
        stackTrace: stackTrace,
      ),

      // Timeout Failures
      TimeoutException e => timeoutFailure(
        e.message ?? 'Operation timed out',
        timeout: e.duration,
        cause: error,
      ),

      // Cancellation Failures
      CancelledException e => cancellationFailure(e.message),

      // Platform Failures
      ZuraffaPlatformException e => platformFailure(
        e.message ?? 'Platform error occurred',
        code: e.code,
        details: e.details,
        cause: error,
        stackTrace: stackTrace,
      ),
      ZuraffaMissingPluginException e => unsupportedFailure(
        e.message ?? 'Plugin not found',
        cause: error,
        stackTrace: stackTrace,
      ),

      // State Failures
      StateError e => stateFailure(
        e.message,
        cause: error,
        stackTrace: stackTrace,
      ),
      ConcurrentModificationError() => stateFailure(
        'Concurrent modification detected',
        cause: error,
        stackTrace: stackTrace,
      ),
      StackOverflowError() => stateFailure(
        'Stack overflow',
        cause: error,
        stackTrace: stackTrace,
      ),
      OutOfMemoryError() => stateFailure(
        'Out of memory',
        cause: error,
        stackTrace: stackTrace,
      ),

      // Type Failures
      TypeError() => typeFailure(
        'Type error: $error',
        cause: error,
        stackTrace: stackTrace,
      ),
      // NoSuchMethodError usually indicates a type/logic issue
      NoSuchMethodError() => typeFailure(
        'No such method: $error',
        cause: error,
        stackTrace: stackTrace,
      ),

      // Unimplemented Failures
      UnimplementedError e => unimplementedFailure(
        e.message ?? 'Feature not implemented',
        cause: error,
        stackTrace: stackTrace,
      ),

      // Unsupported Failures
      UnsupportedError e => unsupportedFailure(
        e.message ?? 'Operation not supported',
        cause: error,
        stackTrace: stackTrace,
      ),

      // Fallback
      _ => appFailureFrom(error, stackTrace ?? StackTrace.current),
    };
  }

  /// Create a server failure (v8: folded into [NetworkFailure]).
  NetworkFailure serverFailure(
    String message, {
    int? statusCode,
    Object? cause,
  }) {
    return NetworkFailure.fromTrusted(
      isRetryable: false,
      message: message,
      statusCode: statusCode,
    );
  }

  /// Create a network failure.
  NetworkFailure networkFailure(String message, {Object? cause}) {
    return NetworkFailure.fromTrusted(isRetryable: false, message: message);
  }

  /// Create a cache failure (v8: folded into [StorageFailure]).
  StorageFailure cacheFailure(String message, {Object? cause}) {
    return StorageFailure.fromTrusted(
      isRetryable: false,
      message: message,
      layer: 'cache',
    );
  }

  /// Create a validation failure (v8: [BoundaryViolationFailure]).
  BoundaryViolationFailure validationFailure(
    String message, {
    Map<String, List<String>>? fieldErrors,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return BoundaryViolationFailure.fromTrusted(
      isRetryable: false,
      message: message,
      violations: fieldErrors == null
          ? const []
          : [
              for (final entry in fieldErrors.entries)
                for (final msg in entry.value)
                  FieldViolation(
                    path: '/${ZorphyPatchWire.pointerToken(entry.key)}',
                    expected: 'string',
                    actual: msg,
                  ),
            ],
    );
  }

  /// Create a not found failure.
  NotFoundFailure notFoundFailure(
    String message, {
    String? resourceId,
    String? resourceType,
    Object? cause,
  }) {
    return NotFoundFailure.fromTrusted(
      isRetryable: false,
      message: message,
      resourceId: resourceId,
      resourceType: resourceType,
    );
  }

  /// Create an unauthorized failure (v8: [PolicyDeniedFailure]).
  PolicyDeniedFailure unauthorizedFailure(String message, {Object? cause}) {
    return PolicyDeniedFailure.fromTrusted(
      isRetryable: false,
      message: message,
      reason: 'unauthenticated',
    );
  }

  /// Create a forbidden failure (v8: [PolicyDeniedFailure]).
  PolicyDeniedFailure forbiddenFailure(
    String message, {
    String? requiredPermission,
    Object? cause,
  }) {
    return PolicyDeniedFailure.fromTrusted(
      isRetryable: false,
      message: message,
      reason: 'forbidden',
    );
  }

  /// Create a conflict failure.
  ConflictFailure conflictFailure(
    String message, {
    String? conflictType,
    Object? cause,
  }) {
    return ConflictFailure.fromTrusted(isRetryable: false, message: message);
  }

  /// Create a timeout failure.
  ///
  /// [isRetryable] matches the top-level [timeoutFailure] helper (true) so
  /// both construction sites give the same variant the same retry semantics;
  /// callers that need a non-retryable timeout pass their own failure.
  TimeoutFailure timeoutFailure(
    String message, {
    Duration? timeout,
    Object? cause,
  }) {
    return TimeoutFailure.fromTrusted(
      isRetryable: true,
      message: message,
      timeout: timeout,
    );
  }

  /// Create a cancellation failure (v8: [CancelledFailure]).
  CancelledFailure cancellationFailure([
    String message = 'Operation was cancelled',
  ]) {
    return CancelledFailure.fromTrusted(isRetryable: false, message: message);
  }

  // The legacy "unknown-ish" variants all fold into UnexpectedFailure. Delegate
  // to the top-level helper so the originating cause and stack trace survive
  // the fold; constructing fromTrusted here used to drop both.

  /// Create a platform failure (v8: folded into [UnexpectedFailure]).
  UnexpectedFailure platformFailure(
    String message, {
    String? code,
    dynamic details,
    Object? cause,
    StackTrace? stackTrace,
  }) => unexpectedFailure(
    message,
    code: code,
    details: details,
    cause: cause,
    stackTrace: stackTrace,
  );

  /// Create a state failure (v8: folded into [UnexpectedFailure]).
  UnexpectedFailure stateFailure(
    String message, {
    Object? cause,
    StackTrace? stackTrace,
  }) => unexpectedFailure(message, cause: cause, stackTrace: stackTrace);

  /// Create a type failure (v8: folded into [UnexpectedFailure]).
  UnexpectedFailure typeFailure(
    String message, {
    Object? cause,
    StackTrace? stackTrace,
  }) => unexpectedFailure(message, cause: cause, stackTrace: stackTrace);

  /// Create an unimplemented failure (v8: folded into [UnexpectedFailure]).
  UnexpectedFailure unimplementedFailure(
    String message, {
    Object? cause,
    StackTrace? stackTrace,
  }) => unexpectedFailure(message, cause: cause, stackTrace: stackTrace);

  /// Create an unsupported failure (v8: folded into [UnexpectedFailure]).
  UnexpectedFailure unsupportedFailure(
    String message, {
    Object? cause,
    StackTrace? stackTrace,
  }) => unexpectedFailure(message, cause: cause, stackTrace: stackTrace);

  /// Create an unknown failure (v8: folded into [UnexpectedFailure]).
  UnexpectedFailure unknownFailure(
    String message, {
    Object? cause,
    StackTrace? stackTrace,
  }) => unexpectedFailure(message, cause: cause, stackTrace: stackTrace);

  /// Log an error and convert it to a failure
  ///
  /// This is a convenience method that logs the error at SEVERE level
  /// and then converts it to an AppFailure.
  AppFailure logAndHandleError(Object error, [StackTrace? stackTrace]) {
    final failure = handleError(error, stackTrace);
    logger.severe('Error occurred: $failure', error, stackTrace);
    FailureReporterRegistry.instance.reportFailure(
      failure,
      stackTrace: stackTrace,
    );
    return failure;
  }
}

// ── Pure-Dart platform exception replacements ──────────────────────────
// These mirror the Flutter services.dart exceptions so that failure_handler
// works without any Flutter SDK dependency.

/// Platform-native exception replacement (mirrors flutter/services.dart).
class ZuraffaPlatformException implements Exception {
  final String code;
  final String? message;
  final dynamic details;
  const ZuraffaPlatformException({
    required this.code,
    this.message,
    this.details,
  });
  @override
  String toString() =>
      'ZuraffaPlatformException($code, $message: ${details ?? ''})';
}

/// Missing-plugin exception replacement (mirrors flutter/services.dart).
class ZuraffaMissingPluginException implements Exception {
  final String? message;
  const ZuraffaMissingPluginException([this.message]);
  @override
  String toString() =>
      'ZuraffaMissingPluginException(${message ?? 'plugin not found'})';
}
