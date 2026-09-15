# Analysis Report: 1466-spec-kit-zfa-boundary-scripts

**Date**: 2026-09-15
**Scope**: spec.md ↔ plan.md ↔ tasks.md ↔ issue #1466 acceptance criteria

## Coverage Matrix

| #1466 Criterion | spec.md anchor | plan.md anchor | tasks.md anchor |
|---|---|---|---|
| 1. Four scripts under `scripts/bash/` | Context (exists, `.specify/scripts/bash/` per 1444-U9) | Project Structure (read-only) | T023 (constraint audit) |
| 2. shellcheck, no warnings | US1-10, SC-2 | Decision 4 | T019 |
| 3. Unit tests (normal/edge/error) | US1-1…9, FR-1/2, SC-1 | Decisions 1–3 | T003–T018 |
| 4. Callable from TDD skills (documented) | US3-1…3, FR-7, SC-4 | Decision 5 | T020 |
| 5. read-tdd-profile dart + flutter JSON | US1-5, US1-6, FR-3 | Decision 3 | T007–T008 |
| 6. sync inserts/updates markers | US1-1, US1-2 | Decision 2 | T003–T004 |
| 7. tick correct task, no corruption | US1-8, US1-9 | Decision 2 | T015–T016 |

## Consistency Checks

1. **Hard constraint leakage** — spec FR-8 + SC-5 forbid edits to
   `.specify/extensions/tdd/commands/**`. plan.md Decision 5 and tasks.md
   T020/T023 comply (README documents; skill files untouched). PASS.
2. **Location drift** — issue text says `scripts/bash/`; repo canonical
   location is `.specify/scripts/bash/` (1444's U9 pinned it, suite lives
   beside the scripts). Recorded as a resolved Clarification in spec.md;
   plan and tasks use one consistent path. PASS (no unresolved drift).
3. **SC-1 count vs. tasks** — SC-1 requires ≥ 20 cases; tasks define
   S1–S6 (6) + P1–P6 (6) + E1–E5 (5) + T1–T7 (7) = 24 test cases + shellcheck
   gate. PASS with margin.
4. **FR-6 dual role** — runner is both aggregator and shellcheck gate;
   T002 (aggregation) and T019 (gate) are sequenced, not duplicated. PASS.
5. **US2 runner test** — US2-2 (failing fixture exits non-zero) is exercised
   by T019's failure path design and harness `t_report` exit semantics;
   explicitly verified during Phase 8 verification with a temporary broken
   fixture, then removed. Documented in verification.md. PASS.
6. **Behavioral-freeze risk** — plan Decision 6 freezes the four scripts and
   common.sh; if RED evidence exposes a real script bug, the finding is
   recorded, not patched, preserving one-PR-per-feature. PASS.
7. **Artifact ↔ issue naming** — deliverables named exactly as the issue's
   suggested scripts; test files derive names from script names
   (`test_sync_behaviors.sh` ↔ `sync-behaviors-to-tasks.sh`) with the
   mapping fixed in plan Project Structure. PASS.

## Verdict

No unresolved cross-artifact drift. Two ambiguities (test location; skill-file
mutability) were converted into explicit spec Clarifications rather than left
implicit. Ready for /speckit.tdd.plan.
