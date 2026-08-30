# Feature Specification: `zfa tdd verify-red` — honest-red gate for the TDD loop

**Feature Branch**: `046-tdd-verify-red`

**Created**: 2026-08-30

**Status**: Draft

**Input**: Precondition spec 1 of 5 for epic `045-tdd-full-app-cycle` (zfa tdd Full-App Cycle). Implements 041 User Story 5 / Phase 7 (T055-T061): `zfa tdd verify-red` asserts that a `gen`-produced test fails for the right reason — an assertion failure — and records the red evidence.

## Mission

Close the red half of the TDD loop. After `zfa tdd gen <behavior-id>` (spec
044) materializes a test+subject pair, `zfa tdd verify-red` proves the test
is *honestly red*: it fails because the stub does not implement the behavior,
not because of a compile error, a load error, a skip, or an accidental green.
Only an honestly-red behavior may proceed to `zfa tdd make`. The command
writes the red evidence to `tdd/cycle-log.md` so the loop driver
(`zfa tdd run`, spec pending) and human auditors can reconstruct exactly what
failed, how, and when.

This command is a **read-only verifier**: it never modifies the test, the
subject, or any project source file.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Verify an honestly-red behavior (Priority: P1)

A developer (or the `zfa tdd run` loop driver) has run `zfa tdd gen B-003`
and wants the red half of the cycle certified. They run
`zfa tdd verify-red B-003`. The tool resolves the behavior's artifacts from
the artifact registry (`specs/<feature>/tdd/artifacts.json`), runs exactly
the behavior's test via the project's `tdd-profile.md` single-test command,
classifies the failure as an assertion failure, appends a red-evidence entry
to `tdd/cycle-log.md`, and exits 0.

**Why this priority**: This is the entire purpose of the command — the
certified-red gate that `make` and `run` depend on.

**Independent Test**: On a feature with a `gen`-produced behavior whose test
fails with an assertion failure, run `zfa tdd verify-red <behavior-id>`;
confirm exit code 0 and a new cycle-log entry containing the behavior id,
runner command, exit code, classification, and captured failure output.

**Acceptance Scenarios**:

1. **Given** behavior `B-003` has registered gen artifacts and its test fails
   with an assertion failure, **When** the developer runs
   `zfa tdd verify-red B-003`, **Then** the tool runs the single test via the
   `tdd-profile.md` `single` command, classifies the failure as
   `assertion`, appends a red-evidence entry to `tdd/cycle-log.md`, prints a
   machine-readable summary line, and exits 0.
2. **Given** the red-evidence entry from scenario 1, **When** an auditor reads
   `tdd/cycle-log.md`, **Then** the entry contains: behavior id, source
   criterion, test path, the exact runner command executed, the runner exit
   code, the failure classification, the captured failure output, and a
   timestamp.
3. **Given** an honestly-red behavior, **When** `verify-red` completes,
   **Then** no file under `test/` or `lib/` has been modified (verifiable by
   checksum comparison before/after).

---

### User Story 2 - Reject dishonest red with a named failure class (Priority: P1)

A developer runs `verify-red` on a behavior whose test does not fail for the
right reason. The tool distinguishes and names each dishonest class —
`compile-error`, `load-error`, `skipped`, `unexpected-green`,
`runner-error` — exits non-zero, and writes NO evidence entry to the cycle
log. The red half is never certified on dishonest evidence.

**Why this priority**: Equal to US1 — a gate that cannot distinguish honest
red from broken tests is worse than no gate, because it launders bad state
into the loop.

**Independent Test**: For each dishonest class, prepare a fixture behavior
exhibiting it; run `verify-red`; confirm non-zero exit, the named class in
the output, and an unchanged cycle log.

**Acceptance Scenarios**:

1. **Given** a behavior whose subject has a compile error, **When** the
   developer runs `zfa tdd verify-red <id>`, **Then** the tool exits
   non-zero, reports classification `compile-error`, and appends nothing to
   `tdd/cycle-log.md`.
