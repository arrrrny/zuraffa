import '../module/interceptor.dart';
import '../signals/signal_result.dart';
import '../usecase/zuraffa_usecase.dart';
import '../context/zuraffa_context.dart';

/// A [ZuraffaUseCase] subclass that supports interceptor pipeline
/// integration.
///
/// [InterceptableUseCase] wraps the abstract [call] method with an
/// interceptor chain from an [InterceptorRegistry]. Subclasses implement
/// [executeCall] instead of [call]; the [call] method automatically
/// runs the interceptor chain before/around the actual execution.
///
/// ## How interception works with SignalResult
///
/// Because [ZuraffaUseCase.call] returns [SignalResult] (not a Future),
/// interception cannot `await` the result inside the interceptor.
/// Instead, the interceptor chain wraps the *creation* of the
/// [SignalResult]. Interceptors can:
///
/// - **Observe** by subscribing to the returned [SignalResult]
///   via `onSuccess`/`onFailure` (fire-and-forget, like the Hook system).
/// - **Short-circuit** by returning a pre-built [SignalResult.success]
///   or [SignalResult.failure] instead of calling `next`.
/// - **Transform** by calling `next`, then using `map` on the
///   resulting [SignalResult] to transform the success value.
///
/// ## Usage
///
/// ```dart
/// class GetProductUseCase extends InterceptableUseCase<String, Product> {
///   final ProductRepository _repo;
///   GetProductUseCase(this._repo);
///
///   @override
///   SignalResult<Product> executeCall(
///     String params, {
///     ZuraffaContext? context,
///   }) {
///     return SignalResult.fromFuture(_repo.getById(params));
///   }
/// }
/// ```
///
/// ## Backward compatibility
///
/// Existing [ZuraffaUseCase] subclasses that do not need interception
/// can continue to extend [ZuraffaUseCase] directly. [InterceptableUseCase]
/// is opt-in.
abstract class InterceptableUseCase<In, Out> extends ZuraffaUseCase<In, Out> {
  /// The interceptor registry to consult before executing.
  ///
  /// When null, the use case behaves identically to a plain
  /// [ZuraffaUseCase] (no interception overhead).
  final InterceptorRegistry? interceptorRegistry;

  /// Creates an [InterceptableUseCase] with an optional [interceptorRegistry].
  const InterceptableUseCase({this.interceptorRegistry});

  @override
  SignalResult<Out> call(In params, {ZuraffaContext? context}) {
    final registry = interceptorRegistry;
    if (registry == null || registry.isEmpty) {
      return executeCall(params, context: context);
    }

    // Build the interceptor chain with executeCall as the tail.
    final pipeline = registry.chain<In, Out>(
      (In request) => executeCall(request, context: context),
    );

    return pipeline(params);
  }

  /// Implement this with the actual use case logic.
  ///
  /// This is called by [call] after running the interceptor chain.
  /// The [context] is forwarded from the original [call] invocation.
  SignalResult<Out> executeCall(In params, {ZuraffaContext? context});
}
