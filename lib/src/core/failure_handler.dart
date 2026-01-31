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
    if (error is ArgumentError) {
      return validationFailure(
        error.message.toString(),
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return AppFailure.from(error, stackTrace ?? StackTrace.current);
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
