---
description: "Task list for spec 077 — `zfa make engine` one-shot preset (issue #1109)"
---

# Tasks: `zfa make engine` One-Shot Preset (issue #1109)

**Input**: Design documents from `/specs/077-make-engine-preset/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Included — the spec mandates trust-tier behavioral suites (FR-011) and the TDD pipeline drives behavior tests first.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US4)

## Path Conventions

Single-package CLI repo: source under `lib/src/`, tests under `test/`.

## Phase 1: Setup

- [ ] T001 Verify baseline: `dart test test/plugins/di/ test/engine/` (or the closest existing engine suite paths) passes on branch `077-make-engine-preset` before any change; record the green set.

## Phase 2: Foundational

- [ ] T002 [P] Add `EngineFindingCode.staticAnalysis` (or equivalent) to the failure taxonomy in `lib/src/engine/engine_models.dart` and carry analyzer findings through `EngineCheckFailure`.
- [ ] T003 [P] Extend `lib/src/engine/engine_receipt_writer.dart` with a v2 writer: `specs/<feature>/tdd/engine.receipt.json` per `contracts/engine-receipt-v2.md` (atomic overwrite, `mock_class` capture, `source_files` sorted). Keep the `.zfa/engine.receipt.json` v1 writer untouched.

## Phase 3: User Story 1 — One-shot engine slice generation (P1)

**Goal**: `zfa make engine <Entity>` completes the chain and writes the issue-shaped receipt.
**Independent Test**: Generate a slice in a temp/sandbox project; verify receipt v2 contents and slice completeness.

- [ ] T004 [US1] [behavior: A1, A2, A3, U1, U7, U8] (MANDATORY — test task T005 must be red first) Wire the certifier's per-method mock class names into the make-command engine tail and write receipt v2 after certification in `lib/src/commands/make_command.dart` (uses T003 writer).
- [ ] T005 [P] [US1] [behavior: A1, A2, A3, U1, U7, U8] MANDATORY behavioral test (write FIRST, prove red): receipt v2 written to `specs/<feature>/tdd/engine.receipt.json` with correct `methods[].{name, mock_certified, mock_class}` and `source_files` after a make-engine run, and slice completeness for requested methods only (temp-project test under `test/engine/`).

## Phase 4: User Story 2 — Idempotent regeneration (P2)

**Goal**: Generated DI is unregister-first; `resetDependencies()` emitted; double setup never throws.
**Independent Test**: Run DI generation twice; compile generated index; call setup twice and reset→setup in a test.

- [ ] T006 [US2] [behavior: A4, A5, U5, U12] (MANDATORY — test task T008 must be red first) Change registration-call emission in `lib/src/plugins/di/di_plugin.dart` so every generated registration is unregister-first (`if (getIt.isRegistered<T>()) getIt.unregister<T>();` before `registerXxx`).
- [ ] T007 [US2] [behavior: A6, U6, U12] Change DI index emission in `lib/src/plugins/di/di_plugin.dart` to also emit `resetDependencies(getIt)` (unregistering every registered type) alongside `setupDependencies`.
- [ ] T008 [P] [US2] [behavior: A4, A5, A6, U5, U6, U12] MANDATORY behavioral tests in `test/plugins/di/` (write FIRST, prove red): (a) generated `setupDependencies` contains unregister-first for each registration and compiles; (b) calling setup twice and reset→setup does not throw (compile/executable test on generated source).

## Phase 5: User Story 3 — Engine check certification gate (P2)

**Goal**: `zfa engine check` runs analyze + receipt + import-boundary legs with actionable output.
**Independent Test**: Healthy slice → exit 0; injected UI import / uncertified method / analyze error → non-zero naming the cause.

- [ ] T009 [US3] [behavior: A7, A10, U9, U10] (MANDATORY — test task T011 must be red first) Add the static-analysis leg to `lib/src/engine/engine_checker.dart`: run `dart analyze` scoped to the entity's slice files, map findings to `EngineCheckFailure`s with file + message; surface in `lib/src/commands/engine_command.dart` output and JSON format.
- [ ] T010 [US3] [behavior: A8, A9, U9, U10] Add the receipt-v2 leg to the checker: read `specs/<feature>/tdd/engine.receipt.json` (v2 writer from T003), fail on missing receipt or any `mock_certified: false`, naming the method.
- [ ] T011 [P] [US3] [behavior: A7, A8, A9, A10, U9, U10] MANDATORY behavioral tests in `test/engine/` (write FIRST, prove red): healthy slice exits 0; UI import → non-zero naming file; uncertified method in receipt → non-zero naming method; analyze-dirty slice → non-zero with analyzer message.

## Phase 6: User Story 4 — Trust-tier generator tests (P3)

**Goal**: ≥2 behavioral tests (structural + compile) per generated artifact type.
**Independent Test**: Run the five suites; each green with the required depth.

- [ ] T012 [P] [US4] [behavior: A11, A12, U11] (MANDATORY — each audit writes its behavioral tests first) Audit `test/plugins/usecase/` for the structural + compile behavioral bar; add missing behavioral tests (generated file exists, signatures correct, source analyzes clean).
- [ ] T013 [P] [US4] [behavior: A11, A12, U11] Same audit + additions for `test/plugins/service/`.
- [ ] T014 [P] [US4] [behavior: A11, A12, U11] Same audit + additions for `test/plugins/repository/`.
- [ ] T015 [P] [US4] [behavior: A11, A12, U11] Same audit + additions for `test/plugins/datasource/`.
- [ ] T016 [P] [US4] [behavior: A11, A12, U11] Same audit + additions for `test/plugins/mock/` (certifier path).

## Phase 7: Polish & Cross-Cutting

- [ ] T017 Update `.zfa/` engine-check-related docs/help text if the check output contract changed (`lib/src/commands/engine_command.dart` usage text).
- [ ] T018 Run `dart format lib test` (AGENTS.md commit gate) and `dart analyze` on all touched paths.
- [ ] T019 Sandbox validation per `quickstart.md` §2–§3: `zfa make engine User --methods=get,create` + `zfa engine check User` in `~/zik_zak_test`; on any zfa misfire, STOP and record per the AGENTS.md stop-on-roadblock rule.

## Dependencies

- T002, T003 parallel; T004 after T003; T005 after T004.
- T006 → T007 → T008.
- T009, T010 after T003 (receipt leg reads v2); T011 after T009/T010.
- T012–T016 parallel, independent of US1–US3.
- T018, T019 last.

## Parallel Execution Examples

- Phase 2: T002 with T003.
- Phase 6: T012–T016 all parallel.
- US2 and US3 phases are independent of each other once Phase 2 lands.

## Implementation Strategy

- MVP = Phase 3 (US1): one-shot generation + receipt v2 is the deliverable.
- US2 and US3 are the correctness gates the issue blocks on; US4 is protective depth.
- T019 is the issue's explicit proof step — never skipped, and governed by the stop-on-roadblock rule.
