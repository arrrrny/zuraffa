# Tasks: The refactor pass must not strand the green evidence it just certified

**Input**: Design documents from `/specs/1430-refactor-refresh-evidence/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/refactor-refresh.md, quickstart.md

**Tests**: TDD per the spec-whole flow — every behavior gets a failing test first (`tdd/test-list.md` is the behavior list; this file carries the non-behavior remainder).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1/US2/US3)

## Path Conventions

Repo-local TDD plugin: `lib/src/plugins/tdd/` (commands + models + services), tests in `test/plugins/tdd/`.

## Phase 1 — Setup

- [x] T001 Confirm the defect surface on the head tree: `RefactorPasses.defaultPasses` format/fix cover all of `lib/` and the re-proof + receipts-refresh region in `lib/src/plugins/tdd/commands/refactor_command.dart` writes no subject reconciliation; `_subjectDriftRefusal` in `lib/src/plugins/tdd/commands/make_command.dart` consults only last red/green; `CycleEntryKind` in `lib/src/plugins/tdd/models/cycle_entry.dart` holds `{red, green, refactor, error}` (research.md D1–D5)

## Phase 2 — Foundational

- [x] T002 Seed the shared fixture helper for the regression suite in `test/plugins/tdd/commands/bug_1430_refresh_evidence_test.dart`: a hermetic temp feature with a behavior record whose subject file exists under `lib/tdd/<feature>/`, a cycle-log carrying a certified green entry stamped with the subject's sha256, and the injectable runner/passes seams the existing refactor suites use — so each behavior test drives a real pass rewrite + re-proof without a network of fakes

## Phase 3 — User Story 1: a run-driven feature resumes clean through the loop (P1) 🎯 MVP

**Goal**: A refactor pass that rewrites a certified subject and re-proofs green leaves evidence consistent with disk; the resume's make skip transition accepts loop-caused drift.

**Independent Test**: Certify a behavior green in the fixture, run the refactor pass so a format-style rewrite touches the subject, then drive make's already-green transition: it accepts with the #1430 provenance note (today: `subject-drift` refusal).

- [x] T003 [US1] [behavior: A-1430-1] (MANDATORY) RED: end-to-end resume rows in `test/plugins/tdd/commands/bug_1430_refresh_evidence_test.dart` — certified green + pass rewrites the subject + green re-proof → the make skip transition ACCEPTS the reformatted subject and prints the `subject drift accepted (issue #1430)` note (fails: today it refuses `subject-drift`)
- [x] T004 [P] [US1] [behavior: U-1430-1] (MANDATORY) RED: writer rows in the same suite — after a green re-proof that covers the touched behavior's test, the refactor command appends one `## Cycle: <id> (refresh)` entry per rewritten certified subject carrying the post-rewrite `subject-hash`, the re-proof command/scope, and the behavior's criterion; with the re-proof scope covering each touched behavior's own test (the covering-test witness; fails: no such entry/behavior today)
- [x] T005 [US1] GREEN: add `CycleEntryKind.refresh` to `lib/src/plugins/tdd/models/cycle_entry.dart` — label `refresh`, renders the standard field lines with `subject-hash`, never the `generation:`/`suite:` blocks (green-only) nor `actions:` (refactor-only); the red assert stays `kind != red || classification != null` (depends on T004's red)
- [x] T006 [US1] GREEN: writer — post-re-proof reconciliation in `lib/src/plugins/tdd/commands/refactor_command.dart`: map changed files under `lib/` to the feature's behavior subject records, and for each certified-green behavior whose recorded hash ≠ post-rewrite hash append the refresh entry via `CycleLog.append`; keep the re-proof scope decision unchanged (the covering-test mapping already witnesses each touched subject) (depends on T004, T005)
- [x] T007 [US1] GREEN: reader — the refresh consult in `_subjectDriftRefusal` in `lib/src/plugins/tdd/commands/make_command.dart`: accept when the behavior's LAST `kind: refresh` entry carries `subject-hash == currentHash` AND its `at` parses AND is newer than the certified basis entry (unparseable/older → refusal stands, fail closed), printing the provenance note (data-model guard table) (depends on T005)
- [x] T008 [US1] [behavior: A-1430-2] (MANDATORY) Evidence ↔ disk agreement: after the refactor pass, the last green-or-refresh evidence hash for every touched certified behavior equals the on-disk subject's sha256 — the invariant the resume guard actually reads (SC-002 spirit, issue #1430 AS-2)

## Phase 4 — User Story 2: the honest guard stays honest (P2)

**Goal**: Out-of-band drift still refuses byte-identically; the refresh consult cannot over-accept.

**Independent Test**: Hand-edit a certified subject outside any refactor pass → the refusal with hash mismatch, #1036 citation, #1162 remedy fires exactly as today.

- [x] T009 [P] [US2] [behavior: A-1430-3] (MANDATORY) Guard pins in `test/plugins/tdd/commands/bug_1430_refresh_evidence_test.dart`: out-of-band post-certification subject edit (no refresh entry) → the `subject-drift` refusal byte-identical (basis, both hashes, #1036, #1162 remedy); these rows are green-first characterization pins against the unfixed tree and must STAY green after T007 (the accept arm only opens for a matching newer refresh entry)

## Phase 5 — User Story 3: no green-washing through the refactor (P3)

**Goal**: A refresh never outruns its proof; untouched passes are byte-identical to today.

**Independent Test**: A red re-proof refreshes nothing (existing failure path); a pass touching no certified subject writes no new entries.

- [x] T010 [P] [US3] [behavior: U-1430-2] (MANDATORY) RED: re-proof fails after the rewrite → the run/refactor reports the existing re-proof failure and appends NO refresh entry (green-washing guard; the writer task T006 must gate on the green verdict)
- [x] T011 [P] [US3] [behavior: U-1430-3] (MANDATORY) Pass touches no certified subject → the cycle log gains exactly today's refactor entry, zero refresh entries, no forced full re-proof (FR-005 byte-equality)
- [x] T012 [P] [US3] [behavior: U-1430-4] Subject of a NOT-certified (pending or red-only) behavior touched → no refresh entry for it; the next certify stamps the then-current hash naturally
- [x] T013 [US3] [behavior: U-1430-5] Several certified subjects rewritten in one pass → one refresh entry per touched behavior under the same green re-proof gate (depends on T006)

## Phase 6 — Polish & cross-cutting

- [x] T014 [behavior: U-1430-6] (MANDATORY) Freshness + neighbor-guard pins: a refresh entry older than the live green certification does not accept (out-of-band edit back to a previously refreshed shape still refuses); refresh-hash ≠ current-hash refuses; the #1162 red-basis implemented-drift fail-open, born-green placeholder refusal, and #1331 tombstone re-drive all behave unchanged
- [x] T015 Targeted regression sweep (no whole-suite runs): existing make skip/#1036 suites, refactor command suites (re-proof classification #1333, receipts refresh #1311), run-driver stale-artifacts suite, cycle-log/chain suites — all green; `dart format` on touched files + `dart analyze lib/src/plugins/tdd test/plugins/tdd` clean; update `specs/1430-refactor-refresh-evidence/quickstart.md` only if the contract shifted during the loop

## Dependencies

- T001 → T002 → Phase 3 behaviors
- T004 (writer red) → T005 (model) → T006 (writer) → T003/T008 go green via T006+T007; T007 (reader) depends on T005
- T009 (US2 pins) is independent of T006/T007 authoring but must stay green after T007
- T010–T012 are red-first against the unfixed tree where the assertion reads the ABSENT guarantee (no refresh entry is trivially true pre-writer; the red is the forced-full-re-proof/absence assertions as specified) — the loop records each honestly
- T013 after T006; T014 after T007; T015 last

## Parallel Execution Examples

- T004 (writer rows) and T009/T010/T011/T012 (guard/no-wash pins) target different assertion groups in the same suite file — coordinate inserts, then author T005–T007.
- T005 (model) blocks T006/T007; nothing else parallelizes with them.

## Implementation Strategy

- MVP = US1 (T003–T008): the loop-caused dead end dies — certify → refactor → resume advances with zero manual `--re-certify`.
- US2 (T009) pins the honest guard so the accept arm cannot widen.
- US3 (T010–T013) closes the green-washing class: no proof, no refresh.
- T014/T015 harden the neighbors (#1162/#1331/tombstone) and sweep the targeted regressions.
- Dogfood hazard (research D6): if a mid-feature resume strands on the pre-fix behavior, the sanctioned bridge is `zfa tdd verify-red <id> --re-certify` per drifted behavior — a workaround, not a misfire.
