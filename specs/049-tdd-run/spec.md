# Feature Specification: `zfa tdd run` — resumable driver for the full red-green-refactor loop

**Feature Branch**: `049-tdd-run`

**Created**: 2026-08-30

**Status**: Draft

**Input**: Precondition spec 4 of 5 for epic `045-tdd-full-app-cycle` (zfa tdd Full-App Cycle). Implements 041 User Story 8 / Phase 10 (T070-T076): `zfa tdd run <feature>` drives every behavior in a feature's `tdd/test-list.md` through `PENDING → RED → GREEN → DONE` by invoking `gen → verify-red → make → refactor`, persists resumable state, and stops honestly on any failure.

## Mission

This is the loop driver — the command the epic's full-app claim actually
runs. Given a feature with a behavior test list, `zfa tdd run <feature>`
walks each behavior through the certified steps delivered by specs 044
(`gen`), 046 (`verify-red`), 047 (`make`), and 048 (`refactor`), persisting
per-behavior state after every step so a run interrupted for minutes or
weeks resumes exactly where it stopped. It consumes the step commands
through their machine-readable contracts (summary lines + exit codes), never
through prose scraping, and it never edits a test or source file itself.

The driver's honesty rule: when any step fails, the run stops immediately,
the behavior's state reflects the last fully-completed step, and the report
names what failed and why. Bounded partial progress is the designed outcome
of a stop — silently faking progress is the forbidden one.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Drive a feature end-to-end (Priority: P1)

A developer has a feature with a `tdd/test-list.md` of N behaviors and a
green baseline suite. They run `zfa tdd run <feature>`. The driver processes
behaviors in test-list order; for each, it invokes `gen`, `verify-red`,
`make`, and `refactor` in sequence, advancing the behavior through
`PENDING → RED → GREEN → DONE` exactly when the corresponding step
certifies. When every behavior is DONE, the driver exits 0 with the final
suite green.

**Why this priority**: This is the epic's core automation claim in one
command.

**Independent Test**: A fixture feature with three behaviors →
`zfa tdd run <feature>` exits 0; the state file shows all three DONE; the
cycle log holds one red and one green entry per behavior; the suite is
green.

**Acceptance Scenarios**:

1. **Given** a feature with three PENDING behaviors, **When** the developer
   runs `zfa tdd run <feature>`, **Then** each behavior advances through all
   four states in test-list order, the cycle log accumulates one red and one
   green entry per behavior, and the command exits 0 with the suite green.
2. **Given** a completed run, **When** the developer re-runs
   `zfa tdd run <feature>`, **Then** the driver finds nothing to do, reports
   all behaviors DONE, changes nothing, and exits 0.
3. **Given** a feature whose test list gains a new behavior mid-project,
   **When** the developer re-runs `zfa tdd run <feature>`, **Then** the new
   behavior is picked up and driven while completed behaviors are untouched.

---

### User Story 2 - Resume an interrupted run (Priority: P1)

A run interrupted at any point — process killed, machine rebooted, session
closed — resumes by re-running the same command. The driver reads
`tdd/run-state.json`, skips behaviors in DONE, and continues from the
behavior whose state is incomplete, re-entering at the correct step for that
state (a behavior in RED continues at `make`, not at `gen`). The resumed run
performs strictly less work than a fresh run.

