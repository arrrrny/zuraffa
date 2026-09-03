---
description: "Task list for feature implementation"
---

# Tasks: Declared-Intent Routing (071)

**Input**: Design documents from `/specs/071-declared-intent-routing/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: INCLUDED — the delivery runs the TDD red-green loop (spec-whole; tdd.profile present). Test tasks are marked and MUST be written to fail before their implementation task.

**Organization**: Tasks grouped by user story (US1–US5 from spec.md) so each story is independently implementable and testable.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US5)
- Include exact file paths in descriptions

## Path Conventions

- Pure-Dart single project: `lib/src/plugins/tdd/` (source), `test/plugins/tdd/` (tests)

---

## Phase 1: Setup

**Purpose**: Baseline capture — prove the tree starts green before any behavior work.

- [ ] T001 Run the tdd plugin fast tier (`dart test test/plugins/tdd`) and record the baseline result (expected: all green at commit `37a46c5b`); any pre-existing red is documented in `specs/071-declared-intent-routing/tdd/cycle-log.md` before work begins.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The declaration vocabulary and the ladder owner every story consumes.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T002 [P] Create routing vocabulary models in `lib/src/plugins/tdd/models/routing.dart`: `GenerationSurface` enum (`entityPipeline`, `dependencyMake`, `viewGeneration`, `plainFunction`, `none`), `Signature` (name/parameters/returnType), `ProvenanceLine` (aspect/source/detail/specLine), `RoutingFailureCode` enum (`declarationConflict`, `danglingReference`, `malformedDeclaration`, `undeclaredStrict`) — per data-model.md.
- [x] T003 [P] Create `Signature` parsing (`name(Params) -> Return`) for Layer-Contracts signature text in `lib/src/plugins/tdd/services/routing_resolver.dart` (pure functions; malformed text yields `RoutingFailureCode.malformedDeclaration` with the offending row text).
- [x] T004 Implement the `RoutingResolver` ladder in `lib/src/plugins/tdd/services/routing_resolver.dart`: `resolve({row, declarations, strict})` → `RoutingDecision | RoutingFailure` implementing rungs 1–3 + strict gate + per-aspect resolution and provenance assembly (kind, surface, entity, signature, persistence), per contracts/routing-resolver.md. Depends on T002, T003.
- [x] T005 MANDATORY [behavior: U1] Write `test/plugins/tdd/services/routing_resolver_test.dart` FIRST (RED before T004): ladder precedence (marker beats row beats section beats fallback), per-aspect mixing, `declarationConflict` names both lines, `danglingReference`, `malformedDeclaration`, strict `undeclaredStrict`, determinism, fallback labeling with fix hint. Depends on T002, T003.

**Checkpoint**: Foundation ready — the ladder is unit-testable; story work can begin.

---

## Phase 3: User Story 1 — Scenario lanes route from declarations (Priority: P1) 🎯 MVP

**Goal**: Lane classification reads scenario declarations (`**Type**` marker, contract-row trace) first; the UI-intent keyword regex becomes a labeled fallback; reworded prose changes nothing.

**Independent Test**: A spec whose scenarios carry routing verbs in every tense routes identically to the reworded variant; marker-declared widget scenarios never route to the func surface (the #950 replay), past-tense scenarios keep their lane (the #936 replay).

### Tests for User Story 1 (write FIRST, ensure RED)

- [x] T006 [P] [US1] MANDATORY [behavior: U2] Write `test/plugins/tdd/services/spec_parser_declarations_test.dart` (RED): parses `**Type**: <kind>` markers into scenario declarations with spec lines; rejects duplicate markers; unparsed specs yield empty declarations.
- [x] T007 [P] [US1] MANDATORY [behavior: A1] Write plan-level replay pins in `test/plugins/tdd/commands/plan_routing_provenance_test.dart` (RED): a marker-declared widget scenario whose text says "renders" plans the widget lane; a past-tense scenario ("rendered", "navigated") keeps its declared lane; reworded prose produces identical routing.

### Implementation for User Story 1

- [x] T008 [US1] Parse `**Type**` scenario markers in `lib/src/plugins/tdd/services/spec_parser.dart` into `ScenarioDeclaration`s (id, kind, specLine) per contracts/template-declarations.md §1. Depends on T006 (RED).
- [x] T009 [US1] Demote `uiAcceptanceIntent` in `lib/src/plugins/tdd/services/spec_parser.dart` to the fallback rung: `_extractAcceptance` consults declarations first, regex only when undeclared (fallback window), provenance labeled either way. Depends on T008, T004.
- [x] T010 [US1] Surface declared lanes through `lib/src/plugins/tdd/commands/plan_command.dart` test-list rendering (marker-declared widget rows land in `## Outer loop: widget behaviors`) and confirm `GenerationPlanner.plan()`'s existing kind dispatch (#950/#835 guards) routes them. Depends on T009.
- [x] T011 [US1] Verify T007 pins green + no regression in `test/plugins/tdd/services/spec_parser_test.dart` and the make widget suites. Depends on T010.

