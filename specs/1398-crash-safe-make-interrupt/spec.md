# Feature Specification: crash-safe make — journal the interrupt, adopt on resume

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `feat/1398-crash-safe-make-journal-interrupt`

**Created**: 2026-09-16

**Status**: Draft

**Input**: GitHub issue #1398 (EPIC engine-skin-split verify, #1012) — "killed/interrupted zfa tdd run leaves subjects mutated green without journal evidence; resume dead-ends at subject-drift (crash-safety gap vs issue #1036 invariant)". Related: #1036 (crash-safety invariant), #1008 (two-cycle driver), #1331 (adopted-outcome path), #1345 (placeholder re-drive).

## Problem

Issue #1036's invariant — *a make that does not complete leaves NO subject mutation* — holds only for graceful failures. When the run driver (or a standalone make) is killed by process death (external timeout SIGKILL, OOM, power loss) mid-make, the subject can already carry the make's mutation while the green evidence was never written. The #1036 fingerprint guard then misclassifies every resume:

1. Resume's verify-red re-runs the recorded red against the mutated subject — the red no longer reproduces: `unexpected-green`.
2. The driver skips to make. Make's drift check passes (target test now green), but the adoption gate (`_tombstonedReDrive`, issue #1331) finds no reset tombstone, so the #1036 subject-drift refusal fires: the on-disk subject hash differs from the certified-red hash with no journaled green to legitimize it.
3. `result=stopped stopped_at=<id>:make` — the documented recovery loop dead-ends. `zfa tdd doctor` prescribes the #1331 adopt semantics, but the driver never reaches them.

