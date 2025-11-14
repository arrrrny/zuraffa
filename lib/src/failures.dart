/// Base failure class for Clean Architecture
///
/// All failures in the domain layer extend this
sealed class AppFailure {
  final String message;
  final StackTrace? stackTrace;

  const AppFailure(this.message, {this.stackTrace});

  @override
  String toString() => '$runtimeType: $message';
}

/// Server-related failures (5xx errors)
final class ServerFailure extends AppFailure {
  final int? statusCode;

  const ServerFailure(super.message, {this.statusCode, super.stackTrace});

  @override
  String toString() => 'ServerFailure($statusCode): $message';
}

/// Network-related failures (connection issues)
final class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {super.stackTrace});
}

/// Cache-related failures (local storage issues)
final class CacheFailure extends AppFailure {
  const CacheFailure(super.message, {super.stackTrace});
}

/// Validation failures (bad input)
final class ValidationFailure extends AppFailure {
  final Map<String, String>? errors;

  const ValidationFailure(super.message, {this.errors, super.stackTrace});

  @override
  String toString() => 'ValidationFailure: $message${errors != null ? ' - $errors' : ''}';
}

/// Not found failures (404)
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure(super.message, {super.stackTrace});
}

/// Unauthorized failures (401, 403)
final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure(super.message, {super.stackTrace});
}

/// Generic failures (catch-all)
final class GenericFailure extends AppFailure {
  const GenericFailure(super.message, {super.stackTrace});
}

/// Extension to convert exceptions to failures
extension ExceptionToFailure on Exception {
  AppFailure toFailure() {
    final message = toString();

    // You can add more sophisticated parsing here
    if (message.contains('SocketException') ||
        message.contains('Connection') ||
        message.contains('Network')) {
      return NetworkFailure(message);
    }

    return GenericFailure(message);
  }
}
