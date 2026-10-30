import 'dart:async';

import 'failure.dart';
import 'trace_observer.dart';

// ---------------------------------------------------------------------------
// HookPhase
// ---------------------------------------------------------------------------

/// Which phase of UseCase execution triggered this hook.
///
/// - [pre] fires before `execute()` is called.
/// - [success] fires after `execute()` completed successfully.
/// - [failure] fires after `execute()` threw an error.
enum HookPhase { pre, success, failure }

/// What a blocking hook's failure means for the UseCase
/// (see [Hook.blocking], [Hook.onError]).
///
/// - [continue_] — log and proceed. The default: the hook must never cost
///   the UseCase its result. An ordering-critical side effect that failed
///   is the hook's own problem to retry or escalate.
/// - [veto] — proceed no further: `UseCase.call` returns
///   `Failure(hookFailure)` WITHOUT running `execute`. Use when the UseCase's
///   result is only valid if the hook ran first (e.g. a result that must not
///   be published before an ordering-critical side effect has landed).
enum HookErrorPolicy { continue_, veto }

// ---------------------------------------------------------------------------
// HookContext
// ---------------------------------------------------------------------------

/// Immutable context passed to every hook during UseCase execution.
///
/// Contains everything a hook needs to decide whether to act and how.
/// The [metadata] map is mutable and shared by reference across all three
/// phases of a single UseCase invocation. Hooks can write values in the
/// `pre` phase and read them back in `success` or `failure`.
///
/// ## Example
///
/// ```dart
/// class MyHook extends Hook {
///   @override
///   String get id => 'my-hook';
///
///   @override
///   Future<void> execute(HookContext context, HookPhase phase) async {
///     switch (phase) {
///       case HookPhase.pre:
///         context.metadata['_start'] = DateTime.now();
///       case HookPhase.success:
///         final start = context.metadata['_start'] as DateTime;
///         print('${context.useCaseName} took ${DateTime.now().difference(start)}');
///       case HookPhase.failure:
///         print('${context.useCaseName} failed: ${context.failure}');
///     }
///   }
/// }
/// ```
class HookContext {
  /// Runtime type of the UseCase (e.g. `'GetDealListUseCase'`).
  final String useCaseName;

  /// The input parameters passed to the UseCase.
  ///
  /// **This is the only view of the UseCase's input a hook gets** — if the
  /// data a hook needs to match on is not carried by the params object (e.g.
  /// a row label that lives on the persisted entity, not in
  /// `CompleteTaskParams`), the hook must look the entity up itself. There
  /// is deliberately no framework-side entity access: hooks match cheaply
  /// on what [params] carries and fetch anything deeper on their own.
  final Object? params;

  /// The successful result (only set in the `success` phase).
  final Object? result;

  /// The failure (only set in the `failure` phase).
  final AppFailure? failure;

  /// Execution duration (null in the `pre` phase).
  final Duration? duration;

  /// When the UseCase was invoked.
  final DateTime timestamp;

  /// W3C trace ID from the active OTel span (if configured).
  final String? traceId;

  /// W3C span ID from the active OTel span (if configured).
  final String? spanId;

  /// Mutable shared metadata bag for cross-phase data.
  ///
  /// Hooks can write values in `pre` and read them in `success` or `failure`.
  /// Each hook should use a namespaced key (e.g. `'_otel_span'`) to avoid
  /// collisions with other hooks.
  final Map<String, dynamic> metadata;

  /// Creates a new hook context.
  ///
  /// [metadata] defaults to an empty map if not provided.
  HookContext({
    required this.useCaseName,
    required this.timestamp,
    this.params,
    this.result,
    this.failure,
    this.duration,
    this.traceId,
    this.spanId,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};

  /// Convenience: cast [params] to expected type.
  P paramsAs<P>() => params as P;

  /// Convenience: cast [result] to expected type.
  R resultAs<R>() => result as R;

  @override
  String toString() =>
      'HookContext(useCase: $useCaseName, duration: $duration, '
      'hasResult: ${result != null}, hasFailure: ${failure != null})';
}

// ---------------------------------------------------------------------------
// Hook
// ---------------------------------------------------------------------------

/// Base class for all Zuraffa hooks.
///
/// A hook intercepts UseCase execution at one or more phases (pre, success,
/// failure) and performs arbitrary side effects: telemetry, engagement
/// tracking, audit logging, performance monitoring, etc.
///
/// Hooks are **fire-and-forget by default**: they must never throw (errors
/// are caught and logged by [HookRegistry]) and they never block the calling
/// UseCase. That is the right contract for observers (telemetry, engagement,
/// audit) and the wrong one for **ordering-critical side effects** — a hook
/// that must complete BEFORE the UseCase's work lands. Such a hook opts in
/// to blocking semantics in the `pre` phase via [blocking] (honored only in
/// `pre`; `success`/`failure` dispatch always stays fire-and-forget): the
/// classic `UseCase.call` awaits it to completion before `execute` begins,
/// with a per-hook abandonment timeout ([blockingTimeout]) and error policy
/// ([onError]). See [HookErrorPolicy] for what a blocking hook's failure
/// means for the UseCase.
///
/// ## Built-in Hook
///
/// - [TelemetryHook] — auto-wraps every UseCase in an OTel span.
///
/// ## Custom Hook Example
///
/// ```dart
/// class SlowOperationAlertHook extends Hook {
///   @override
///   String get id => 'slow-op-alert';
///
///   @override
///   Set<HookPhase> get phases => {HookPhase.success};
///
///   @override
///   Future<void> execute(HookContext context, HookPhase phase) async {
///     if (context.duration != null && context.duration!.inSeconds > 2) {
///       await alertService.notify(
///         '${context.useCaseName} took ${context.duration!.inMilliseconds}ms',
///       );
///     }
///   }
/// }
/// ```
abstract class Hook {
  /// Unique identifier for this hook.
  String get id;

