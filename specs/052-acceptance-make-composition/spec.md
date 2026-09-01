# Feature Specification: `zfa tdd compose` — phase-2 acceptance make composition (wire acceptance subjects against green unit subjects)

**Feature Branch**: `052-acceptance-make-composition`

**Created**: 2026-09-01

**Status**: Draft

**Input**: Issue [#642](https://github.com/arrrrny/zuraffa/issues/642) — "tdd run phase 2: acceptance make cannot actually flip green against the units — planner has no composition surface". Follow-up gap surfaced while verifying #635 (the refactor-deferral fix), per the #625 assessment's Risks & Considerations.

## Mission

`zfa tdd run` defers a phase-1 acceptance `make` that reports `unexpressible` and
re-attempts it at phase 2 (bug #625), then runs the deferred refactors on the
fully-green suite (bug #635). But in the REAL pipeline nothing can flip the
deferred acceptance make green at phase 2: `generation_planner.dart` `plan()` is
pure and description-keyed — expressibility depends only on the behavior
description (entity/CRUD keywords → a plan; otherwise `unexpressible`) — so an
acceptance behavior that reports `unexpressible` in phase 1 (pure
Given/When/Then prose) deterministically reports `unexpressible` again at phase
2. The re-attempt is the by-design honest-stop certification (FR-007 of
049-tdd-run), not a path to green. The driver tests script the acceptance make
as `unexpressible` on the phase-1 attempt and `ok` on the phase-2 attempt — the
flip-green path — but that scripted flip has no real-pipeline counterpart: there
is no composition step that implements an acceptance subject against the
feature's already-green unit subjects once they exist.

This feature closes the loop started by #625 (acceptance deferral) and #635
(refactor deferral): when the planner refuses acceptance prose, the 047 make
pipeline offers a **composition plan** that wires the acceptance subject against
the feature's already-green unit subjects — via an explicit
`zfa tdd compose` step — so deferred acceptance behaviors can actually turn
green at phase 2, while keeping the honest stop for prose that remains
uncomposable.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A deferred acceptance make flips green at phase 2 through the real pipeline (Priority: P1)

A maintainer drives a feature whose acceptance behavior is pure
Given/When/Then prose (no entity/CRUD keywords). Phase 1 certifies the
acceptance behavior red and defers its make (the planner refuses the prose by
design); the unit behaviors complete green. At phase 2 the driver re-attempts
the acceptance make: the planner refuses again, but this time the make pipeline
offers a composition plan — `zfa tdd compose <id>` then `build` — because the
feature's unit subjects are green and their subject artifacts exist. The
compose step implements the acceptance subject by wiring it against those green
unit subjects, the build compiles it, the target acceptance test passes, the
suite guard stays clean, and green evidence is appended. The acceptance
behavior is DONE — the scripted phase-2 flip now has a real-pipeline
counterpart.

**Why this priority**: This is the entire point of the feature — #625's story
is only fully complete when acceptance behaviors can actually turn green at
phase 2. Without it the phase-2 re-attempt is guaranteed to honest-stop.

**Independent Test**: A fixture feature with one acceptance behavior (pure
prose) and one unit behavior, driven through `zfa tdd run` with a pure exec
forwarder to the real zfa CLI: the run completes with both behaviors DONE, the
acceptance subject file carries the composed implementation referencing the
green unit subject, and the cycle log carries green evidence naming the compose
step.

**Acceptance Scenarios**:

1. **Given** a feature with an acceptance behavior whose make is
   unexpressible in phase 1 and unit behaviors that complete green, **When**
   phase 2 re-attempts the acceptance make, **Then** the make falls back to a
   composition plan (`compose` + `build`), the acceptance subject is wired
   against the feature's green unit subjects, the target test passes, and
   green evidence is appended — the run completes with every behavior DONE.
2. **Given** a successful phase-2 composition, **When** the green-evidence
   entry is written, **Then** it records the compose invocation as one of the
   captured generation steps (the audit trail stays honest — every actual
   invocation is captured, never the planner's decision).
3. **Given** the composed acceptance subject file, **When** it is inspected,
   **Then** it was written by the compose step (a generation-pipeline step,
   stamped as such), references the feature's green unit subjects as the
   implementation anchor, and the paired test file is untouched.

---

### User Story 2 - `zfa tdd compose` is the composition surface (Priority: P1)

A maintainer (or the make pipeline) invokes `zfa tdd compose <behavior-id>`.
The command resolves the behavior's registry record (same resolution rules as
`verify-red`/`make`/`wire`), confirms the behavior's subject stub exists and
still carries the `UnimplementedError` shape gen wrote, discovers the
feature's already-green unit subjects (unit-kind rows in the feature's test
list whose behavior ids carry green evidence in `tdd/cycle-log.md` and whose
subject artifacts exist on disk), and replaces the subject stub with the
minimal composed implementation — the green unit subject files are imported
and referenced as the implementation anchor. The command is idempotent: an
already-composed subject reports `already-composed` and exits 0, so a resumed
pipeline re-running the step stays green.

**Why this priority**: The command IS the composition surface — the make
fallback (US1) is a pipeline over it. Without the command there is no
composition.

**Independent Test**: A fixture with an acceptance behavior (red evidence) and
a green unit behavior (green evidence + existing subject file): `zfa tdd
compose A1` exits 0, prints the summary line, rewrites the acceptance subject
with the composed implementation referencing the unit subject, and leaves the
test file untouched; a second invocation reports `already-composed` and exits
0.

**Acceptance Scenarios**:

1. **Given** a registry record with a gen'd subject stub and a feature
   holding at least one green unit subject, **When** `zfa tdd compose <id>`
   runs, **Then** the subject stub's `UnimplementedError` body is replaced by
   the composed implementation that imports and references the green unit
   subject files, and the summary line
   `compose: behavior=<id> outcome=<label> feature=<f>` is the final stdout
   line.
2. **Given** a subject with no `UnimplementedError` left (already composed or
   wired), **When** compose runs again, **Then** it reports
   `already-composed` and exits 0 (idempotent, resume-safe).
3. **Given** the feature has NO green unit subjects (no unit-kind behavior
   carries green evidence), **When** compose runs, **Then** it misfire-stops
   non-zero naming the missing precondition — composition never fabricates
   units to wire against.
4. **Given** a green unit behavior whose recorded subject file is missing on
   disk, **When** compose runs, **Then** it misfire-stops non-zero naming the
   missing artifact — a partial anchor is not silently dropped.
5. **Given** any compose outcome, **When** it finishes, **Then** the paired
   test file is byte-identical to before (044 ownership contract — the
   subject's test is never touched).

---

### User Story 3 - The planner stays pure; the honest stop survives (Priority: P1)

The composition surface lives OUTSIDE the planner: `GenerationPlanner.plan()`
keeps its current pure, description-keyed contract (no phase, run-state, or
subject knowledge; the same input always yields the same plan). Composition
engages only when ALL of these hold: the behavior's test-list row is
acceptance-kind, the planner refused the prose (unexpressible), and the
feature has at least one composable green unit subject. Everything else keeps
today's semantics: entity-bearing acceptance behaviors drive to all-DONE in
phase 1 exactly as before (no regression, SC-018 stays green); unit behaviors
whose make reports unexpressible honest-stop the run exactly as before (FR-007
of 049-tdd-run); acceptance prose with no green unit subjects to wire against
remains uncomposable and honest-stops with the units green.

**Why this priority**: This is the safety rail. A composition surface that
mutates the planner or erodes the honest-stop would break the #625/#635
contracts the driver tests pin.

**Independent Test**: `generation_planner_test.dart` (existing) passes
unchanged — the planner's plan for any description is byte-identical before
and after this feature. A fixture with an acceptance behavior and zero green
unit behaviors: the phase-2 make honest-stops (`unexpressible`), the run
stops non-zero with the units green, exactly as on master.

**Acceptance Scenarios**:

1. **Given** any behavior description the planner maps today, **When**
   `plan()` is called before and after this feature, **Then** the returned
   plan is identical — the planner gains no phase, run-state, or subject
   awareness.
2. **Given** an acceptance behavior deferred at phase 1 whose feature has no
   green unit subjects at phase 2, **When** the re-attempted make runs,
   **Then** it reports `unexpressible` and the run honest-stops non-zero with
   the units green (FR-007 of 049-tdd-run, unchanged).
3. **Given** a unit behavior whose make reports unexpressible, **When** its
   make runs (any phase), **Then** composition never engages — the run honest-
   stops exactly as on master.
4. **Given** an entity-bearing acceptance behavior (description carries
   "create entity"), **When** the feature is driven end to end, **Then** it
   completes all-DONE through the real pipeline in phase 1 exactly as before
   (no regression — the SC-018 path stays green).

---

### User Story 4 - The composition plan is a first-class pipeline plan (Priority: P2)

The composition fallback produces the same artifact type the planner produces:
an ordered plan whose steps execute through the existing `PipelineRunner`
(`compose` then `build` — every expressible plan terminates in a build step,
the only step that produces compile-validated output). A failed compose step
misfire-stops the make with `generation-error` exactly like any other failing
generation step; a failed build likewise. The green-evidence entry records
every executed step, so the audit trail distinguishes a composed make from a
generated one.

**Why this priority**: Reusing the pipeline machinery is what keeps the
composition honest (captured invocations, misfire-stop, build-terminated) but
it is plumbing on top of US1/US2.

**Independent Test**: A fixture whose scripted compose step fails (or whose
build fails): the make stops non-zero with `generation-error`, no green entry
is appended, and the failure names the failed step and its exit code.

**Acceptance Scenarios**:

1. **Given** an acceptance make whose planner refusal triggers the
   composition fallback, **When** the fallback plan executes, **Then** the
   steps run through `PipelineRunner` in order (`compose` → `build`) and each
   invocation is captured with command, exit code, and output.
2. **Given** a compose step that exits non-zero, **When** the make runs,
   **Then** the make stops non-zero with `generation-error`, appends no green
   entry, and names the failed step.
3. **Given** a build step that exits non-zero after a successful compose,
   **When** the make runs, **Then** the make stops non-zero with
   `generation-error` and appends no green entry.

---

### Edge Cases

- An acceptance behavior whose description ALSO carries entity/CRUD keywords
  is expressible to the planner and never reaches the composition fallback
  (the planner's plan wins; composition is a fallback, never an override).
- A green unit subject whose file was deleted after its make certified green:
  compose misfire-stops naming the missing artifact (US2.AC4) rather than
  composing against a partial anchor.
- A feature whose test list carries no unit-kind rows at all: composition has
  nothing to anchor to and misfire-stops with the same "no green unit
  subjects" precondition failure as an all-acceptance feature.
- An acceptance behavior that was already composed (its subject carries no
  stub): the compose step reports `already-composed` and exits 0, so a
  resumed make re-running the plan stays green (idempotence, mirroring
  wire's `already-wired`).
- A subject file with an `UnimplementedError` in an unrecognized shape:
  compose refuses to rewrite a file it did not generate (wire's refusal
  pattern) and misfire-stops.

## Requirements *(mandatory)*

### Functional Requirements

**Composition surface**

- **FR-001**: `zfa tdd compose [behavior-id]` MUST resolve the target
  behavior from the artifact registry with the same resolution rules as
  `zfa tdd wire` (explicit id, registry scan, ambiguity error, planned-but-
  not-gen'd remediation hint).
- **FR-002**: The command MUST require certified-red evidence for the
  behavior in `tdd/cycle-log.md` before composing (composition is the
  implementation step of a certified-red behavior, mirroring make's FR-001).
- **FR-003**: The command MUST discover the feature's composable anchors as:
  unit-kind rows in the feature's `tdd/test-list.md` (parsed by the shared
  `TestListReader`) whose behavior ids carry green evidence in
  `tdd/cycle-log.md` and whose registry `subject_path` artifacts exist on
  disk. A feature with no such anchors MUST misfire-stop non-zero naming the
  missing precondition ("no green unit subjects to compose against").
- **FR-004**: The command MUST replace the subject's `UnimplementedError`
  stub body with the minimal composed implementation — the green unit
  subject files are imported and referenced as the implementation anchor
  (spec 047 FR-005's minimal-generation rule applied to composition). The
  command MUST NOT write any other source file and MUST NOT modify any test
  file.
- **FR-005**: The command MUST be idempotent: a subject with no
  `UnimplementedError` left is reported `already-composed` with exit 0, so a
  resumed pipeline re-running the step stays green. An `UnimplementedError`
  in an unrecognized shape MUST refuse to rewrite the file (non-zero) —
  compose never rewrites a file it did not generate.
- **FR-006**: The command MUST print the machine-readable summary line
  `compose: behavior=<id> outcome=<label> feature=<feature>` as the final
  stdout line on every code path, with exit code 0 meaning exactly
  "composed (or already composed)" — the contract the driver and the make
  pipeline consume.

**Make fallback (phase-2 awareness)**

- **FR-007**: When the planner returns an unexpressible plan for a behavior
  whose test-list row is acceptance-kind, `zfa tdd make` MUST attempt the
  composition fallback: a plan of `compose <id>` → `build` executed through
  the existing `PipelineRunner`, provided the feature has at least one
  composable green unit subject (FR-003's discovery). The fallback MUST NOT
  engage for unit-kind behaviors or for behaviors with no test-list row —
  their unexpressible outcome is the honest stop (FR-007 of 049-tdd-run,
  unchanged).
- **FR-008**: `GenerationPlanner.plan()` MUST remain pure and
  description-keyed with its current mapping rules byte-identical: no phase,
  run-state, subject, or test-list knowledge enters the planner. The
  composition fallback lives in the make command layer (a separate
  composition planner service), consuming discovery results passed to it.
- **FR-009**: When the composition fallback is unavailable (no composable
  green unit subjects) or its plan is unexpressible, the make MUST report
  `unexpressible` exactly as today — the honest stop for prose that remains
  uncomposable, with the planner's unexpressible reason phrased in behavior
  terms.
- **FR-010**: Every fallback-plan invocation MUST be captured as a
  `GenerationStep` and recorded in the green-evidence entry (make's FR-006
  audit rule applies unchanged); a failed compose or build step MUST
  misfire-stop the make with `generation-error` and no green entry, exactly
  like any other failing generation step (US4.AC2 of 047-tdd-make).

**Driver integration (the real phase-2 flip)**

- **FR-011**: The run driver's phase-2a re-attempt of a deferred acceptance
  make MUST go through the same `make` step contract as today (spawn
  `tdd make <id>`, consume `outcome=green`): the flip-green emerges from
  make's composition fallback inside the spawned process, not from a new
  driver step or a relaxed driver contract. The driver's step sequencing,
  deferral rules, and state semantics are unchanged.
- **FR-012**: The refactor deferral (bug #635) and the acceptance deferral
  (bug #625) MUST keep their current outcomes in all scenarios where
  composition cannot flip the make green: the driver's summary line, exit
  codes, and honest-stop reports are unchanged.

### Key Entities

- **CompositionPlan** — the fallback plan for an acceptance make: ordered
  steps (`compose <id>`, `build`), the same `GenerationPlan` shape the
  planner returns, so the pipeline runner consumes it unchanged.
- **ComposableUnitSubject** — one anchor discovered for composition: a
  unit-kind test-list row whose behavior id has green cycle-log evidence and
  whose subject artifact exists on disk (behavior id + subject path).
- **ComposeOutcome** — the command's machine labels: `composed`,
  `already-composed`, `not-certified-red`, `no-green-units`, `runner-error`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A fixture feature with one pure-prose acceptance behavior and
  one unit behavior, driven through `zfa tdd run` with a pure exec forwarder
  to the REAL zfa CLI (SC-017/SC-018 pattern), completes with BOTH behaviors
  DONE — the acceptance behavior flips green at phase 2 through the real
  make + compose pipeline, with no fake-zfa scripting of the phase-2 outcome.
- **SC-002**: The cycle log's green entry for the composed acceptance
  behavior names the `compose` invocation among its captured generation
  steps, and the composed subject file references the green unit subject
  files.
- **SC-003**: An acceptance make with NO composable green unit subjects
  reports `unexpressible` and honest-stops the run non-zero with the units
  green — identical observable behavior to master (the FR-007 honest-stop
  contract of 049-tdd-run holds).
- **SC-004**: A unit behavior whose make reports unexpressible honest-stops
  the run exactly as on master — composition never engages for unit-kind
  behaviors.
- **SC-005**: An entity-bearing acceptance behavior drives to all-DONE
  through the real pipeline exactly as before (no regression to the SC-018
  path; its make is expressible in phase 1 and never defers).
- **SC-006**: The existing `generation_planner_test.dart` suite passes
  unchanged — the planner's plans are byte-identical before and after this
  feature (FR-008).
- **SC-007**: The full fast test suite passes (`dart analyze` clean,
  `tools/run_tests_chunked.sh` OK), with the new behaviors covered by
  fast-tier unit tests and slow-tier scenario tests traced in
  `tdd/test-list.md`.

## Out of Scope

- A new driver step or driver contract change: the run driver spawns the
  same `make` step at phase 2a as today (FR-011); no `compose` step in the
  driver's step order.
- Making the planner phase-aware or run-state-aware in any form (FR-008).
- Composition for unit-kind behaviors (a unit subject implements its own
  logic; wiring it against other units is not composition).
- Composing against non-zuraffa implementations (external packages, hand-
  written subjects): composition anchors are the feature's own green unit
  subjects only.
- Mutating the honest-stop certification semantics of phase-2 re-attempts
  beyond what composition enables (FR-012).

## Assumptions

- The feature's test list is the source of truth for behavior kind
  (acceptance vs unit), consistent with the shared `TestListReader`
  contract; registry records carry no kind of their own.
- Green cycle-log evidence is the source of truth for "already-green unit
  subjects" — the same evidence the driver's reconciliation consumes — so
  make/compose stay independent of `tdd/run-state.json` (the driver owns
  run state; the make pipeline owns the cycle log).
- `zfa build` remains the terminal step of every expressible plan (the
  047 FR-005 rule), so a composed make is compile-validated before its
  target test runs.
- The compose step's emitted implementation is an anchor reference (mirroring
  wire's minimal wired body), not behavioral logic: the acceptance test's
  pass comes from the composed subject satisfying its own assertions via the
  anchored units' surfaces; richer composition logic is refactor-phase work
  and stays out of scope.
