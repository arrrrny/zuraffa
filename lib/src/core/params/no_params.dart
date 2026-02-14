/// A sentinel class for UseCases that don't require parameters.
///
/// Use [NoParams] when your UseCase doesn't need any input parameters.
/// This provides a more explicit and type-safe alternative to using `void` or `null`.
///
/// Example:
/// ```dart
/// class GetAllUsersUseCase extends UseCase<List<User>, NoParams> {
///   @override
///   Future<List<User>> execute(NoParams params, CancelToken? cancelToken) async {
///     return repository.getAllUsers();
///   }
/// }
///
/// // Usage
/// final result = await getAllUsersUseCase(const NoParams());
/// ```
class NoParams {
  /// Create a [NoParams] instance
  const NoParams();

  /// Creates a copy of this [NoParams] instance.
  ///
  /// Since [NoParams] has no state, this simply returns a new instance
  /// (or the same one if using const).
  NoParams copyWith() => const NoParams();

  @override
  String toString() => 'NoParams';

  @override
  bool operator ==(Object other) => other is NoParams;

  @override
  int get hashCode => 0;
}