  /// Priority order for execution (lower runs first).
  ///
  /// Defaults to `0`. Use negative values for hooks that must run before
  /// others (e.g., a tracing hook that sets up context), positive for hooks
  /// that depend on earlier hooks' side effects.
  int get priority => 0;

  /// Which phases this hook should fire on.
  ///
  /// Override to limit which phases your hook cares about.
  /// Default: all three phases.
  Set<HookPhase> get phases => const {
    HookPhase.pre,
    HookPhase.success,
    HookPhase.failure,
  };

  /// Whether this hook should fire for the given context + phase.
  ///
  /// Override to filter by UseCase name, params type, duration, etc.
  /// This is checked before [execute] is called.
  bool shouldTrigger(HookContext context, HookPhase phase) => true;

  /// The hook's execution logic.
  ///
  /// **Must be resilient** — exceptions are caught and logged by the
  /// [HookRegistry] but won't stop other hooks or the UseCase from running
  /// (unless the hook opts into [HookErrorPolicy.veto] via [onError] while
  /// [blocking]).
  Future<void> execute(HookContext context, HookPhase phase);

  /// Whether `UseCase.call` must AWAIT this hook to completion (in the `pre`
  /// phase only) before the UseCase's `execute` begins.
  ///
  /// Default `false` — today's fire-and-forget behavior, unchanged. Set
  /// `true` only for **ordering-critical** side effects whose completion is
  /// a precondition of the UseCase's work (e.g. an egress-proxy rotation
  /// that must finish before a task status write lands). Telemetry and
  /// engagement observers must NOT block.
  ///
  /// Honored ONLY in the `pre` phase of the classic `UseCase`: `success` and
  /// `failure` dispatch stays fire-and-forget regardless of this flag.
  bool get blocking => false;

  /// How long a [blocking] run may take before the registry abandons it and
  /// proceeds (the hook's own child processes remain its responsibility to
  /// kill — the registry timeout is the backstop, NOT the reaper: this is
  /// abandonment, not cancellation; the hook's future keeps running to
  /// completion). `null` — the default — means no timeout.
  Duration? get blockingTimeout => null;

  /// What this hook's failure means for the UseCase when [blocking].
  ///
  /// - [HookErrorPolicy.continue_] (default): log and proceed — the UseCase
  ///   keeps its result.
  /// - [HookErrorPolicy.veto]: `UseCase.call` returns
  ///   `Failure(hookFailure)` without running `execute`. Applies to a
  ///   [blockingTimeout] abandonment too: a vetoed hook that never completed
  ///   must not land the result.
  HookErrorPolicy get onError => HookErrorPolicy.continue_;

  @override
  String toString() =>
      'Hook($id, priority: $priority, phases: $phases, blocking: $blocking)';
}

/// Thrown by [HookRegistry.dispatchAwaited] when a blocking hook with
/// [HookErrorPolicy.veto] fails (or is abandoned at its
/// [Hook.blockingTimeout]).
///
/// `UseCase.call` catches it and returns `Failure([failure])` WITHOUT
/// running `execute` and without dispatching the `success`/`failure` phases
/// — a veto proceeds no further.
class HookVetoException implements Exception {
  /// The hook's failure, wrapped for the classic `Result<T, AppFailure>`
  /// contract. An [AppFailure] thrown by the hook passes through as-is;
  /// anything else is wrapped via [AppFailure.from].
  final AppFailure failure;

  /// The [Hook.id] of the vetoing hook.
  final String hookId;

  /// The original error thrown by (or the [TimeoutException] abandoning)
  /// the hook, for diagnostics.
  final Object? originalError;

  /// The original stack trace, for diagnostics.
  final StackTrace? originalStack;

  /// Creates a veto signal for [hookId] carrying [failure].
  HookVetoException({
    required this.failure,
    required this.hookId,
    this.originalError,
    this.originalStack,
  });

  @override
  String toString() =>
      'HookVetoException(hook: $hookId, failure: ${failure.message})';
}

// ---------------------------------------------------------------------------
// Re-export for convenience
// ---------------------------------------------------------------------------

/// Captures the active OTel trace/span context at the current call site.
///
/// Used by [UseCase.call()] and [StreamUseCase.call()] when constructing
/// [HookContext] instances. Returns `null` values when OTel is not configured.
({String? traceId, String? spanId}) captureTraceContext() {
  return (
    traceId: TraceObserver.instance.currentTraceId,
    spanId: TraceObserver.instance.currentSpanId,
  );
}
