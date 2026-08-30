# Feature Specification: `zfa tdd make` — generation-only green step of the TDD loop

**Feature Branch**: `047-tdd-make`

**Created**: 2026-08-30

**Status**: Draft

**Input**: Precondition spec 2 of 5 for epic `045-tdd-full-app-cycle` (zfa tdd Full-App Cycle). Implements 041 User Story 6 / Phase 8 (T062-T065): `zfa tdd make <behavior-id>` turns a certified-red behavior green by generating the minimal implementation through the existing `zfa make`/`zfa entity create`/`zfa build` pipeline — never by hand-writing source, never by touching the test.

## Mission

Close the green half of the TDD loop. After `zfa tdd verify-red` (spec 046)
certifies that a behavior's test fails for the right reason,
`zfa tdd make <behavior-id>` produces the minimal implementation that turns
exactly that test green — exclusively through the zuraffa generation pipeline.
It then proves the green is real (target test passes) and safe (the full
suite stays green), and records the green evidence in `tdd/cycle-log.md`.

This command is the guardrail for the epic's central claim — *a full app
written only by the zfa tdd cycle*. If the pipeline cannot express the
required implementation, the command stops and reports the gap; it never
hand-writes source and never edits the test to force a pass.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Turn a certified-red behavior green via generation (Priority: P1)

A developer (or the `zfa tdd run` loop driver) has a behavior in state RED —
`verify-red` evidence is present in the cycle log. They run
`zfa tdd make B-003`. The tool resolves the behavior's artifacts from the
registry, confirms the certified-red precondition, derives the minimal
implementation the behavior requires, produces it through the generation
pipeline (`zfa entity create` / `zfa make` / `zfa build` as appropriate),
runs the behavior's test via the project's `tdd-profile.md`, asserts it now
passes, and appends a green-evidence entry to `tdd/cycle-log.md`.

**Why this priority**: This is the core of the epic — production code from
the generator pipeline only. Everything else in this spec exists to keep
this story honest.

**Independent Test**: On a fixture project with a certified-red behavior,
run `zfa tdd make <id>`; confirm exit 0, the target test now passes, and the
cycle log gains a green entry recording the generation commands used.

**Acceptance Scenarios**:

1. **Given** behavior `B-003` with certified-red evidence, **When** the
   developer runs `zfa tdd make B-003`, **Then** the implementation is
   produced exclusively by generation-pipeline invocations, the target test
   passes, a green-evidence entry is appended to `tdd/cycle-log.md`, a
   machine-readable summary line is printed, and the command exits 0.
2. **Given** the green-evidence entry from scenario 1, **When** an auditor
   reads `tdd/cycle-log.md`, **Then** the entry contains: behavior id, source
   criterion, the exact generation commands invoked, the runner command, the
   runner exit code, the captured passing output, and a timestamp.
3. **Given** a completed `make` run, **When** an auditor inspects the
   behavior's test file, **Then** it is byte-identical to its pre-`make`
   content — the test is never modified to reach green.

---

### User Story 2 - Refuse to run without certified red (Priority: P1)

A developer runs `zfa tdd make <id>` on a behavior that has not been
certified red: no red-evidence entry exists in the cycle log, or the
behavior's artifacts are missing from the registry. The tool stops before
generating anything, exits non-zero, and names the missing precondition with
the remediation step (`zfa tdd gen` / `zfa tdd verify-red`).

**Why this priority**: Equal to US1 — the loop's integrity depends on green
evidence always being preceded by red evidence. A `make` that runs on an
uncertified behavior can silently pass against a vacuous test.

**Acceptance Scenarios**:

1. **Given** a behavior with gen artifacts but no red-evidence entry,
   **When** the developer runs `zfa tdd make <id>`, **Then** the command
   exits non-zero, states that certified red is missing, and instructs the
   developer to run `zfa tdd verify-red <id>` first — generating nothing.
2. **Given** a behavior id unknown to the registry, **When** `make <id>`
   runs, **Then** it exits non-zero naming the id and instructing
   `zfa tdd gen <id>` first, before any generation.
