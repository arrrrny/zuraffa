# Feature Specification: UseCase Hook System

**Feature Branch**: `011-usecase-hook-system`

**Created**: 2026-06-28

**Status**: Draft

**Input**: User description: "Add a generic hook system to Zuraffa that intercepts UseCase.call() at pre/success/failure phases. Multiple hooks can be registered simultaneously (telemetry, engagement tracking, audit logging, etc.) and all fire independently. Ship a built-in TelemetryHook that auto-wraps every UseCase in an OTel span. Validate the system by implementing ZikZak's user engagement tracking entirely through hooks — zero controller-level boilerplate."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Generic Hook Interception (Priority: P1)

As a framework developer, I want to register hooks that automatically intercept any UseCase execution at three phases (before, on success, on failure), so that I can add cross-cutting concerns like telemetry, engagement tracking, or audit logging without modifying individual UseCases or controllers.

**Why this priority**: This is the foundation. Without the generic hook registry and dispatch mechanism, no hooks can exist. All other stories depend on this.

**Independent Test**: Register a simple test hook that logs the UseCase name on success. Execute any UseCase. Verify the hook fired exactly once with the correct UseCase name.

**Acceptance Scenarios**:

1. **Given** a Hook is registered with phases `{pre, success, failure}`, **When** any UseCase completes successfully, **Then** the hook's `execute()` is called for the `pre` phase before `execute()` runs, and for the `success` phase after it completes, with the correct `HookContext` (useCaseName, params, result, duration).
2. **Given** a Hook is registered, **When** a UseCase throws an `AppFailure`, **Then** the hook's `execute()` is called for the `pre` phase and the `failure` phase, with `context.failure` populated and `context.result` null.
3. **Given** multiple Hooks are registered simultaneously, **When** a UseCase executes, **Then** all hooks that match (via `shouldTrigger` and `phases`) fire independently in priority order, and a failure in one hook does not prevent others from firing.
4. **Given** the global kill switch `Zuraffa.hooksEnabled = false`, **When** a UseCase executes, **Then** no hooks fire at all.
5. **Given** no hooks are registered, **When** a UseCase executes, **Then** dispatch returns immediately with negligible overhead (single `isEmpty` check).

---

### User Story 2 - Built-in TelemetryHook (Priority: P1)

As an app developer using Zuraffa, I want a built-in hook that automatically wraps every UseCase execution in an OpenTelemetry span, so that I get distributed tracing for all business operations without manually wrapping each one with `OtelTracer.trace()`.

**Why this priority**: This is the first opinionated consumer of the hook system. It proves the generic hook works for a real, complex use case (span lifecycle management across pre/success/failure phases).

**Independent Test**: Register `TelemetryHook()`, execute any UseCase, verify an OTel span was created with name `usecase.{UseCaseName}`, correct status (OK on success, ERROR on failure), and duration attribute.

**Acceptance Scenarios**:

1. **Given** `TelemetryHook` is registered and OTel reporting is enabled, **When** a UseCase completes successfully, **Then** a span named `usecase.{UseCaseName}` is created with status OK and a `usecase.duration_ms` attribute.
2. **Given** `TelemetryHook` is registered, **When** a UseCase fails, **Then** the span ends with status ERROR and records the failure type, message, and stack trace.
3. **Given** `TelemetryHook(onlyUseCases: {'GetDealListUseCase'})`, **When** `GetDealListUseCase` executes, **Then** the hook fires. **When** any other UseCase executes, **Then** the hook does NOT fire.
4. **Given** `TelemetryHook(excludeUseCases: {'WatchConnectivityUseCase'})`, **When** any UseCase except `WatchConnectivityUseCase` executes, **Then** the hook fires. For `WatchConnectivityUseCase`, it does NOT fire.
5. **Given** both `onlyUseCases` and `excludeUseCases` contain the same UseCase name, **Then** `excludeUseCases` wins — the hook does NOT fire for that UseCase.

---

### User Story 3 - App-Specific EngagementHook Validation (Priority: P2)

As the ZikZak app developer, I want to replace all 8 manual engagement tracking calls in controllers with a single hook registration, so that user actions (barcode scan, deal like, search, etc.) are tracked automatically when their corresponding UseCases complete — with zero controller-level boilerplate.

