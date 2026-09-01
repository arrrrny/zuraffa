# Research: `zfa tdd compose` — phase-2 acceptance make composition

Feature: 052-acceptance-make-composition | Date: 2026-09-01 | Spec: [spec.md](./spec.md)

## R1 — Where does composition awareness live?

**Question**: The planner has no composition surface (#642). Should phase/run
awareness enter `GenerationPlanner.plan()`, or live in the command layer?

**Findings**:

- `generation_planner.dart` `plan()` is pure and description-keyed: its
  doc comment pins "It never reads or writes files, never invokes
  subprocesses"; expressibility depends only on description keywords
  (`create entity` / `entity … with` → entity plan; CRUD/use-case keywords →
  make plan; otherwise `unexpressible`). Its inputs are a `BehaviorSummary`
  (id, feature, criterion, description, target) — no phase, no run state,
  no subjects.
- The #625 verification (`.specify/bugs/tdd-run-acceptance-deferral/tdd/
  verification.md`, finding 2) already flagged the pure planner as the
  structural reason a phase-2 re-attempt deterministically repeats the
  phase-1 refusal. Making the planner stateful would couple the pure
  translation layer to driver semantics and invalidate
  `generation_planner_test.dart`'s pinned plans.
- The make command (`make_command.dart`) is the natural host: it already
  owns precondition checks (certified-red, drift, baseline), consumes
  `planner.plan(summary)` verbatim, and executes the plan via
  `PipelineRunner`. A fallback consulted AFTER the planner refuses is a
  local, additive change.

**Decision**: Composition awareness lives in the make command layer behind a
separate pure service (`CompositionPlanner`); `plan()` is untouched
(spec FR-008, SC-006). Alternative rejected: a phase-aware flag on
`BehaviorSummary.plan()` — it would thread run-phase knowledge into every
planner call site and break the pure contract the existing tests pin.

## R2 — What counts as an "already-green unit subject"?

**Question**: How does the composition surface discover the anchors it wires
against, without reading driver state?

**Findings**:

- `tdd/run-state.json` is the driver's private state (owned by
  `RunStateStore`, with in-flight markers and pid-based concurrency
  refusals). Reading it from make would couple the make pipeline to driver
  semantics the spec forbids touching (FR-011/FR-012) and break standalone
  make invocations.
- `tdd/cycle-log.md` green evidence is the driver-independent "certified
  green" record: `CycleEvidence.greenEvidence()` parses `kind: green`
  sections into behavior ids; make already reads the cycle log for
  certified-red (its FR-001 precondition).
- Behavior kind (acceptance vs unit) lives only in the test list;
  `TestListReader` is the single format contract (bug #617) whose rows
  carry `kind` and `target`. Registry records (`artifacts.json`) map
  behavior id → `subject_path` (gen wrote them; wire consumes the same
  field).

**Decision**: A composable anchor = unit-kind `TestListReader` row ∩ green
cycle-log evidence ∩ existing `subject_path` artifact. Discovery is a pure
service over the three file contracts (`composition_targets.dart`). A green
unit whose subject file is missing is a misfire-stop, not a silent skip
(US2.AC4). Alternative rejected: run-state.json — driver-owned, stale-prone,
and standalone-make-incompatible.

## R3 — Which behaviors may compose?

**Question**: Should the fallback engage for any unexpressible make, or only
acceptance-kind behaviors?

**Findings**:

- The driver defers ONLY acceptance makes reporting `unexpressible`
  (bug #625 rule: `step == 'make' && row.kind == acceptance &&
  outcome == 'unexpressible'`). A unit make reporting unexpressible is an
  immediate honest stop (FR-007 of 049-tdd-run) — it never reaches phase 2.
- A unit subject's semantic is "implements its own logic"; wiring a unit
  subject against OTHER units is not composition and would erase the
  honest-stop for genuine generator gaps ("parse bespoke syntax").
- The issue scopes the gap to acceptance subjects: "there is no composition
  step that implements an acceptance subject against the unit subjects once
  they exist".

**Decision**: The fallback engages only when the behavior's test-list row is
acceptance-kind (spec FR-007). No row → no fallback (fail-closed). A
malformed test list stops the fallback with a named error rather than
guessing kinds.

## R4 — Command shape for the composition step

**Question**: Compose as a make-internal step only, or an explicit
`zfa tdd compose` command?

**Findings**:

- Wire (`zfa tdd wire`, bug #610) established the precedent: subject
  implementation lives in a dedicated tdd-plugin subcommand because the
  subject contract (`lib/tdd/<id>_subject.dart` — fixture layout
  `lib/<snake>_subject.dart`, registry `subject_path`) is owned by the tdd
  plugin, and a dedicated invocation gives the provenance audit a clean,
  self-describing attribution record. The issue's suggested direction names
  "an explicit `zfa tdd compose` step in the 047 make pipeline".
- The make pipeline consumes plans of argv specs (`GenerationStepSpec`), so
  the fallback plan's `compose` step is just `['tdd', 'compose', id]` — the
  same indirection `entity create` / `make` / `tdd wire` steps already use.

**Decision**: `zfa tdd compose <behavior-id>` as a first-class subcommand
(wire's sibling: resolution rules, stub-signature parsing, ownership
refusals, `already-composed` idempotence, summary-line contract), and the
fallback plan invokes it through `PipelineRunner` so every invocation is
captured (spec FR-001/FR-006/FR-010).

## R5 — What does the composed subject contain?

**Question**: The compose step rewrites a stub body — what is the minimal
honest content?

**Findings**:

- Wire emits a minimal "implementation anchor" body: the generated entity is
  imported and referenced (`final Type wiredEntityAnchor = <Entity>;`), with
  a GENERATED stamp naming the command, behavior id, criterion, and anchor.
  The paired test is never touched (044 ownership).
- The acceptance subject's anchors are the feature's green unit subject
  files. Importing and referencing them as typed anchors is the same
  minimal-generation rule (047 FR-005) applied to composition: the emitted
  code is compile-validated by the plan's terminal `build` step.
- In the real pipeline the acceptance test that phase 2 flips is authored by
  the fixture harness (a Given/When/Then prose behavior); the composed
  anchor is what makes the subject real and buildable — richer composition
  logic is refactor-phase work (spec Assumptions).

**Decision**: Compose emits the GENERATED-stamped subject with the green
unit subjects as imported, referenced anchors (`final List<Type>
composedUnitAnchors = [U1Subject, ...]` shape rendered from the resolved
subject libraries), replacing the `UnimplementedError` stub. Unrecognized
stub shapes are refused, not rewritten (US2 edge case).

## R6 — Driver integration surface

**Question**: Does the run driver need any change?

**Findings**:

- Phase 2a already re-spawns `tdd make <id>` for deferred acceptance
  behaviors and consumes `outcome=green` (run_command.dart, `_driveBehavior`
  + `_phaseTwoMakeSteps`). The deferral rules (`unexpressible` → defer in
  phase 1 only) and the honest stop in phase 2 are pinned by driver tests.
- If make's fallback flips the make green in phase 2, the driver needs
  nothing: it observes `outcome=green` and advances the behavior. If
  composition cannot engage, make still reports `unexpressible` and the
  driver honest-stops exactly as today.

**Decision**: Zero driver changes (spec FR-011/FR-012). The flip-green
emerges inside the spawned make. This keeps the integration surface to the
make command + one new command, and every #625/#635 driver test remains
authoritative.
