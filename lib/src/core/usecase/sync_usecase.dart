import 'package:meta/meta.dart';
import 'package:zorphy_annotation/zorphy_annotation.dart' show ZorphyIntentBase;

import '../cancel_token.dart';
import '../context/cancellation_token.dart';
import '../context/zfa_context.dart';
import '../failure.dart';
import '../result.dart';

/// The v8 synchronous use case archetype.
///
/// A [SyncUseCase] is a single business operation that returns immediately
/// without awaiting — validation, calculation, or a pure transformation. It
/// takes a typed [ZorphyIntentBase] intent and a [ZfaContext] and returns a
/// [Result] carrying either the output or an [AppFailure].
///
/// Cancellation is cooperative: [execute] checks [ZfaContext.throwIfCancelled]
/// at its own checkpoints. A thrown [CancellationTokenException] — or a legacy
/// [CancelledException] — is translated into a cancelled [AppFailure].
///
/// ## Example
///
/// ```dart
/// class ValidateUseCase extends SyncUseCase<ValidateIntent, bool> {
///   @override
///   Result<bool, AppFailure> execute(ValidateIntent intent, ZfaContext ctx) {
///     return Result.success(intent.email.contains('@'));
///   }
/// }
/// ```
abstract class SyncUseCase<I extends ZorphyIntentBase, O> {
  /// Creates a synchronous use case.
  const SyncUseCase();

  /// Execute [intent] under [ctx] and wrap the outcome in a [Result].
  ///
  /// Returns a [Result.success] with [execute]'s output, or a
  /// [Result.failure] carrying an [AppFailure]. Cancellation and unexpected
  /// throws are funnelled onto the same [Result.failure] channel.
  Result<O, AppFailure> call(I intent, ZfaContext ctx) {
    try {
      ctx.throwIfCancelled();
      return execute(intent, ctx);
    } on CancellationTokenException catch (e) {
      return Result.failure(
        AppFailure.cancelled(message: e.reason ?? 'Operation was cancelled'),
      );
    } on CancelledException catch (e) {
      return Result.failure(AppFailure.cancelled(message: e.message));
    } on AppFailure catch (failure) {
      return Result.failure(failure);
    } catch (e, stackTrace) {
      return Result.failure(AppFailure.from(e, stackTrace));
    }
  }

  /// Override this to implement the synchronous use case logic.
  ///
  /// Return a [Result.success] with the output, a [Result.failure] with an
  /// expected [AppFailure], or throw — an [AppFailure] is passed through, a
  /// cancellation becomes a cancelled failure, and anything else is classified
  /// through [AppFailure.from].
  @protected
  Result<O, AppFailure> execute(I intent, ZfaContext ctx);
}