2. **Given** a behavior whose test file fails to load (missing import,
   missing file), **When** `verify-red` runs, **Then** it exits non-zero with
   classification `load-error` and no log entry.
3. **Given** a behavior whose test passes (already implemented or vacuous),
   **When** `verify-red` runs, **Then** it exits non-zero with classification
   `unexpected-green` and no log entry.
4. **Given** a behavior whose test is skipped or pending, **When**
   `verify-red` runs, **Then** it exits non-zero with classification
   `skipped` and no log entry.
5. **Given** the test runner itself fails to execute (tooling/infrastructure
   error, timeout), **When** `verify-red` runs, **Then** it exits non-zero
   with classification `runner-error` and no log entry.

---

### User Story 3 - Unambiguous target resolution (Priority: P2)

A developer runs `zfa tdd verify-red` with or without an explicit behavior
id. With an id, the tool resolves that behavior's artifacts from the
registry; an unknown id is an error. Without an id, the tool infers the
target only when exactly one behavior in the feature has registered gen
artifacts but no red-evidence entry yet; zero or multiple such behaviors is
an error that names the candidates and asks for an explicit id.

**Why this priority**: The loop driver needs deterministic targeting; a human
in a loop wants the ergonomic default. Ambiguity must never silently pick a
target.

**Acceptance Scenarios**:

1. **Given** a feature with exactly one gen'd behavior lacking red evidence,
   **When** the developer runs `zfa tdd verify-red` with no arguments,
   **Then** that behavior is verified.
2. **Given** multiple gen'd behaviors lacking red evidence, **When** the
   developer runs `zfa tdd verify-red` with no arguments, **Then** the tool
   exits non-zero listing the candidate behavior ids and asking for an
   explicit id.
3. **Given** an unknown behavior id, **When** the developer runs
   `zfa tdd verify-red B-999`, **Then** the tool exits non-zero naming the
   unknown id, before running any test.
4. **Given** a behavior id present in the test list but with no registered
   gen artifacts, **When** `verify-red <id>` runs, **Then** it exits non-zero
   instructing the developer to run `zfa tdd gen <id>` first.

---

### User Story 4 - Machine-readable result for the loop driver (Priority: P2)

The `zfa tdd run` loop driver (and CI) consumes `verify-red` results
programmatically. The command prints a final machine-readable summary line
containing the behavior id, classification, and outcome, and its exit code
alone is sufficient to distinguish certified-red (0) from any rejection
(non-zero).

**Why this priority**: `zfa tdd run` is the whole point of the epic; its
state machine needs a contract it can parse without scraping prose.

**Acceptance Scenarios**:

1. **Given** any completed `verify-red` invocation, **When** the output is
   parsed, **Then** the final summary line contains the behavior id, the
   classification, and the exit outcome in a stable, documented format.
2. **Given** a CI step that runs `zfa tdd verify-red <id>`, **When** the
   command exits, **Then** exit code 0 means exactly "honest red certified
   and logged" and any non-zero code means "not certified".

---

### Edge Cases

- The registry entry exists but the test file was deleted from disk:
  classified as `load-error` (or a distinct `missing-artifact` rejection),
  non-zero, no log entry.
- The runner output contains multiple test results (profile misconfiguration
  running more than the target test): the command MUST detect the mismatch
  and reject with `runner-error` rather than classify a blended result.
- Re-running `verify-red` on an already-certified behavior: allowed; each run
  appends its own dated evidence entry (the log is append-only history).
- A behavior whose test produces both assertion and non-assertion diagnostics:
  classification MUST be driven by the primary test result, not incidental
  output.
- Flutter vs pure-Dart projects: the runner invocation always comes from
  `tdd-profile.md`; the command never hard-codes a runner.

## Requirements *(mandatory)*

### Functional Requirements

**Target resolution**

