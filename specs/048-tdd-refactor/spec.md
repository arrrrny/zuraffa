# Feature Specification: `zfa tdd refactor` — green-only refactoring step of the TDD loop

**Feature Branch**: `048-tdd-refactor`

**Created**: 2026-08-30

**Status**: Draft

**Input**: Precondition spec 3 of 5 for epic `045-tdd-full-app-cycle` (zfa tdd Full-App Cycle). Implements 041 User Story 7 / Phase 9 (T066-T069): `zfa tdd refactor` applies safe production-code refactoring through the generation/build machinery only when the suite is fully green, never touches test files, and re-proves green afterwards.

## Mission

Complete the third step of the red-green-**refactor** cycle. After
`zfa tdd make` (spec 047) certifies a green behavior, code generated in a
hurry accumulates duplication and drift between generated artifacts.
`zfa tdd refactor` is the only sanctioned way to clean up: it refuses to run
on a red suite, applies refactors exclusively through the zuraffa
generation/build pipeline and other tool-driven transforms (never hand edits,
never test files), re-runs the suite, and records what it did as auditable
evidence.

The loop's credibility rule is absolute here: **tests are the specification,
so a refactor step that edits a test is indistinguishable from cheating.**

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Green-suite preflight gate (Priority: P1)

A developer runs `zfa tdd refactor` with a failing suite. The tool runs the
project's suite command (from `tdd-profile.md`) before anything else, finds
failures, exits non-zero naming each failing test, and instructs the
developer to return to `zfa tdd make`. No refactor is offered or applied.

**Why this priority**: Refactoring on a red suite destroys the signal that
makes refactoring safe. This gate is the entire discipline of the step.

**Independent Test**: Fixture project with one failing test →
`zfa tdd refactor` exits non-zero naming that test and changes no files.

**Acceptance Scenarios**:

1. **Given** a fully green suite, **When** the developer runs
   `zfa tdd refactor`, **Then** the preflight passes and the command proceeds
   to its refactor passes.
2. **Given** a suite with at least one failing test, **When** the developer
   runs `zfa tdd refactor`, **Then** the command exits non-zero, names every
   failing test, instructs a return to `zfa tdd make`, and modifies no files.
3. **Given** a suite that cannot even start (runner/profile broken), **When**
   the preflight runs, **Then** the command treats it as not-green, exits
   non-zero with a runner-error report, and modifies no files.

---

### User Story 2 - Refactors applied only through tool-driven transforms (Priority: P1)

A developer with a green suite runs `zfa tdd refactor`. The tool applies its
refactor passes exclusively through invocable tooling: regeneration of
generator-owned files via the pipeline (`zfa make`/`zfa build`) and
tool-driven normalizations (the project's configured formatter/analyzer
fixer). It never hand-edits a source file, and it never modifies, creates, or
deletes any file under the project's test directory.

**Why this priority**: "Refactor by hand" is how the zfa-only contract dies.
Every production change must remain attributable to a tool invocation.

**Acceptance Scenarios**:

1. **Given** a green suite and generator-owned files that drifted from the
   generator's current output, **When** `zfa tdd refactor` runs, **Then** the
   drift is normalized by re-invoking the generator/build tooling, and each
   applied action is recorded with the exact command used.
2. **Given** a green suite, **When** `zfa tdd refactor` completes, **Then**
   every file under the test directory is byte-identical to its pre-run
   content (checksum-verifiable).
3. **Given** a green suite, **When** any file under `lib/` changed during the
   run, **Then** the change is attributable to a recorded tool invocation —
   no unattributed edits exist.

---

### User Story 3 - Post-refactor suite re-proves green (Priority: P1)

After any refactor pass modifies production code, the tool re-runs the suite.
If the re-run is green, the command exits 0 and records the refactor
evidence. If the re-run regresses, the command exits non-zero, names the
regressed tests, records NO success evidence, and reports that the suite must
be restored before continuing.

**Acceptance Scenarios**:

1. **Given** a green preflight and refactor passes that change files,
   **When** the post-refactor suite runs green, **Then** the command exits 0
   and appends a refactor-evidence entry to `tdd/cycle-log.md` listing every
   applied action and its command.
2. **Given** a refactor pass that breaks a previously-green test, **When**
   the post-refactor suite runs, **Then** the command exits non-zero, names
   the regressed test, and appends no success evidence.
3. **Given** a refactor run where no pass needed to change anything,
   **When** the command completes, **Then** it reports a clean no-op
   (suite re-proven green, nothing applied) and exits 0 without fabricating
   evidence of changes that did not happen.

---

### User Story 4 - Machine-readable result for the loop driver (Priority: P2)

The `zfa tdd run` loop driver and CI consume `refactor` results
programmatically. The command prints a final machine-readable summary line
(feature, outcome, applied-action count) in the same contract style as
`verify-red` and `make`, and its exit code alone distinguishes a safe
refactor state (0) from any refusal or regression (non-zero).

**Acceptance Scenarios**:

1. **Given** any completed `refactor` invocation, **When** the output is
   parsed, **Then** the final summary line contains the outcome
   (`clean` / `refactored` / `not-green` / `regression` / `runner-error`)
   and the count of applied actions, in a stable documented format.
