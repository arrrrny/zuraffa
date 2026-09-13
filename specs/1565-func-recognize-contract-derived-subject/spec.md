# Feature Spec: Make Plan Schedules Func Against Gen's Contract-Derived Subject [SPEC 1565]

**Feature ID:** 1565-func-recognize-contract-derived-subject
**Issue:** #1565
**Related:** #1259 (contract-derived subjects), #1489/#1498/#1500 (entity-wired shape / renderability lift), #1517 (header-claim reconciliation)
**Status:** IMPLEMENTED

## Summary

Three writers own the same unit-subject artifact with two different shapes.
`make`'s plan schedules `tdd func` for a behavior whose subject is already a
`gen` contract-derived stub. `func` finds a file it did not generate, refuses
to rewrite, and the step fails — `generation-error` on a subject that is
already what the behavior needs.

## Problem (symptom)

```
[run] U1 gen -> ok
[run] U1 verify-red -> certified
[run] U1 make -> generation-error
   zfa tdd func: subject carries an UnimplementedError in an unrecognized shape
               — refusing to rewrite a file this command did not generate.
```

## Root Cause

`gen` (since #1259) emits contract-derived subjects with the real declared
signature (`scan() -> ScanSession`). Since SPEC 1489 the degradation is
CONDITIONAL: when the declared entity exists on disk, the signature renders
verbatim (`ScanSession subject_u1() => throw UnimplementedError(...)`).

`func` only recognizes the legacy bounded stub shapes — its `_stubSignature`
matches `(int|void|String|bool|double|num|Object|dynamic)? name(params) =>
throw UnimplementedError(...);`. An entity-typed signature (`ScanSession`,
`User`, `List<Task>`) is outside that set, so the stub regex misses, the
broader `UnimplementedError` scan hits, and func refuses with the honest
"this command did not generate" guard.

The guard is correct; the plan is wrong. `make`'s `GenerationPlanner` still
schedules `tdd func` for every unit-kind / function-intent / declared
plain-function behavior without consulting the subject's current shape, so
the make dead-ends in `generation-error` on a subject that already carries
the exact declared signature the behavior needs.

## Measurable Success Criteria

- **SC-1** — `zfa tdd func <id>` on a behavior whose subject is a gen
  contract-derived stub (provenance header `GENERATED STUB — zfa tdd gen` +
  `CONTRACT-DERIVED SUBJECT` marker) whose declaration func's bounded set
  does not cover exits **0** with outcome `contract-derived-noop`, and the
  subject file is byte-identical after the run.
- **SC-2** — The refusal is preserved for every unrecognized shape WITHOUT
  the contract-derived provenance: a hand-authored entity-typed subject
  (`User login(...) => throw UnimplementedError(...)`) still exits 1 with
  the `unrecognized shape` refusal (the "did not generate" guard stands).
- **SC-3** — `make`'s plan does not schedule the `tdd func` step when the
  behavior's subject is a gen contract-derived stub func would refuse: the
  recorded generation commands carry no `zfa tdd func` step, and the make
  does not fail at the func step.
- **SC-4** — Legacy plain-function stubs keep scaffolding exactly as before:
  a gen-shaped `int subject_u1() => throw UnimplementedError(...)` stub is
  still rewritten (outcome `scaffolded`), and scalar contract-derived stubs
  still take the declared-dummy path (outcome `scaffolded`).
- **SC-5** — `dart analyze` on the changed files reports no new warnings;
  the func command suite and the generation planner suite pass unchanged
  except for the new #1565 behaviors.

## Requirements

### FR-1 — Shared subject-provenance service

A single source of truth for the provenance markers and the func
rewritability predicate (`subject_provenance.dart`):

- FR-1.1: `isContractDerivedGenStub(source)` is true exactly when the source
  carries BOTH the gen provenance header (`// GENERATED STUB — `zfa tdd gen`)
  AND the contract-derived marker (`// CONTRACT-DERIVED SUBJECT (issue
  #1259):`). The markers are consumed verbatim from what
  `SubjectWriter._renderContractUnitSubject` emits, so the two sides cannot
  drift.
- FR-1.2: `funcRewritableStubPattern` is func's bounded-shape regex, moved
  here so make's plan decision and func's refusal decision cannot disagree.
- FR-1.3: `contractDerivedDeclarationPattern` recognizes the declaration
  line gen emits for the contract-derived shape — any renderable Dart type
  token (identifier, generic, nullable) instead of the bounded scalar set.
  It is applied ONLY when FR-1.1's markers are present.
- FR-1.4: `funcWouldRefuseContractDerivedStub(source)` — the plan-skip
  predicate: provenance markers present AND an actual `throw
  UnimplementedError` AND the bounded stub regex misses.

### FR-2 — func is provenance-aware (recognition logic only)

- FR-2.1: when the stub regex misses and the subject carries an
  `UnimplementedError`, func checks FR-1.1 + FR-1.3. On a match it reports
  outcome `contract-derived-noop`, prints that the declared signature is
  already in place and the body is the author's hand work, and exits 0. The
  subject is NOT rewritten.
- FR-2.2: every other unrecognized shape keeps the existing refusal (exit 1,
  `runner-error`, the `unrecognized shape` message) — byte-identical
  behavior for hand-authored subjects.
- FR-2.3: the already-implemented path (no `UnimplementedError` left) is
  untouched.

### FR-3 — make's plan skips the doomed func step (scheduling only)

- FR-3.1: `BehaviorSummary` carries `skipFuncScaffold` (default false).
  `make` computes it from the subject file (FR-1.4) BEFORE planning.
- FR-3.2: `_functionSurfacePlan` emits only the terminal `build` step when
  `skipFuncScaffold` is set; the plan stays expressible (non-empty, ending
  in `build`).
- FR-3.3: scalar contract-derived subjects (func's bounded set covers them;
  the declared-dummy path applies) keep the func step — no regression to the
  existing green-by-dummy flow.

### FR-4 — Constraints

- FR-4.1: NO changes to `gen`, `wire`, the contract lane, or the run state
  machine. Only func's recognition logic and make's plan scheduling.
- FR-4.2: func for legacy plain-function stubs is unchanged (SC-4).
- FR-4.3: no new analyzer warnings (SC-5).