**Checkpoint**: Lanes are declaration-driven end to end; MVP of the routing story.

---

## Phase 4: User Story 2 — Generation surface + signatures from contract rows (Priority: P2)

**Goal**: The planner picks the generation surface from the behavior's contract-row trace and derives subject signatures from declared signatures; entity naming reads declared rows; prose extraction/inference become labeled fallbacks.

**Independent Test**: A spec with an entity row, a function row (declared signature), and a presentation row plans entity pipeline / `tdd func` with the declared return type / `tdd view` respectively — including a case where prose verbs would have inferred the wrong surface under legacy matching.

### Tests for User Story 2 (write FIRST, ensure RED)

- [x] T012 [P] [US2] MANDATORY [behavior: U3] Write `test/plugins/tdd/services/function_contracts_parsing_test.dart` (RED): the `**Function**` Layer Contracts bullet parses into rows with parsed signatures; a bullet missing `->` is a `malformedDeclaration` naming the row.
- [ ] T013 [P] [US2] MANDATORY [behavior: A2] Write planner surface pins in `test/plugins/tdd/services/generation_planner_declared_test.dart` (RED): entity-row trace → entity pipeline steps; function-row trace → `tdd func` with declared signature; presentation-row trace → view-lane unexpressible; undeclared behaviors fall back labeled (planner reason carries provenance).

### Implementation for User Story 2

- [x] T014 [US2] Parse the `**Function**` contracts bullet in `lib/src/plugins/tdd/services/spec_parser.dart` (`parseLayerContracts` gains the function layer; signatures via T003 parser). Depends on T012 (RED).
- [ ] T015 [US2] Route `GenerationPlanner.plan()` through the resolver in `lib/src/plugins/tdd/services/generation_planner.dart`: declared surface decides the plan (entity pipeline / dependency make / view / func); the id-prefix and prose branches become the fallback rung with labeled reasons; `_extractEntityName`/`_extractCapitalizedTrace` run only when no entity row is declared, with fallback provenance naming the Key Entities row to declare. Depends on T004, T013 (RED).
- [ ] T016 [US2] Prefer declared signatures in `lib/src/plugins/tdd/commands/func_command.dart` and the wire path: contract-row signature first, `subject_signature_deriver.dart` as labeled fallback. Depends on T014, T015.
- [ ] T017 [US2] Verify T013 pins green + the #920 replay (an entity-fields FR with a declared String function signature scaffolds `String`, not `int`) + existing planner suites stay green. Depends on T016.

**Checkpoint**: Surfaces, signatures, and entity attribution are declaration-driven.

---

## Phase 5: User Story 3 — Persistence marking declared, not sniffed (Priority: P3)

**Goal**: The `[persistence]` mark triggers from `[persistent]` FR tags or storage-dependency traces; `PersistenceMarker.keywords` becomes the labeled fallback.

**Independent Test**: "caches the result for display" (undeclared) is unmarked; "[persistent] The cart survives an app restart" is marked; a trace to a `storage:` dependency row marks without storage vocabulary.

### Tests for User Story 3 (write FIRST, ensure RED)

- [ ] T018 [P] [US3] MANDATORY [behavior: U4] Write `test/plugins/tdd/services/persistence_declaration_test.dart` (RED): tag → marked; storage-dependency trace → marked; storage vocabulary without declaration → unmarked; fallback marking labeled in provenance.

### Implementation for User Story 3

- [ ] T019 [US3] Parse `[persistent]` FR tags and storage-dependency traces into `PersistenceDeclaration`s in `lib/src/plugins/tdd/services/spec_parser.dart`. Depends on T018 (RED).
- [ ] T020 [US3] Switch the mark trigger in `lib/src/plugins/tdd/services/test_list_reader.dart` / `lib/src/plugins/tdd/commands/plan_command.dart` (`_marked`) to declarations, keywords demoted to fallback (read-side `PersistenceMarker.extract` unchanged). Depends on T019, T004.
- [ ] T021 [US3] Verify T018 pins green + existing persistence suites (`plan_persistence_marking_833_test.dart` family) stay green. Depends on T020.

**Checkpoint**: Persistence harnesses appear exactly where declared.

---

## Phase 6: User Story 4 — Routing provenance per behavior (Priority: P4)

**Goal**: `zfa tdd plan` prints one `route:` line per behavior (declared or fallback, naming spec lines) and writes provenance into the test list artifact.

**Independent Test**: A mixed spec plans with every behavior's `route:` line naming a real declaration (or a labeled fallback + fix hint) that exists in the spec.

### Tests for User Story 4 (write FIRST, ensure RED)

