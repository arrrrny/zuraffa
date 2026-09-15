---
description: "Task list for feature 1466-spec-kit-zfa-boundary-scripts"
---

# Tasks: Spec-Kit ↔ ZFA Boundary Scripts — Acceptance Hardening (#1466)

**Input**: Design documents from `/specs/1466-spec-kit-zfa-boundary-scripts/`

**Prerequisites**: plan.md (required), spec.md (required)

**Tests**: Test-first is mandatory for US1/US2 tasks (TDD extension); the
test code IS the deliverable, so each task pairs RED evidence with GREEN.

**Organization**: Tasks grouped by user story; US1 is the MVP slice.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- Scripts under test: `.specify/scripts/bash/*.sh` (read-only this feature)
- New work: `.specify/scripts/bash/tests/` and `.specify/scripts/bash/README.md`
- Spec artifacts: `specs/1466-spec-kit-zfa-boundary-scripts/`

## Phase 3.1 — Suite skeleton (US2 substrate, MVP-first)

- [ ] T001 [US1] Create `.specify/scripts/bash/tests/harness.sh`: `t_case`
  (register case), `t_assert_eq`, `t_assert_contains`, `t_assert_exit`
  (captures exit code + stderr), `t_fixture_dir` (mktemp -d + trap cleanup),
  `t_report` (per-file `Passed: N/N` line). Zero external deps.
- [ ] T002 [US2] Create `.specify/scripts/bash/tests/run_tests.sh`: discover
  `test_*.sh` in own directory, run each in a subshell, print per-file
  summary + aggregate `Passed: N/N, Failed: 0/N`, exit non-zero on any
  failure (FR-5).

## Phase 3.2 — sync-behaviors-to-tasks.sh suite (US1)

- [ ] T003 [P] [US1] RED: write `tests/test_sync_behaviors.sh` with S1
  (normal insert, A1/U1/C1 grouping per US1-1), S2 (idempotency +
  byte-identical preservation per US1-2), S3 (duplicate ID error, tasks.md
  untouched per US1-3). Run → confirm FAIL (file absent = red evidence).
- [ ] T004 [P] [US1] GREEN: implement the three cases; suite passes.
- [ ] T005 [P] [US1] RED: add S4 (malformed ID skipped with stderr warning,
  valid behaviors still sync per US1-4), S5 (missing test-list.md and
  missing tasks.md → non-zero + stderr, per FR-2 error tier), S6 (--json
  success shape `status/behaviors_added/behaviors` asserted via jq when
  present per FR-4). Run → confirm FAIL for new cases only.
- [ ] T006 [P] [US1] GREEN: implement S4–S6; file passes 6/6.

## Phase 3.3 — read-tdd-profile.sh suite (US1)

- [ ] T007 [P] [US1] RED: write `tests/test_read_profile.sh` with P1 (dart
  engine JSON per US1-5), P2 (flutter engine with optional fields per
  US1-6), P3 (optional fields absent → JSON null + text "(not configured)"
  per US1-6). Run → red evidence.
- [ ] T008 [P] [US1] GREEN: implement P1–P3.
- [ ] T009 [P] [US1] RED: add P4 (missing file → non-zero + stderr; no
  frontmatter → non-zero per US1 error tier), P5 (missing engine OR missing
  test_command → non-zero), P6 (text mode lists Engine/Test Command lines).
  Run → red for new cases.
- [ ] T010 [P] [US1] GREEN: implement P4–P6; file passes 6/6.

## Phase 3.4 — read-cycle-evidence.sh suite (US1)

- [ ] T011 [P] [US1] RED: write `tests/test_read_evidence.sh` with E1 (RED/
  GREEN/REFACTOR entries parsed to JSON with phase + behavior fields per
  US1-7), E2 (malformed entry skipped with stderr warning, valid entries
  kept per US1-7), E3 (log with no evidence entries → zero entries, exit 0).
  Run → red evidence.
- [ ] T012 [P] [US1] GREEN: implement E1–E3.
- [ ] T013 [P] [US1] RED: add E4 (missing file → non-zero + stderr), E5
  (text mode summary lists entries; --json parseable by jq when present).
  Run → red for new cases.
- [ ] T014 [P] [US1] GREEN: implement E4–E5; file passes 5/5.

## Phase 3.5 — tick-behavior-task.sh suite (US1)

- [ ] T015 [P] [US1] RED: write `tests/test_tick_behavior.sh` with T1 (ticks
  exactly the U1 line, all other lines byte-identical per US1-8), T2 (already
  ticked → exit 0 + already_done, file unchanged per US1-9), T3 (unknown
  behavior → non-zero, file unchanged per US1-9). Run → red evidence.
- [ ] T016 [P] [US1] GREEN: implement T1–T3.
- [ ] T017 [P] [US1] RED: add T4 (duplicate markers → first ticked, warning
  on stderr, second marker line untouched per FR-2 edge tier), T5 (missing
  --behavior flag → non-zero + usage on stderr), T6 (--json success shape
  `status/behavior_id` per FR-4), T7 (file permission bits preserved across
  the atomic replace — regression guard for the mktemp 0600 hazard). Run →
  red for new cases.
- [ ] T018 [P] [US1] GREEN: implement T4–T7; file passes 7/7.

## Phase 3.6 — Shellcheck gate (US2)

- [ ] T019 [US2] Extend `run_tests.sh`: after suites, run
  `shellcheck -x -S warning` on the four boundary scripts; fail the runner on
  any warning; if shellcheck is missing, print an explicit SKIP notice and
  continue (FR-6, SC-2).

## Phase 3.7 — Integration documentation (US3, non-behavioral)

- [ ] T020 [US3] Write `.specify/scripts/bash/README.md`: purpose of the four
  boundary scripts; per-skill-step integration table
  (`speckit.tdd.plan` Step 3 → sync; `speckit.tdd.setup` Phase 2/profile →
  read-tdd-profile; `speckit.tdd.run` Step 3 evidence + Step 4 ticking →
  read-cycle-evidence + tick-behavior-task; `speckit.tdd.verify` evidence →
  read-cycle-evidence), argument tables, JSON shapes, exit-code contracts,
  default-path fallback rules, and the constraint note that skill files are
  not modified (FR-7, SC-4).

## Phase 3.8 — Final validation

- [ ] T021 Run full 1466 suite (`run_tests.sh`) + shellcheck; record actual
  counts in `tdd/verification.md`.
- [ ] T022 Regression: run 1444 suite
  (`specs/1444-spec-kit-boundary-scripts/tdd/tests/run_all_tests.sh`) — must
  stay 20/20 (SC-6).
- [ ] T023 Constraint audit: `git diff --stat` confirms zero changes under
  `.specify/extensions/` and zero behavior edits to the four scripts /
  `common.sh` (SC-5).
