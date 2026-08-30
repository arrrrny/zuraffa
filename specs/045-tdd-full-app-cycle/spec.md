# Feature Specification: zfa tdd Full-App Cycle — build a zik_zak-scale app using ONLY the zfa tdd loop

**Feature Branch**: `045-tdd-full-app-cycle`

**Created**: 2026-08-30

**Status**: Draft

**Input**: User description: "zfa tdd plugin MUST be able write a full app in the scale of Developer/zik_zak ONLY by zfa tdd cycle. Developer/zik_zak_tdd is a greenfield project with all specs extracted from zik_zak, new implementation should be COMPLETED only with the zfa tdd cycle. BE REALISTIC, COMPREHENSIVE ABOUT REQUIREMENTS. 041-tdd-plugin has unimplemented stub phases for 6-10. THIS IS THE CORE of the zuraffa automation so make sure you establish all requirements first, PRECISELY DEFINE them as separate specs, so no work starts before those preconditions are met."

## Mission

Prove and complete the core zuraffa automation claim: a full application at the
scale of `~/Developer/zik_zak` (144 entities, 56 use-case domains, 60 feature
specs, ~2,000 Dart files, ~230k lines) can be produced in a greenfield project
(`~/Developer/zik_zak_tdd`) using **only** the `zfa tdd` red-green-refactor
cycle — `tdd plan → tdd gen → tdd verify-red → tdd make → tdd refactor`,
driven per feature by `zfa tdd run` — with zero hand-written production code
outside the documented manual-UI carve-out.

Current state (verified against `lib/src/plugins/tdd/`):

- **Delivered** (spec 041): `zfa tdd init`, `zfa tdd plan`, plus the
  `zfa setup` TDD baseline.
- **Delivered** (spec 044): `zfa tdd gen` (behavior-aware honest-red
  test+subject generation, artifact registry, ownership conflicts) and
  `zfa tdd verify` (trustworthy mutation evidence with preflight, gate
  decisions, source restoration).
- **Stubbed — NOT implemented**: `zfa tdd verify-red` (Phase 7, T055-T061),
  `zfa tdd make` (Phase 8, T062-T065), `zfa tdd refactor` (Phase 9, T066-T069),
  `zfa tdd run` (Phase 10, T070-T076). Each currently exits with a
  "not yet implemented" misfire-stop.

This spec is an **epic/gate spec**: its primary deliverable is the precise
definition of the precondition specs below. No implementation work on the
remaining phases starts before those preconditions exist and pass their own
quality validation.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Precondition specs are established before any work starts (Priority: P1)

A maintainer wants the remaining TDD-loop capability specified with the same
rigor as 041/044 before a single line of implementation is written. Each
remaining phase and the greenfield harness gets its **own separate spec**
created via `/speckit-specify`, each passing its own quality checklist with no
unresolved `[NEEDS CLARIFICATION]` markers. Only after all precondition specs
exist and are validated may planning or implementation for them begin.

**Why this priority**: This is the user's explicit hard gate ("no work starts
before those preconditions are met"). The TDD plugin is the core of zuraffa
automation; an under-specified loop driver would corrupt every downstream
artifact at app scale.

**Independent Test**: List the required precondition specs (see
*Precondition Specs* section) and confirm each exists under `specs/` with a
completed `checklists/requirements.md` showing all items passing.

**Acceptance Scenarios**:

1. **Given** this epic spec is approved, **When** the maintainer reviews the
   `specs/` directory, **Then** a separate spec exists for each of: `verify-red`
   (Phase 7), `make` (Phase 8), `refactor` (Phase 9), `run` (Phase 10), and the
   `zik_zak_tdd` greenfield harness — each with its own validated checklist.
2. **Given** any precondition spec missing or still carrying
   `[NEEDS CLARIFICATION]` markers, **When** anyone attempts to start planning
   or implementation for that phase, **Then** the work is refused and the
   missing specification is completed first.
3. **Given** all precondition specs validated, **When** implementation of a
   phase begins, **Then** it traces to its own spec's requirements, not to this
   epic's summary alone.

---

### User Story 2 - Greenfield `zik_zak_tdd` harness created only via zfa commands (Priority: P1)

