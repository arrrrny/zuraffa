import 'dart:async';
import 'package:flutter/services.dart';

import 'package:zuraffa/zuraffa.dart';

import '../core/loggable.dart';

import 'failure.dart';

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
      IndexError e => validationFailure(
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
      PlatformException e => platformFailure(
          e.message ?? 'Platform error occurred',
          code: e.code,
          details: e.details,
          cause: error,
        ),
      MissingPluginException e => unsupportedFailure(
          e.message ?? 'Plugin not found',
          cause: error,
        ),

      // State Failures
      StateError e => stateFailure(e.message, cause: error),
      ConcurrentModificationError() => stateFailure(
          'Concurrent modification detected',
          cause: error,
        ),
      StackOverflowError() => stateFailure(
          'Stack overflow',
          cause: error,
        ),
      OutOfMemoryError() => stateFailure(
          'Out of memory',
          cause: error,
        ),

      // Type Failures
      TypeError() => typeFailure(
          'Type error: $error',
          cause: error,
        ),
      // NoSuchMethodError usually indicates a type/logic issue
      NoSuchMethodError() => typeFailure(
          'No such method: $error',
          cause: error,
        ),

      // Unimplemented Failures
      UnimplementedError e => unimplementedFailure(
          e.message ?? 'Feature not implemented',
          cause: error,
        ),

      // Unsupported Failures
      UnsupportedError e => unsupportedFailure(
          e.message ?? 'Operation not supported',
          cause: error,
        ),

      // Fallback
      _ => AppFailure.from(error, stackTrace ?? StackTrace.current),
    };
  }

  /// Create a server failure
  ///
  /// Use when the server returns an error status code (500-599)
  /// or when the server response indicates an internal error.
  ServerFailure serverFailure(
    String message, {
    int? statusCode,
    Object? cause,
  }) {
    return ServerFailure(
      message,
      statusCode: statusCode,
      stackTrace: StackTrace.current,
      cause: cause,
    );
  }

  /// Create a network failure
  ///
  /// Use when there are connection issues, DNS failures,
  /// or the device is offline.
  NetworkFailure networkFailure(String message, {Object? cause}) {
    return NetworkFailure(
      message,
      stackTrace: StackTrace.current,
      cause: cause,
    );
  }

  /// Create a cache failure
  ///
  /// Use when there are issues reading from or writing to local storage,
  /// or when cached data is corrupted or expired.
  CacheFailure cacheFailure(String message, {Object? cause}) {
    return CacheFailure(message, stackTrace: StackTrace.current, cause: cause);
  }

  /// Create a validation failure
  ///
  /// Use when input data fails validation rules.
  /// Optionally includes field-specific error messages.
  ValidationFailure validationFailure(
    String message, {
    Map<String, List<String>>? fieldErrors,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return ValidationFailure(
      message,
      fieldErrors: fieldErrors,
      stackTrace: stackTrace ?? StackTrace.current,
      cause: cause,
    );
  }

  /// Create a not found failure
  ///
  /// Use when a requested resource does not exist.
  NotFoundFailure notFoundFailure(
    String message, {
    String? resourceId,
    String? resourceType,
    Object? cause,
  }) {
    return NotFoundFailure(
      message,
      resourceId: resourceId,
      resourceType: resourceType,
      stackTrace: StackTrace.current,
      cause: cause,
    );
  }

  /// Create an unauthorized failure
  ///
  /// Use when authentication is required but missing or invalid.
  /// The user needs to login or refresh their credentials.
  UnauthorizedFailure unauthorizedFailure(String message, {Object? cause}) {
    return UnauthorizedFailure(
      message,
      stackTrace: StackTrace.current,
      cause: cause,
    );
  }

  /// Create a forbidden failure
  ///
  /// Use when the user is authenticated but lacks permission
  /// to access the requested resource.
  ForbiddenFailure forbiddenFailure(
    String message, {
    String? requiredPermission,
    Object? cause,
  }) {
    return ForbiddenFailure(
      message,
      requiredPermission: requiredPermission,
      stackTrace: StackTrace.current,
      cause: cause,
    );
  }

  /// Create a conflict failure
  ///
  /// Use when the request conflicts with the current state of the resource,
  /// such as duplicate entries or version conflicts.
  ConflictFailure conflictFailure(
    String message, {
    String? conflictType,
    Object? cause,
  }) {
    return ConflictFailure(
      message,
      conflictType: conflictType,
      stackTrace: StackTrace.current,
      cause: cause,
    );
  }

  /// Create a timeout failure
  ///
  /// Use when an operation takes too long to complete.
  TimeoutFailure timeoutFailure(
    String message, {
    Duration? timeout,
    Object? cause,
  }) {
    return TimeoutFailure(
      message,
      timeout: timeout,
      stackTrace: StackTrace.current,
      cause: cause,
    );
  }

  /// Create a cancellation failure
  ///
  /// Use when an operation is explicitly cancelled by the user or system.
  /// This is typically not shown as an error to the user.
  CancellationFailure cancellationFailure([
    String message = 'Operation was cancelled',
  ]) {
    return CancellationFailure(message);
  }

  /// Create a platform failure
  ///
  /// Use when a platform-specific error occurs.
  PlatformFailure platformFailure(
    String message, {
    String? code,
    dynamic details,
    Object? cause,
  }) {
    return PlatformFailure(
      message,
      code: code,
      details: details,
      stackTrace: StackTrace.current,
      cause: cause,
    );
  }

  /// Create a state failure
  ///
  /// Use when the application is in an invalid state.
  StateFailure stateFailure(String message, {Object? cause}) {
    return StateFailure(
      message,
      stackTrace: StackTrace.current,
      cause: cause,
    );
  }

  /// Create a type failure
  ///
  /// Use when a value has an unexpected type.
  TypeFailure typeFailure(String message, {Object? cause}) {
    return TypeFailure(
      message,
      stackTrace: StackTrace.current,
      cause: cause,
    );
  }

  /// Create an unimplemented failure
  ///
  /// Use when a feature is not implemented.
  UnimplementedFailure unimplementedFailure(String message, {Object? cause}) {
    return UnimplementedFailure(
      message,
      stackTrace: StackTrace.current,
      cause: cause,
    );
  }

  /// Create an unsupported failure
  ///
  /// Use when an operation is not supported.
  UnsupportedFailure unsupportedFailure(String message, {Object? cause}) {
    return UnsupportedFailure(
      message,
      stackTrace: StackTrace.current,
      cause: cause,
    );
  }

  /// Create an unknown failure
  ///
  /// Use as a fallback when the error type cannot be determined.
  /// Prefer using more specific failure types when possible.
  UnknownFailure unknownFailure(String message, {Object? cause}) {
    return UnknownFailure(
      message,
      stackTrace: StackTrace.current,
      cause: cause,
    );
  }

  /// Log an error and convert it to a failure
  ///
  /// This is a convenience method that logs the error at SEVERE level
  /// and then converts it to an AppFailure.
  AppFailure logAndHandleError(
    Object error, [
    StackTrace? stackTrace,
  ]) {
    final failure = handleError(error, stackTrace);
    logger.severe(
      'Error occurred: $failure',
      error,
      stackTrace,
    );
    return failure;
  }
}