The crash class and the dishonest class are indistinguishable: a user who hand-edited a subject to green and a driver that was killed mid-make leave byte-identical crime scenes. The first must keep refusing (the #1036 guard's entire purpose); the second must recover, because the mutation is the loop's OWN work product — half of an honest make.

## Proposal

Journal the interruption. The make step gains a write-ahead interrupt marker — the same atomic tmp→fsync→rename discipline the run driver's `TddTransaction` (bug #828) already uses — so a make that dies mid-flight leaves a durable "I was here, I was the driver, I did not finish" record that a graceful exit never leaves behind. On the next make of the same behavior, the marker's presence distinguishes the honest crash class from the dishonest hand-edit class:

- **Marker present, subject real** → the resumed make auto-adopts the passing subject through the #1331 adoption semantics (green evidence binds the CURRENT subject hash; any post-adoption drift still refuses) and exits 0 with the EXPLICIT `adopted-interrupted` outcome — "resume after interruption" is a surfaced outcome, not a silent skip and not a refusal.
- **Marker present, subject is the born-green placeholder** → the adoption is withheld exactly as the #1331/#1345 placeholder gate withholds it: a vacuous subject is never adopted into green (the #1036 refusal stands).
- **Marker absent** → every existing behavior is byte-identical: the hand-edit class keeps refusing subject-drift; the #694 skip, #1331 tombstone re-drive, #1345 placeholder re-entry, #1162 re-certify, and #1430 refresh acceptances are untouched.

The marker is evidence about the DRIVER, not a license for the subject: it records which behavior was mid-make, when, and under which process, and it is consumed by any graceful make exit — success, skip, adoption, or refusal. Only process death leaves it behind.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — a killed make recovers on resume (Priority: P1)

An external 600s timeout kills `zfa tdd run` mid-make, after the pipeline mutated the subject to its green shape but before green evidence landed. The user re-runs the same command. The resume re-drives the behavior honestly: the marker the killed make left behind identifies the drift as the loop's own half-made work, and the make adopts the passing subject — the run flows to refactor and completes. No `subject-drift` dead end.

**Why this priority**: this is the misfire. Without it, every process death permanently wedges the feature at `<id>:make`.

**Independent Test**: SIGKILL a real make after the subject mutation lands (marker provably on disk), resume the make, observe `outcome=adopted-interrupted`, exit 0, green evidence binding the current subject hash.

**Acceptance Scenarios**:

#### Scenario 1.1 — killed mid-make leaves the interrupt marker (AC-1)

```gherkin
Given a feature whose behavior A1 has certified red evidence and a throwing subject
And a make of A1 has started and mutated the subject to its green shape
When the make process is killed by SIGKILL before it finishes
Then the interrupt marker for A1 survives on disk inside the feature's tdd/ directory
And the marker names A1, the make's own process identity, and a UTC timestamp
And no green evidence entry was appended for A1
```

**Type**: integration (real subprocess, real SIGKILL)

#### Scenario 1.2 — resume adopts the interrupted subject (AC-2)

```gherkin
Given A1's make was killed mid-flight leaving the interrupt marker
And the on-disk subject is the make's mutated green shape and the target test passes against it
When make A1 runs again
Then it exits 0 with outcome=adopted-interrupted
And a green evidence entry is appended binding the CURRENT subject hash
And the run driver grades the step a terminal success and advances the behavior to green
```

**Type**: integration

#### Scenario 1.3 — the driver completes the resumed run (AC-2)

```gherkin
Given a run whose make step was killed mid-flight
When the run is resumed to completion
Then the run reports result=complete
And the resumed make's transcript carries the adopted-interrupted transition, not subject-drift
```

**Type**: integration (driver level, fake zfa steps)

### User Story 2 — dishonest edits keep refusing (Priority: P1)

A user hand-edits a certified subject to its green shape without any make in flight — no marker exists — and the make still refuses with subject-drift, the #1036 remedy, and no green entry. The adoption cannot be farmed by editing files; only the loop's own interrupted work is adoptable. A crash that left a born-green placeholder (the vacuous class) also keeps refusing.

**Why this priority**: the adoption must not become a bypass of the #1036 honesty guard. Without this story the fix trades a dead-end for a hole.

**Independent Test**: reproduce the identical drift state WITHOUT a marker (hand-mutated subject) and observe the refusal; reproduce marker + placeholder subject and observe the refusal.

**Acceptance Scenarios**:

#### Scenario 2.1 — hand-edit without a crash still refuses (AC-3)

```gherkin
Given A1 has certified red evidence and its certified subject hash
And the subject file was hand-rewritten to a passing shape with NO make ever started
When make A1 runs
Then it exits non-zero with outcome=subject-drift
And no green evidence entry is appended
And the fix line names the git-restore / re-certify remedy
```

**Type**: integration

#### Scenario 2.2 — a crash marker does not legitimize a vacuous subject (AC-3)

```gherkin
Given A1's make was killed leaving the interrupt marker
And the on-disk subject is the born-green placeholder shape (scaffolded marker, still-throwing or constant body)
When make A1 runs and the target test already passes
Then the adoption is withheld and the subject-drift refusal stands
And no green evidence entry is appended
```

**Type**: integration

#### Scenario 2.3 — the marker is consumed by graceful exits (AC-3)

```gherkin
Given a make of A1 that started and wrote the interrupt marker
When the make exits through ANY graceful path (green, skipped, adopted, refusal, generation-error)
Then the marker is removed
And a subsequent hand-edit of the subject is refused again (no stale license)
```

**Type**: integration

### User Story 3 — the accounting stays honest (Priority: P2)

The resumed make's outcome is EXPLICITLY `adopted-interrupted` — machine-parseable in the summary line, distinguishable in the cycle log and the run receipt from `green` (generated this make), `skipped` (#694), and `adopted` (#1331 tombstone re-drive). The run driver accepts the token as a terminal make success, records the evidence when the child's exit code disagrees, and the end-of-run accounting counts it as green-with-provenance.

**Why this priority**: the distinction is the issue's third acceptance criterion and what makes the crash class auditable later; it changes no behavior, only truthfulness of the record.

**Independent Test**: drive a resumed run against the fake zfa steps carrying the `adopted-interrupted` token; the loop advances and the journal entry names the transition.

**Acceptance Scenarios**:

#### Scenario 3.1 — the driver accepts the token (AC-2, AC-4)

```gherkin
Given a feature whose make step reports outcome=adopted-interrupted
When the run driver processes the step result
Then the step is graded a terminal make success
And the behavior advances to green and the run completes
And when the exit code disagrees with the token the driver records the green evidence itself
```

**Type**: integration (driver level)

#### Scenario 3.2 — a corrupt marker never widens the adoption (AC-3)

```gherkin
Given an interrupt marker file that is unparseable or names a different behavior
When make runs against an already-green target test
Then the marker is treated as absent (fail closed)
And the existing refusal / skip behavior applies unchanged
```

**Type**: unit

## Requirements

### Functional Requirements

- **FR-1 (write-ahead marker)**: the make step writes a behavior-scoped interrupt marker to the feature's `tdd/` directory BEFORE any work that can mutate the subject, atomically (temp file + fsync + rename), carrying at minimum: schema version, feature, behavior id, process id, and a UTC timestamp.
- **FR-2 (consume on resume)**: when a make of behavior B starts and finds a marker for B left by a PREVIOUS make process, the make treats the drift class as the honest crash class.
- **FR-3 (interrupt adoption)**: under FR-2, when the target test already passes and the on-disk subject is NOT the born-green placeholder shape, make certifies green through the existing #1331 adoption mechanics (green evidence binding the current subject hash) and exits 0 with the explicit `adopted-interrupted` outcome token.
- **FR-4 (placeholder guard)**: under FR-2 with a placeholder-shaped subject, the adoption is withheld and the existing subject-drift refusal stands (fail closed).
- **FR-5 (marker hygiene)**: every graceful make exit clears the marker — including refusals, generation errors, and the adoption itself — so only process death leaves one behind. A corrupt, unparseable, or foreign-behavior marker is treated as absent (never blocks, never adopts).
- **FR-6 (driver acceptance)**: the run driver and the step outcome contract grade `adopted-interrupted` exactly like `adopted`: a terminal make success whose evidence is recorded by the driver when the child's exit code disagrees (the bug #986 pattern).
- **FR-7 (no regression)**: the make-skip logic (#694), the fingerprint comparison (#1036), the tombstone re-drive (#1331), the placeholder re-entry (#1345), and the subject-drift recovery prescriptions (#1324/#1430) are behaviorally unchanged when no interrupt marker is present.

### Success Criteria

- **SC-1**: A make SIGKILLed after the subject mutation leaves a durable, behavior-named interrupt marker; no green evidence exists at kill time. (Measured: marker file present with the killed make's behavior id; cycle log has no green entry.)
- **SC-2**: Resuming the make after the kill yields `outcome=adopted-interrupted`, exit 0, and a green evidence entry whose subject hash equals the on-disk subject's hash — not a `subject-drift` refusal. (Measured: summary token + exit code + cycle-log hash equality.)
- **SC-3**: The identical drift state WITHOUT a marker still refuses `subject-drift` with no green entry. (Measured: exit non-zero, token `subject-drift`.)
- **SC-4**: Marker + born-green placeholder still refuses; no green entry. (Measured: exit non-zero.)
- **SC-5**: A resumed run (driver level) reaches `result=complete` with the adopted-interrupted transition in the transcript and the behavior done. (Measured: driver summary line.)
- **SC-6**: Every graceful make exit removes the marker; a corrupt marker behaves as absent. (Measured: file absence after each outcome class; unit test on the reader.)
- **SC-7**: The full existing suite for the touched commands passes unchanged (`dart analyze` clean; `dart test` for the touched areas reports only pre-existing failures, if any, as flagged).

## Assumptions

- Process death is the only marker-leaving path; a caught exception still funnels through the summary line and clears the marker (FR-010's every-exit-path summary contract).
- The marker records the make's own process id for auditability, but liveness probing is NOT used for decisions: read-before-overwrite inside the same process is the only discrimination needed, and pid reuse makes liveness checks unsound.
- Single-writer discipline holds as today (the run driver serializes makes per feature); concurrent makes of the same behavior remain unsupported, unchanged.
- The adoption reuses the #1331 mechanics verbatim — no new evidence format, no new state, no new flag.

## Key Entities

- **Interrupt marker** (`specs/<feature>/tdd/make-interrupt.json`): `{schema, feature, behavior, pid, at, status}` — the write-ahead record of an in-flight make; presence after process death = honest crash class.
- **MakeOutcome** vocabulary: gains `adopted-interrupted` (crash-recovery adoption); all existing labels unchanged.
- **Subject hash binding**: unchanged — green evidence always binds the CURRENT subject hash at certification time.
