import 'package:meta/meta.dart';
import '../core/result.dart';
import '../core/failure.dart';

/// Base class for synchronous UseCases that return immediately without async.
///
/// Use this for operations that don't require asynchronous processing,
/// such as validation, calculations, or data transformations.
///
/// ## Example
/// ```dart
/// class ValidateEmailUseCase extends SyncUseCase<bool, String> {
///   @override
///   bool execute(String email) {
///     return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
///   }
/// }
///
/// // Usage
/// final validateEmail = ValidateEmailUseCase();
/// final result = validateEmail('user@example.com');
/// result.fold(
///   (isValid) => print('Email is valid: $isValid'),
///   (failure) => print('Validation failed: $failure'),
/// );
/// ```
abstract class SyncUseCase<T, Params> {
  /// Execute the UseCase synchronously.
  ///
  /// This method should contain the business logic and return the result
  /// immediately without any async operations.
  @protected
  T execute(Params params);

  /// Call the UseCase and wrap the result in a [Result].
  ///
  /// This method handles exceptions and converts them to [AppFailure]s.
  Result<T, AppFailure> call(Params params) {
    try {
      final result = execute(params);
      return Result.success(result);
    } catch (e, stackTrace) {
      final failure = _handleException(e, stackTrace);
      return Result.failure(failure);
    }
  }

  AppFailure _handleException(Object error, StackTrace stackTrace) {
    if (error is AppFailure) {
      return error;
    }

    // Convert common exceptions to appropriate failures
    if (error is ArgumentError) {
      return ValidationFailure(
        error.message?.toString() ?? 'Invalid argument',
        stackTrace: stackTrace,
        cause: error,
      );
    }

    if (error is StateError) {
      return ValidationFailure(
        error.message,
        stackTrace: stackTrace,
        cause: error,
      );
    }

    // Default to UnknownFailure for unexpected exceptions
    return UnknownFailure(
      error.toString(),
      stackTrace: stackTrace,
      cause: error,
    );
  }
}
