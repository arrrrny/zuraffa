# Feature Specification: tdd make generates an id-keyed CRUD mock/repo for id-less entities instead of the #307 upfront refusal (spec 016 contract)

**Feature Branch**: `1692-tdd-make-idless-entity-gate`

**Priority**: high

**GitHub Issue**: #1692

## Problem

Driving an id-less entity through the tdd loop's unit make (entity pipeline surface)
generates a full id-keyed CRUD stack (`UpdateParams<String, UserSessionPatch>`,
`item.id == params.id`) that cannot compile against the entity. Spec 016's contract
says id-dependent plugins on an id-less entity refuse UPFRONT with the #307
`MakeCommandException` before generation — that gate did not fire on the tdd-driven
make path. The mock certification (backstop) caught the broken output downstream
instead.

## Repro

```text
zfa setup idless_probe --dart
→ spec with Key Entity lacking id field (| UserSession | token: String, email: String |)
  traced by FR to a domain contract
zfa tdd plan f && zfa tdd run f
→ phase-0 creates entity, scaffolds U1, certify red, make runs generation
→ emits id-assuming code:

  Future<UserSession> update(UpdateParams<String, UserSessionPatch> params) async {
    final existing = UserSessionMockData.userSessions.firstWhere(
      (item) => item.id == params.id,   // ERROR: UserSession has no `id`

Mock certification then fails as designed:
  make: behavior=U3 outcome=generation-error
```

## Root Cause

The #307 id-gate (make_command entity-resolution step) either is not consulted on
the tdd make path or the tdd pipeline passes a plugin set that bypasses the 016
gating. Generation should never emit `item.id` for an entity whose fields were
resolved at plan time.

## Suggested Fix

Gate the tdd-driven make pipeline on the same 016 id-check: when the traced entity
has no id and the pipeline would generate id-dependent surfaces
(repository/datasource/mock/update/toggle), refuse BEFORE generation with the #307
remediation text (add `id: String` to the entity, or narrow the traced contract to
id-neutral methods). The mock cert backstop stays as the second line of defense.

## Hard Constraints

Fix ONLY the tdd make path gating; do NOT change the #307 gate itself or the 016
contract semantics; one PR per spec. The fix must:

1. consult the 016 id-check on the tdd make path,
2. refuse BEFORE generation with the #307 remediation text,
3. keep the mock cert backstop,
4. not break id-bearing entity generation.

## Requirements

- **FR-1**: A unit behavior whose FR traces to a Key Entity that resolves id-less
  (the same `EntityFieldResolver.resolveIdField` semantics spec 016/#307 use: no
  literal `id`, no `*Id` field, no `autoId`, not a value object) and whose
  generation plan contains an id-dependent surface (`mock create` for the traced
  entity, or a real `zfa make <Entity>` step) MUST refuse BEFORE any pipeline step
  runs, printing the #307 diagnostic (message + remediation) and exiting non-zero
  with no green entry appended.
- **FR-2**: The refusal text MUST carry the #307 remediation: add `id: String` to
  the entity, or narrow the traced contract to id-neutral methods (the tdd-path
  formulation of the same contract).
- **FR-3**: The refusal MUST be classified as an upfront refusal (the
  `unexpressible` outcome vocabulary: non-zero exit, no green entry, the run loop
  defers then stops honestly) — NOT `generation-error`, and no generation
  subprocess may be spawned on that path.
- **FR-4**: An id-bearing traced entity (literal `id`, `*Id`-suffixed, `autoId`,
  value objects, or a missing entity file) MUST keep today's behavior exactly:
  the pipeline runs, the mock certification backstop stays armed.

## Success Criteria

- **SC-1**: The idless_probe repro, re-run after the fix, refuses at make with the
  #307 remediation text BEFORE any generation step (no mock datasource file is
  written for the id-less entity by the make path).
- **SC-2**: An equivalent probe with an id-bearing Key Entity still generates the
  full CRUD stack unchanged (green through the same pipeline).
- **SC-3**: `dart analyze` on the changed files is clean; the new regression tests
  prove both directions (refusal on id-less, generation on id-bearing); `dart
  format .` leaves no drift.
- **SC-4**: The mock cert backstop is untouched (no changes under the mock
  certification path).
