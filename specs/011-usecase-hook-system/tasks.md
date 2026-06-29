# Tasks: UseCase Hook System

**Input**: Design documents from `/specs/011-usecase-hook-system/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Unit and integration tests are requested as part of Clean Architecture. Tests are included per user story.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Branch verification and dependency check

- [x] T001 Initialize feature branch `011-usecase-hook-system` and verify `pubspec.yaml` has `opentelemetry: ^0.18.11`, `logging: ^1.3.0`, `meta: ^1.18.0` in `zuraffa/pubspec.yaml`
- [x] T002 [P] Verify existing `lib/src/core/otel_tracer.dart` exports `OtelTracer.instance.startSpan()`, `endSpan()`, `endSpanWithError()`, `currentTraceId`, `currentSpanId` for use by `TelemetryHook`
- [x] T003 [P] Verify existing `lib/src/domain/usecase.dart` `call()` method structure (try-catch, FailureReporterRegistry calls) in `zuraffa/lib/src/domain/usecase.dart`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core hook types that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 [P] Create `HookPhase` enum with values `pre`, `success`, `failure` in `zuraffa/lib/src/core/hook.dart`
- [x] T005 [P] Create `HookContext` class with fields `useCaseName`, `params`, `result`, `failure`, `duration`, `timestamp`, `traceId`, `spanId`, `metadata` and helper methods `paramsAs<P>()`, `resultAs<R>()` in `zuraffa/lib/src/core/hook.dart`
- [x] T006 Create `Hook` abstract base class with `id`, `priority` (default 0), `phases` (default all three), `shouldTrigger()` (default true), `execute()` (abstract) in `zuraffa/lib/src/core/hook.dart` (depends on T004, T005)
- [x] T007 Create `HookRegistry` singleton with `register()`, `unregister()`, `clear()`, `isEnabled`, `hooks` (sorted by priority), `dispatch()` (fire-and-forget, catches all errors) in `zuraffa/lib/src/core/hook_registry.dart` (depends on T006)
- [x] T008 Write unit tests for `HookRegistry` covering register/unregister, dispatch filtering by phases and shouldTrigger, error isolation, empty-registry fast path, global kill switch in `zuraffa/test/core/hook_registry_test.dart` (depends on T007)
- [x] T009 Export `Hook`, `HookPhase`, `HookContext`, `HookRegistry` from `zuraffa/lib/zuraffa.dart`

**Checkpoint**: Foundation ready — `HookRegistry` exists and is tested. User story implementation can now begin.

---

## Phase 3: User Story 1 - Generic Hook Interception (Priority: P1) 🎯 MVP

**Goal**: Wire `HookRegistry.dispatch()` into `UseCase.call()` and `StreamUseCase.call()` at three phases.

**Independent Test**: Register a test hook that records dispatches, execute any UseCase, verify the hook fired for `pre` and `success` (or `failure`) with correct `HookContext` fields.

### Implementation for User Story 1

- [x] T010 [US1] Add three `HookRegistry.instance.dispatch()` calls to `UseCase.call()` in `zuraffa/lib/src/domain/usecase.dart`: `pre` before `execute()`, `success` after success, `failure` after catching error. Preserve existing try-catch and `FailureReporterRegistry` calls unchanged. Create `HookContext` with shared `metadata` map per invocation.
- [x] T011 [US1] Add three `HookRegistry.instance.dispatch()` calls to `StreamUseCase.call()` in `zuraffa/lib/src/domain/stream_usecase.dart`: `pre` before stream starts, `success` after stream completes, `failure` if stream emits failure or throws.
- [x] T012 [P] [US1] Add `registerHook(Hook)`, `unregisterHook(String)`, and `hooksEnabled` setter to `Zuraffa` facade class in `zuraffa/lib/zuraffa.dart`
- [x] T013 [US1] Write integration test verifying UseCase dispatches to hooks at correct phases with correct context in `zuraffa/test/domain/usecase_hook_test.dart` (depends on T010)
- [ ] T014 [US1] Write integration test verifying StreamUseCase dispatches to hooks at correct phases in `zuraffa/test/domain/stream_usecase_hook_test.dart` (depends on T011)

**Checkpoint**: Generic hook system is fully functional. Any registered hook fires automatically on every UseCase/StreamUseCase execution.

---

## Phase 4: User Story 2 - Built-in TelemetryHook (Priority: P1)

**Goal**: Ship a `TelemetryHook` that auto-wraps every UseCase in an OTel span with `onlyUseCases`/`excludeUseCases` filtering.

**Independent Test**: Register `TelemetryHook()`, execute a UseCase, verify an OTel span named `usecase.{UseCaseName}` was created with status OK and `usecase.duration_ms` attribute.

### Implementation for User Story 2

- [x] T015 [P] [US2] Create `TelemetryHook` class extending `Hook` in `zuraffa/lib/src/core/telemetry_hook.dart` with `onlyUseCases`, `excludeUseCases`, `spanNamePrefix` constructor params. Override `phases` to all three, `id` to `'zuraffa-telemetry'`.
- [x] T016 [US2] Implement `shouldTrigger()` in `TelemetryHook` with filtering logic: skip if in `excludeUseCases`; if `onlyUseCases` non-empty, skip if not in it. `excludeUseCases` always wins. in `zuraffa/lib/src/core/telemetry_hook.dart` (depends on T015)
- [x] T017 [US2] Implement `execute()` in `TelemetryHook` with span lifecycle: `pre` phase calls `OtelTracer.instance.startSpan()` and stashes span in `context.metadata['_telemetry_span']`; `success` phase sets duration attribute and calls `endSpan()`; `failure` phase calls `endSpanWithError()` in `zuraffa/lib/src/core/telemetry_hook.dart` (depends on T016)
- [x] T018 [US2] Export `TelemetryHook` from `zuraffa/lib/zuraffa.dart`
- [x] T019 [US2] Write unit tests for `TelemetryHook` covering span creation, span ending on success/failure, `onlyUseCases` whitelist filtering, `excludeUseCases` blacklist filtering, both-filters-precedence in `zuraffa/test/core/telemetry_hook_test.dart` (depends on T017)

**Checkpoint**: `TelemetryHook` is shipped and tested. Users can register it with one line for automatic OTel tracing.

---

## Phase 5: User Story 3 - ZikZak EngagementHook Validation (Priority: P2)

**Goal**: Replace 8 manual engagement tracking calls in ZikZak controllers with a single `EngagementHook` registration. Zero controller boilerplate.

**Independent Test**: Register `EngagementHook(repository)` in ZikZak's `main()`, trigger a barcode scan, verify an `EngagementEvent(BARCODE_SCAN)` is stored in Hive. Verify zero `trackXxx()` calls remain in any controller.

### Implementation for User Story 3

- [x] T020 [P] [US3] Create `EngagementHook` class extending `Hook` in `zik_zak/lib/src/presentation/hooks/engagement_hook.dart` that takes `EngagementEventRepository` as constructor dependency
- [x] T021 [US3] Implement `useCaseEventMap` mapping 8 UseCase names to `EngagementEventType` enum values (BARCODE_SCAN, LINK_SHARE, DEAL_LIKE, DEAL_SHARE, LISTING_SHARE, ASK_ZIKZAK, VISIT_LINK, SEARCH_TERM) and `shouldTrigger()` checking the map in `zik_zak/lib/src/presentation/hooks/engagement_hook.dart` (depends on T020)
- [x] T022 [US3] Implement `execute()` calling `_repository.create(EngagementEvent(...))` with extracted payload from `HookContext.params` per UseCase type, `phases` set to `{HookPhase.success}` only in `zik_zak/lib/src/presentation/hooks/engagement_hook.dart` (depends on T021)
- [x] T023 [US3] Register `EngagementHook(getIt<EngagementEventRepository>())` in ZikZak's `main()` in `zik_zak/lib/main.dart` (depends on T022)
- [x] T024 [US3] Remove all `CreateTelemetryEventUseCase` calls and `trackXxx()` methods from controllers in `zik_zak/lib/src/presentation/pages/barcode_listing/barcode_listing_controller.dart`, `zik_zak/lib/src/presentation/pages/ask_zikzak/ask_zikzak_controller.dart`, `zik_zak/lib/src/presentation/pages/url_listing/url_listing_controller.dart`, `zik_zak/lib/src/presentation/pages/deal/deal_controller.dart`, and `zik_zak/lib/src/presentation/widgets/share/share_button.dart` (depends on T023)
- [x] T025 [US3] Verify zero `CreateTelemetryEventUseCase` or `TelemetryEvent` imports remain in any controller by running `grep -r "CreateTelemetryEventUseCase\|TelemetryEvent" zik_zak/lib/src/presentation/` (depends on T024)

**Checkpoint**: ZikZak engagement tracking is fully automated via hooks. Zero controller boilerplate remains.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, analysis, and final validation

- [x] T026 [P] Update `zuraffa/doc/HOOK_SYSTEM.md` with final implementation details (actual file paths, confirmed API signatures)
- [x] T027 [P] Run `dart format .` on all new and modified files in `zuraffa/`
- [x] T028 Run `dart analyze` with zero errors/warnings on modified files in `zuraffa/lib/src/core/hook.dart`, `zuraffa/lib/src/core/hook_registry.dart`, `zuraffa/lib/src/core/telemetry_hook.dart`, `zuraffa/lib/src/domain/usecase.dart`, `zuraffa/lib/src/domain/stream_usecase.dart`, `zuraffa/lib/zuraffa.dart`
- [x] T029 Run `flutter test test/core/hook_registry_test.dart test/core/telemetry_hook_test.dart test/domain/usecase_hook_test.dart test/domain/stream_usecase_hook_test.dart` and verify all pass
- [x] T030 Run validation scenarios from `specs/011-usecase-hook-system/quickstart.md` — scenarios 1-5 in Zuraffa, scenario 6 (EngagementHook) in ZikZak

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — verification only
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Foundational — implements UseCase dispatch integration
- **US2 (Phase 4)**: Depends on Foundational — can run in parallel with US1 (different files: `telemetry_hook.dart` vs `usecase.dart`)
- **US3 (Phase 5)**: Depends on US1 (needs working dispatch to fire the hook) and US2 (coexistence validation)
- **Polish (Phase 6)**: Depends on all user stories complete

### User Story Dependencies

- **US1 (P1)**: Can start after Foundational — no story dependencies
- **US2 (P1)**: Can start after Foundational — independent of US1 at code level (different files), but logically validates the dispatch system
- **US3 (P2)**: Depends on US1 (hooks must dispatch for EngagementHook to fire) and the existing ZikZak `EngagementEventRepository`

### Within Each User Story

- Core types before integration
- Implementation before tests
- Tests before moving to next story

### Parallel Opportunities

- Phase 2: T004, T005 are independent (different sections of `hook.dart`)
- Phase 3 & 4: US1 (`usecase.dart`, `stream_usecase.dart`) and US2 (`telemetry_hook.dart`) touch different files — can run in parallel
- Phase 5: T020 is independent of T021/T022 within the same file

---

## Parallel Example: US1 + US2

```bash
# These touch completely different files and can run in parallel:
# US1: Modify UseCase.call() and StreamUseCase.call()
Task: "Add dispatch calls to UseCase.call() in lib/src/domain/usecase.dart"
Task: "Add dispatch calls to StreamUseCase.call() in lib/src/domain/stream_usecase.dart"

# US2: Create TelemetryHook (new file)
Task: "Create TelemetryHook in lib/src/core/telemetry_hook.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (verify existing code)
2. Complete Phase 2: Foundational (Hook, HookContext, HookPhase, HookRegistry + tests)
3. Complete Phase 3: User Story 1 (dispatch integration in UseCase + StreamUseCase)
4. **STOP and VALIDATE**: Register a test hook, execute a UseCase, verify dispatch works

### Incremental Delivery

1. Foundational → Hook types and registry ready
2. US1 → UseCase dispatch works → MVP (generic hook system functional)
3. US2 → TelemetryHook shipped → Built-in OTel tracing available
4. US3 → ZikZak EngagementHook → Real-world validation, zero boilerplate
5. Polish → Format, analyze, test, validate quickstart scenarios

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- US3 tasks are in the ZikZak project (`zik_zak/`), not Zuraffa (`zuraffa/`)
- The existing `TrackEngagementEventUseCase` in ZikZak becomes dead code after US3 — do NOT delete it, just stop calling it
- All Zuraffa changes are non-breaking: existing `UseCase.call()` behavior is preserved, hooks are opt-in