A maintainer needs a clean-room target project at `~/Developer/zik_zak_tdd`
whose entire skeleton comes from `zfa` commands: scaffolded by `zfa setup`,
brought to the TDD baseline by `zfa tdd init`, with every entity created by
`zfa entity create` and every architecture layer by `zfa make`/`zfa build`.
The requirements corpus is extracted from `~/Developer/zik_zak`'s existing
specs (60 feature specs) and domain model (144 entities, 56 use-case domains)
into `zik_zak_tdd/specs/`, so every behavior the app must exhibit traces to a
spec containing acceptance scenarios.

**Why this priority**: Without the harness and corpus, there is nothing for
the cycle to build and no way to prove the scale claim.

**Independent Test**: `cd ~/Developer/zik_zak_tdd && flutter test` exits 0 on
a fresh harness; every file under `lib/` is attributable to a recorded `zfa`
command; `specs/` in `zik_zak_tdd` contains the extracted feature specs, each
with at least one `Given/When/Then` acceptance scenario.

**Acceptance Scenarios**:

1. **Given** `~/Developer/zik_zak_tdd` does not exist, **When** the harness is
   created, **Then** it is scaffolded exclusively via `zfa setup` and
   `zfa tdd init` (or their documented equivalents), and `flutter test` passes
   on the untouched scaffold.
2. **Given** the extracted spec corpus, **When** `zfa tdd plan <feature>` runs
   against any extracted feature spec, **Then** it produces a `test-list.md`
   whose behaviors trace back to that spec's scenarios and requirements.
3. **Given** any file under `zik_zak_tdd/lib/`, **When** its provenance is
   audited, **Then** it maps to a logged `zfa` command invocation; files that
   cannot be attributed are treated as contract violations.

---

### User Story 3 - `zfa tdd verify-red` proves honest red (Priority: P2)

Per 041 User Story 5 and its Phase 7 tasks (T055-T061): the developer runs
`zfa tdd verify-red` after `gen`; the tool runs the target test, parses runner
output, asserts the failure is an assertion failure (not compile/load error,
not skip, not unexpected green), appends red evidence to `tdd/cycle-log.md`,
and exits non-zero on any dishonest red.

**Why this priority**: The loop's credibility depends on proving the red half;
without it, `make` has no trustworthy starting point.

**Independent Test**: On a `gen`-produced behavior, `zfa tdd verify-red` exits
0 and appends a classified red-evidence entry; on a tampered (compiling-green
or compile-broken) test it exits non-zero and writes no evidence.

**Acceptance Scenarios**:

1. **Given** an honestly-red `gen` artifact pair, **When** the developer runs
   `zfa tdd verify-red`, **Then** the failure is classified as an assertion
   failure, a red-evidence entry (behavior id, runner command, exit code,
   captured output) is appended to `tdd/cycle-log.md`, and the command exits 0.
2. **Given** a test that fails to compile or load, **When** `verify-red` runs,
   **Then** it exits non-zero naming the compile/load class and writes no
   evidence entry.
3. **Given** a test that is unexpectedly green, **When** `verify-red` runs,
   **Then** it exits non-zero reporting the premature green and writes no
   evidence entry.

---

### User Story 4 - `zfa tdd make` turns red green via generation only (Priority: P2)

Per 041 User Story 6 and Phase 8 tasks (T062-T065): the developer runs
`zfa tdd make <behavior-id>`; the tool produces the minimal implementation
exclusively through `zfa make`/`zfa entity create`/`zfa build`, runs the
target test green, runs the full suite to catch sibling regressions, and
appends green evidence. It never hand-writes source and never modifies a test
to force a pass.

**Why this priority**: This is the generative heart of the claim — production
code at app scale must come from the generator pipeline, not from hand patches.

**Acceptance Scenarios**:

1. **Given** an honestly-red behavior, **When** the developer runs
   `zfa tdd make <behavior-id>`, **Then** the implementation is produced via
   the generation pipeline, the target test passes, the full suite stays green,
   and a green-evidence entry is appended to `tdd/cycle-log.md`.
