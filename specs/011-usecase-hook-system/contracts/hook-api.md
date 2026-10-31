# Public API Contract: UseCase Hook System

**Feature**: 011-usecase-hook-system
**Date**: 2026-06-28
**Updated**: 2026-10-30 — blocking (awaited) `pre` hooks, issue #2032

## Zuraffa Facade API

New static methods on the `Zuraffa` class:

```dart
/// Register a generic hook.
static void registerHook(Hook hook);

/// Unregister a hook by ID.
static void unregisterHook(String id);

/// Global enable/disable for all hooks (GDPR compliance, debug mode).
static set hooksEnabled(bool value);
```

### Usage

```dart
void main() async {
  // Register built-in telemetry hook
  Zuraffa.registerHook(TelemetryHook());

  // Register app-specific hooks
  Zuraffa.registerHook(EngagementHook(repository));

  // Disable all hooks (e.g., user opted out of analytics)
  // Zuraffa.hooksEnabled = false;

  runApp(MyApp());
}
```

---

## Core Types

### HookPhase

```dart
/// Which phase of UseCase execution triggered this hook.
enum HookPhase {
  pre,       // Before execute() is called
  success,   // After execute() completed successfully
  failure,   // After execute() threw an AppFailure
}
```

### HookContext

```dart
/// Immutable context passed to every hook during UseCase execution.
///
/// The [metadata] map is mutable and shared by reference across all three
/// phases of a single UseCase invocation. Hooks can write values in `pre`
/// and read them in `success` or `failure`.
class HookContext {
  final String useCaseName;
  final Object? params;
  final Object? result;
  final AppFailure? failure;
  final Duration? duration;
  final DateTime timestamp;
  final String? traceId;
  final String? spanId;
  final Map<String, dynamic> metadata;

  /// Cast params to expected type.
  P paramsAs<P>() => params as P;

  /// Cast result to expected type.
  R resultAs<R>() => result as R;
}
```

### Hook

```dart
/// Base class for all Zuraffa hooks.
///
/// Hooks intercept UseCase execution at one or more phases (pre, success,
/// failure) and perform arbitrary side effects: telemetry, engagement
/// tracking, audit logging, etc.
///
/// Hooks are fire-and-forget by default: they must never throw (errors are
/// caught and logged) and they never block the calling UseCase. A hook
/// whose completion is a precondition of the UseCase's work opts into
/// blocking semantics (below) — honored only in the `pre` phase.
abstract class Hook {
  /// Unique identifier for this hook.
  String get id;

  /// Priority order for execution (lower runs first).
  int get priority => 0;

  /// Which phases this hook should fire on.
  Set<HookPhase> get phases => const {
    HookPhase.pre,
    HookPhase.success,
    HookPhase.failure,
  };

  /// Whether this hook should fire for the given context + phase.
  ///
  /// A throwing matcher is contained per hook (warning log, treated as
  /// "no match") — it never aborts a dispatch or disarms the hooks
  /// ordered after it.
  bool shouldTrigger(HookContext context, HookPhase phase) => true;

  /// The hook's execution logic. Must be resilient (never throw).
  ///
  /// A synchronously-throwing non-`async` override is contained the same
  /// way: the registry wraps the call in `Future.sync` before attaching
  /// its error handler.
  Future<void> execute(HookContext context, HookPhase phase);

  /// Whether `UseCase.call` must AWAIT this hook to completion (in the
  /// `pre` phase only) before the UseCase's `execute` begins.
  /// Default `false` — fire-and-forget, unchanged.
  ///
  /// A blocking `pre` hook also runs BEFORE the UseCase's cancellation
  /// check: `HookContext` carries no `CancelToken`, so
  /// [blockingTimeout] is the only bound on the wait.
  bool get blocking => false;

  /// How long a [blocking] run may take before the registry abandons it
  /// and proceeds. Abandonment, NOT cancellation — the hook's own future
  /// keeps running and its cleanup stays its own responsibility.
  /// Default `null` (no timeout).
  Duration? get blockingTimeout => null;

  /// What this hook's failure means for the UseCase when [blocking].
  HookErrorPolicy get onError => HookErrorPolicy.continue_;
}
```

### HookErrorPolicy

```dart
/// What a blocking hook's failure means for the UseCase
/// (see [Hook.blocking], [Hook.onError]).
enum HookErrorPolicy {
  /// Log and proceed. The default: the hook must never cost the UseCase
  /// its result.
  continue_,

  /// Proceed no further: `UseCase.call` returns `Failure(hookFailure)`
  /// WITHOUT running `execute` and without dispatching the
  /// `success`/`failure` phases.
  veto,
}
```

### HookVetoException

```dart
/// Thrown by [HookRegistry.dispatchAwaited] when a blocking hook with
/// [HookErrorPolicy.veto] fails (or is abandoned at its
/// [Hook.blockingTimeout]).
///
/// `UseCase.call` catches it and returns `Failure(failure)` WITHOUT
/// running `execute` and without dispatching the `success`/`failure`
/// phases — a veto proceeds no further. Because those phases never fire,
/// a hook that acquires a resource in `pre` and releases it in
/// `success`/`failure` (the built-in telemetry span is the canonical
/// example) never reaches its release phase on a vetoed call: it must
/// release the resource itself on the veto path, or must not be paired
/// with vetoing hooks.
class HookVetoException implements Exception {
  final AppFailure failure;   // the hook's failure, wrapped for Result
  final String hookId;
  final Object? originalError;
  final StackTrace? originalStack;
}
```

