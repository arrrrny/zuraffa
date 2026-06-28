# 006 - UseCase Hook System

## Status

Proposed

## Context

Zuraffa's `UseCase.call()` is the single interception point for all business operations. It already handles error reporting via `FailureReporterRegistry` and artifact publishing via `ArtifactPublisher`. However, there is no mechanism for hooks that fire on the **success path** or **before execution**.

This gap forces application developers to manually wire side-effects (telemetry, engagement tracking, audit logging, performance monitoring) into individual controllers — duplicating logic across every entry point. For example, ZikZak's engagement tracking required 8 manual `CreateTelemetryEventUseCase` calls across 8 controllers, all doing essentially the same thing: "when this UseCase completes, record an event."

The existing patterns (`FailureReporterRegistry`, `ArtifactHook`, `OtelTracer`) demonstrate the right approach: register globally, dispatch automatically, filter per-instance. But none of them cover the success path or the pre-execution path.

## Decision

Introduce a generic **Hook System** that intercepts `UseCase.call()` at three phases: `pre`, `success`, `failure`. Multiple hooks can be registered simultaneously and all fire independently.

### Core Types

- **`Hook`** — abstract base class with `id`, `priority`, `phases`, `shouldTrigger()`, `execute()`
- **`HookContext`** — immutable context with UseCase name, params, result/failure, duration, trace IDs, shared metadata
- **`HookPhase`** — enum: `pre`, `success`, `failure`
- **`HookRegistry`** — global singleton (same pattern as `FailureReporterRegistry`)

### Built-in

- **`TelemetryHook`** — shipped with Zuraffa, auto-wraps every UseCase in an OTel span. Supports `onlyUseCases` (whitelist) and `excludeUseCases` (blacklist) for fine-grained control over which UseCases get traced.

### Registration API

```dart
Zuraffa.registerHook(MyHook());                    // generic
Zuraffa.registerHook(TelemetryHook());              // built-in
Zuraffa.registerHook(EngagementHook(repository));   // app-specific
Zuraffa.hooksEnabled = false;                       // global kill switch
```

### Integration

Three `HookRegistry.instance.dispatch()` calls added to `UseCase.call()` and `StreamUseCase.call()`. No breaking changes to existing code.

## Consequences

- **Positive**: Side-effects (telemetry, engagement, audit) are decoupled from controllers. Adding a new tracked event is a one-line map entry, not a new controller method.
- **Positive**: Multiple concerns coexist without coupling. TelemetryHook and EngagementHook fire independently on the same UseCase.
- **Positive**: Follows existing Zuraffa patterns (registry + hook + fire-and-forget dispatch). No new paradigms.
- **Negative**: Tiny overhead on every `UseCase.call()` for dispatch (one registry lookup + filter check). Negligible when no hooks are registered.
- **Mitigation**: `HookRegistry.isEnabled` provides a global kill switch. `shouldTrigger()` filtering ensures hooks only pay the cost for relevant UseCases.

## Alternatives Considered

### AOP / Code Generation

Use Dart's build_runner to inject hook calls into generated UseCase code. **Rejected**: Adds build-time complexity, requires regeneration when hooks change, and Dart's analyzer doesn't support runtime AOP.

### Middleware / Decorator Pattern

Wrap each UseCase in a decorator at registration time. **Rejected**: Changes the DI registration pattern, adds wrapper objects, and makes debugging harder (stack traces show decorator layers).

### Event Bus

Publish UseCase execution events to a stream that subscribers listen to. **Rejected**: Loses the synchronous `pre` phase (needed for span creation), adds stream lifecycle management, and doesn't integrate with the existing `call()` try-catch structure.

## References

- `lib/src/core/failure_reporter_registry.dart` — existing registry pattern
- `lib/src/core/artifact_publisher.dart` — existing hook pattern (`ArtifactHook`)
- `lib/src/domain/usecase.dart` — integration point (`call()` method)
- ZikZak spec `039-user-engagement-tracking` — motivating use case