2. **Given** a behavior the generation pipeline cannot satisfy, **When**
   `make` runs, **Then** it exits non-zero naming what it could not generate
   and leaves the test untouched (misfire-stop, per the repository
   STOP-ON-ROADBLOCK rule).
3. **Given** a green target test that breaks a previously-green sibling,
   **When** `make` runs the full suite, **Then** it exits non-zero naming the
   regressed test rather than declaring the behavior done.

---

### User Story 5 - `zfa tdd refactor` on green suites only, never touching tests (Priority: P3)

Per 041 User Story 7 and Phase 9 tasks (T066-T069): the developer runs
`zfa tdd refactor`; the tool asserts the suite is fully green before any
change, applies refactors through the generation/build machinery, re-runs the
suite afterwards, and never modifies a test file.

**Acceptance Scenarios**:

1. **Given** a fully green suite, **When** the developer runs
   `zfa tdd refactor`, **Then** the green preflight passes, the refactor is
   applied via the existing machinery, and the suite is re-run green before
   the command exits 0.
2. **Given** a red suite, **When** `refactor` runs, **Then** it exits non-zero
   before any change, naming the failing test.
3. **Given** a refactor that introduces a regression, **When** the post-run
   suite executes, **Then** the command exits non-zero naming the regressed
   test and records no success evidence.

---

### User Story 6 - `zfa tdd run` drives the full loop, resumable at app scale (Priority: P2)

Per 041 User Story 8 and Phase 10 tasks (T070-T076): the developer runs
`zfa tdd run <feature>`; the driver advances every behavior in
`tdd/test-list.md` through `PENDING → RED → GREEN → DONE` by invoking
`gen → verify-red → make → refactor`, persists per-behavior state so an
interrupted run resumes where it stopped, and stops immediately (non-zero,
behavior left `RED`, no test edits) when any step cannot complete. At app
scale this must survive interruptions across sessions and machines.

**Acceptance Scenarios**:

1. **Given** a feature with N behaviors, **When** the developer runs
   `zfa tdd run <feature>`, **Then** each behavior advances through all four
   states in order, the cycle log holds one red and one green entry per
   behavior, and the final suite is green.
2. **Given** a run interrupted mid-feature, **When** the developer re-runs the
   same command (possibly in a later session), **Then** completed behaviors
   are not re-done and the run resumes from the last incomplete state.
3. **Given** a behavior whose `make` step hits a generator gap, **When** the
   driver reaches it, **Then** the driver stops non-zero, leaves the behavior
   `RED`, documents the gap, and makes no workaround edits.

---

### User Story 7 - Full-app proof gate at zik_zak scale (Priority: P1)

A maintainer wants the decisive evidence: the extracted corpus is driven
through the completed loop in `zik_zak_tdd`, and the result is a real,
compiling application whose entire suite is green, whose verification audit
passes, and in which every production file is traceable to a `zfa` command
invocation recorded in the cycle logs. **Proof scope (clarified 2026-08-30):
full zik_zak parity** — all 60 feature specs and all 144 entities, including
UI-heavy features. The proof is not complete on a subset.

**Why this priority**: This is the epic's reason to exist — the scale claim is
only credible with a completed, audited app.

**Independent Test**: From a clean checkout of `zik_zak_tdd`: the project
analyzes clean, the full test suite is green, `zfa tdd verify` reports a
passing gate, and a provenance audit attributes 100% of `lib/` files (outside
the manual-UI carve-out) to logged `zfa` commands.

**Acceptance Scenarios**:

1. **Given** the precondition specs are implemented, **When** the extracted
   corpus is processed feature-by-feature through `zfa tdd run`, **Then**
   every feature ends with all behaviors `DONE`, a green suite, and a passing
   `zfa tdd verify` gate.
2. **Given** the completed `zik_zak_tdd`, **When** a provenance audit runs,
   **Then** 100% of production files outside the documented manual carve-out
   trace to logged generator invocations; any unattributed file fails the
   gate.
3. **Given** a generator gap encountered during the corpus run, **When** the
   loop stops on it, **Then** the gap is documented and fixed in zuraffa
   itself (merged) before the corpus run resumes — partial or worked-around
   progress does not count toward the proof.

---

