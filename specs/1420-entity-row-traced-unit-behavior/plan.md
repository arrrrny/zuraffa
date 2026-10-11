# Plan: SPEC 1420 — the entity pipeline engages at gen for row-only entity traces

**Feature ID:** 1420-entity-row-traced-unit-behavior
**Issue:** #1420

## Technical Context

### The resolution seam and what it drops

`gen` resolves a unit behavior's declared contract through ONE seam
(`gen_command.dart`, "Issue #1259: a DECLARED Layer Contract derives the unit
subject's signature..."):

```dart
final declared = await bounded(
  DeclaredRouting.declaredSignatureFor(...), 'resolve declared contract');
if (declared != null) {
  contractShape = await UnitContractShape.ofResolved(declared, cwd: cwd);
}
```

`declaredSignatureFor` returns `result.signature` ONLY. The resolver's
`RoutingDecision` for a row-only Key Entity trace is
`(kind: unit, surface: entityPipeline, entityName: <Entity>, signature: null)` —
`_qualifiedTraces` passes entity rows through row-only BY DESIGN ("the declared
surface rides the entity pipeline, not the signature path", plan_command.dart).
Gen consumes only the signature, gets null, keeps `contractShape == null`, and
the writer falls through the prose heuristics to the bare guard: the guard-only
fallback pair, no marker, nonsense prose-guessed subject.

### Why the loop then dead-ends

- `make` step 3c refuses the guard-only test vacuous-green (#1259 semantics —
  correct: generation could flip it green with zero declared-contract code).
- The run driver's marker-absent branch prints "fallback-routed (no traces: to a
  declared contract row)" and prescribes `add traces: <ContractRow>` / the
  `FR-00N, Row.method` hand-delta — both false (the trace exists) and impossible
  (Key Entity rows declare no methods to qualify).
- make's DECLARED plan path (`_declaredPlan` → `_entityPipelinePlan`) would serve
  the row-only entity trace perfectly — but 3c fires BEFORE planning, so the
  pipeline never gets the chance. The unlock must happen at GEN: the test must
  carry a real assertion (or the traced marker) before make can drive generation.

### Fix surface (constraint-compliant)

Row-only entity traces ONLY; the contract lane, `_qualifiedTraces`, and the
vacuous-green gate semantics are untouched.

1. **`declared_routing.dart`** — new `declaredRoutingFor` returning the full
   `RoutingDecision?` (the reads are exactly `declaredSignatureFor`'s; the old
   method delegates to it, byte-identical behavior). Single-sourced so gen and
   the run driver cannot drift.
2. **`gen_command.dart`** — resolve the full decision; when
   `surface == entityPipeline && signature == null && entityName != null`
   (the row-only entity class), synthesize the declared entity-surface signature
   `<Entity>() -> <Entity>` and feed the EXISTING `UnitContractShape.ofResolved`
   machinery. Everything downstream is already-designed behavior:
   - entity EXISTS on disk (run phase-0 created it, or pre-existing — SPEC 1489):
     `scalarOutcome == true` → test emits `expect(result, isA<Entity>())` with
     the entity import; subject renders `<Entity> subject_u1()` verbatim with
     the `//     <Entity>() -> <Entity>` provenance header. make 3c passes, the
     declared plan routes `_entityPipelinePlan` (entity create → mock create
     --certify → wire → build), wire's stub-header fallback derives
     `declaredReturn = <Entity>` and binds the mock sample (#1500 machinery) —
     the pair goes green HONESTLY.
   - entity MISSING at gen: degradation to `Object?` (FR-011 compile safety),
     `scalarOutcome == false` → `_declaredAssertion`'s non-scalar branch emits
     the traced `zfa:tdd: vacuous-guard` marker — the #1308/#1320 designed
     hand-delta seam (run driver classifies `stopped_at=<id>:hand`). The
     gen-time guard-only warning stays silent for this class (its condition
     excludes marker-carrying content).
3. **`vacuous_guard.dart` + `run_driver_core.dart`** — the marker-ABSENT
   vacuous-green stop probes the declared routing (the same single-sourced
   helper): when the traces cell resolves declared contract row(s), the stop
   names the declared row class and prescribes the stale-artifact re-gen remedy
   (#1388 class — the regenerated pair carries the entity-surface assertion or
   the marker) + the hand step, instead of the false "no traces" claim. The
   stop contract stays `stopped_at=<id>:make`; detection/loop untouched.

### Why synthesize `<Entity>() -> <Entity>` and not invent value assertions

The #920 principle: declaration outranks inference; the engine never invents
shapes the spec did not declare. A row-only entity trace declares the entity as
the behavior's surface; the mechanically assertable declared surface is the
declared type itself (`isA<Entity>()` — exactly the SPEC 1489 ruling for
existing entity returns: "an EXISTING entity return is also mechanically
assertable"). Richer value assertions (`values` order, json round-trip) are the
author's hand step — the marker path names it.

### Migration of pre-fix artifacts

The #683 staleness re-render byte-compares a still-stub subject against the
current render — the render changes for entity-row traces, so a resumed run
regenerates the stale guard-only pair; the #1388 fingerprint gate forces the
same for progressed subjects whose routing changed. No manual migration.

## Risks / Bounds

- `declaredSignatureFor` delegation must keep the EXACT legacy result for every
  input (pinned by test).
- The gen synthesis keys on `surface == entityPipeline && entityName != null &&
  signature == null` — a domain/data row WITH a signature never reaches it (its
  signature is non-null); an entity row with a method-qualified trace still
  yields signature null but that shape is not expressible on entity rows (they
  declare no methods — the resolver's `_signatureFor` is not consulted for
  entity rows).
- The run driver probe is stop-path only (terminal state) — no hot-loop I/O.
