# Plan: SPEC 1565 — func recognizes the gen contract-derived subject; make plan skips the doomed step

**Feature ID:** 1565-func-recognize-contract-derived-subject
**Issue:** #1565

## Technical Context

### The three-writer conflict

The unit-subject artifact (`lib/tdd/<feature>/<id>_subject.dart` equivalents
under the registry's `subject_path`) is written by:

1. **`gen`** — `SubjectWriter` emits the honest-red stub. For a behavior
   whose spec declares a Layer Contract row (issue #1259), the
   contract-derived shape rides the unit pair; since SPEC 1489 the declared
   entity types render VERBATIM when the entity exists on disk (import
   included). The header carries the provenance markers:
   `// GENERATED STUB — `zfa tdd gen <id>` (spec 044-test-tdd-generation
   + issue #1259 contract derivation).` and
   `// CONTRACT-DERIVED SUBJECT (issue #1259): the signature below is`.
2. **`func`** — scaffolds the minimal implementation for plain-function
   subjects. Its rewrite set is the bounded-shape regex `_stubSignature`
   (`int|void|String|bool|double|num|Object|dynamic` — never an arbitrary
   identifier, so a hand-authored entity-typed subject still refuses).
   Anything else with an actual `throw UnimplementedError` is refused with
   "refusing to rewrite a file this command did not generate".
3. **the author** — hand-implements the body (the #1308 hand-step seam).

### Why the make dead-ends

`GenerationPlanner._functionSurfacePlan` schedules `tdd func <id> --feature
<f>` + `build` for every unit-kind (`U<n>`), function-intent, and declared
plain-function behavior. The plan is a pure function of `BehaviorSummary` —
it never consults the subject's current shape. When gen has already written
the contract-derived stub with a verbatim entity signature, func refuses
(exit 1), `PipelineRunner` grades the step failed, and make reports
`generation-error` — on a subject that already IS the declared contract.

### Fix surface (constraint-compliant)

The hard constraints name exactly two legal surfaces: make's plan scheduling
and func's recognition logic. Both are fixed, sharing ONE predicate source
so the two decisions cannot drift:

- **New service `subject_provenance.dart`** — owns the provenance markers
  (verbatim from `SubjectWriter`'s contract-derived template), func's
  bounded-shape regex (moved from `func_command._stubSignature` — same
  pattern, new home), the broadened contract-derived declaration pattern,
  and the combined plan-skip predicate.
- **`func_command.dart`** — in the refusal branch only: when the provenance
  markers AND the contract-derived declaration shape both match, report
  `contract-derived-noop` (exit 0) instead of refusing. No rewrite, no
  receipt, the file byte-identical. Every other path untouched.
- **`generation_planner.dart`** — `BehaviorSummary.skipFuncScaffold` (default
  false); `_functionSurfacePlan` omits the func step when set. The plan
  stays expressible (the terminal `build` step remains).
- **`make_command.dart`** — reads the subject BEFORE planning (the same
  recorded `subject_path` step 7 snapshots) and computes
  `skipFuncScaffold` via the shared predicate.

### Explicitly out of scope (FR-4.1)

- `gen_command.dart` / `subject_writer.dart` (the gen lane and its
  provenance header stay byte-identical).
- `wire_command.dart` / the #1498/#1500 entity-wired shape.
- The contract lane writers, `verify-red`, the run state machine.
- The scalar contract-derived dummy path (func's declared scaffold) — it
  keeps working and keeps its func step.

## Alternatives considered (from the issue)

1. *make plan skip only* — fixes the pipeline but leaves a direct
   `zfa tdd func <id>` (resume, replay, corpus drivers) dead-ending on the
   same subject. Insufficient alone.
2. *func provenance-aware only* — fixes every invocation path but keeps the
   plan scheduling a step whose outcome is predetermined (the doomed spawn
   and its confusing refusal output remain the plan's product). Insufficient
   alone.
3. *single writer per artifact* — the architectural end-state, far outside
   this issue's constraint envelope (touches gen + wire + contract lane).

Chosen: 1 + 2, sharing one predicate (the closest safe step toward 3).

## Verification strategy

- Fast-tier unit tests for the service predicates (marker detection,
  rewritability, refusal classification).
- Fast-tier CLI tests for func: no-op success (exit 0, byte-identical
  subject, outcome token), preserved refusals (no provenance / mangled
  declaration), untouched legacy scaffolding.
- Fast-tier planner tests: func step present/absent per `skipFuncScaffold`,
  plan invariants (non-empty, ends in build).
- One make-level test driving the real `zfa tdd make` surface against a
  TddFixture with the contract-derived subject: the recorded generation
  commands carry no `tdd func` step and the subject survives byte-identical.