### Edge Cases

- A `zfa tdd run` interrupted across days/sessions must resume from persisted
  state, not restart; the state file must reflect the last fully completed
  step only.
- An extracted zik_zak spec may reference capabilities the generator pipeline
  cannot express (custom parsers, platform integrations); the loop must
  misfire-stop and surface the gap rather than fake a pass.
- The full suite at app scale may take minutes; per-behavior full-suite runs
  must not make the loop unusably slow (suite-scope strategy is a phase-spec
  concern, but the epic requires the corpus run to be completable).
- An extracted spec edited mid-run must reconcile through `zfa tdd plan`'s
  stable behavior IDs without renumbering completed behaviors.
- Flaky tests in a large suite must be detectable as dishonest evidence, not
  silently absorbed into green logs.
- `zik_zak_tdd` does not exist yet; its creation is part of the harness story
  and must itself obey the zfa-only rule.

## Requirements *(mandatory)*

### Functional Requirements

**Preconditions (hard gate)**

- **FR-001**: Before any planning or implementation of the remaining TDD
  phases, a separate, individually validated spec MUST exist for each item in
  *Precondition Specs*; work on a phase whose spec is missing or unvalidated
  MUST be refused.
- **FR-002**: Each precondition spec MUST define its own acceptance scenarios,
  functional requirements, and measurable success criteria, and MUST pass its
  own specification quality checklist with zero unresolved clarification
  markers.

**Harness & corpus**

- **FR-003**: `~/Developer/zik_zak_tdd` MUST be created exclusively through
  `zfa` commands (scaffold, TDD baseline, entities, architecture); no
  hand-created entities or hand-edited generator-owned files.
- **FR-004**: The requirements corpus MUST be extracted from zik_zak's specs
  and domain model into `zik_zak_tdd/specs/` such that every in-scope app
  behavior traces to a spec with at least one acceptance scenario.
- **FR-005**: A provenance audit MUST be able to attribute every file under
  `zik_zak_tdd/lib/` to a specific logged `zfa` command invocation, except
  files inside the documented manual-UI carve-out. **Carve-out (clarified
  2026-08-30): allowed** — view composition details, page-specific widget
  layout, and styling refinements (the repository AGENTS.md "Handcraft only"
  list) may be hand-written, but each such file MUST be declared in the
  carve-out manifest; anything not declared and not generator-attributed
  fails the audit.

**Loop completion (each detailed by its own precondition spec)**

- **FR-006**: `zfa tdd verify-red` MUST implement 041 User Story 5 / Phase 7:
  assertion-failure classification, red-evidence logging, non-zero exit on
  compile/load failure or unexpected green.
- **FR-007**: `zfa tdd make` MUST implement 041 User Story 6 / Phase 8:
  implementation via the generation pipeline only, target-test green,
  full-suite regression check, green-evidence logging, misfire-stop when the
  pipeline cannot satisfy the behavior.
- **FR-008**: `zfa tdd refactor` MUST implement 041 User Story 7 / Phase 9:
  green-suite preflight, production-code-only changes, post-refactor suite
  re-run, non-zero exit on regression.
- **FR-009**: `zfa tdd run` MUST implement 041 User Story 8 / Phase 10:
  per-behavior `PENDING → RED → GREEN → DONE` state machine, persisted
  resumable state, immediate non-zero stop on any step that cannot complete,
  no test modification to fake a pass.
- **FR-010**: Every `zfa tdd` subcommand MUST consult the project's
  `.specify/memory/tdd-profile.md` as the single source of truth for runner
  invocations, and MUST honor the repository STOP-ON-ROADBLOCK policy: stop,
  document, file the zuraffa gap, and wait for a merged fix before resuming.

**Proof gate**

- **FR-011**: The epic is complete only when the extracted corpus has been
  driven through the loop in `zik_zak_tdd` and: the project analyzes clean,
  the full suite is green, `zfa tdd verify` passes per its gate policy, and
  the provenance audit of FR-005 reports 100% attribution.
- **FR-012**: Every generator gap hit during the corpus run MUST be recorded
  (command, expected, actual, root cause) and resolved in zuraffa via a merged
  fix before the corpus run resumes; worked-around progress MUST NOT count
  toward completion.

