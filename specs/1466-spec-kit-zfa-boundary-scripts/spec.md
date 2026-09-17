# Feature Specification: Spec-Kit ↔ ZFA Boundary Scripts — Acceptance Hardening for #1466

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `feat/1466-spec-kit-zfa-boundary-scripts`

**Created**: 2026-09-15

**Status**: Draft

**Input**: User description: "Create .sh scripts for spec-kit ↔ zfa boundary operations (issue #1466). Four deterministic bash scripts — sync-behaviors-to-tasks.sh, read-tdd-profile.sh, read-cycle-evidence.sh, tick-behavior-task.sh — replacing LLM-driven file manipulation of shared markdown (test-list.md, tdd-profile.md, cycle-log.md, tasks.md)."

**Context**: The four boundary scripts themselves already exist at
`.specify/scripts/bash/` (merged via PR #1474, feature 1444). Issue #1466
remains open because three of its seven acceptance criteria are not yet
satisfied by anything durable: (3) per-script unit tests covering normal
input, edge cases and error conditions, (2) a verifiable shellcheck-clean
gate, and (4) documented integration points that make the scripts callable
from the TDD skills. This spec covers that remaining scope. The hard
constraint from the issue stands: the spec-kit skill definition files
(`.specify/extensions/tdd/commands/*.md`) and the TDD workflow logic MUST NOT
change — integration points are documented, skill files are not rewritten.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Durable unit tests for every boundary script (Priority: P1)

A maintainer who changes any boundary script can prove it still behaves
correctly by running one command from a clean checkout. The tests live next
to the scripts they cover (`.specify/scripts/bash/tests/`, i.e. colocated in
the same directory tree the scripts live in), so they survive spec-directory
archival and are discoverable without reading historical feature folders.
Each of the four scripts has unit tests for normal input, edge cases, and
error conditions.

**Why this priority**: Without durable tests the deterministic boundary is
unprotected — a regression in any script silently hands file mutation back to
LLM freehand, which is exactly the failure mode issue #1466 exists to remove.

**Independent Test**: Run the suite in a clean clone against temp fixtures;
it passes without network access, a Dart SDK, or any prior repo state.

**Acceptance Scenarios**:

1. **Given** a tasks.md without behavior markers and a test-list.md defining
   behaviors A1, U1, C1, **When** `sync-behaviors-to-tasks.sh` runs, **Then**
   tasks.md gains one `[behavior: <id>]` marker per behavior, grouped into
   Acceptance Behaviors / Unit Behaviors / Characterization Behaviors
   sections.
   **Type**: acceptance
2. **Given** tasks.md already contains some markers, **When** the sync script
   runs twice, **Then** the first run inserts only missing markers, existing
   lines stay byte-identical, and the second run is a no-op
   (`behaviors_added: 0`).
   **Type**: acceptance
3. **Given** a test-list.md with a duplicate behavior ID, **When** the sync
   script runs, **Then** it exits non-zero with a descriptive error and does
   not modify tasks.md.
   **Type**: acceptance
4. **Given** a test-list.md containing a malformed behavior ID (fails
   `^[A-Z]+[0-9]+$`), **When** the sync script runs, **Then** the malformed
   entry is skipped with a warning on stderr while valid behaviors still
   sync.
   **Type**: acceptance
5. **Given** a tdd-profile.md with `engine: dart` frontmatter, **When**
   `read-tdd-profile.sh --json` runs, **Then** JSON output carries
   `engine: dart` and the recorded `test_command`.
   **Type**: acceptance
6. **Given** a tdd-profile.md with `engine: flutter` plus optional
   `verify_command` and `plan_command`, **When** `read-tdd-profile.sh --json`
   runs, **Then** all four fields are emitted with the flutter values, and
   **when** the optional fields are absent they are emitted as JSON `null`.
   **Type**: acceptance
7. **Given** a cycle-log.md with RED, GREEN and REFACTOR entries, **When**
   `read-cycle-evidence.sh --json` runs, **Then** every entry is returned
   with its phase, behavior id and evidence fields, and malformed entries are
   skipped with a stderr warning instead of aborting.
   **Type**: acceptance
8. **Given** tasks.md with an unticked `[behavior: U1]` task among other
   tasks, **When** `tick-behavior-task.sh <tasks> --behavior U1` runs,
   **Then** exactly that line's checkbox becomes `[x]`, every other line —
   including other unticked tasks — is byte-identical, and the JSON output
   reports `status: success`.
   **Type**: acceptance
9. **Given** a behavior already ticked, **When** the tick script re-runs,
   **Then** it exits 0 reporting `already_done` and the file is unchanged;
   **given** an unknown behavior id, **Then** it exits non-zero without
   modifying the file.
   **Type**: acceptance
10. **Given** any of the four scripts plus `common.sh`, **When** the suite's
    shellcheck gate runs (`shellcheck -x -S warning`), **Then** zero
    warnings are reported for all four scripts.
    **Type**: acceptance

### User Story 2 - One-command suite runner with aggregation (Priority: P2)

A contributor runs a single entry point that executes every boundary-script
test file, prints per-suite and aggregate pass/fail counts, and exits
non-zero if any test fails — suitable as a local gate and as CI glue.

**Why this priority**: The tests only protect the boundary if running them is
easier than skipping them; the runner is what makes the suite a gate rather
than a demo.

**Independent Test**: `bash tests/run_tests.sh` in the scripts' directory
prints an aggregate `Passed: N/N` line and exits 0 on a healthy tree, 1 when
any fixture test fails.

**Acceptance Scenarios**:

1. **Given** the four test files, **When** the runner executes, **Then** it
   prints each test id with PASS/FAIL, a per-file summary, and one aggregate
   `Passed: N/N, Failed: 0/N` line.
   **Type**: acceptance
2. **Given** a deliberately broken fixture (a test forced to fail), **When**
   the runner executes, **Then** it exits non-zero and names the failing
   test.
   **Type**: acceptance

### User Story 3 - Documented integration points (Priority: P2)

An agent or developer wiring the TDD skills to deterministic file operations
can open one document beside the scripts that maps each skill step that
currently manipulates shared markdown freehand to the exact script
invocation that replaces it — without the skill definition files being
modified (hard constraint from the issue).

**Why this priority**: Criterion 4 of the issue ("Scripts are callable from
the TDD skills (documented integration points)") is only met when the
integration contract is written down where the scripts live.

**Independent Test**: Reading `.specify/scripts/bash/README.md` alone is
sufficient to call all four scripts with correct arguments for each TDD skill
step; every documented call was executed at least once by the tests in US1.

**Acceptance Scenarios**:

1. **Given** the README, **When** a reader looks up
   `/speckit.tdd.plan` Step 3 (sync tasks.md), **Then** they find the
   `sync-behaviors-to-tasks.sh <test-list> <tasks> [--json]` invocation with
   argument meanings and the JSON success shape.
   **Type**: acceptance
2. **Given** the README, **When** a reader looks up `/speckit.tdd.setup` and
   `/speckit.tdd.run` engine/evidence reads, **Then** they find
   `read-tdd-profile.sh` and `read-cycle-evidence.sh` invocations including
   the default-path fallback behavior when arguments are omitted.
   **Type**: acceptance
3. **Given** the README, **When** a reader looks up `/speckit.tdd.run` Step 4
   and `/speckit.tdd.verify` remediation ticking, **Then** they find the
   `tick-behavior-task.sh <tasks> --behavior <id> [--json]` invocation plus
   its error contract (not_found / already_done).
   **Type**: acceptance

## Requirements *(mandatory)*

### Functional Requirements

- **FR-1** (US1): A durable test directory `.specify/scripts/bash/tests/`
  contains one test file per boundary script plus a runner; tests construct
  their fixtures in a temp directory and never mutate repository files.
- **FR-2** (US1): Every script is covered for: normal input (success path),
  at least one edge case (idempotency, duplicates, malformed ids, missing
  optional fields, already-ticked, multiple markers), and at least one error
  condition (missing file, missing flag, unknown id — non-zero exit with
  message on stderr).
- **FR-3** (US1): `read-tdd-profile.sh` tests include both a `dart` engine
  fixture and a `flutter` engine fixture, asserting engine + test_command
  round-trip in JSON mode.
- **FR-4** (US1): Tests that check JSON output assert via `jq` when
  available, mirroring the scripts' own cascade discipline.
- **FR-5** (US2): `run_tests.sh` aggregates all test files in the directory,
  prints per-test results and an aggregate `Passed: N/N` summary, and exits
  non-zero on any failure.
- **FR-6** (US2): The runner doubles as the shellcheck gate: it invokes
  `shellcheck -x -S warning` on the four scripts and fails the run on any
  warning (skipped with a skip notice only when shellcheck is not installed).
- **FR-7** (US3): `.specify/scripts/bash/README.md` documents, for each TDD
  skill step that touches test-list.md / tdd-profile.md / cycle-log.md /
  tasks.md, the replacing script, full argument list, default-path fallback,
  `--json` output shape, and exit/error contract.
- **FR-8** (all): The skill definition files
  (`.specify/extensions/tdd/commands/*.md`) and TDD workflow logic are NOT
  modified by this feature; integration points are documentation only.

### Key Entities

- **Boundary script**: one of `sync-behaviors-to-tasks.sh`,
  `read-tdd-profile.sh`, `read-cycle-evidence.sh`, `tick-behavior-task.sh`;
  all live at `.specify/scripts/bash/`, use `set -euo pipefail`, source
  `common.sh`, parse via the jq → python3 → grep/sed cascade, and emit JSON
  with `--json` built via `jq --arg` when jq is present.
- **Test fixture**: minimal markdown file (test-list / tasks / cycle-log /
  tdd-profile) created under `mktemp -d` per test, removed on exit.
- **Integration point**: a (skill step → script invocation) mapping recorded
  in the README.

## Success Criteria *(measurable)*

- **SC-1**: `bash .specify/scripts/bash/tests/run_tests.sh` passes ≥ 20
  distinct test cases covering all four scripts, including every acceptance
  scenario US1-1 … US1-9; aggregate line reports `Failed: 0`.
- **SC-2**: `shellcheck -x -S warning` returns zero findings for all four
  scripts and the gate is part of the runner (SC-1 run includes it).
- **SC-3**: The suite runs green on a clean clone with no network, no Dart
  SDK, and no zfa binary — proving the boundary scripts are
  self-contained bash.
- **SC-4**: `.specify/scripts/bash/README.md` exists and names all four
  scripts with skill-step mappings, argument tables, and error contracts
  (criterion 4 of the issue).
- **SC-5**: `git diff` shows zero modifications under
  `.specify/extensions/tdd/commands/` (hard constraint respected).
- **SC-6**: The pre-existing feature-1444 suite
  (`specs/1444-spec-kit-boundary-scripts/tdd/tests/run_all_tests.sh`) still
  passes 20/20 after this feature's changes — no regression to merged
  behavior.

## Clarifications

### Session 2026-09-15

- Q: Where do the durable tests live, given the issue says `scripts/bash/`
  but the merged scripts live at `.specify/scripts/bash/`?
  A: Colocated at `.specify/scripts/bash/tests/` — the repo's canonical
  spec-kit script directory (feature 1444's U9 pinned the scripts' location
  there; the issue's `scripts/bash/` is shorthand for that directory).

- Q: Do the tests replace the 1444 acceptance suite?
  A: No. They complement it: 1444's suite proves the original behaviors and
  stays as historical evidence (SC-6); the 1466 suite adds the
  normal/edge/error depth, the shellcheck gate, and a durable location that
  survives spec archival.

- Q: May the TDD skill markdown be updated to call the scripts?
  A: No — the issue's hard constraint forbids changing the skills or TDD
  workflow logic in this PR. Integration is documented (US3), not wired into
  the skill files.
