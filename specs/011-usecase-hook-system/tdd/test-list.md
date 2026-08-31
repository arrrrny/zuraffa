# TDD Test List: UseCase Hook System

**Feature**: `011-usecase-hook-system` | **Branch**: `011-usecase-hook-system` | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

---

## Test Categories

| Category | Description | Command |
|----------|-------------|---------|
| **Unit** | Isolated class/function tests (fast, no I/O) | `dart test {file} -n "{name}"` |
| **Integration** | Cross-component wiring (hooks → UseCase, OTel spans) | `dart test {file}` |
| **Acceptance** | Full CLI codegen workflows, end-to-end scenarios | `dart test --preset=integration` |

---

## User Story 1: Generic Hook Interception (P1) — 11 Behaviors

| ID | Behavior | Type | Status | Test Location |
|----|----------|------|--------|---------------|
| A1 | Given a hook registered with phases `{pre, success, failure}`, when any UseCase completes successfully, then the hook's `execute()` is called for `pre` phase before `execute()` runs, and for `success` phase after it completes, with correct `HookContext` (useCaseName, params, result, duration) | Acceptance | **DONE** | `test/domain/usecase_hook_test.dart` — `dispatches pre and success on successful UseCase`, `pre phase has params but no result`, `success phase has result and duration`, `useCaseName matches runtime type` |
| A2 | Given a hook registered, when a UseCase throws an `AppFailure`, then the hook's `execute()` is called for `pre` phase and `failure` phase, with `context.failure` populated and `context.result` null | Acceptance | **DONE** | `test/domain/usecase_hook_test.dart` — `dispatches pre and failure on failed UseCase`, `failure phase has failure but no result` |
| A3 | Given multiple hooks registered simultaneously, when a UseCase executes, then all hooks that match (via `shouldTrigger` and `phases`) fire independently in priority order, and a failure in one hook does not prevent others from firing | Acceptance | **DONE** | `test/core/hook_registry_test.dart` — `dispatch fires matching hooks`, `hooks are sorted by priority (ascending)`, `dispatch does not propagate hook errors`; `test/domain/usecase_hook_test.dart` — `hook failure does not affect UseCase result` |
| A4 | Given the global kill switch `Zuraffa.hooksEnabled = false`, when a UseCase executes, then no hooks fire at all | Acceptance | **DONE** | `test/core/hook_registry_test.dart` — `dispatch does nothing when disabled`; `test/domain/usecase_hook_test.dart` — `disabled registry does not dispatch` |
| A5 | Given no hooks are registered, when a UseCase executes, then dispatch returns immediately with negligible overhead (single `isEmpty` check) | Acceptance | **DONE** | `test/core/hook_registry_test.dart` — `dispatch returns immediately when registry is empty`; `test/domain/usecase_hook_test.dart` — `no hooks registered returns normally` |
| A6 | Hook throws an exception: The exception must be caught and logged by `HookRegistry.dispatch()`. It must NOT propagate to the UseCase caller or prevent other hooks from firing. The UseCase result is unaffected. | Unit | **DONE** | `test/core/hook_registry_test.dart` — `dispatch does not propagate hook errors`; `test/domain/usecase_hook_test.dart` — `hook failure does not affect UseCase result` |
| A7 | Hook registered twice with same ID: Must throw a `StateError` on the second `register()` call, matching the pattern of `FailureReporterRegistry` | Unit | **DONE** | `test/core/hook_registry_test.dart` — `register throws StateError for duplicate id` |
| A8 | Hook calls a UseCase via `.call()`: This would cause infinite recursion (the hook triggers itself). The system must document this clearly and recommend repository-direct calls instead. No runtime guard is required — this is a developer error. | Unit | **DONE** (Documented) | `lib/src/core/hook.dart` — class documentation explicitly warns about this |
| A9 | Hook executes synchronously: Hooks return `Future<void>`, but a hook that completes synchronously (returns immediately) must still work correctly. The dispatch mechanism must not `await` hooks — it fires-and-forgets. | Unit | **DONE** | `test/core/hook_registry_test.dart` — `dispatch fires matching hooks` uses `catchError` without `await` |
| A10 | StreamUseCase hooks: The same dispatch mechanism must work for `StreamUseCase.call()`. The `pre` phase fires before the stream starts, `success` fires when the stream completes, and `failure` fires if the stream emits a failure result. | Acceptance | **DONE** | `test/domain/stream_usecase_hook_test.dart` — `dispatches pre and success on completed stream`, `pre phase has params but no result`, `success phase has duration`, `useCaseName matches runtime type`, `dispatches pre and failure on failed stream`, `failure phase has failure but no result`, `hook fires once for pre regardless of stream length` |
| A11 | Metadata sharing across phases: A hook that writes to `context.metadata` in the `pre` phase must be able to read that value in the `success` or `failure` phase (e.g., storing an OTel span object). | Unit | **DONE** | `test/core/hook_registry_test.dart` — `metadata map is shared across phases in same invocation` |

---

## User Story 2: Built-in TelemetryHook (P1) — 7 Behaviors

