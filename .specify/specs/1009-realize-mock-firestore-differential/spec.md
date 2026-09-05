# 1009-realize-mock-firestore-differential

- **Spec ID**: 1009-realize-mock-firestore-differential
- **Created**: 2026-09-05
- **Source**: GitHub issue #1009 ([ZIKZAK-REBUILD] Differential gate: realize-mock against Firestore, M-TRACK)
- **Type**: feature
- **Priority**: P1

## Problem

`zfa tdd realize` (#913) swaps mock → REAL. Before that crossing is worth
making, a cheaper parity question must be answerable: does the entity's
contract hold identically against a Tier-2 (Firestore-shaped) adapter as
it does against the Tier-1 in-memory mock? Today there is no command that
runs the SAME contract cases through both tiers and certifies — or fails —
the pair.

## Goal

`zfa tdd realize-mock <Entity> --against=firestore` runs the entity's
Tier-1 contract test, then the same committed contract cases through a
`Tier2MockProvider` (a Firestore-shaped adapter behind the same invocation
surface, backed by a fake `FirebaseFirestore` instance), compares the two
tiers per method, and writes a differential receipt. Divergence (value OR
type) is a failure; identical results certify the pair.

## Command contract

`zfa tdd realize-mock <Entity> --against=firestore [--feature F]
[--project DIR] [--json]`:

1. **Resolves the entity** through the artifact registries (the realize
   resolution surface: `specs/<feature>/tdd/artifacts.json` records whose
   descriptions name the entity).
2. **Loads the Tier-1 contract test** (the entity's registered test files)
   and runs it — a red Tier-1 baseline blocks the differential (the mock
   era is blamed, never the Tier-2 adapter; fail-closed).
3. **Loads the contract cases** — the committed fixtures under
   `specs/<feature>/tdd/fixtures/` (`realize-diff.v1`: `input.op` + args,
   optional recorded `mockOutput` = the Tier-1 oracle, optional `seed`
   records pre-loaded into the Tier-2 store). An empty surface is never
   certified.
4. **Swaps in the Tier2MockProvider**: a fresh provider per case (state
   isolation), backed by `FakeFirebaseFirestore` — documents hold the
   Firestore REST wire-shape typed values (`integerValue` / `doubleValue`
   / `stringValue` / ...), so type fidelity is enforced exactly as a real
   Firestore round-trip enforces it (`42` vs `42.0` is a REAL divergence).
5. **Compares per method**: JSON-encoding equality on both tiers' results
   (key order canonicalized; value AND type equality — `42` vs `'42'` is a
   mismatch). Every case runs and is recorded — the gate is per-entity,
   never per-method.
6. **Writes the differential receipt** `realize.<Entity>.firestore.receipt.json`
   under `.zfa/receipts/` — per-method
   `{method, tier1_result, tier2_result, diff: none|mismatch}` inside a
   `proof.v1` envelope, so `zfa proof check` parses and counts it (empty
   `files` list = it proves the run, not a tree artifact).
7. **Appends era-tagged cycle-log evidence** (kind `realize-mock`, era
   `MOCKED` — the differential certifies mock-era parity; it never
   crosses eras and never rebinds DI).
8. **Exits 0 only when every method's `diff == none`**; a divergent method
   is named in the output with both tiers' values.

## Success criteria

- `zfa tdd realize-mock Login --against=firestore` exits 0 with a clean
  receipt
- Deliberately introducing a divergent method (Tier-2 adapter returns
  wrong type) causes exit 1 with the mismatched method named
- Receipt is machine-readable and parseable by `zfa proof check`

## Hard constraints

- The differential gate is **additive** to the existing `realize` command:
  no change to realize's behavior; a new sibling verb only.
- One PR for this spec.

## References

- #1009 (GitHub issue, ZIKZAK-REBUILD M-TRACK)
- #913 (realize: the mock → real swap this extends)
- #908 (Mock-First Realization parent)
- #807 (proof-carrying receipts — the `proof.v1` envelope)
- #832 (fixture commitment — the `realize-diff.v1` contract cases)

## Out of scope

- Additional `--against` targets (firestore only; more land with their own
  receipts)
- Persisted DI rebinds or era transitions (realize-mock certifies; it
  never mutates the target tree beyond the receipt + cycle-log evidence)
