import 'package:zuraffa/zuraffa.dart';

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
part 'no_params.zorphy.dart';

@zorphy
abstract class $NoParams {
  /// Create a [NoParams] instance
  const $NoParams();
}
