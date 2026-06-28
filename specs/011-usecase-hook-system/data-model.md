# Data Model: UseCase Hook System

**Feature**: 011-usecase-hook-system
**Date**: 2026-06-28

## Core Types

### 1. `HookPhase` (Enum)

The three interception points during UseCase execution.

| Value | Description | When It Fires |
|-------|-------------|---------------|
| `pre` | Before `execute()` is called | After cancellation check, before business logic |
| `success` | After `execute()` completed successfully | Before returning `Result.success()` |
| `failure` | After `execute()` threw an error | Before returning `Result.failure()` |

---

### 2. `HookContext` (Immutable Value Object)

The context passed to every hook during dispatch. Created once per UseCase invocation, shared across all three phases (the `metadata` map is mutable and passed by reference).

| Field | Type | Nullable | Description |
|-------|------|----------|-------------|
| `useCaseName` | `String` | No | Runtime type of the UseCase (e.g., `'GetDealListUseCase'`) |
| `params` | `Object?` | Yes | The input parameters passed to the UseCase |
| `result` | `Object?` | Yes | The successful result (only set in `success` phase) |
| `failure` | `AppFailure?` | Yes | The failure (only set in `failure` phase) |
| `duration` | `Duration?` | Yes | Execution duration (null in `pre` phase) |
| `timestamp` | `DateTime` | No | When the UseCase was invoked |
| `traceId` | `String?` | Yes | W3C trace ID from active OTel span |
| `spanId` | `String?` | Yes | W3C span ID from active OTel span |
| `metadata` | `Map<String, dynamic>` | No | Shared mutable bag for cross-phase data (passed by reference) |

**Convenience methods**:
- `P paramsAs<P>()` — cast params to expected type
- `R resultAs<R>()` — cast result to expected type

---

### 3. `Hook` (Abstract Base Class)

| Member | Type | Default | Description |
|--------|------|---------|-------------|
| `id` | `String` | (abstract) | Unique identifier for this hook |
| `priority` | `int` | `0` | Execution order (lower runs first) |
| `phases` | `Set<HookPhase>` | `{pre, success, failure}` | Which phases this hook fires on |
| `shouldTrigger(context, phase)` | `bool` | `true` | Whether this hook should fire for the given context |
| `execute(context, phase)` | `Future<void>` | (abstract) | The hook's side-effect logic. Must be resilient (never throw). |

---

### 4. `HookRegistry` (Singleton)

| Member | Type | Description |
|--------|------|-------------|
| `instance` | `HookRegistry` | Global singleton |
| `isEnabled` | `bool` | Global kill switch (default: `true`) |
| `hooks` | `List<Hook>` | All registered hooks, sorted by priority (read-only) |
| `register(hook)` | `void` | Register a hook (throws if ID exists) |
| `unregister(id)` | `void` | Remove a hook by ID |
| `clear()` | `void` | Remove all hooks |
| `dispatch(context, phase)` | `void` | Fire-and-forget dispatch to all matching hooks |

---

### 5. `TelemetryHook` (Built-in, extends `Hook`)

| Member | Type | Default | Description |
|--------|------|---------|-------------|
| `id` | `String` | `'zuraffa-telemetry'` | Fixed identifier |
| `phases` | `Set<HookPhase>` | `{pre, success, failure}` | All three phases |
| `onlyUseCases` | `Set<String>` | `{}` (empty = all) | Whitelist — if non-empty, only these UseCases are traced |
| `excludeUseCases` | `Set<String>` | `{}` | Blacklist — these UseCases are never traced (wins over whitelist) |
| `spanNamePrefix` | `String` | `'usecase'` | Prefix for span names |

---

## Type Relationships

```mermaid
classDiagram
    class HookPhase {
        <<enum>>
        pre
        success
        failure
    }

    class HookContext {
        +String useCaseName
        +Object? params
        +Object? result
        +AppFailure? failure
        +Duration? duration
        +DateTime timestamp
        +String? traceId
        +String? spanId
        +Map metadata
        +paramsAs~P~()
        +resultAs~R~()
    }

    class Hook {
        <<abstract>>
        +String id*
        +int priority
        +Set~HookPhase~ phases
        +shouldTrigger(HookContext, HookPhase) bool
        +execute(HookContext, HookPhase) Future~void~*
    }

    class HookRegistry {
        +static HookRegistry instance
        +bool isEnabled
        +List~Hook~ hooks
        +register(Hook)
        +unregister(String)
        +clear()
        +dispatch(HookContext, HookPhase)
    }

    class TelemetryHook {
        +String id
        +Set onlyUseCases
        +Set excludeUseCases
        +String spanNamePrefix
    }

    class UseCase {
        <<abstract>>
        +call(params) Future~Result~
    }

    Hook <|-- TelemetryHook
    HookRegistry o-- Hook : manages
    HookRegistry --> HookContext : creates
    UseCase --> HookRegistry : dispatches to
    UseCase ..> HookContext : creates
```

---

## Dispatch Flow (State Machine)

```mermaid
stateDiagram-v2
    [*] --> UseCaseCall: call(params)

    UseCaseCall --> CheckEmpty: start
    CheckEmpty --> Skip: registry empty
    CheckEmpty --> PrePhase: hooks exist

    PrePhase --> FilterPre: for each hook
    FilterPre --> FirePre: shouldTrigger=true
    FilterPre --> SkipHook: shouldTrigger=false
    FirePre --> FilterPre: next hook
    SkipHook --> FilterPre: next hook
    FilterPre --> Execute: all hooks checked

    Execute --> SuccessPhase: execute() returned
    Execute --> FailurePhase: execute() threw

    SuccessPhase --> FilterSuccess: for each hook
    FilterSuccess --> FireSuccess: shouldTrigger=true
    FilterSuccess --> SkipSuccess: shouldTrigger=false

    FailurePhase --> ReportFailure: FailureReporterRegistry
    FailurePhase --> FilterFail: for each hook
    FilterFail --> FireFail: shouldTrigger=true
    FilterFail --> SkipFail: shouldTrigger=false

    FireSuccess --> ReturnSuccess
    FireFail --> ReturnFailure
    SkipSuccess --> ReturnSuccess
    SkipFail --> ReturnFailure

    ReturnSuccess --> [*]
    ReturnFailure --> [*]
    Skip --> [*]
```
