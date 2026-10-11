# Feature Spec: Entity-row-traced unit behavior engages the entity pipeline at gen [SPEC 1420]

**Feature ID:** 1420-entity-row-traced-unit-behavior
**Issue:** #1420
**Related:** #1259 (vacuous-green gate), #1308/#1320 (traced entity/void hand-step seam), #1388 (stale gen artifact reuse), #1498 (declared entityPipeline plan), #1489 (conditional entity degradation), #1512 (acceptance fallback token)
**Status:** IN-PROGRESS

## Summary

A unit behavior whose FR traces a declared **Key Entity** row (`traces: SharedAttachmentType`, row-only — Key Entity rows declare no methods) routes correctly at plan (`unit lane (entity pipeline: <Entity>)`), but `zfa tdd gen` never engages the entity pipeline: the gen-side declared-routing resolution consumes ONLY the resolved signature, which a row-only entity trace does not declare. The pair lands as a guard-only fallback test (`expect(result, isNot(isA<UnimplementedError>()))`) with a prose-guessed subject (`int subject_u1()`), `make` refuses vacuous-green (#1259), and the run driver's fallback stop claims the behavior is "fallback-routed (**no traces**: to a declared contract row)" — a remedy that is false (the FR DOES trace a declared row) and impossible to follow (the designed hand-delta seam `FR-00N, Row.method` has no method to name). The loop dead-ends.

## Problem (symptom)

```
$ zfa tdd plan 001-intents-port
  U1 ... unit lane (entity pipeline: SharedAttachmentType)   # routes correctly
$ zfa tdd run 001-intents-port
  U1 gen   -> ok  (guard-only test, int subject_u1(), NO vacuous-guard marker)
  U1 verify-red -> certified (honest red)
  U1 make  -> vacuous-green refusal
     the generated test is GUARD-ONLY [zfa:tdd: guard-only]
     — the behavior is fallback-routed (no traces: to a declared contract row) ...
     --> fix: add traces: <ContractRow> to the FR ... or hand-edit the lane plan
        traces cell to FR-00N, Row.method       # false AND impossible
```

## Root Cause

1. `DeclaredRouting.declaredSignatureFor` (the single gen-side declared-resolution seam)
   returns `result.signature` and discards the rest of the `RoutingDecision`. For a
   row-only entity trace the resolver deliberately passes the row through unqualified
   (`_qualifiedTraces` row-only pass-through: "the declared surface rides the entity
   pipeline, not the signature path"), so `signature == null` — gen concludes
   "undeclared" and emits the legacy guard-only fallback pair.
2. The run driver's marker-absent vacuous-green stop hardcodes the
   fallback-routed claim ("no traces: to a declared contract row") without probing
   whether the row's traces cell actually resolves declared contract row(s).

## Measurable Success Criteria

- **SC-1** — For a unit behavior whose traces cell resolves a declared Key Entity
  row (row-only), `zfa tdd gen` produces an entity-surface pair through the EXISTING
  contract-shape machinery (SPEC 1489):
  - **SC-1a** (entity exists on disk): the paired test asserts the declared entity
    surface (`expect(result, isA<Entity>())`, entity import emitted) and the subject
    renders the declared type verbatim (`<Entity> subject_u1()`) with the provenance
    header `<Entity>() -> <Entity>`; the test is NOT vacuous-green and carries no
    vacuous-guard marker — `make` proceeds and the declared entity pipeline
    (`entity create` → `mock create --certify` → `tdd wire` → `build`) can engage.
  - **SC-1b** (entity absent at gen): the paired test carries the traced
    `zfa:tdd: vacuous-guard` marker (the designed #1308/#1320 hand-delta seam — the
    run driver classifies the stop `stopped_at=<id>:hand`), the subject degrades to
    `Object?` while the header preserves the declared entity shape, and the gen-time
    guard-only WARNING TOKEN stays silent for this traced class.
- **SC-2** — The marker-absent vacuous-green stop for a row whose traces cell DOES
  resolve declared contract row(s) never claims "no traces: to a declared contract
  row"; it names the declared row class, the stale-artifact re-gen remedy, and the
  hand step, and keeps the `stopped_at=<id>:make` machine contract.
- **SC-3** — The gen-side declared resolution exposes the full routing decision
  (surface + entity name + signature) through a single-sourced helper; the legacy
  `declaredSignatureFor` contract is unchanged (still returns exactly the resolved
  signature or null) so the contract lane keeps its exact behavior.
- **SC-4** — No regression: unit behaviors with declared SIGNATURES (scalar
  contract rows, entity-returning contract rows) keep their existing pairs
  byte-for-byte; undeclared behaviors keep the guard-only fallback + gen warning;
  `_qualifiedTraces` pass-through, the vacuous-green gate semantics, and the
  acceptance-lane fallback token are untouched.

## Hard Constraints (from the issue)

- Fix the entity pipeline engagement for ROW-ONLY traces only.
- Do NOT change the contract lane, the `_qualifiedTraces` pass-through logic, or the
  vacuous-green gate semantics.
- One PR per feature; closes #1420.

## Out of Scope

- Domain/data rows that declare NO signature and NO entity-shaped return (the
  #1498 refusal already handles their plan side honestly); changing their gen pair
  would violate the row-only-entity scoping.
- Inventing entity-VALUE assertions (`values` order, json round-trip) the spec
  never declared — the #920 principle (declaration outranks inference) holds: the
  mechanically assertable declared surface of a row-only entity trace is the
  declared entity type itself; richer assertions are the author's hand step.
