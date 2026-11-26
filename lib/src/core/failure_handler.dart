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
      IndexError() => AppFailure.boundaryViolation(
        message: 'Index out of bounds',
        violations: [
          FieldViolation(
            path: '/index',
            expected: 'within bounds',
            actual: error.toString(),
          ),
        ],
      ),
      RangeError e => AppFailure.boundaryViolation(
        message: 'Value out of range: ${e.message}',
        violations: [
          FieldViolation(
            path: '/value',
            expected: e.start == null || e.end == null
                ? 'in range'
                : 'in [${e.start}, ${e.end})',
            actual: e.invalidValue.toString(),
          ),
        ],
      ),
      ArgumentError e => AppFailure.boundaryViolation(
        message: e.message.toString(),
        violations: [
          FieldViolation(
            path: e.name == null ? '/' : '/${ZorphyPatchWire.pointerToken(e.name!)}',
            expected: 'valid argument',
            actual: e.invalidValue?.toString() ?? 'null',
          ),
        ],
      ),
      FormatException e => AppFailure.boundaryViolation(
        message: e.message,
        violations: [
          FieldViolation(
            path: '/source',
            expected: 'parseable input',
            actual: e.source?.toString() ?? 'null',
          ),
        ],
      ),

      // Timeout Failures
      TimeoutException e => AppFailure.timeout(
        message: e.message ?? 'Operation timed out',
        timeout: e.duration,
      ),

      // Cancellation Failures
      CancelledException e => AppFailure.cancelled(message: e.message),

      // Platform Failures — a platform channel error carries a code; the
      // native payload is diagnostic and is folded into the cause.
      ZuraffaPlatformException e => AppFailure.unexpected(
        message: e.message ?? 'Platform error occurred',
        code: e.code,
        cause: e.details?.toString(),
        stackTrace: stackTrace?.toString(),
      ),
      ZuraffaMissingPluginException e => AppFailure.unexpected(
        message: e.message ?? 'Plugin not found',
        code: 'missing_plugin',
        cause: error.toString(),
        stackTrace: stackTrace?.toString(),
      ),

      // State Failures
      StateError e => AppFailure.unexpected(
        message: e.message,
        cause: error.toString(),
        stackTrace: stackTrace?.toString(),
      ),
      ConcurrentModificationError() => AppFailure.unexpected(
        message: 'Concurrent modification detected',
        cause: error.toString(),
        stackTrace: stackTrace?.toString(),
      ),
      StackOverflowError() => AppFailure.unexpected(
        message: 'Stack overflow',
        cause: error.toString(),
        stackTrace: stackTrace?.toString(),
      ),
      OutOfMemoryError() => AppFailure.unexpected(
        message: 'Out of memory',
        cause: error.toString(),
        stackTrace: stackTrace?.toString(),
      ),

      // Type Failures
      TypeError() => AppFailure.unexpected(
        message: 'Type error: $error',
        cause: error.toString(),
        stackTrace: stackTrace?.toString(),
      ),
      // NoSuchMethodError usually indicates a type/logic issue
      NoSuchMethodError() => AppFailure.unexpected(
        message: 'No such method: $error',
        cause: error.toString(),
        stackTrace: stackTrace?.toString(),
      ),

      // Unimplemented Failures
      UnimplementedError e => AppFailure.unexpected(
        message: e.message ?? 'Feature not implemented',
        code: 'unimplemented',
        cause: error.toString(),
        stackTrace: stackTrace?.toString(),
      ),

      // Unsupported Failures
      UnsupportedError e => AppFailure.unexpected(
        message: e.message ?? 'Operation not supported',
        code: 'unsupported',
        cause: error.toString(),
        stackTrace: stackTrace?.toString(),
      ),

      // Fallback
      _ => AppFailure.from(error, stackTrace ?? StackTrace.current),
    };
  }

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