**Why this priority**: At app scale (the epic's full-parity corpus), runs
WILL be interrupted; a driver that restarts from scratch cannot finish.

**Acceptance Scenarios**:

1. **Given** a run that stopped with `B-002` in state RED, **When** the
   developer re-runs `zfa tdd run <feature>`, **Then** `B-001` (DONE) is not
   re-processed, `B-002` resumes at `make`, and the run completes.
2. **Given** a process killed mid-step (no step evidence written), **When**
   the run resumes, **Then** the in-flight behavior re-enters at the step
   that was executing, and the step's own idempotency/ownership rules make
   re-entry safe.
3. **Given** a corrupted or unreadable state file, **When** the driver
   starts, **Then** it stops with a non-zero exit naming the corruption and
   the recovery path (delete to restart, or repair), rather than guessing
   state.

---

### User Story 3 - Stop honestly on failure (Priority: P1)

When any step fails for a behavior — `gen` ownership conflict, `verify-red`
dishonest red, `make` unexpressible, `refactor` regression — the driver
stops the entire run immediately: exit non-zero, the behavior left in the
state of its last completed step, the failing step's outcome and output
surfaced in the report, and clear resume instructions. The driver never
retries silently, never modifies a test to force progress, and never marks a
behavior DONE without the full evidence chain (red entry + green entry).

**Why this priority**: The epic's gap protocol depends on the driver
surfacing misfires as first-class stops, not burying them.

**Acceptance Scenarios**:

1. **Given** `make` returns `unexpressible` for `B-002`, **When** the driver
   reaches it, **Then** the run stops non-zero, `B-002` remains RED, the
   report names the unmet capability, and `B-003` is not started.
2. **Given** any step failure, **When** the report is printed, **Then** it
   names the behavior, the failing step, the step's outcome class, and the
   command to resume after the underlying issue is fixed.
3. **Given** a behavior with a red entry but no green entry, **When** the
   driver evaluates it, **Then** it is never marked DONE regardless of state
   file content — evidence beats state on conflict.

---

### User Story 4 - Progress visibility and machine-readable summary (Priority: P2)

A developer (or orchestrator) watching a long run sees per-behavior progress
as it happens — behavior id, step, outcome — and every invocation ends with
a machine-readable summary line: feature, counts per state, the stopping
behavior and step if stopped, and the overall result. Exit code 0 means
exactly "every behavior DONE with complete evidence".

**Acceptance Scenarios**:

1. **Given** a run in progress, **When** a behavior completes a step,
   **Then** a progress line naming the behavior, step, and outcome is
   printed immediately.
2. **Given** any completed or stopped run, **When** the output is parsed,
   **Then** the final summary line contains feature, per-state counts,
   result (`complete` / `stopped`), and — when stopped — the behavior and
   step that stopped it, in a stable documented format.
3. **Given** a CI step running `zfa tdd run <feature>`, **When** the command
   exits, **Then** exit code 0 means exactly "all behaviors DONE with
   complete red+green evidence" and non-zero means "stopped early" with the
   reason in the summary.

---

### Edge Cases

- State file says DONE but the cycle log lacks the green entry: evidence
  wins — the behavior is treated as not done (US3.AC3).
- Test-list rows removed mid-run: the removed behavior's state is retained
  in `run-state.json` marked DROPPED-by-spec-edit, never deleted (audit
  trail), and the driver continues with the remaining rows.
- A step command itself is missing/stubbed (returns the not-implemented
  misfire): treated as a step failure — stop, name it, no workaround.
- Behaviors sharing a subject file: `make`'s regression guard protects
  siblings; the driver adds no extra coordination.
- Two `run` processes on the same feature concurrently: the second detects
  the in-flight marker and refuses with a message (no state corruption).
- A behavior already RED from a manual `gen`+`verify-red` session: the
  driver adopts it and continues at `make`.

## Requirements *(mandatory)*

### Functional Requirements

**Driving the loop**

- **FR-001**: `zfa tdd run <feature>` MUST process every behavior in the
  feature's `tdd/test-list.md` in list order, invoking `gen → verify-red →
  make → refactor` per behavior and advancing `PENDING → RED → GREEN → DONE`
  exactly when the corresponding step certifies.
- **FR-002**: The driver MUST consume step results via the step commands'
  documented machine contracts (summary lines + exit codes), never by
  parsing human prose output.
- **FR-003**: A behavior MUST be marked DONE only when both its red and green
  evidence entries exist in `tdd/cycle-log.md` and the suite is green;
  state-file claims without evidence MUST be treated as not done.

**Resumable state**

- **FR-004**: The driver MUST persist per-behavior state plus the in-flight
  behavior/step to `tdd/run-state.json` after every completed step, so an
  interruption loses at most the in-flight step.
- **FR-005**: On start, the driver MUST resume from the persisted state:
  DONE behaviors are skipped, incomplete behaviors re-enter at the step
  implied by their state; a resumed run MUST perform strictly less work than
  a fresh run.
- **FR-006**: A corrupted/unreadable state file MUST stop the driver
  non-zero with the corruption and recovery path named; a second concurrent
  run on the same feature MUST be refused via the in-flight marker.

**Honest stopping**

- **FR-007**: Any step failure MUST stop the run immediately with a non-zero
  exit: behavior left at its last completed state, failing step and outcome
  named, later behaviors not started, resume instructions printed.
- **FR-008**: The driver MUST NOT modify test files or production source
  itself, MUST NOT retry a failed step silently, and MUST NOT mark DONE
  without complete evidence.

**Reporting**

- **FR-009**: The driver MUST print a per-step progress line (behavior, step,
  outcome) as each step completes.
- **FR-010**: The driver MUST print a final machine-readable summary line
  with feature, per-state counts, result (`complete`/`stopped`), and — when
  stopped — the stopping behavior and step; exit 0 MUST mean exactly "all
  DONE with complete evidence".
- **FR-011**: The driver MUST honor the misfire-stop policy: any internal
  step that cannot complete as specified stops the run with a non-zero exit
  and a clear report.

### Key Entities

- **Run State**: `tdd/run-state.json` — per-behavior states plus in-flight
  behavior/step markers (the `RunState` model already exists on master).
- **Test List / Cycle Log / Artifact Registry / TDD Profile**: the 041/044
  contracts this driver consumes.
- **Step**: one invocation of `gen`, `verify-red`, `make`, or `refactor`
  with its machine-readable outcome.
- **Run Report**: the progress lines + final summary line emitted per
  invocation.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A single `zfa tdd run <feature>` invocation drives a fixture
  feature from all-PENDING to all-DONE with zero human intervention and a
  green final suite.
- **SC-002**: A run interrupted at any of the 4 step boundaries × N behaviors
  resumes and completes with strictly less work than a fresh run (verified
  per boundary in tests).
- **SC-003**: 100% of step failures stop the run with the behavior left in
  its last completed state and no later behavior started (fixture matrix).
- **SC-004**: 100% of DONE behaviors have complete red+green evidence; a
  state/evidence conflict is always resolved toward not-done (0 exceptions).
- **SC-005**: The summary line and exit-code contract is stable enough for
  CI and the epic's corpus orchestration to consume without parsing prose
  (contract test).
- **SC-006**: A second concurrent run on the same feature is refused in
  100% of tests, with zero state-file corruption.

## Out of Scope

- Parallel behavior execution within a run (sequential order only in v1).
- Cross-feature orchestration (driving many features — that's the epic's
  corpus run, which may script multiple `zfa tdd run` invocations).
- Implementing the step commands themselves (044/046/047/048 own them);
  where a step is still a stub, the driver treats it as a step failure.
- Interactive prompting mid-run (the driver is non-interactive; a stop
  means a human or a later invocation resumes).

## Assumptions

- The step commands' machine contracts (044 registry/ownership, 046
  summary line, 047 summary line, 048 summary line) are stable; this driver
  consumes, not defines, them.
- `RunState` (`lib/src/plugins/tdd/models/run_state.dart`) already models
  per-behavior states and in-flight markers; this spec extends it with
  persistence load/save (041 T074) rather than replacing it.
- Re-entering a step is safe because each step is idempotent or guarded:
  `gen` (ownership/idempotency, 044), `verify-red` (append-only evidence),
  `make` (drift check), `refactor` (green preflight).
- The driver invokes steps as sub-processes of the same CLI so crashes of a
  step cannot corrupt driver state.
- Sequential per-feature execution is sufficient; app-scale throughput comes
  from resumability, not intra-feature parallelism.