**Why this priority**: This validates the generic hook system against a real, production-grade use case. It proves that app-specific hooks can be built on top of the generic system without framework modifications, and that the repository-direct pattern (no UseCase-in-hook recursion) works correctly.

**Independent Test**: Register `EngagementHook(repository)` in ZikZak's `main()`. Trigger a barcode scan from the app. Verify an `EngagementEvent` with `eventType=BARCODE_SCAN` and the correct payload is stored in the local Hive box and eventually synced to the backend. Verify zero `trackXxx()` calls remain in any controller.

**Acceptance Scenarios**:

1. **Given** `EngagementHook` is registered and the user scans a barcode, **When** the barcode scan UseCase completes successfully, **Then** an `EngagementEvent(type=BARCODE_SCAN, payload=barcode_number)` is created via the `EngagementEventRepository` (stored locally in Hive, marked for background sync).
2. **Given** `EngagementHook` is registered and the user submits a search query, **When** the search UseCase completes successfully, **Then** an `EngagementEvent(type=SEARCH_TERM, payload=query_string)` is created.
3. **Given** `EngagementHook` is registered and a tracked UseCase FAILS, **When** the UseCase returns a failure result, **Then** NO engagement event is created (the hook fires on success only).
4. **Given** both `TelemetryHook` and `EngagementHook` are registered simultaneously, **When** a tracked UseCase executes, **Then** both hooks fire independently — the telemetry hook creates an OTel span, and the engagement hook creates an engagement event — without interfering with each other.
5. **Given** `EngagementHook` is registered, **When** inspecting all ZikZak controllers, **Then** there are ZERO manual `CreateTelemetryEventUseCase` calls or `trackXxx()` methods remaining — all tracking is fully automated via the hook.

---

### Edge Cases

- **Hook throws an exception**: The exception must be caught and logged by `HookRegistry.dispatch()`. It must NOT propagate to the UseCase caller or prevent other hooks from firing. The UseCase result is unaffected.
- **Hook registered twice with same ID**: Must throw a `StateError` on the second `register()` call, matching the pattern of `FailureReporterRegistry`.
- **Hook calls a UseCase via `.call()`**: This would cause infinite recursion (the hook triggers itself). The system must document this clearly and recommend repository-direct calls instead. No runtime guard is required — this is a developer error.
- **Hook executes synchronously**: Hooks return `Future<void>`, but a hook that completes synchronously (returns immediately) must still work correctly. The dispatch mechanism must not `await` hooks — it fires-and-forgets.
- **StreamUseCase hooks**: The same dispatch mechanism must work for `StreamUseCase.call()`. The `pre` phase fires before the stream starts, `success` fires when the stream completes, and `failure` fires if the stream emits a failure result.
- **Metadata sharing across phases**: A hook that writes to `context.metadata` in the `pre` phase must be able to read that value in the `success` or `failure` phase (e.g., storing an OTel span object).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a `Hook` abstract base class with: `id` (unique identifier), `priority` (execution order, lower first), `phases` (set of `HookPhase` to fire on), `shouldTrigger(HookContext, HookPhase)` (filter predicate), and `execute(HookContext, HookPhase)` (side-effect logic).
- **FR-002**: System MUST provide a `HookContext` immutable object containing: `useCaseName` (runtime type string), `params` (the UseCase input), `result` (on success), `failure` (on failure), `duration` (null in pre phase), `timestamp`, `traceId`/`spanId` (from active OTel span if configured), and a mutable `metadata` map for cross-phase data sharing.
- **FR-003**: System MUST define a `HookPhase` enum with three values: `pre`, `success`, `failure`.
- **FR-004**: System MUST provide a `HookRegistry` global singleton with: `register(Hook)`, `unregister(String id)`, `clear()`, `isEnabled` (global kill switch), `hooks` (sorted by priority), and `dispatch(HookContext, HookPhase)` (fire-and-forget, never throws).
- **FR-005**: `UseCase.call()` MUST dispatch to `HookRegistry` at three points: before `execute()` (pre phase), after successful `execute()` (success phase), and after catching a failure (failure phase). The existing try-catch structure and `FailureReporterRegistry` calls must remain unchanged.
- **FR-006**: `StreamUseCase.call()` MUST dispatch to `HookRegistry` at the same three points, adapted for stream lifecycle.
- **FR-007**: `HookRegistry.dispatch()` MUST be fire-and-forget: it must never throw, never block the calling UseCase, and catch/log all errors from individual hooks.
- **FR-008**: The `Zuraffa` facade class MUST expose: `registerHook(Hook)`, `unregisterHook(String id)`, and `hooksEnabled` setter.
- **FR-009**: System MUST ship a built-in `TelemetryHook` that auto-wraps every UseCase in an OTel span. It MUST support `onlyUseCases` (whitelist) and `excludeUseCases` (blacklist) constructor parameters, with `excludeUseCases` taking precedence when both contain the same UseCase.
- **FR-010**: `TelemetryHook` MUST store the OTel span in `HookContext.metadata` during the `pre` phase and retrieve it in `success`/`failure` phases to end it appropriately.
- **FR-011**: When `HookRegistry.isEnabled` is `false`, `dispatch()` MUST return immediately without iterating hooks.
- **FR-012**: When no hooks are registered, `dispatch()` MUST return immediately after an `isEmpty` check.