- [ ] T022 [P] [US4] MANDATORY [behavior: A3] Write provenance rendering pins in `test/plugins/tdd/commands/plan_routing_provenance_test.dart` (RED, extend T007 file): `route:` line grammar per contracts/cli-routing.md (declared/fallback bracket tokens, spec-line references), provenance block persisted into the test list.

### Implementation for User Story 4

- [ ] T023 [US4] Emit per-behavior `route:` lines from `lib/src/plugins/tdd/commands/plan_command.dart` (resolver decisions → rendered provenance) and persist the provenance block into the test-list artifact. Depends on T022 (RED), T010, T020.
- [ ] T024 [US4] Verify T022 pins green + plan command suites (`plan_command_ffi_835_test.dart`, `plan_gen_contract_test.dart`) stay green. Depends on T023.

**Checkpoint**: Routing is inspectable per behavior, in terminal and artifact.

---

## Phase 7: User Story 5 — Strict mode (Priority: P5)

**Goal**: `--strict-routing` makes undeclared intent a fix-naming refusal; fallbacks unreachable; conflicts/dangling/malformed declarations refuse with spec-line errors.

**Independent Test**: Undeclared behavior + `--strict-routing` → exit 1 with `--> fix:` naming the spec line; the five bug-class replays cannot reproduce; fully declared specs behave identically to the fallback window.

### Tests for User Story 5 (write FIRST, ensure RED)

- [ ] T025 [P] [US5] MANDATORY [behavior: A4] Write strict-mode pins in `test/plugins/tdd/commands/plan_routing_provenance_test.dart` (RED): strict refusal message shape (behavior id + spec line + `--> fix:` declaration), exit code 1, no fallback routes in output; conflict/dangling refusals surface at plan time; declared-only spec plans clean under strict.

### Implementation for User Story 5

- [ ] T026 [US5] Add `--strict-routing` to `lib/src/plugins/tdd/commands/plan_command.dart` (flag + project-config opt-in, flag wins): wire `strict` into resolver calls, render refusals per contracts/cli-routing.md, exit 1. Depends on T025 (RED), T023.
- [ ] T027 [US5] Honor strict mode in `lib/src/plugins/tdd/commands/make_command.dart` planning (no fallback routes when strict; refusals carry the same fix-naming shape). Depends on T026.
- [ ] T028 [US5] Verify T025 pins green + the five replay pins from T007/T013/T018 pass under strict + full fast tier green. Depends on T027.

**Checkpoint**: The defect class is unreachable; routing is declaration-only when strict.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T029 [P] Document the v1.1 declarations (marker, traces, function bullet, `[persistent]`) in `openwiki/` (authoring guide page) per contracts/template-declarations.md.
- [ ] T030 [P] Update the tdd plugin docs (`doc/` routing-related pages) that describe description-keyed routing: note the declaration ladder, fallback window, and strict flag.
- [ ] T031 Run `specs/071-declared-intent-routing/quickstart.md` scenarios end-to-end against a scratch project and record results in the feature's `tdd/cycle-log.md`.
- [ ] T032 Full fast-tier sweep (`dart test test/plugins/tdd`) + `dart analyze` on touched files; fix any drift.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (T001)**: immediately, records the green baseline.
- **Foundational (T002–T005)**: blocks ALL user stories (resolver + vocabulary).
- **US1 (T006–T011)**: first story; depends on Foundational.
- **US2 (T012–T017)**: depends on Foundational; independent of US1 (both touch the planner — sequence T015 after T010 to avoid same-file churn, but tests are independent).
- **US3 (T018–T021)**: depends on Foundational; independent of US1/US2 files.
- **US4 (T022–T024)**: depends on US1+US2+US3 decisions existing to render (T010, T020) — provenance renders what earlier stories produce.
- **US5 (T025–T028)**: last story — strict mode gates everything the earlier stories declared.
- **Polish (T029–T032)**: after all stories.

### Parallel Opportunities

- T002 ∥ T003 (different concerns, one new file each)
- Story test tasks T006/T007, T012/T013, T018, T022, T025 are [P] within their phases (distinct test files; write-first)
- T029 ∥ T030 ∥ T031 (docs vs validation)

## Implementation Strategy

- **MVP**: Foundational + US1 — lanes become declaration-driven; the #950/#936 class dies. Shippable alone.
- **Incremental**: US2 (surfaces/signatures) → US3 (persistence) → US4 (visibility) → US5 (the strict flip) — each independently testable.
- Tests precede implementation in every story; the loop records each RED before the change that flips it.

## Notes

- Commit after each task or logical group; the repo's fast tier (`dart test test/plugins/tdd`) must stay green between stories.
- Same-file hot spots to sequence, not parallelize: `spec_parser.dart` (T008/T009, T014, T019), `plan_command.dart` (T010, T020, T023, T026), `generation_planner.dart` (T015).
