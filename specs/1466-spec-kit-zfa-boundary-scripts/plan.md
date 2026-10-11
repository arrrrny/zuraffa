# Implementation Plan: Spec-Kit ↔ ZFA Boundary Scripts — Acceptance Hardening (#1466)

**Branch**: `feat/1466-spec-kit-zfa-boundary-scripts` | **Date**: 2026-09-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/1466-spec-kit-zfa-boundary-scripts/spec.md`

## Summary

Complete the three unsatisfied acceptance criteria of issue #1466 on top of the
boundary scripts merged by PR #1474 (feature 1444): a durable per-script unit
test suite (normal/edge/error) colocated at `.specify/scripts/bash/tests/`,
a one-command runner that doubles as the shellcheck gate, and a README that
documents every TDD-skill integration point. No changes to the four scripts'
behavior, to `common.sh`'s behavior, or to the TDD skill definition files.

## Technical Context

**Language/Version**: Bash (POSIX-compatible constructs, bash 3.2+ for macOS
compatibility), driven by `set -euo pipefail` fail-fast discipline

**Primary Dependencies**: none mandatory — `jq` (preferred JSON assertions),
`python3` (script cascade tier 2), `shellcheck` (gate; skip-noticed when
absent). All optional at runtime: every assertion has a grep/sed fallback
where the script under test has one.

**Storage**: N/A (markdown fixture files under `mktemp -d`)

**Testing**: plain-bash test harness (assert helpers in `tests/harness.sh`),
following the `setup-tasks.sh` pattern of zero external test-framework
dependencies

**Target Platform**: Linux/macOS CI shells + developer workstations

**Project Type**: repository tooling (bash scripts + tests + docs)

**Performance Goals**: full suite < 30 s (each test spawns 1–2 script
processes on tiny fixtures)

**Constraints**: tests must not mutate any repository file; must pass with no
network, no Dart/Flutter SDK, no zfa binary; must not modify
`.specify/extensions/tdd/commands/**` (hard constraint, spec FR-8)

**Scale/Scope**: 4 test files (one per script) + harness + runner + README;
~22 test cases

## Constitution Check

- **TDD discipline**: the suite itself is developed test-first — RED runs are
  recorded in `tdd/cycle-log.md` before each GREEN (see `tdd/test-list.md`
  traceability). N/A for pure-markdown docs (README is non-behavioral).
- **Determinism at the boundary**: the suite makes the boundary testable;
  aligns with the constitution's honesty rules — the runner reports real
  pass/fail counts, never fabricates green.
- **No Flutter dependency**: suite is pure bash; SC-3 proves SDK independence.

**Gate result**: PASS — no violations.

## Project Structure

```
.specify/scripts/bash/
├── common.sh                      # existing shared helpers (UNCHANGED behavior)
├── sync-behaviors-to-tasks.sh     # existing (UNCHANGED behavior)
├── read-tdd-profile.sh            # existing (UNCHANGED behavior)
├── read-cycle-evidence.sh         # existing (UNCHANGED behavior)
├── tick-behavior-task.sh          # existing (UNCHANGED behavior)
├── README.md                      # NEW: integration points (US3, FR-7)
└── tests/                         # NEW: durable suite (US1/US2, FR-1..6)
    ├── harness.sh                 # assert helpers, fixture factory
    ├── test_sync_behaviors.sh     # S1..S6
    ├── test_read_profile.sh       # P1..P6
    ├── test_read_evidence.sh      # E1..E5
    ├── test_tick_behavior.sh      # T1..T7
    └── run_tests.sh               # aggregation + shellcheck gate (FR-5, FR-6)
```

**Nested-suite layout note**: each `test_*.sh` sources `harness.sh` with
`TESTS_DIR` set, registers cases, and exits with the file's failure count;
`run_tests.sh` discovers `test_*.sh`, runs each in a subshell, and prints the
aggregate `Passed: N/N, Failed: 0/N` line.

## Technical Decisions

1. **Plain-bash harness, no bats/framework** — the repo's spec-kit tooling
   deliberately avoids install-time dependencies (`setup-tasks.sh` pattern);
   a 60-line harness keeps that property and keeps SC-3 trivially true.

2. **Fixtures via `mktemp -d` + trap cleanup** — mirrors the atomic-write
   discipline of the scripts themselves; guarantees FR-1 (no repo mutation)
   and safe parallel runs.

3. **Assertions mirror the script cascade** — JSON assertions use `jq -e`
   when jq exists, fall back to grep/sed checks otherwise, so the suite
   passes on minimal images (FR-4) while proving the preferred path where
   available. The harness records which tier ran so the verification report
   can state it honestly.

4. **Runner = test gate + shellcheck gate** — one entry point, one aggregate
   line, one exit code (FR-5/FR-6). shellcheck absence is a *skip* with a
   loud notice, not a silent pass, honoring the constitution's honesty rule.

5. **README documents, does not wire** — the issue's hard constraint
   (FR-8/SC-5) forbids editing the skill commands; the README carries the
   integration contract: per-skill-step invocation tables, argument
   semantics, JSON shapes, exit codes, and the default-path fallback rules
   inherited from `common.sh` (`SPECIFY_FEATURE_DIRECTORY` /
   `.specify/feature.json`).

6. **No production-script edits** — if a test uncovers a script bug, it is
   recorded as a finding and fixed in a follow-up PR per the issue's
   one-PR-per-feature constraint; the only in-place edits permitted here are
   inside `tests/` and `README.md`.

## Verification Strategy

- RED→GREEN cycles per test case, logged with real command output in
  `tdd/cycle-log.md`.
- Final verification (Phase 8) re-runs: `run_tests.sh` (1466 suite),
  `shellcheck` on all touched files, the 1444 regression suite (SC-6),
  `dart analyze` on the repo diff (expected: no Dart files touched), and
  `dart format` compliance check. Results land in `tdd/verification.md`
  with actual counts.
