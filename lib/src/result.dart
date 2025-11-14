/// Result pattern for Clean Architecture
///
/// Represents either a success (Right) or failure (Left)
/// Inspired by functional programming's Either type
sealed class Result<S, F> {
  const Result();

  /// Check if result is success
  bool get isSuccess => this is Success<S, F>;

  /// Check if result is failure
  bool get isFailure => this is Failure<S, F>;

  /// Get success value (throws if failure)
  S get value => (this as Success<S, F>).value;

  /// Get failure value (throws if success)
  F get error => (this as Failure<S, F>).error;

  /// Fold the result into a single value
  T fold<T>(
    T Function(F failure) onFailure,
    T Function(S success) onSuccess,
  ) {
    return switch (this) {
      Success(:final value) => onSuccess(value),
      Failure(:final error) => onFailure(error),
    };
  }

  /// Map the success value
  Result<T, F> map<T>(T Function(S) transform) {
    return switch (this) {
      Success(:final value) => Success(transform(value)),
      Failure(:final error) => Failure(error),
    };
  }

  /// FlatMap for chaining operations
  Result<T, F> flatMap<T>(Result<T, F> Function(S) transform) {
    return switch (this) {
      Success(:final value) => transform(value),
      Failure(:final error) => Failure(error),
    };
  }

  /// Get value or default
  S getOrElse(S Function() defaultValue) {
    return switch (this) {
      Success(:final value) => value,
      Failure() => defaultValue(),
    };
  }

  /// Get value or null
  S? getOrNull() {
    return switch (this) {
      Success(:final value) => value,
      Failure() => null,
    };
  }
}

/// Success case of Result
final class Success<S, F> extends Result<S, F> {
  final S value;

  const Success(this.value);

  @override
  String toString() => 'Success($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Failure case of Result
final class Failure<S, F> extends Result<S, F> {
  final F error;

  const Failure(this.error);

  @override
  String toString() => 'Failure($error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure && runtimeType == other.runtimeType && error == other.error;

  @override
  int get hashCode => error.hashCode;
}