3. **Given** a behavior whose certified-red test currently passes already
   (drift: someone implemented it by hand), **When** `make <id>` runs,
   **Then** it detects the test is already green, reports the drift, and
   exits non-zero rather than recording a vacuous green.

---

### User Story 3 - Regression guard via the full suite (Priority: P1)

A developer's generated implementation turns the target test green but breaks
a previously-green sibling test. The tool runs the full suite (per the
project's `tdd-profile.md`) after the target test passes, detects the
regression, exits non-zero naming the regressed test, and does NOT append a
green-evidence entry.

**Acceptance Scenarios**:

1. **Given** a generated implementation that passes the target test and keeps
   the full suite green, **When** `make` completes, **Then** the green entry
   records both the target-test pass and the full-suite pass.
2. **Given** a generated implementation that passes the target test but
   regresses a sibling, **When** `make` runs the full suite, **Then** it
   exits non-zero naming the regressed test, appends no green entry, and
   leaves the generated source in place for inspection (the failure report
   says so).
3. **Given** a full suite that was already red before `make` ran (pre-existing
   breakage), **When** `make` evaluates the regression guard, **Then** it
   compares against the recorded pre-run baseline and fails only on NEW
   failures, naming them.

---

### User Story 4 - Misfire-stop when the pipeline cannot satisfy the behavior (Priority: P1)

A behavior requires an implementation the generation pipeline cannot express
(e.g., bespoke parsing logic with no generator surface). The tool stops with
a non-zero exit, reports precisely what it could not generate, appends no
green entry, modifies no test, and leaves the behavior RED for the gap to be
filed per the repository STOP-ON-ROADBLOCK policy.

**Why this priority**: This is how the epic finds zuraffa's gaps honestly —
every misfire is a zuraffa issue, never a workaround.

**Acceptance Scenarios**:

1. **Given** a behavior whose implementation is not expressible through the
   generation pipeline, **When** `make <id>` runs, **Then** it exits
   non-zero, reports the unmet capability in terms of the behavior (not an
   internal stack trace), and writes no green evidence.
2. **Given** a generation step that itself errors or produces non-compiling
   output, **When** `make` detects it, **Then** it stops non-zero, reports
   the failing generation command and its output, and does not run the test
   suite against known-broken code.
3. **Given** any misfire, **When** the command stops, **Then** the behavior's
   test file and the cycle log are unchanged, and the report names the exact
   pipeline step that failed.

---

### User Story 5 - Machine-readable result for the loop driver (Priority: P2)

The `zfa tdd run` loop driver and CI consume `make` results
programmatically. The command prints a final machine-readable summary line
(behavior id, outcome, feature) in the same contract style as
`verify-red`, and its exit code alone distinguishes green-certified (0) from
any failure (non-zero).

**Acceptance Scenarios**:

1. **Given** any completed `make` invocation, **When** the output is parsed,
   **Then** the final summary line contains the behavior id, the outcome
   (`green` / a named failure class), and the feature, in a stable documented
   format.
2. **Given** a CI step running `zfa tdd make <id>`, **When** the command
   exits, **Then** exit code 0 means exactly "test green via generated
   implementation, suite green, evidence logged" and any non-zero code means
   "not certified".

---

### Edge Cases

- `zfa build` partially completes (some artifacts generated, then failure):
  `make` must detect the partial state, report it, and stop — not proceed to
  the test run.
- The behavior's test passes for the wrong reason after generation (e.g., a
  sibling change made it vacuously green): out of detection scope for `make`;
  caught by `zfa tdd verify`'s mutation gate at feature completion.
- Re-running `make` on an already-green-certified behavior: idempotent report
  (already green, no duplicate evidence) rather than a second generation
  pass.
- Multiple behaviors share a subject file: the regression guard (US3) is the
  protection; `make` never reverts other behaviors' implementations.
- The registry record exists but the subject file was deleted:
  regeneration through the pipeline is allowed; a missing test file is a
  hard error (return to `gen`).

## Requirements *(mandatory)*

### Functional Requirements

**Preconditions & targeting**

- **FR-001**: `zfa tdd make [behavior-id]` MUST resolve the target behavior
  from the artifact registry and MUST require certified-red evidence (a red
  entry from `verify-red`) in `tdd/cycle-log.md` before generating anything;
  missing precondition → non-zero exit naming the remediation.
