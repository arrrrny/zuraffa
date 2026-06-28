import 'dart:async';

import 'failure.dart';
import 'otel_tracer.dart';

// ---------------------------------------------------------------------------
// HookPhase
// ---------------------------------------------------------------------------

/// Which phase of UseCase execution triggered this hook.
///
/// - [pre] fires before `execute()` is called.
/// - [success] fires after `execute()` completed successfully.
/// - [failure] fires after `execute()` threw an error.
enum HookPhase { pre, success, failure }

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
/// Hooks are **fire-and-forget**: they must never throw (errors are caught
/// and logged by [HookRegistry]) and they never block the calling UseCase.
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
  /// [HookRegistry] but won't stop other hooks or the UseCase from running.
  Future<void> execute(HookContext context, HookPhase phase);

  @override
  String toString() => 'Hook($id, priority: $priority, phases: $phases)';
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
    traceId: OtelTracer.instance.currentTraceId,
    spanId: OtelTracer.instance.currentSpanId,
  );
}