### HookRegistry

```dart
/// Global singleton registry for all hooks.
///
/// All UseCases automatically dispatch to registered hooks —
/// no per-UseCase configuration needed.
class HookRegistry {
  static final HookRegistry instance = HookRegistry._();

  bool get isEnabled;
  set isEnabled(bool value);

  List<Hook> get hooks;  // sorted by priority (ascending)

  void register(Hook hook);
  void unregister(String id);
  void clear();

  /// Fire-and-forget dispatch. Never throws, never blocks.
  ///
  /// A throwing [Hook.shouldTrigger] or a synchronously-throwing
  /// [Hook.execute] is contained per hook (warning log) — the dispatch
  /// always completes.
  void dispatch(HookContext context, HookPhase phase);

  /// Awaited dispatch (issue #2032): blocking hooks ([Hook.blocking]) run
  /// sequentially in priority order, each awaited to completion (or
  /// abandoned at its [Hook.blockingTimeout]); non-blocking hooks keep
  /// [dispatch]'s exact fire-and-forget semantics. Degenerates to
  /// [dispatch] when nothing blocking matches. Only [HookVetoException]
  /// ever propagates — every other per-hook failure is contained.
  Future<void> dispatchAwaited(HookContext context, HookPhase phase);
}
```

---

## Built-in: TelemetryHook

```dart
/// Automatically wraps every UseCase execution in an OpenTelemetry span.
///
/// Replaces manual OtelTracer.trace() calls. Once registered, every
/// UseCase.call() and StreamUseCase.call() is traced automatically.
class TelemetryHook extends Hook {
  TelemetryHook({
    Set<String> onlyUseCases = const {},
    Set<String> excludeUseCases = const {},
    String spanNamePrefix = 'usecase',
  });

  @override
  String get id => 'zuraffa-telemetry';

  @override
  Set<HookPhase> get phases => const {
    HookPhase.pre,
    HookPhase.success,
    HookPhase.failure,
  };
}
```

### Filtering Rules

| Configuration | Behavior |
|---------------|----------|
| `onlyUseCases: {}` (default), `excludeUseCases: {}` | Traces ALL UseCases |
| `onlyUseCases: {'A', 'B'}` | Traces ONLY A and B |
| `excludeUseCases: {'C'}` | Traces all EXCEPT C |
| `onlyUseCases: {'A', 'C'}`, `excludeUseCases: {'C'}` | Traces A only (exclude wins) |

### Span Attributes

| Attribute | Value | Phase |
|-----------|-------|-------|
| Span name | `usecase.{UseCaseName}` | pre |
| `usecase.name` | Runtime type string | pre |
| `usecase.phase` | `started` / `success` / `failure` | all |
| `usecase.duration_ms` | Execution time in ms | success, failure |

---

## UseCase.call() Integration Contract

The `UseCase.call()` method gains three dispatch points. The existing try-catch structure, `FailureReporterRegistry` calls, and logging remain unchanged. The **pre** dispatch is AWAITED (issue #2032): blocking hooks complete before `execute` begins, and a vetoing hook fails the call without running `execute` or dispatching later phases.

```dart
Future<Result<T, AppFailure>> call(Params params, {CancelToken? cancelToken}) async {
  final startTime = DateTime.now();
  final hookMetadata = <String, dynamic>{};

  // DISPATCH: pre phase — AWAITED (blocking hooks only; issue #2032)
  try {
    await HookRegistry.instance.dispatchAwaited(
      HookContext(
        useCaseName: '$runtimeType',
        params: params,
        timestamp: startTime,
        traceId: OtelTracer.instance.currentTraceId,
        spanId: OtelTracer.instance.currentSpanId,
        metadata: hookMetadata,
      ),
      HookPhase.pre,
    );
  } on HookVetoException catch (e) {
    // A veto proceeds no further: no execute, no success/failure dispatch.
    return Result.failure(e.failure);
  }

  try {
    cancelToken?.throwIfCancelled();
    final value = await execute(params, cancelToken);

    // DISPATCH: success phase
    HookRegistry.instance.dispatch(/* ... */, HookPhase.success);

    return Result.success(value);
  } on AppFailure catch (e) {
    // existing FailureReporterRegistry call (unchanged)

    // DISPATCH: failure phase
    HookRegistry.instance.dispatch(/* ... */, HookPhase.failure);

    return Result.failure(e);
  } catch (e, stackTrace) {
    // existing error wrapping (unchanged)

    // DISPATCH: failure phase
    HookRegistry.instance.dispatch(/* ... */, HookPhase.failure);

    return Result.failure(failure);
  }
}
```

---

## Exports (zuraffa.dart)

The following are added to the public API exports:

```dart
// In zuraffa.dart
export 'src/core/hook.dart' show Hook, HookPhase, HookContext, HookErrorPolicy, HookVetoException;
export 'src/core/hook_registry.dart' show HookRegistry;
export 'src/core/telemetry_hook.dart' show TelemetryHook;
```