- **FR-001**: `zfa tdd verify-red [behavior-id]` MUST resolve the target
  behavior's test path and runnable test name from the artifact registry
  written by `zfa tdd gen`; it MUST NOT rediscover artifacts by globbing.
- **FR-002**: With an explicit id unknown to the registry, the command MUST
  exit non-zero naming the id before running anything. With no id, it MUST
  infer the target only when exactly one behavior has gen artifacts and no
  red evidence; otherwise it MUST exit non-zero listing the candidates (or
  stating that none exist).

**Execution & classification**

- **FR-003**: The command MUST execute exactly the target test using the
  `single` command template from `.specify/memory/tdd-profile.md`; no
  hard-coded runner invocations.
- **FR-004**: The command MUST classify the outcome into exactly one of:
  `assertion` (honest red), `compile-error`, `load-error`, `skipped`,
  `unexpected-green`, `runner-error`.
- **FR-005**: The command MUST reject (non-zero, no evidence) when the runner
  executed anything other than exactly the target test.

**Evidence**

- **FR-006**: On `assertion` classification only, the command MUST append a
  red-evidence entry to `specs/<feature>/tdd/cycle-log.md` containing:
  behavior id, source criterion, test path, runner command, runner exit code,
  classification, captured failure output, and timestamp. The log is
  append-only; entries are never edited or deleted.
- **FR-007**: On any non-`assertion` classification, the command MUST exit
  non-zero, print the named classification with a remediation hint, and write
  no evidence entry.

**Integrity**

- **FR-008**: The command MUST NOT modify, create, or delete any file under
  `test/` or `lib/`; the only file it writes is the cycle-log append.
- **FR-009**: The command MUST print a final machine-readable summary line
  with the behavior id, classification, and outcome; exit code 0 MUST mean
  exactly "honest red certified".
- **FR-010**: The command MUST honor the misfire-stop policy: any internal
  step that cannot complete as specified stops the command immediately with a
  non-zero exit and a clear message.

### Key Entities

- **Artifact Registry**: `specs/<feature>/tdd/artifacts.json` (spec 044) —
  the source of truth for behavior → test path + subject path + runnable
  test name.
- **Cycle Log**: `specs/<feature>/tdd/cycle-log.md` — append-only evidence
  history; red entries are written by this command.
- **TDD Profile**: `.specify/memory/tdd-profile.md` — runner command map
  (spec 041).
- **Red Classification**: The six-way outcome class of a verification run.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% correct classification across a fixture matrix covering
  all six outcome classes (assertion, compile-error, load-error, skipped,
  unexpected-green, runner-error), verified by automated tests.
- **SC-002**: 100% of certified-red runs produce a complete cycle-log entry
  (all eight required fields present); 0% of rejected runs produce an entry.
- **SC-003**: 0 files under `test/` or `lib/` modified across all runs
  (checksum-verified in tests).
- **SC-004**: Target resolution never silently selects among multiple
  candidates: ambiguous invocations fail with a candidate list in 100% of
  cases.
- **SC-005**: The summary line and exit code contract is stable enough for
  `zfa tdd run` to consume without parsing prose (covered by a contract
  test).

## Out of Scope

- Turning red green (`zfa tdd make`) — separate precondition spec.
- Driving multiple behaviors (`zfa tdd run`) — separate precondition spec;
  this command only defines the contract `run` will consume.
- Re-classifying or auditing historical cycle-log entries.
- Changing `zfa tdd gen` artifact shapes (any gap found follows the epic's
  FR-012 gap protocol).

## Assumptions

- The artifact registry format from spec 044 (`artifacts.json`) is stable and
  readable; this command is a consumer only.
- The `tdd-profile.md` `single` template supports running one named test in
  one file (041 FR-004).
- Cycle-log format follows the append-only convention already used by
  existing `tdd/cycle-log.md` files in this repository.
- The loop driver will invoke this command once per behavior; repeated
  invocations are safe and append additional dated entries.
