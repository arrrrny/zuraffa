# 976-state-aplus-upgrade

- **Spec ID**: 976-state-aplus-upgrade
- **Created**: 2026-09-05
- **Source**: GitHub issue #976 (A+ UPGRADE: state)
- **Type**: test-infrastructure + refactor + CLI hardening
- **Priority**: P1

## Problem

`state` is the most pervasive codegen footprint in zik_zak (104 generated
`*_state.dart` files in production) yet it is graded B− (3.20/5):

1. **Tests 2/5** — two content-`contains` tests (`state_builder_test.dart`,
   82 LOC) cover a 1,265-LOC builder with three emission modes. Nothing
   pins equality/hashCode, orchestrator fields, pagination defaults, or
   the flavor switch. String presence is not a compile contract.
2. **Internal duplication** — `needsEntityField`/`needsEntityListField`
   derivation repeated 6× (`state_builder.dart:47-62, 346-362, 484-500,
   664-680, 750-766, 825-841`): a drift factory — a semantics edit applied
   at five sites and forgotten at the sixth silently forks emission.
3. **Schema drift** — `CreateStateCapability.outputSchema` says
   `files: string[]` while `execute` also returns `generatedFiles`
   objects (`create_state_capability.dart:53-61` vs `82-86`); the schema
   misdescribes the actual return shape.
4. **No verdict surface** — `zfa state create` prints emoji prose, writes
   no receipt: automation cannot consume the outcome and `zfa proof
   check` cannot cover state artifacts.
5. **Docs 2/5** — no openwiki mention of the state command surface; the
   three emission modes (entity/orchestrator/custom) documented nowhere.

## Goal

Make `state` an A+ plugin: prove the builder with a property-based
compile tier, dedupe the derivation behind one resolver (provably
byte-neutral), emit a versioned `--json` verdict + `proof.v1` receipt,
gate `state create ≡ make --state` with a drift test, fix the
outputSchema, and document the three emission modes.

## Orders

1. **Property-based test tier** — for representative method-set
   combinations (CRUD, getList+pagination, orchestrator, custom-usecase):
   generate the state into a sandbox, `dart analyze` it, round-trip
   `copyWith`/equality. Compile-cleanliness is the contract, not string
   presence. A deliberately broken emission must fail the tier.
2. **`zfa state create --json`** — envelope `{path, fields[], modes[],
   flavor, schema:1}` + `.zfa/receipts/state-<entity>.json` via
   `ReceiptStore`.
3. **Dedupe the derivation** — collapse the 6 duplicated sites into one
   resolver function. No behavior change: output bytes identical
   before/after (snapshot test proves it on a fixture matrix).
4. **Drift test** — `zfa state create` output ≡ `zfa make --state`
   output for the same config; the two entry points must never diverge.
5. **Fix the outputSchema** to match the actual return shape.
6. **openwiki** — `cli.md` row + short doc of the three emission modes
   (entity/orchestrator/custom).

## Constraints

- The dedupe must be provably behavior-neutral (byte-identical output on
  the fixture matrix).
- Failing-first tests under `test/plugins/state/`.

## Acceptance criteria (all must hold)

- AC-1: Property suite green across the method-set matrix; a
  deliberately broken emission (e.g. non-compiling copyWith) fails it.
- AC-2: `--json` envelope + receipt asserted; `zfa proof check` covers
  state artifacts.
- AC-3: Snapshot test proves byte-identical output pre/post dedupe.
- AC-4: `state create ≡ make --state` drift test lands and passes.

## Success scenarios

### SC-1 (compile contract)

Given a representative method-set matrix (CRUD, getList+pagination,
orchestrator, custom-usecase), when each state is generated into a
sandbox project whose pubspec declares a path dependency on zuraffa,
then `dart analyze` exits 0 with no issues, and a driver that
round-trips `copyWith`, `==`, `hashCode` and the pagination defaults
executes successfully; and when an emission is deliberately corrupted
into a non-compiling `copyWith`, `dart analyze` fails.

### SC-2 (verdict + receipt)

Given `zfa state create --name Product --methods get,getList --json`
inside a project, then the last stdout line is a single-line JSON
envelope `{"path":…, "fields":[…], "modes":[…], "flavor":…,
"schema":1}`, and `.zfa/receipts/state-Product.json` exists as a
`proof.v1` receipt whose per-file sha256 matches the artifact on disk,
and `zfa proof check --format=json` reports `"ok":true`.

### SC-3 (byte-identity across dedupe)

Given the fixture-matrix goldens captured from the pre-dedupe builder,
when the deduped builder regenerates the same matrix, then every file is
byte-identical to its golden.

### SC-4 (no entry-point drift)

Given the same entity and the same explicit method set, when state files
are produced by `zfa state create` and by `zfa make --state`, then the
two `*_state.dart` files are byte-identical.