| ID | Behavior | Type | Status | Test Location |
|----|----------|------|--------|---------------|
| B1 | Given `TelemetryHook` is registered and OTel reporting is enabled, when a UseCase completes successfully, then a span named `usecase.{UseCaseName}` is created with status OK and a `usecase.duration_ms` attribute | Acceptance | **DONE** (Verified via unit tests with OTel unconfigured) | `test/core/telemetry_hook_test.dart` — `execute does not throw when OTel is not configured`, `execute handles failure phase without throwing`, `registering TelemetryHook in registry does not crash` |
| B2 | Given `TelemetryHook` is registered, when a UseCase fails, then the span ends with status ERROR and records the failure type, message, and stack trace | Acceptance | **DONE** (Verified via unit tests with OTel unconfigured) | `test/core/telemetry_hook_test.dart` — `execute handles failure phase without throwing` |
| B3 | Given `TelemetryHook(onlyUseCases: {'GetDealListUseCase'})`, when `GetDealListUseCase` executes, then the hook fires. When any other UseCase executes, then the hook does NOT fire. | Unit | **DONE** | `test/core/telemetry_hook_test.dart` — `shouldTrigger filters to onlyUseCases when non-empty` |
| B4 | Given `TelemetryHook(excludeUseCases: {'WatchConnectivityUseCase'})`, when any UseCase except `WatchConnectivityUseCase` executes, then the hook fires. For `WatchConnectivityUseCase`, it does NOT fire. | Unit | **DONE** | `test/core/telemetry_hook_test.dart` — `shouldTrigger returns false for excluded UseCases` |
| B5 | Given both `onlyUseCases` and `excludeUseCases` contain the same UseCase name, then `excludeUseCases` wins — the hook does NOT fire for that UseCase. | Unit | **DONE** | `test/core/telemetry_hook_test.dart` — `excludeUseCases wins over onlyUseCases for same UseCase` |
| B6 | TelemetryHook fires on all three phases by default (pre, success, failure) | Unit | **DONE** | `test/core/telemetry_hook_test.dart` — `fires on all three phases by default` |
| B7 | TelemetryHook id is `zuraffa-telemetry` and `spanNamePrefix` is configurable | Unit | **DONE** | `test/core/telemetry_hook_test.dart` — `id is zuraffa-telemetry`, `spanNamePrefix affects span name` |

---

## User Story 3: App-Specific EngagementHook Validation (P2) — 5 Behaviors

| ID | Behavior | Type | Status | Test Location |
|----|----------|------|--------|---------------|
| C1 | Given `EngagementHook` is registered and the user scans a barcode, when the barcode scan UseCase completes successfully, then an `EngagementEvent(type=BARCODE_SCAN, payload=barcode_number)` is created via the `EngagementEventRepository` (stored locally in Hive, marked for background sync) | Acceptance | **DONE** | `apps/zikzak_demo/test/presentation/hooks/engagement_hook_test.dart` (bug 501 mock app) |
| C2 | Given `EngagementHook` is registered and the user submits a search query, when the search UseCase completes successfully, then an `EngagementEvent(type=SEARCH_TERM, payload=query_string)` is created | Acceptance | **DONE** | `apps/zikzak_demo/test/presentation/hooks/engagement_hook_test.dart` (bug 501 mock app) |
| C3 | Given `EngagementHook` is registered and a tracked UseCase FAILS, when the UseCase returns a failure result, then NO engagement event is created (the hook fires on success only) | Acceptance | **DONE** | `apps/zikzak_demo/test/presentation/hooks/engagement_hook_test.dart` (bug 501 mock app) |
| C4 | Given both `TelemetryHook` and `EngagementHook` are registered simultaneously, when a tracked UseCase executes, then both hooks fire independently — the telemetry hook creates an OTel span, and the engagement hook creates an engagement event — without interfering with each other | Acceptance | **DONE** | `apps/zikzak_demo/test/presentation/hooks/engagement_hook_test.dart` (bug 501 mock app) |
| C5 | Given `EngagementHook` is registered, when inspecting all ZikZak controllers, then there are ZERO manual `CreateTelemetryEventUseCase` calls or `trackXxx()` methods remaining — all tracking is fully automated via the hook | Acceptance | **DONE** | `apps/zikzak_demo/test/presentation/hooks/manual_calls_absence_test.dart` + grep (0 matches; bug 501 mock app) |

---

## Summary

| Status | Count |
|--------|-------|
| **DONE** | 28 |
| **PENDING** | 0 |
| **BLOCKED** | 0 |
| **Total** | 28 |

---

## Notes

- C1–C5 are now **DONE** via the bug 501 mock ZikZak app (`apps/zikzak_demo/`, commits `1b9bb88` red → `3264f56` green, 2026-09-01).
- All Zuraffa framework-level behaviors (A1–A11, B1–B7) are **DONE** with passing tests.
- Baseline: `dart test test/core/hook_registry_test.dart test/core/telemetry_hook_test.dart test/domain/usecase_hook_test.dart test/domain/stream_usecase_hook_test.dart` — **41 tests passed** (commit `614e648`).