2. **Given** a CI step running `zfa tdd refactor`, **When** the command
   exits, **Then** exit code 0 means exactly "suite green before and after;
   zero or more recorded tool-driven actions applied" and any non-zero code
   means the refactor state is unsafe.

---

### Edge Cases

- A refactor pass partially applies (some files normalized, then a tool
  fails): the command stops, reports the failing tool, re-runs the suite to
  determine safety, and never leaves silent half-state unreported.
- The project has no generator-owned drift and nothing to normalize: the
  clean no-op path (US3.AC3) applies — not an error.
- The preflight suite run is slow at app scale: the command still runs it;
  skipping the preflight is never allowed (a `--skip-preflight` flag must not
  exist).
- A test file is also generator-owned (generated tests): the test-directory
  immutability rule still wins — `refactor` never regenerates test
  artifacts; that is `gen`'s job in a new cycle.
- Running `refactor` with pending uncommitted work: allowed; the evidence
  entry records the actions so the diff stays auditable.

## Requirements *(mandatory)*

### Functional Requirements

**Preflight**

- **FR-001**: `zfa tdd refactor` MUST run the full suite via the project's
  `tdd-profile.md` before any refactor pass, and MUST refuse (non-zero,
  failing tests named) when the suite is not green or cannot run.
- **FR-002**: The command MUST provide no option to skip or weaken the
  preflight.

**Tool-driven refactors only**

- **FR-003**: Every production-code change MUST be produced by an invocable
  tool action (pipeline regeneration, build, formatter, analyzer fixer); the
  command MUST NOT hand-edit source content itself.
- **FR-004**: The command MUST NOT modify, create, or delete any file under
  the project's test directory, including generator-owned test artifacts.
- **FR-005**: Every applied action MUST be recorded with its exact command
  and outcome; a change without a recorded action is a contract violation.

**Re-proof & evidence**

- **FR-006**: After any action modifies production code, the command MUST
  re-run the full suite and require green; on regression it MUST exit
  non-zero, name the regressed tests, and write no success evidence.
- **FR-007**: On success with applied actions, the command MUST append a
  refactor-evidence entry to `tdd/cycle-log.md` listing each action, its
  command, and the before/after suite results. Append-only.
- **FR-008**: When no action is needed, the command MUST report a clean
  no-op (suite re-proven green) and MUST NOT fabricate evidence of changes
  that did not happen; a no-op evidence entry is optional but, if written,
  must say no-op explicitly.

**Contract**

- **FR-009**: The command MUST print a final machine-readable summary line
  (`feature`, `outcome`, `applied` count) compatible with the `verify-red` /
  `make` contract style; exit code 0 MUST mean exactly "green before and
  after".
- **FR-010**: The command MUST honor the misfire-stop policy: any tool action
  that cannot complete stops the command, and the suite is re-run to
  determine and report the resulting safety state.

### Key Entities

- **TDD Profile / Cycle Log**: as defined by specs 041/046 — suite command
  source and evidence sink.
- **Refactor Action**: one recorded tool invocation (command, outcome, files
  touched).
- **Refactor Evidence**: the cycle-log entry kind written by this command.
- **Refactor Outcome**: `clean` | `refactored` | `not-green` | `regression` |
  `runner-error`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of invocations on a red suite refuse before any file
  change (0 files modified across the rejection fixture matrix).
- **SC-002**: 0 test-directory files modified across all runs
  (checksum-verified in tests), including runs with applied actions.
- **SC-003**: 100% of `lib/` changes across all runs are attributable to a
  recorded tool command in the evidence entry.
- **SC-004**: 100% of post-refactor regressions exit non-zero with the
  regressed tests named and no success evidence written.
- **SC-005**: A no-op run reports `clean`, exits 0, and fabricates no
  changes (0 files touched, evidence says no-op if written).
- **SC-006**: The summary line and exit-code contract is stable enough for
  `zfa tdd run` to consume without parsing prose (contract test).

## Out of Scope

- Semantic or architecture-level refactoring decisions (renaming concepts,
  restructuring layers) — those are new behaviors and go through the full
  red-green cycle, not this command.
- Refactoring the zuraffa CLI's own codebase — this command operates on the
  TARGET project.
- Undo/rollback of applied actions after a regression (the report names the
  state; restoring is the developer's or the loop driver's decision).
- `zfa tdd run` — the loop driver that calls this command is a separate
  precondition spec.

## Assumptions

- The refactor pass set in v1 is deliberately small: pipeline regeneration of
  drifted generator-owned files, `zfa build` normalization, and the project's
  configured formatter/analyzer fixer. Each pass is individually recorded.
- The suite command from `tdd-profile.md` is the same one `make`'s guard
  uses; a red-at-baseline suite simply means refusal (no NEW-failure
  semantics here — refactor requires fully green, per 041 US7).
- Test-directory immutability applies even to generator-owned test files;
  regenerating tests is a `gen` concern.
- Evidence format follows the cycle-log conventions established by specs
  046/047.
