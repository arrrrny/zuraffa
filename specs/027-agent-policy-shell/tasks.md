# Tasks: Agent Policy Shell

**Input**: Design documents from `/specs/027-agent-policy-shell/` (spec.md, plan.md)

**Tests**: All implementation tasks include paired test tasks (test-first). Tests under `test/agent/policy/`.

**Organization**: MVP-first. MVP tasks prefixed `[MVP]`.

## Path Conventions

- Source: `lib/src/agent/policy/...`
- Tests: `test/agent/policy/...`
- Public exports via `lib/zuraffa.dart`.

---

## Phase 1: Setup

- [ ] T001 [MVP] Create `lib/src/agent/policy/` directory
- [ ] T002 [MVP] Create `policy_shell.dart` barrel
- [ ] T003 [MVP] Export barrel from `lib/zuraffa.dart`

## Phase 2: Policy Hook Framework (FR-011)

- [ ] T004 [MVP] Implement `PolicyHook` abstract class (id, enabled, beforeToolCall, afterToolCall, beforeRun, afterRun)
- [ ] T005 [MVP] Implement `PolicyShell` that composes hooks in registration order; each hook can be disabled individually
- [ ] T006 [MVP] Implement `ToolCallContext` (missionId, toolName, args, mission object, internal flag)

## Phase 3: Tool Gating (FR-001, FR-002, FR-003, FR-004, FR-012)

- [ ] T007 [MVP] Implement `RiskLevel` enum (safe, confirm, admin)
- [ ] T008 [MVP] Implement `PermissionRegistry` (tool name → risk level; most-restrictive-wins on conflict)
- [ ] T009 [MVP] Implement `ToolGatingHook` (evaluates before every tool call; emits typed UI approval for confirm; denies admin for non-internal)
- [ ] T010 [MVP] Implement timeout for confirm-tier (deny on timeout)
- [ ] T011 [MVP] Implement per-mission tool allowlist (deny if tool not in allowlist)
- [ ] T012 [MVP] Read tool risk metadata from agent core when registry entry missing (FR-012)
- [ ] T013 Test: safe-tier auto-executes
- [ ] T014 Test: confirm-tier blocks until approved (and denies on timeout)
- [ ] T015 Test: admin-tier denied for non-internal mission
- [ ] T016 Test: admin-tier allowed for internal mission
- [ ] T017 Test: per-mission allowlist overrides risk level
- [ ] T018 Test: most-restrictive-wins on registry conflict (edge case)

## Phase 4: Mission Budget (FR-005, FR-006, FR-013)

- [ ] T019 [MVP] Implement `MissionBudget` (4 dimensions: calls, wall-clock, tokens, per-tool-class seconds)
- [ ] T020 [MVP] Implement `MissionBudgetHook` (checks budget before each tool call; emits typed budget-exceeded event + cancels mission on breach)
- [ ] T021 [MVP] Implement `BudgetBreach` typed event (carries which limit + current + max)
- [ ] T022 Implement budget-degrade integration point (FR-013) — callback for model-client interaction
- [ ] T023 Test: max-calls exceeded → cancel with calls-limit reason
- [ ] T024 Test: max-wall-clock exceeded → cancel with time-limit reason
- [ ] T025 Test: max-tokens exceeded → cancel with token-limit reason
- [ ] T026 Test: per-tool-class seconds exceeded → cancel with per-tool-class reason
- [ ] T027 Test: budget=0 → immediate cancel on first call (edge case)

## Phase 5: Mission Trace (FR-007, FR-008, FR-009)

- [ ] T028 [MVP] Implement `ToolCallRecord` (name, argsHash, duration, status, tokenUsage, provider)
- [ ] T029 [MVP] Implement `MissionTrace` (missionId, inputHash, planSteps, toolCallRecords, duration, status, outcome)
- [ ] T030 [MVP] Implement `MissionTraceRecorder` (append-only; concurrent-streaming safe via single-isolate)
- [ ] T031 [MVP] Hash all args by default; allowlist fields recorded in cleartext (FR-008)
- [ ] T032 [MVP] Implement `toJson()` producing schema-valid JSON
- [ ] T033 Test: 20+ tool calls → schema-valid replayable JSON (SC-003)
- [ ] T034 Test: args hashed by default
- [ ] T035 Test: allowlist fields in cleartext
- [ ] T036 Test: concurrent streaming — no corruption (FR-009)

## Phase 6: Oversized Result Guard (FR-010)

- [ ] T037 [MVP] Implement `ArtifactReference` (uri, size, sha256)
- [ ] T038 [MVP] Implement `OversizedResultGuard` (intercepts results > threshold; swaps with artifact reference)
- [ ] T039 [MVP] Test: oversized result never enters model context (SC-004)
- [ ] T040 Test: artifact storage unavailable → truncated with marker (edge case)

## Phase 7: Composition & Verification

- [ ] T041 [MVP] Wire all three hooks into `PolicyShell`; each individually disableable
- [ ] T042 Run `dart analyze` clean
- [ ] T043 Run `dart test test/agent/policy/` — all green
- [ ] T044 Write `tdd/verification.md` mapping FRs/SCs to tests
- [ ] T045 Commit + push + PR
