import 'result.dart';
import 'failures.dart';

/// Base class for all use cases
///
/// Type parameters:
/// - [Type]: The return type of the use case
/// - [Params]: The input parameters for the use case
abstract class UseCase<Type, Params> {
  /// Execute the use case
  Future<Result<Type, AppFailure>> execute(Params params);
}

/// Use case with no parameters
abstract class NoParamsUseCase<Type> {
  /// Execute the use case
  Future<Result<Type, AppFailure>> execute();
}

/// Marker class for use cases with no parameters
class NoParams {
  const NoParams();
}
