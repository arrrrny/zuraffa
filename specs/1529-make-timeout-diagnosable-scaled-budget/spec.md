# Feature Specification: 1529 make timeout — diagnosable kill receipt, scaled budget, trimmed re-certification

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `feat/1529-make-timeout-diagnosable-scaled-budget`

**Created**: 2026-09-13

**Status**: Draft

**Input**: GitHub issue arrrrny/zuraffa#1529 — "tdd: make step timeout is
diagnose-blind (SIGKILL, no receipt) and the fixed 25-min budget is unsafe
as suite-recertification cost grows"

## Summary

`zfa tdd run`'s make step is spawned as a sub-process under one uniform
deadline (bug #742). When the deadline fires, the child is SIGKILLed and
graded `runner-error` — but the kill is DIAGNOSE-BLIND: no receipt is
written (no `make.<id>.*.json` in the feature's tdd dir), and the captured
output tail is usually just the step header because the child sits inside
a silent `flutter test`/`dart test` invocation. The operator knows only
"it hung somewhere in a suite run" and can only blind re-roll.

Two independent failures in one misfire:

1. **The kill leaves no diagnostic trail.** `StepRunner.run` maps the
   `ProcessTimeoutException` to a `runner-error` StepResult whose output
   is the exception text; nothing durable, structured, or inspectable is
   recorded about WHERE the child was (compiling vs running), WHAT argv
   ran, HOW LONG it actually lived, or WHAT it had produced so far.

2. **The per-step budget does not scale with the work.** The deadline
   (whatever `--timeout` says, default 10 min per step) was calibrated on
   an idle machine. Make's cost grows with the suite it re-certifies
   against: every behavior's make re-runs a strictly larger suite as the
   run progresses (acceptance reds never reach `done`), making total make
   cost roughly quadratic in behavior count. A fixed per-step timeout gets
   LESS safe exactly when the work is biggest — the dogfood run's U2–U7
   scraped through under concurrent load and U8 crossed the line.

Additionally, make's re-certification can still run the FULL suite where a
bounded set would prove the same thing: the behavior's own test plus the
tests whose imports the make step's writes could touch.

## Locked decisions

1. **Receipt on kill (criterion 1).** When the run driver's make STEP
   child is killed by the deadline, the driver writes a structured,
   inspectable receipt at `specs/<feature>/tdd/make.<behaviorId>.timeout.json`
   (stable name — the latest kill wins, matching the issue's
   `make.u8.*.json` glob) containing AT MINIMUM: the schema token, the
   behavior id and step, the child's full argv, the ACTUAL elapsed wall
   time (not just the configured deadline), the inferred phase
   (`compiling` | `running` | `unknown`), the phase evidence (the child
   process-tree snapshot when the platform could observe it, plus the
   captured-output signals used), and the captured output tail. The
   driver prints the receipt path in the failure report. The outcome
   stays `runner-error` (the #742 contract: never a silent pass) and the
   run remains resumable.
2. **Phase inference is best-effort and honest.** On POSIX the killer
   snapshots the child's descendant process argv (`ps`) at the deadline
   before the kill; a descendant matching a test runner
   (`flutter_tester`, a `dart test`/`flutter test` invocation) grades
   phase `running`; one matching a compile/kernel/build step
   (`frontend_server`, kernel snapshot, `build_runner`, `dart compile`)
   grades `compiling`; with no observable signal the phase is `unknown`
   — the receipt NEVER guesses silently, it records the evidence it has.
   Windows and failed snapshots degrade to the captured-output markers,
   then to `unknown`.
3. **Scaled budget (criterion 2).** The run driver's DEFAULT per-step
   budget (no explicit `--timeout`) is derived from the suite-baseline
   duration the driver already measures once per run (#741 capture):
   `budget = max(25 min floor, 4 x measured baseline duration)`. When the
   baseline is reused from a cache (no fresh measurement), the recorded
   duration rides along in the cache file; with no measurement at all the
   floor applies. An explicit `--timeout` ALWAYS wins — the flag is the
   operator's override — but when the projected make cost
   (4 x baseline) meets or exceeds the explicit budget, the driver
   prints a LOUD multi-line warning at run start naming both numbers and
   the remedy. The scaled budget is still ONE uniform deadline handed to
   every spawned step child (issue #1159's contract) and is passed down
   as the child's `--timeout`.
4. **Trimmed re-certification (criterion 3).** make's suite re-run
   certifies ONLY the behavior's own test plus the tests whose transitive
   import closure reaches the files make wrote (the declared write set:
   the registered subject and test paths) — never the full suite — WHEN
   the untouched-rest proof holds: (a) a dependency fingerprint is
   computable (pubspec/lock/suite-template stable, the #1505 corpus
   fingerprint machinery), and (b) a post-generation mtime scan proves
   make modified no shared file outside the declared write set. Any
   condition failing (no fingerprint, shared writes observed, unparseable
   scoped transcript, spawn failure) falls back to the EXISTING paths —
   the live full-suite baseline/guard for standalone make, the cached-
   baseline + scoped single-test guard for driver-driven make — which are
   unchanged. The scoped run appends the scoped test paths to the suite
   template exactly like the #1374 `--baseline-scope` pattern. The
   baseline and the guard always certify the SAME scope (or the guard's
   superset is graded through the existing #731 already-red tolerance
   against the cached full-suite baseline when one exists); an
   unattributable failure is a fail-closed refusal, never a silent pass.
5. **Scope of change (hard constraints).** Only the make STEP timeout
   handling (the driver's spawn/kill/grade path and its receipt), the run
   driver's budget derivation, and make's re-certification set selection
   change. The `zfa make` generation command itself, the suite runner's
   spawn/parse mechanics (`SingleTestRunner.runSuite`), the run-state
   machine, and the cycle-log format do not change.
6. **Small/fast suites are not broken.** When the trimmed scope equals
   the whole suite (every test is in scope) the code runs the full suite
   exactly as before; when the importer set is empty the driver-path
   guard keeps certifying from the already-executed post-generation
   single-test transcript with zero extra spawns; the scaled budget's
   floor (25 min) is never below the old behavior's effective ceiling for
   fast suites.
7. **The receipt is additive evidence, not a gate.** Nothing reads the
   timeout receipt to make decisions in this spec; it exists for the
   operator (and future tooling) so resume is an informed decision
   instead of a blind re-roll. A failed receipt write is reported, not
   fatal (the receipt discipline).

## User Scenarios & Testing

### User Story 1 - A killed make step leaves an inspectable receipt (Priority: P1)

An operator runs `zfa tdd run` on a large feature under concurrent load.
A make step outlives the per-step deadline and is SIGKILLed. Instead of a
blind `runner-error` with a one-line header tail, the failure report names
a receipt file the operator can open to learn: the exact command that
ran, how long the child actually lived, whether it was compiling or
running tests, and everything it printed before the kill.

**Why this priority**: without diagnostics every timeout is an
unactionable blind re-roll — the highest-cost failure mode named in the
issue.

**Independent Test**: drive the run driver against a fake zfa entrypoint
whose make step sleeps past a tiny deadline; assert the runner-error is
reported, the receipt exists at `specs/<feature>/tdd/make.<id>.timeout.json`,
and its JSON carries argv, elapsed, phase, and the captured output tail.

**Acceptance Scenarios**:

1. **Given** a feature whose make step child outlives the per-step
   deadline, **When** the driver kills the child and grades the step,
   **Then** the step outcome is `runner-error` AND
   `specs/<feature>/tdd/make.<behaviorId>.timeout.json` exists with the
   child's argv, the actual elapsed wall time, a phase field, and the
   captured output tail.
   **Type**: acceptance
2. **Given** the killed child was inside a test invocation with a
   flutter_tester/test-runner descendant observable (POSIX), **When** the
   receipt is written, **Then** the phase is `running` with the observed
   argv recorded as evidence; **Given** instead the child shows only
   compile/kernel signals, **Then** the phase is `compiling`; **Given**
   no observable signal at all, **Then** the phase is `unknown` and the
   receipt says so honestly.
   **Type**: unit
3. **Given** the receipt write itself fails (unwritable directory),
   **When** the driver reports the runner-error, **Then** the run still
   stops honestly with a note naming the failed write — the receipt is
   never a gate.
   **Type**: unit

### User Story 2 - The per-step budget scales with the measured suite (Priority: P2)

An operator runs `zfa tdd run` WITHOUT `--timeout` on a repo whose suite
takes 9 minutes. The driver measures the baseline suite once (the #741
capture), derives the per-step budget as `max(25 min, 4 x 9 min) = 36
min`, and hands that ONE uniform deadline to every step child. A second
operator passes `--timeout 25` while the baseline measures 9 minutes;
the driver starts the run but prints a loud warning naming the projected
36-minute make cost against the 25-minute budget before any step spawns.

**Why this priority**: the scaled budget is what makes the run SURVIVE
realistic load; the receipt (US1) is what makes a residual kill
actionable.

**Independent Test**: drive the driver with a fake suite template whose
baseline duration is controlled; assert the spawned step children receive
the scaled (or floor) budget via their `--timeout`, and that an explicit
`--timeout` below the projection triggers the loud warning without
changing the honored value.

**Acceptance Scenarios**:

1. **Given** no explicit `--timeout` and a measured baseline duration of
   B minutes, **When** the driver spawns any step child, **Then** the
   child's effective deadline is `max(25, 4B)` minutes, handed down as
   the child's `--timeout` argument.
   **Type**: unit
2. **Given** an explicit `--timeout 25` and a measured baseline of 9
   minutes, **When** the run starts, **Then** the honored budget stays 25
   minutes AND the driver prints a loud multi-line warning naming
   `4 x 9 = 36` against `25` before the first step spawns.
   **Type**: acceptance
3. **Given** the baseline is reused from a cache that recorded its
   original capture duration, **When** the driver derives the budget,
   **Then** the recorded duration is used in place of a fresh
   measurement (and the floor still applies when no duration is
   recorded).
   **Type**: unit

### User Story 3 - make re-certifies a trimmed scope, not the full suite (Priority: P3)

A make step in a repo with a 50-minute full suite writes only the
behavior's subject and test files (the mtime scan proves no shared file
was touched) and a dependency fingerprint is computable. Its baseline and
guard runs certify only the behavior's own test plus the tests whose
import closures reach those written files — never the full suite. A
neighbor repo where make DOES touch a shared DI file keeps the existing
full-suite certification for that make.

**Why this priority**: the trimming removes the quadratic growth (the
root cause), but the receipt and the scaled budget already de-risk the
failure mode; this is the economics fix.

**Independent Test**: point the scoping service at a fixture tree (own
test, an importer test, an unrelated test, package: self imports,
exports); assert the scope contains exactly the own test and the
importer; drive make's re-certification decision against a stubbed
transcript source and assert the scoped command, the same-scope baseline/
guard pairing, and every fallback.

**Acceptance Scenarios**:

1. **Given** a project where the behavior's write set is {subject, own
   test} and exactly one other test imports the subject, **When** make
   picks its re-certification set, **Then** the scoped run certifies
   exactly {own test, importer test} and never spawns the full suite.
   **Type**: acceptance
2. **Given** the scope computation covers every test file in the
   project, **When** make picks its re-certification set, **Then** the
   full suite runs exactly as before (no behavior change for
   small/fast suites).
   **Type**: unit
3. **Given** a dependency fingerprint is not computable (no pubspec) OR
   the mtime scan shows a shared file modified outside the declared
   write set OR the scoped transcript is unparseable, **When** make
   picks its re-certification set, **Then** the existing full-suite (or
   cached-baseline) path runs unchanged — fail-closed, never a silent
   pass.
   **Type**: unit

## Requirements

### Functional Requirements

- **FR-1**: The run driver MUST write the make-step timeout receipt
  before reporting the runner-error stop, and MUST print the receipt's
  path in the failure report.
- **FR-2**: The receipt MUST contain: a schema token
  (`tdd-make-timeout-receipt.v1`), the behavior id, the step name, the
  child argv (as executed), the actual elapsed wall time, the configured
  deadline, the inferred phase, the phase evidence (descendant argv
  snapshot and/or output markers), and the captured output tail.
- **FR-3**: Phase inference MUST prefer the observed process-tree
  evidence, then captured-output markers, then grade `unknown` — it MUST
  NOT present a guess as an observation.
- **FR-4**: The default per-step budget (no explicit `--timeout`) MUST
  be `max(25 min, 4 x measured baseline suite duration)`; with a cached
  baseline the recorded duration substitutes for a fresh measurement;
  with no duration at all the 25-minute floor applies.
- **FR-5**: An explicit `--timeout` MUST always win; when
  `4 x measured baseline >= explicit budget` the driver MUST print a
  loud multi-line warning naming both numbers before the first step
  spawns.
- **FR-6**: The scaled budget MUST be handed to every step child as the
  ONE uniform deadline (the #1159 contract), including the `--timeout`
  the child inherits.
- **FR-7**: The baseline caches (#741 feature-local, #1505 corpus-wide)
  MUST persist the measured capture duration and make it available to
  the budget derivation; older cache files without a duration keep
  working (floor applies).
- **FR-8**: make's re-certification set MUST be the behavior's own test
  plus the tests whose transitive import closure (imports, exports,
  parts; relative and self-package URIs) reaches the declared write set
  (the registered subject and test paths), computable as a pure function
  over the test tree.
- **FR-9**: The trimmed path MUST require BOTH a computable dependency
  fingerprint AND a post-generation mtime scan proving no shared file
  was modified outside the declared write set; otherwise the existing
  full-suite/cached-baseline path runs unchanged.
- **FR-10**: The scoped run MUST append the scoped test paths to the
  suite template (the #1374 pattern), MUST be parseable (else fall
  back), and the baseline and guard MUST certify the same scope — an
  unattributable guard failure is a fail-closed refusal, never a silent
  pass.
- **FR-11**: When the scope equals the whole test tree, or the importer
  set is empty on the driver path, the existing behavior runs with no
  extra spawns.
- **FR-12**: The receipt write MUST be best-effort: a failed write is
  reported on stderr and never changes the run's outcome or exit code.

### Success Criteria (measurable)

- **SC-1**: A make step killed at the deadline produces
  `specs/<feature>/tdd/make.<behaviorId>.timeout.json` with argv,
  elapsed, phase, and output tail present (US1 scenario 1) — verified by
  a fast-tier driver test with a fake zfa entrypoint.
- **SC-2**: The phase field is one of `compiling`|`running`|`unknown`
  and every non-unknown value carries its evidence — verified by pure
  unit tests over the inference function.
- **SC-3**: With a 9-minute measured baseline and no explicit
  `--timeout`, spawned step children receive `--timeout` = 36.0000
  minutes; with a 4-minute baseline they receive 25.0000 (the floor) —
  verified by unit tests over the budget function plus a driver test
  asserting the hand-down.
- **SC-4**: An explicit `--timeout 25` with a 9-minute baseline prints
  the loud warning naming 36 vs 25 and still honors 25 — verified by a
  driver test.
- **SC-5**: The scoping service returns exactly {own test, importer} for
  the fixture tree with an unrelated test present, handles package:
  self-imports and exports, and returns the full-tree signal when
  everything is in scope — verified by pure unit tests.
- **SC-6**: make's re-certification decision yields the scoped command
  only under FR-9's conditions and every fallback branch preserves the
  pre-existing behavior — verified by unit tests over the decision
  function plus the existing make/driver suites staying green.
- **SC-7**: `dart analyze` on the changed files reports no new warnings;
  the existing fast-tier suites for the touched surfaces stay green.

## Key Entities

- **MakeTimeoutReceipt**: the durable kill record (schema, behavior,
  step, argv, elapsed, deadline, phase, evidence, output tail); written
  to `specs/<feature>/tdd/make.<behaviorId>.timeout.json`.
- **StepBudget**: the per-step deadline the driver derives:
  `max(floor, multiple x baseline)` with explicit-override semantics.
- **RecertScope**: the trimmed certification set: own test + import-
  closure hits over a write set; `null` = run the full suite.
- **BaselineDurationMs**: the measured wall time of a suite baseline
  capture, persisted alongside the #741/#1505 snapshots.

## Risks & Mitigations

- **Process-tree observation is platform-dependent** → best-effort by
  design: `ps` on POSIX, absent on Windows, `unknown` phase when
  nothing is observable; the receipt records what it has.
- **Import-closure scoping can miss dynamic imports** → the trimmed
  path only fires when the mtime scan proves make wrote nothing outside
  the declared set; string-based dynamic imports of untouched files
  cannot be affected by those writes.
- **The scaled budget lengthens worst-case hangs on the default path**
  → the floor is 25 min (not 10) by the issue's own calibration, and
  the explicit `--timeout` override remains the operator's lever; the
  loud warning surfaces mismatches either way.
- **Receipt sprawl** → one stable filename per behavior (latest kill
  wins); the receipt is evidence for the CURRENT misfire, matching the
  issue's `make.u8.*.json` glob.
