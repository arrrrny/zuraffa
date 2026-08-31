# Tasks: TDD plan↔gen test-list format contract

**Input**: Design documents from `/specs/050-tdd-test-list-format/`

**Prerequisites**: plan.md, spec.md, checklists/requirements.md

**Tests**: MANDATORY (tdd.plan) — the feature IS a format contract; spec
SC-001..SC-005 demand automated proof. Every behavior in `tdd/test-list.md`
has a test task below, and each test must be observed failing before its
implementation task starts. Reader/contract tests are fast tier; the loop e2e
is `@Tags(['slow', 'integration'])`.

**Organization**: Tasks grouped by user story from spec.md. Behavior markers
(`[A1]`, `[U1]`) trace tasks to `tdd/test-list.md`; `/speckit.tdd.run` ticks
tasks by these markers.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Baseline proof and fixture shapes shared by all stories

- [x] T001 Record the pre-feature baseline: `dart test test/plugins/tdd/` green (220 passed) and the live repro of the remaining migration gap — `zfa tdd run 049-tdd-run` exits `result=runner-error` on list-reading (test-list line 24, 6-column extension dialect), `zfa tdd gen A1 --feature 046-tdd-verify-red` stops malformed (line 28, kind cell `example`)
- [x] T002 Confirm the landed #617 core (master `74c132db`) already satisfies US1's canonical path: gen consumes the shared `TestListReader`, plan writes the 4-column shape, `sc_018_plan_run_loop_e2e_test.dart` pins plan→run — no new work may regress or duplicate it

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The one parser change every story depends on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T003 [US2] [U4] [U5] Write the failing reader tests FIRST in `test/plugins/tdd/services/test_list_reader_test.dart`: a 6-column row whose kind cell is an extension test shape (`example`) in the outer section resolves as acceptance with the default target and triggers the one-time deprecation note; the same row in the inner section resolves as unit; a 6-column extension-shape row outside any section stays malformed; an unknown kind cell (neither acceptance/unit nor an extension shape) stays malformed — observe red before touching the reader
- [ ] T004 [US2] [U6] Extend `TestListReader._parseDataRow` in `lib/src/plugins/tdd/services/test_list_reader.dart`: accept the extension's 6-column dialect (kind cell ∈ `example`/`property`/`contract`/`approval`/`characterization`) — kind from the section header (required, else malformed), last cell treated as a test reference (empty/path-like → `subject_<snake-id>` default), `deprecated: true` with the existing one-per-file stderr note; keep the `acceptance`/`unit` cell-wins rule and the named-line misfire-stop for every other shape (depends on T003 red)
- [ ] T005 [US2] [U1] Re-point BOTH existing tests that pin the old malformed behavior of extension-shape kind cells in `test/plugins/tdd/services/test_list_reader_test.dart` — the U3 test ("a malformed row stops with an error naming the line", 4-col table + one 6-col `example` row) and the 617-shim test ("a 6-column row with an unusable kind cell stays malformed") — at shapes that stay malformed under the completed shim (unknown kind cell like `banana`, or a wrong column count) so FR-005 keeps a live guard; test-first, observed red where applicable

**Checkpoint**: Foundation ready — user story work can begin

---

## Phase 3: User Story 1 - Run the full loop from plan to done (Priority: P1) 🎯 MVP

**Goal**: The canonical 4-column plan→gen→run round trip is pinned and green
(the landed core), and stays green through this feature's shim change.

**Independent Test**: `dart test test/plugins/tdd/commands/plan_gen_contract_test.dart` + slow tier `sc_018_plan_run_loop_e2e_test.dart` pass; no `unknown behavior id`, no `stopped_at=A1:gen`.

