# Issue #1624 — `zfa tdd refactor` is 78–88% of a run: per-behavior pipeline, ungated build, redundant re-proof

## Symptom

After the #1587 fix made the make's terminal build step skippable, the
remaining cost of a green behavior is its `zfa tdd refactor` step: a
measured ~85–190s per behavior, 78–88% of a whole `zfa tdd run`.

## Measured per-refactor breakdown

One `zfa tdd refactor` spawn pays, in order:

| Stage | Cost | Why it was paid |
|-------|------|-----------------|
| Full-suite preflight (`refactor_command.dart` step 3) | ~35s | the absolute-green gate (spec 048 FR-001) |
| Pass registry `build` (`zfa build`) | build_runner ~21s + whole-project `dart analyze lib/` ~5s | the fixed pass registry always spawned build → format → fix |
| `dart format lib/` | seconds | the format pass |
| `dart fix --apply lib/` | seconds | the fix pass |
| Re-proof suite (step 7) | ~25s | FR-006 |

## Three distinct defects

### R1 — the pass-batch ledger never engaged on the phase-1 path

The #1588 pass-batch ledger (`specs/<feature>/tdd/pass-batch.json`) lets a
later refactor of the SAME batch on a byte-identical `lib/` + `test/` tree
inherit the gate a previous invocation proved. But `run_driver_core.dart`
passed `batchRefactor: true` ONLY from the phase-2b refactor loop (~line
1196). The phase-1 per-behavior refactor spawn (~line 1004, inside the
loop that calls `_driveBehavior`) never did, so every behavior's refactor
re-paid the whole pipeline.

### R2 — the refactor's build pass was ungated

The #1587 gate (`BuildRelevance`) skipped the MAKE's terminal build when
nothing builder-consumable changed, but `RefactorPasses` still spawned a
whole-project `zfa build` (build_runner + `dart analyze lib/`) on every
refactor. On a feature whose generation writes only plain Dart — zero
`.g.dart` outputs — that pass is pure overhead.

The refactor has no "before" fingerprint to diff against (it did not write
the tree), so the gate must decide from build_runner's own state marker:
`.dart_tool/build/asset_graph.json`.

### R3 — the re-proof ran even when the pass registry changed nothing

When every recorded pass reported `filesChanged: []`, the tree the
re-proof would grade is byte-identical to the tree the preflight certified
moments earlier — yet step 7 still spawned the full suite (~25s) to
re-observe the same bytes.

## Remedies

1. **R1** — the phase-1 `_driveBehavior` call passes `batchRefactor: true`
   too. The ledger's byte-identity check is what makes it safe: only a
   byte-identical `lib/` + `test/` tree under the same suite/baseline/
   config/exempt set inherits a previously proven gate.
2. **R2** — `BuildRelevance.refactorBuildSkipNote` gates the refactor's
   `build` pass by build relevance, and `RefactorPasses` records a
   synthetic skipped action (`skipped: true`, `filesChanged: []`) instead
   of spawning it.
3. **R3** — when the pass registry changed no file and `--full-reproof` is
   not set, the re-proof is INHERITED from the preflight and named as such
   in the evidence and the pass-batch ledger. A timed-out or non-zero pass
   keeps its existing failure path.

## Hard constraints

- The make step, the state machine (`RunState`/`BehaviorState`) and the
  suite runner are untouched.
- `--full-reproof` never inherits.
- A flag-less standalone `zfa tdd refactor` keeps the absolute-green
  preflight contract (spec 048 FR-001); only the redundant re-proof is
  skipped.
