# Research: UseCase Hook System

**Feature**: 011-usecase-hook-system
**Date**: 2026-06-28

## R1: Dispatch Timing — Synchronous vs Asynchronous

### Decision
Dispatch is **synchronous** (not awaited). `HookRegistry.dispatch()` iterates hooks and calls `execute()` without awaiting each one. Each hook's `Future` is fire-and-forget with `.catchError()` for error logging.

### Rationale
- The `pre` phase must complete before `execute()` runs (synchronous setup like span creation). But we don't need to `await` the hook's async work — the hook writes to the shared `metadata` map synchronously (e.g., stashing a span reference).
- The `success` and `failure` phases happen after the UseCase result is already computed. Awaiting them would add latency to the caller for no benefit.
- This matches `FailureReporterRegistry.reportFailure()` which is also fire-and-forget (`void`, not `Future`).

### Alternatives Considered
- **Await all hooks**: Would allow hooks to complete before the UseCase returns. Rejected because telemetry/engagement tracking should never block the user-facing operation. If a hook is slow (network call to analytics backend), it would delay the app's response.

## R2: Metadata Sharing — How Pre Phase Passes Data to Success/Failure

### Decision
The `HookContext.metadata` field is a mutable `Map<String, dynamic>` created once per UseCase invocation and passed by reference to all three phases. A hook writes a value in `pre` (e.g., `context.metadata['_otel_span'] = span`) and reads it in `success`/`failure`.

### Rationale
- Dart maps are passed by reference, so mutations are visible across phases without copying.
- This is the simplest approach — no zone variables, no thread-local storage, no async context.
- Each hook should use a namespaced key (prefixed with `_` or the hook ID) to avoid collisions.

### Alternatives Considered
- **Zone-scoped variables**: Dart's `Zone.current` could store per-invocation data. Rejected because it's fragile (async boundaries may lose zone context), harder to debug, and overkill for what's essentially a per-call scratchpad.
- **Separate context per phase**: Each phase gets its own context with no shared state. Rejected because the OTel span lifecycle REQUIRES the same span object across phases. Without shared metadata, the `success` phase has no reference to the span created in `pre`.

## R3: TelemetryHook Span Lifecycle — Zone vs Manual

### Decision
`TelemetryHook` manually manages span lifecycle via the shared `metadata` map. In `pre`, it calls `OtelTracer.instance.startSpan()` and stashes the span. In `success`, it calls `endSpan()`. In `failure`, it calls `endSpanWithError()`. No zone context is attached.

### Rationale
- The existing `OtelTracer.trace()` method uses `Context.attach()` + `runZoned()` to make the span "active" so that child operations can access it. For `TelemetryHook`, we don't need the span to be "active" — we just need it created and ended. The span still gets exported to the collector; it just doesn't affect the active context.
- If a child UseCase needs to be a child span, it will get its own `TelemetryHook` dispatch and create its own span as a child of whatever context is active (which may be none, or may be an outer `OtelTracer.trace()` call from the controller).
- Manual lifecycle is simpler, testable, and avoids the complexity of zone management inside a fire-and-forget hook.

### Alternatives Considered
- **Use `OtelTracer.trace()` in the hook**: Would require wrapping `execute()` inside the hook, which means the hook would need to control the UseCase execution flow. But hooks are observers, not wrappers — they don't control execution. Also, `trace()` is synchronous and returns a Future, but our dispatch is fire-and-forget.

## R4: Filtering — onlyUseCases vs excludeUseCases Precedence

### Decision
When both `onlyUseCases` and `excludeUseCases` are non-empty and contain the same UseCase name, `excludeUseCases` wins. The logic is:
1. If `onlyUseCases` is non-empty AND the UseCase is NOT in it → skip.
2. If the UseCase IS in `excludeUseCases` → skip.
3. Otherwise → fire.

### Rationale
- `excludeUseCases` is an explicit "never trace this" statement. It should always be honored regardless of the whitelist.
- Use case: You want to trace 5 specific UseCases (`onlyUseCases`) but one of them is a background sync that you don't want to trace during testing (`excludeUseCases`).

### Alternatives Considered
- **onlyUseCases wins**: Would mean the whitelist overrides the blacklist. This is counterintuitive — a "do not track" should always win.
- **Intersection**: If both are set, only fire for UseCases in `onlyUseCases` but NOT in `excludeUseCases`. This is functionally identical to the chosen approach.

## R5: StreamUseCase Integration

### Decision
`StreamUseCase.call()` dispatches hooks at three points:
- `pre`: before the stream starts
- `success`: after the stream completes normally (all values emitted)
- `failure`: if the stream emits a failure result or throws

### Rationale
- The existing `StreamUseCase.call()` is an `async*` generator. The `pre` dispatch happens before the first `yield`. The `success`/`failure` dispatch happens after the stream finishes.
- Per-value hooks (firing on each emitted value) are NOT supported — this would be too noisy and expensive for telemetry. If per-value tracking is needed, it should be done inside `execute()` manually.

### Alternatives Considered
- **Per-value dispatch**: Fire `success` on each emitted value. Rejected — too expensive, and most hooks (telemetry, engagement) care about the overall operation, not each value.
- **Stream-only hooks**: A separate `StreamHook` base class with per-value callbacks. Rejected — unnecessary complexity. The three-phase model is sufficient for streams.
