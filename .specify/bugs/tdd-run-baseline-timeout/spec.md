# Bug Specification: zfa tdd run baseline honors the --timeout override

**Branch**: `fix/tdd-run-baseline-timeout`

**Created**: 2026-09-05

**Status**: Draft

**Input**: Bug assessment `.specify/bugs/tdd-run-baseline-timeout/assessment.md` (issue #1159): the run-level suite baseline in the TDD driver drops the driver's `--timeout` override and uses the hardcoded 10-minute `defaultSuite` deadline, so on repos whose fast suite exceeds 10 minutes the baseline child is killed, no `run-baseline.json` is written, and `zfa tdd make` refuses — the loop can never pass its first behavior.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Baseline honors the run-level timeout override (Priority: P1)

A developer running `zfa tdd run <feature> --timeout N` on a large repo expects the
run-level suite baseline to receive the same N-minute deadline as every other spawned
process. With the override forwarded, the baseline completes, the snapshot is parseable,
`run-baseline.json` is cached for the run, and make steps reuse it.

**Why this priority**: This is the bug; without it the TDD loop cannot run on large repos at all.

**Independent Test**: Drive the baseline with a suite command that outlives `defaultSuite` (10 min) but fits within the override, and verify the snapshot is produced instead of a timeout kill.

**Acceptance Scenarios**:

1. **Given** a driver invocation with `--timeout N` where N > default, **When** the baseline suite runs longer than the 10-minute default but less than N, **Then** it completes and a parseable baseline snapshot is cached (not a `timedOut: true` record).
2. **Given** no override is passed, **When** the baseline runs, **Then** the default 10-minute deadline still applies (no behavior change for small repos).

---

### User Story 2 - Make's fallback baseline honors --timeout (Priority: P1)

When no cached snapshot exists, `zfa tdd make` runs its own live suite baseline. The
`--timeout` override passed on the make command line (and the override `zfa tdd run`
forwards when spawning make) must apply to that baseline too, so a slow-but-completing
suite produces a usable snapshot instead of `baseline exit: -1`.

**Why this priority**: The fallback path is what the failing run actually hit; fixing only the driver path leaves the standalone-make refusal in place.

**Independent Test**: Invoke `zfa tdd make` with `--timeout N` against a suite that outlives the default; verify the baseline is not killed at 10 minutes.

**Acceptance Scenarios**:

1. **Given** `zfa tdd make ... --timeout N` (N > 10), **When** its fallback live baseline needs more than 10 minutes, **Then** it is allowed up to N and produces a usable snapshot.

---

### User Story 3 - Slow baseline still yields a cached snapshot end-to-end (Priority: P2)

Given the two fixes, a full `zfa tdd run` on a repo whose fast suite takes longer than
10 minutes gets past the first make step: the baseline is cached once per run and
subsequent make steps reuse it instead of re-running the suite.

**Why this priority**: Proves the original failing scenario is fixed end-to-end.

**Independent Test**: Resume `zfa tdd run 077-make-engine-preset --timeout 25` and verify the run proceeds past `A1:make` with a cached baseline message.

**Acceptance Scenarios**:

1. **Given** the fixed driver, **When** `zfa tdd run 077-make-engine-preset --timeout 25` runs, **Then** the baseline is cached ("baseline cached for this run") and A1's make step executes.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The TDD driver MUST forward its `--timeout` override to the run-level suite baseline process.
- **FR-002**: `zfa tdd make` MUST apply its `--timeout` override to its fallback live suite baseline.
- **FR-003**: When `zfa tdd run` spawns `zfa tdd make`, the spawn MUST carry the run-level `--timeout` override so every spawned process shares one deadline (bug #742 contract).
- **FR-004**: Absent an override, the 10-minute `defaultSuite` deadline MUST remain unchanged.
- **FR-005**: A baseline that completes under the effective deadline MUST produce a parseable snapshot and a cached `run-baseline.json` exactly as the small-repo path does today.

### Key Entities

- **Suite baseline**: the pre-run full-suite snapshot (failed-test set) cached once per run and consumed by make steps.
- **Timeout override**: the `--timeout <minutes>` deadline from `zfa tdd run` / `zfa tdd make`, parsed by `parseTddTimeoutMinutes`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A baseline suite needing 11+ minutes completes when `--timeout` allows it, and `run-baseline.json` is written.
- **SC-002**: `zfa tdd run` on this repo proceeds past `A1:make` with `--timeout 25`.
- **SC-003**: Without `--timeout`, existing small-repo behavior is unchanged (default 10-minute deadline).
