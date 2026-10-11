---
description: "Task list for spec 078 — skin-contract.v1 model, parser, schema emitter (issue #1164)"
---

# Tasks: skin-contract.v1 (issue #1164, stage 1/4 of #1111)

**Input**: Design documents from `/specs/078-skin-contract-schema/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Included — this feature IS tests-plus-model; the TDD loop drives behaviors first.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US3)

## Path Conventions

Single-package repo: source under `lib/src/skin/contract/` and `lib/src/plugins/tdd/`, tests under `test/plugins/`.

## Phase 1: Setup

- [ ] T001 Confirm baseline: `dart test test/plugins/skin_contract/ 2>/dev/null || echo "suite absent (expected)"` and `dart test test/plugins/tdd/ --plain-name "skin"` scoped green set recorded on branch `078-skin-contract-schema`.

## Phase 2: Foundational

- [ ] T002 [P] Create the typed model `lib/src/skin/contract/skin_contract.dart` per `data-model.md` (SkinContract, ContractRoute, ContractState, ContractPlatformRow, ContractStateRow) with a declarative field table the schema generator walks.
- [ ] T003 [P] Create the strict parser `lib/src/skin/contract/skin_contract_parser.dart`: `fromJson` failing with errors that name the offending section/key; unknown fields, missing sections, and wrong `schemaVersion` all fail.

## Phase 3: User Story 1 — Parse a skin contract (P1)

**Goal**: valid JSON → populated model; malformed → named error.
**Independent Test**: parser unit tests on valid/malformed/unknown-field inputs.

- [ ] T004 [behavior: A1, U1, U2, U3] [US1] [behavior: A1, U1, U2, U3] (MANDATORY — test task T005 must be red first) Implement round-trip `toJson` on the model: model → JSON → model is lossless for every field.
- [ ] T005 [behavior: A1, U1, U2, U3] [P] [US1] [behavior: A1, U1, U2, U3] MANDATORY behavioral tests in `test/plugins/skin_contract/skin_contract_parser_test.dart` (write FIRST, prove red): valid contract parses fully populated; missing section / unknown field / wrong version each fail naming the culprit; round-trip is lossless.

## Phase 4: User Story 2 — Schema generated + emitted by zfa tdd plan (P2)

**Goal**: `04-skin-contract.schema.json` generated from the model, written only for contract-bearing specs.
**Independent Test**: emitter tests — contract-bearing spec writes/overwrites the schema; spec without the section writes nothing; schema is valid JSON Schema covering every model field.

- [ ] T006 [behavior: A2, U4, U5, U7] [US2] [behavior: A2, U4, U5, U7] (MANDATORY — test task T008 first) Schema generator `lib/src/skin/contract/skin_contract_schema.dart`: builds valid JSON Schema from the model's field table (required fields, additionalProperties: false).
- [ ] T007 [behavior: A2, A3, U4, U6] [US2] [behavior: A2, A3, U4, U6] Emitter hook in `lib/src/plugins/tdd/commands/plan_command.dart`: spec carries `## Skin Contract:` → write (or deterministically overwrite) `specs/<feature>/tdd/04-skin-contract.schema.json`; absent section → no write.
- [ ] T008 [behavior: A2, A3, U4, U5, U6, U7] [P] [US2] [behavior: A2, A3, U4, U5, U6, U7] MANDATORY behavioral tests in `test/plugins/tdd/plan_skin_contract_test.dart` (write FIRST, prove red): emitter write/no-op/overwrite cases + schema validity + field-parity both directions (no drift, no orphans).

## Phase 5: User Story 3 — Repo-wide schema conformance (P2)

**Goal**: every contract-bearing spec in `specs/` is continuously validated.
**Independent Test**: the suite passes on the current tree and fails naming spec+key when a contract violates the schema.

- [ ] T009 [behavior: A3, A6, A7, U6] [US3] [behavior: A3, U6] (MANDATORY — test task T010 first) `test/plugins/skin_contract/schema_test.dart`: walk `specs/*`, discover `## Skin Contract:` sections, parse each, validate against the generated schema; failures name the spec path and violating key.
- [ ] T010 [behavior: A7, U6] [P] [US3] [behavior: A3, U6] MANDATORY negative-path test: a deliberately broken contract fixture fails validation naming the spec and key (fixture lives under the test's own fixtures, not `specs/`).

## Phase 6: Polish & Cross-Cutting

- [ ] T011 Update the 006-login-skin spec (or the first contract-bearing spec) if its Skin Contract section predates the v1 shape — the repo-wide test must pass on the real tree.
- [ ] T012 Run `dart format lib test` (scoped to touched dirs first; full pass at commit) and `dart analyze` on all touched paths.

## Dependencies

- T002, T003 parallel → T004/T005 → T006/T007/T008 → T009/T010 → T011/T012.
- T007 depends on T006; T009 depends on T006 + T007 (validates against the generated schema).

## Parallel Execution Examples

- T002 with T003; T005 with T008 after their implementation tasks; T009 with T010.

## Implementation Strategy

- MVP = US1 (parser + round-trip): the model everything else consumes.
- US2 is the generated-schema guarantee; US3 is the standing enforcement.
- All behaviors are CORE-lane pure Dart — no Flutter, no sandbox needed for this stage.
