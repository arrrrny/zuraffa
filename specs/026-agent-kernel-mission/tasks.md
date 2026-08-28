# Tasks: Agent Kernel — Mission Coalescing, Cancellation & Partial-Salvage

**Input**: Design documents from `/specs/026-agent-kernel-mission/` (spec.md, plan.md)

**Prerequisites**: plan.md (required), spec.md (required for user stories).

**Tests**: All implementation tasks include paired test tasks (test-first). Tests live under `test/agent/kernel/`.

**Organization**: MVP-first. Tasks grouped by phase. MVP-critical tasks prefixed `[MVP]`.

## Path Conventions

- Single project (pure-Dart `zuraffa` package).
- Source: `lib/src/agent/kernel/...`
- Tests: `test/agent/kernel/...`
- Public exports via `lib/zuraffa.dart` (new `agent_kernel.dart` barrel added).

---

## Phase 1: Setup

- [ ] T001 [MVP] Create `lib/src/agent/kernel/` directory
- [ ] T002 [MVP] Create `lib/src/agent/kernel/agent_kernel.dart` barrel file
- [ ] T003 [MVP] Export the barrel from `lib/zuraffa.dart`

## Phase 2: Foundational Types

- [ ] T004 [MVP] Implement `MissionKey` (composite key: sparkType + normalizedValue + country + strategyVariant + stable string + hashCode)
- [ ] T005 [MVP] Implement `Mission` (status, outcome, partials, subscribers)
- [ ] T006 [MVP] Implement `MissionStatus` enum (`pending`, `running`, `cancelled`, `completed`, `failed`)
- [ ] T007 [MVP] Implement `MissionOutcome` sealed class (`completed`, `cancelled_partial`, `failed`, `cached_served`)
- [ ] T008 [MVP] Implement `ResourceHandle` interface (dispose() returns Future) + a `FakeResourceHandle` for tests
- [ ] T009 [MVP] Implement `MissionEvent` sealed class (progress / partial / completed / failed / cancelled)

## Phase 3: Coalescing (FR-001, FR-002, FR-010)

- [ ] T010 [MVP] Implement `CoalescingGroup` (running mission + broadcast stream + subscriber set + completion completer)
- [ ] T011 [MVP] Implement `MissionCoalescer` (lookup-or-create group; attach subscriber; fan-out events)
- [ ] T012 [MVP] Make coalescing window configurable via `KernelConfig.coalescingWindow` (default 50ms)
- [ ] T013 [MVP] Test: 50 identical submissions → exactly 1 executes (SC-001)
- [ ] T014 Test: late subscribers receive pending partial-progress events
- [ ] T015 Test: differing strategy variant → no coalescing (independent runs)

## Phase 4: Cancellation & Partial Salvage (FR-003, FR-004, FR-005, FR-006)

- [ ] T016 [MVP] Implement `CancelToken` (trigger + grace period + completion signal)
- [ ] T017 [MVP] Implement grace-period resource disposal (Future.any over all `ResourceHandle.dispose()` with timeout)
- [ ] T018 [MVP] Implement partial-salvage protocol (record partials as `cancelled_partial`)
- [ ] T019 [MVP] Implement post-cancellation zero-leak assertion (assert pool empty, streams closed, no orphaned handles)
- [ ] T020 [MVP] Implement subscriber-survives-original-cancel (continue / escalate / serve-partial per policy)
- [ ] T021 Test: mid-exec cancel disposes all resources (SC-002)
- [ ] T022 Test: zero-leak assertion passes after cancellation
- [ ] T023 Test: original caller cancels → subscribers continue (FR-003)

## Phase 5: Idempotency Cache (FR-007)

- [ ] T024 [MVP] Implement `IdempotencyCache` (TTL-bounded; lookup-or-store; evict-expired-on-read)
- [ ] T025 Test: re-submit within TTL → cached outcome, no re-exec (SC-004a)
- [ ] T026 Test: re-submit after TTL → fresh execution (SC-004b)
- [ ] T027 Test: TTL=0 (disabled) → always fresh

## Phase 6: Introspection (FR-008)

- [ ] T028 Implement `Introspection` endpoints: `activeMissions()`, `waitingSubscribers(key)`, `coalescingWindow()`
- [ ] T029 Test: introspection returns correct active mission + subscriber count
- [ ] T030 Test: completed mission no longer appears in `activeMissions`

## Phase 7: Documentation & Multi-Isolate Extension Point (FR-009)

- [ ] T031 Document single-isolate assumption in `agent_kernel.dart` library doc comment
- [ ] T032 Provide `MissionExecutor` and `ResourceRegistry` as injectable interfaces (multi-isolate extension point)

## Phase 8: Verification

- [ ] T033 Run `dart analyze` clean on `lib/src/agent/kernel/` + `test/agent/kernel/`
- [ ] T034 Run `dart test test/agent/kernel/` — all green
- [ ] T035 Run mixed-load test: 200 missions (80% dup) — no deadlock, bounded memory (SC-003)
- [ ] T036 Write `tdd/verification.md` mapping FRs/SCs to tests
- [ ] T037 Commit + push + PR
