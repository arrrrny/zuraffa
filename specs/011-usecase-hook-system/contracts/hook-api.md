# Public API Contract: UseCase Hook System

**Feature**: 011-usecase-hook-system
**Date**: 2026-06-28

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
/// Hooks are fire-and-forget: they must never throw (errors are caught and
/// logged) and they never block the calling UseCase.
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
  bool shouldTrigger(HookContext context, HookPhase phase) => true;

  /// The hook's execution logic. Must be resilient (never throw).
  Future<void> execute(HookContext context, HookPhase phase);
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
  void dispatch(HookContext context, HookPhase phase);
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

The `UseCase.call()` method gains three dispatch points. The existing try-catch structure, `FailureReporterRegistry` calls, and logging remain unchanged.

```dart
Future<Result<T, AppFailure>> call(Params params, {CancelToken? cancelToken}) async {
  final startTime = DateTime.now();
  final hookMetadata = <String, dynamic>{};

  // DISPATCH: pre phase
  HookRegistry.instance.dispatch(
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
export 'src/core/hook.dart' show Hook, HookPhase, HookContext;
export 'src/core/hook_registry.dart' show HookRegistry;
export 'src/core/telemetry_hook.dart' show TelemetryHook;
```
