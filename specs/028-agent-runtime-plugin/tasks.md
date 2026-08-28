# Tasks: Agent Runtime Plugin

**Input**: Design documents from `/specs/028-agent-runtime-plugin/` (spec.md, plan.md)

**Tests**: All implementation tasks include paired test tasks (test-first). Tests under `test/agent/runtime/`.

**Organization**: MVP-first. MVP tasks prefixed `[MVP]`.

## Path Conventions

- Source: `lib/src/agent/runtime/...`
- Tests: `test/agent/runtime/...`
- Public exports via `lib/zuraffa.dart`.

---

## Phase 1: Setup

- [ ] T001 [MVP] Create `lib/src/agent/runtime/` directory
- [ ] T002 [MVP] Create `agent_runtime_plugin.dart` barrel
- [ ] T003 [MVP] Export barrel from `lib/zuraffa.dart`

## Phase 2: SPI & Registry (FR-001, FR-002, FR-003, FR-004, FR-012)

- [ ] T004 [MVP] Implement `McpToolProvider` SPI interface (namespace + buildTools)
- [ ] T005 [MVP] Implement `McpToolContext` (DI accessor passed to buildTools)
- [ ] T006 [MVP] Implement `McpTool` (name, description, inputSchema, invoke)
- [ ] T007 [MVP] Implement `McpToolRegistry` (flat map; collision detection FR-012)
- [ ] T008 [MVP] Implement in-proc serving path (LocalMcpTransport interface; zero IPC)
- [ ] T009 [MVP] Implement DI/engine registration of McpToolProvider (FR-002)
- [ ] T010 [MVP] Test: SPI provider builds tools via DI
- [ ] T011 [MVP] Test: registry assembles from 3 sources (SPI + usecase + remote)
- [ ] T012 [MVP] Test: namespace collision detected + prevented (FR-012)

## Phase 3: Mission & Kernel (FR-005, FR-008, FR-013)

- [ ] T013 [MVP] Implement `Mission` (missionId, spark, country/locale, budgets, toolAllowlist, riskTier)
- [ ] T014 [MVP] Implement `MissionEvent` sealed class (typed stream events)
- [ ] T015 [MVP] Implement `AgentKernel` with `runMission(Mission): Stream<MissionEvent>`
- [ ] T016 [MVP] Implement `StatefulAgent` SPI interface (delegate target; FR-013)
- [ ] T017 [MVP] Wire AgentKernel to delegate to StatefulAgent.runStream (FR-005, FR-013)
- [ ] T018 [MVP] Test: 3-tool mission (1 SPI + 1 usecase) streams typed events (SC-001)
- [ ] T019 [MVP] Test: agent-loop delegation — no duplication (FR-013)

## Phase 4: System Prompt & LLM (FR-006, FR-007)

- [ ] T020 [MVP] Implement `SystemPromptComposer` (playbook + tool manifests)
- [ ] T021 [MVP] Implement `LlmClient` interface + `FallbackLLMClient` (FR-007)
- [ ] T022 [MVP] Wire FallbackLLMClient as default
- [ ] T023 [MVP] Test: system prompt composition
- [ ] T024 [MVP] Test: FallbackLLMClient default wiring

## Phase 5: State Persistence (FR-009)

- [ ] T025 [MVP] Implement `AgentState` + `FileStateStorage` interface (per-mission)
- [ ] T026 [MVP] Test: session state persisted + resumed

## Phase 6: Hooks (FR-010)

- [ ] T027 [MVP] Implement `AgentHook` (ordered; lifecycle points)
- [ ] T028 [MVP] Test: hooks run in registration order

## Phase 7: Status (FR-011)

- [ ] T029 [MVP] Implement `KernelStatus` (providers, toolCountPerNamespace, remoteServerHealth)
- [ ] T030 [MVP] Implement `kernel.status()` (FR-011)
- [ ] T031 [MVP] Test: kernel.status() reports accurate state

## Phase 8: Verification

- [ ] T032 Run `dart analyze` clean
- [ ] T033 Run `dart test test/agent/runtime/` — all green
- [ ] T034 Test: remote SSE tools merged + collision prevented (SC-002)
- [ ] T035 Write `tdd/verification.md`
- [ ] T036 Commit + push + PR