- **FR-002**: Target resolution (explicit id, single-candidate inference,
  ambiguity error) MUST follow the same rules as `zfa tdd verify-red`.
- **FR-003**: Before generating, the command MUST re-run the target test and
  confirm it still fails; an already-green test is reported as drift and
  stops the command non-zero.

**Generation-only implementation**

- **FR-004**: The implementation MUST be produced exclusively through the
  generation pipeline (`zfa entity create`, `zfa make`, `zfa build`); the
  command MUST NOT write or edit production source directly, and MUST NOT
  modify any test file.
- **FR-005**: The command MUST choose the minimal generation that satisfies
  the behavior's test; when no pipeline capability can satisfy it, the
  command MUST misfire-stop per US4 — naming the unmet capability — rather
  than approximating.
- **FR-006**: Every pipeline invocation MUST be captured (command, exit code,
  output) and recorded in the green-evidence entry.

**Verification & evidence**

- **FR-007**: After generation, the command MUST run the target test via the
  `tdd-profile.md` `single` command and require a pass; then run the full
  suite via the profile `suite` command and require no NEW failures relative
  to a pre-run baseline.
- **FR-008**: On success, the command MUST append a green-evidence entry to
  `tdd/cycle-log.md` containing: behavior id, source criterion, generation
  commands invoked, runner command, runner exit code, captured passing
  output, full-suite result, and timestamp. Append-only; never edits history.
- **FR-009**: On any failure, the command MUST exit non-zero, append no green
  entry, and leave the test file and cycle log unmodified.
- **FR-010**: The command MUST print a final machine-readable summary line
  (`behavior`, `outcome`, `feature`) compatible with the `verify-red`
  contract style; exit code 0 MUST mean exactly "green certified".
- **FR-011**: The command MUST honor the misfire-stop policy: any internal
  step that cannot complete as specified stops the command immediately with
  a non-zero exit and a clear report.

### Key Entities

- **Artifact Registry / Cycle Log / TDD Profile**: as defined by specs 044,
  046, 041 — this command reads the registry, reads red evidence and appends
  green evidence to the log, and takes all runner commands from the profile.
- **Green Evidence**: the cycle-log entry kind written by this command.
- **Suite Baseline**: the pass/fail counts of the full suite captured before
  generation, used by the regression guard to identify NEW failures.
- **Generation Step**: one recorded pipeline invocation (command, exit code,
  output) inside a green-evidence entry.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of successful `make` runs produce green evidence whose
  recorded generation commands, when replayed on the pre-run state, reproduce
  the implementation (auditable from the log alone).
- **SC-002**: 100% of runs on behaviors without certified red are refused
  before any generation (0 generation side effects in tests).
- **SC-003**: 100% of runs where the full suite gains a new failure exit
  non-zero with no green entry; 0 regressions are ever certified.
- **SC-004**: 0 test-file modifications across all runs (checksum-verified in
  tests).
- **SC-005**: 100% of misfires name the failing pipeline step and the unmet
  capability in the report (fixture-driven test matrix).
- **SC-006**: The summary line and exit-code contract is stable enough for
  `zfa tdd run` to consume without parsing prose (contract test).

## Out of Scope

- Deciding HOW a behavior maps to generation commands beyond the minimal
  mapping needed for the fixtures (the general behavior→generation planner
  grows with the corpus run under epic 045's gap protocol).
- `zfa tdd refactor` and `zfa tdd run` — separate precondition specs.
- Reverting or garbage-collecting generated source after a failed run.
- Detecting vacuous greens introduced by sibling changes (`zfa tdd verify`'s
  job at feature completion).

## Assumptions

- The artifact registry, cycle log, and tdd-profile contracts from specs
  041/044/046 are stable; this command is a consumer/producer within them.
- The generation pipeline is invoked as CLI sub-processes of `zfa` so each
  step is capturable and auditable.
- "Minimal generation" means the smallest set of pipeline invocations that
  turns the target test green; when multiple are equivalent, the simplest
  (fewest generated files) wins.
- Re-running `make` on a green-certified behavior is a safe no-op that
  reports the existing certification.