- [x] T006 [US1] [A1] [A2] Verify the existing coverage credits: `plan_gen_contract_test.dart` pins plan→gen round trip in both loop sections and target-defaulting (landed with #617); `sc_018_plan_run_loop_e2e_test.dart` pins the exact repro — plan → run on a real temp project with the real pipeline driving all behaviors to DONE, exit 0 (landed with #617). Confirm both still pass after T004 lands; add no duplicate
- [x] T007 [US1] [A3] Credit the existing guard: `test/plugins/tdd/commands/gen_command_test.dart:178` already asserts `zfa tdd gen <unknown-id>` exits non-zero with `unknown behavior id` before any file is written — re-confirm it passes after T004 lands; add no duplicate

---

## Phase 4: User Story 2 - Hand-written 6-column lists keep working (Priority: P2)

**Goal**: The repo's own extension-dialect fixtures (specs/044–049) read
without a malformed stop; migration is a printed note, not a brick.

**Independent Test**: Reader + gen tests on extension-dialect fixtures pass; a repo-fixture read of the 049 list resolves rows (no `result=runner-error` from list-reading).

- [ ] T008 [US2] [U2] [U7] Write the failing gen test FIRST in `test/plugins/tdd/commands/plan_gen_contract_test.dart`: `zfa tdd gen <id> --feature <f>` resolves a behavior id from a hand-written 6-column extension-dialect list (the 046/049 shape: kind cell `example`, test-path last cell) — observe red, then confirm it turns green with T004
- [ ] T009 [US2] [A4] [U8] Write the failing run-level test FIRST: `zfa tdd run <feature>` gets past list-reading on a feature whose list is the hand-written 6-column extension dialect (no `result=runner-error` from the dialect) — seed the smallest honest fixture (a list whose rows are all already DONE with evidence, or a run that stops at a real step for a non-format reason), in `test/plugins/tdd/run_command_test.dart` or a scenario file as the existing style dictates
- [ ] T010 [US2] [U3] Add the reader test proving the deprecation note is printed exactly once per file for a mixed-dialect list (one 4-col row + one 6-col extension row + one 6-col acceptance-cell row) and never re-printed for later rows, in `test/plugins/tdd/services/test_list_reader_test.dart`; assert the list file's bytes are unchanged after the read (FR-010 side-effect-free)

---

## Phase 5: User Story 3 - Format drift fails loudly at the front door (Priority: P3)

**Goal**: Unknown shapes stop with the named line; CI catches drift at the
loop's front door.

**Independent Test**: Malformed-shape reader tests pass; slow-tier e2e present and green.

- [x] T011 [US3] [A5] [U9] Verify the existing coverage credits: the reader's malformed-row tests (line number + raw line in the error, unknown state, empty id) and `sc_018` as the CI front door — confirm they still pass after the shim change; extend only where T005 re-pointed the malformed shape
- [ ] T012 [US3] [A6] Add the repo-fixture regression guard: a test that reads the REAL `specs/049-tdd-run/tdd/test-list.md` (and the 046–048 siblings) through `TestListReader` and asserts rows resolve — so a future dialect change that re-bricks the repo's own completed features fails fast, in `test/plugins/tdd/services/test_list_reader_test.dart`

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Delivery gates

- [ ] T013 Run `dart analyze` (zero issues) and `dart test test/plugins/tdd/` (fast tier green), fix anything this feature broke
- [ ] T014 Run `tools/run_tests_chunked.sh` (whole fast suite, disk-safe) — zero failures
- [ ] T015 Run `dart format .` and confirm `git diff --stat` shows zero formatting diffs
- [ ] T016 Run `/speckit.tdd.verify` and commit `tdd/verification.md` from THIS session's real evidence; clean up scratch fixtures and check `df -h .`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: done (baseline recorded)
- **Foundational (Phase 2)**: T003 (red) → T004 (green) → T005 (guard re-point); BLOCKS all story work
- **US1 (Phase 3)**: T006 is verification-only (landed core); T007 after T004 to prove no regression
- **US2 (Phase 4)**: T008/T009 red can be written before or after T004 but must be observed failing against pre-T004 code; T010 after T004
- **US3 (Phase 5)**: T011 verification-only; T012 after T004
- **Polish (Phase 6)**: last

### Within Each User Story

- Tests written and observed failing FIRST (recorded in `tdd/cycle-log.md`)
- Reader change (T004) is the single green step; everything else guards it

### Parallel Opportunities

- T008 and T009 ([P], different files) can be written together
- T010 and T012 ([P], same file but disjoint sections) can follow together

---

## Implementation Strategy

MVP order: T001/T002 (done) → T003 red → T004 green → T005 guard → T007 →
T008/T009 (red→already-green after T004; record honestly which reds were
observed pre-T004) → T010 → T012 → T013–T016. Commit at green per the repo's
feature-scale convention, with `spec(050):`/`feat(050):`/`test(050):`/
`fix(050):` prefixes.

---

## Notes

- [P] tasks = different files, no dependencies
- Behavior markers are load-bearing: `/speckit.tdd.run` ticks by them
- Never weaken an existing test to reach green — the U3 re-point (T005) is a
  contract change, not a weakening: its old shape (kind cell `example`) moves
  from malformed to accepted-by-shim per FR-007, and the malformed guard
  moves to a genuinely unknown shape
- Pre-extension 7-column legacy lists stay out of scope (spec Assumptions)