### Key Entities

- **Hook**: Abstract base class for all hooks. Each hook declares which phases and which UseCases it cares about, and implements side-effect logic.
- **HookContext**: Immutable snapshot of a UseCase invocation — what was called, with what params, what resulted, how long it took, and what trace context was active.
- **HookPhase**: The three interception points: `pre` (before business logic), `success` (after successful completion), `failure` (after error).
- **HookRegistry**: Global singleton that manages hook lifecycle and dispatch. Follows the same pattern as `FailureReporterRegistry`.
- **TelemetryHook**: Built-in hook that creates OTel spans for every UseCase. Ships with Zuraffa.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of UseCase executions dispatch to all registered hooks within the hook's declared phases, with zero missed dispatches.
- **SC-002**: A hook error never propagates to the UseCase caller — 0 cases where a hook exception causes the UseCase to fail or change its result.
- **SC-003**: When no hooks are registered, UseCase execution overhead increases by less than 1 microsecond (single `isEmpty` check).
- **SC-004**: ZikZak's engagement tracking is fully automated via a single `EngagementHook` registration — zero `trackXxx()` method calls or manual `CreateTelemetryEventUseCase` invocations remain in any controller.
- **SC-005**: All 8 engagement event types (BARCODE_SCAN, LINK_SHARE, DEAL_LIKE, DEAL_SHARE, LISTING_SHARE, ASK_ZIKZAK, VISIT_LINK, SEARCH_TERM) are tracked correctly when their corresponding UseCases complete successfully.
- **SC-006**: When both `TelemetryHook` and `EngagementHook` are registered simultaneously, both fire on the same UseCase execution without interfering with each other or the UseCase result.
- **SC-007**: `TelemetryHook` with `onlyUseCases` filter fires for exactly the specified UseCases and no others. `excludeUseCases` filter excludes exactly the specified UseCases and no others.

## Assumptions

- The existing `UseCase.call()` and `StreamUseCase.call()` methods are the only integration points — no other framework classes need modification.
- The existing `FailureReporterRegistry` and `OtelTracer` remain unchanged and continue to work as before.
- Hooks are registered once at app startup (in `main()`) and remain active for the app's lifetime. Dynamic registration/unregistration during runtime is supported but not the primary use case.
- The `HookContext.metadata` map is shared by reference across all three phases of a single UseCase invocation. Hooks should use a namespaced key (e.g., `_otel_span`, `_zikzak_payload`) to avoid collisions.
- ZikZak's `EngagementEventRepository` (already implemented) handles local Hive storage, demographic enrichment, and background sync. The `EngagementHook` delegates to this repository directly — no `TrackEngagementEventUseCase` is needed.
- The `TelemetryHook` requires `OtelFailureReporter` to be initialized first (which sets up the global `TracerProvider`). If OTel is not configured, `TelemetryHook` still runs but spans are no-ops.