### Key Entities

- **Precondition Spec**: A standalone spec under `specs/` gating one phase of
  the loop or the harness; carries its own checklist and acceptance criteria.
- **Corpus**: The set of feature specs extracted from zik_zak into
  `zik_zak_tdd/specs/`, the source of all behaviors.
- **Behavior / Test List / Cycle Log / Cycle State / Artifact Registry /
  Verification Report**: as defined by specs 041 and 044 (`tdd/test-list.md`,
  `tdd/cycle-log.md`, `tdd/run-state.json`, `tdd/artifacts.json`,
  `tdd/verification.md`).
- **Provenance Record**: The mapping from a production file to the logged
  `zfa` invocation that created it.
- **Carve-out Manifest**: The declared list of hand-written files allowed
  under the manual-UI carve-out; anything outside it must be
  generator-attributed.

## Precondition Specs (blocking)

Each MUST be created as its own feature via `/speckit-specify` and validated
before its phase starts. Suggested scopes (each spec author owns the details):

1. **`zfa tdd verify-red`** (041 Phase 7, T055-T061) — honest-red
   classification, evidence logging, dishonest-red rejection.
2. **`zfa tdd make`** (041 Phase 8, T062-T065) — generation-only green, suite
   regression guard, misfire-stop contract.
3. **`zfa tdd refactor`** (041 Phase 9, T066-T069) — green-only refactoring,
   test-file immutability.
4. **`zfa tdd run`** (041 Phase 10, T070-T076) — loop driver, state machine,
   resumability across sessions.
5. **`zik_zak_tdd` greenfield harness** — scaffold + baseline + spec-corpus
   extraction + provenance audit mechanism.

Note: `zfa tdd gen` (Phase 6) is already delivered by spec 044 and needs no
new spec; gaps discovered in it during the corpus run follow FR-012.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All 5 precondition specs exist and pass their quality
  checklists before any phase implementation begins (0 exceptions).
- **SC-002**: A single `zfa tdd run <feature>` invocation drives a feature
  from extracted spec to green suite with zero hand-written production source,
  evidenced by the cycle log and provenance audit.
- **SC-003**: An interrupted corpus run resumes and completes strictly less
  remaining work than a fresh run, across sessions.
- **SC-004**: The completed `zik_zak_tdd` proof covers 100% of the full-parity
  corpus (all 60 extracted feature specs, all 144 entities) with every
  behavior traced from spec criterion → test-list row → red evidence → green
  evidence.
- **SC-005**: The provenance audit attributes 100% of production files to
  logged generator invocations, excluding only files declared in the approved
  manual-UI carve-out manifest.
- **SC-006**: Every generator gap encountered is logged and resolved by a
  merged zuraffa fix before resume; the final report lists total gaps found
  and fixed, and zero unresolved workarounds.
- **SC-007**: The final `zik_zak_tdd` state passes: clean static analysis,
  100% green suite, and a passing verification gate as defined by the
  `zfa tdd verify` spec (044).

## Out of Scope

- Changes to already-delivered commands (`init`, `plan`, `gen`, `verify`)
  except via the FR-012 gap-fix protocol.
- Porting zik_zak's backend services, credentials, store assets, or private
  API keys; the proof targets the application codebase, not operations.
- Performance benchmarking of the generated app beyond a green suite and
  clean analysis.

## Assumptions

- `~/Developer/zik_zak_tdd` will be created fresh as a Flutter project via
  `zfa setup` (zik_zak is a Flutter app); the directory does not exist today.
- zik_zak's specs and source are readable on this machine and serve as the
  extraction source; extraction is a mechanical copy/normalize, not a
  re-authoring of requirements.
- The repository STOP-ON-ROADBLOCK rule (AGENTS.md) applies verbatim to the
  corpus run: gaps stop the run and are fixed in zuraffa, never worked around.
- The mutation-gate threshold for app scale is defined by the `verify` phase
  policy (spec 044); this epic does not relax it.
- Behavior IDs remain stable across re-planning (spec 041 FR-011), so corpus
  edits mid-run do not invalidate completed behaviors.
