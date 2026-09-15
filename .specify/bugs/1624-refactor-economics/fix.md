# Fix — BUG 1624 (refactor economics: batch phase 1, gate the build, inherit the re-proof)

## Change surface (make step, state machine and suite runner untouched)

| File | Change |
|------|--------|
| `lib/src/plugins/tdd/services/build_relevance.dart` | NEW `refactorBuildSkipNote(projectRoot:)` + `refactorBuildSkippedNote`. The refactor's build gate: `.dart_tool/build/asset_graph.json` is the marker; every file under `lib/`, `test/`, `bin/`, `tool/` (skipping `*.g.dart.part`) plus `buildConfigFiles` whose mtime is NOT before the marker's is "newer"; no newer file → skip; any newer config / non-`.dart` / builder-annotated `.dart` → run. Every filesystem/read error → run. |
| `lib/src/plugins/tdd/services/refactor_passes.dart` | `RefactorPassSpec` gains an optional `skipGate`. `RefactorPasses` / `defaultPassSpecs` gain `buildSkipGate` (defaulting to `BuildRelevance.refactorBuildSkipNote` bound to the project root; a null root or an explicit `passSpecs` attaches nothing). `run()` asks each spec's gate first: a non-null note records a synthetic `RefactorAction(skipped: true, filesChanged: [], exitCode: 0)` and continues — no snapshot, no #1540 tracked guard, no executor invocation. Only the `build` spec carries a gate. |
| `lib/src/plugins/tdd/models/refactor_action.dart` | `RefactorAction.skipped` (default `false`) — the explicit "this pass never spawned" marker. |
| `lib/src/plugins/tdd/models/cycle_entry.dart` | The refactor `actions:` block renders an additive `note: skipped …` line for a skipped action (the #1587 additive-note precedent); the theater parser is unaffected (the line sits after `changed:`). |
| `lib/src/plugins/tdd/commands/refactor_command.dart` | R3: `registryChangedNothing` / `reproofInherited = !stopped && registryChangedNothing && !fullReproof`. When inherited, the re-proof is NOT spawned — a synthetic `SuiteRunRecord(exitCode: 0)` carries the inherited verdict, a stdout line names the inheritance, `reproofVerdict` becomes `inherited from the preflight — the pass registry changed no file (issue #1624)`, the cycle-log/receipt and the pass-batch ledger record that label, and the #1430 refresh candidates are empty (no changed subject to reconcile). `libAfter`/`testAfter` are still captured for the ledger. |
| `lib/src/plugins/tdd/commands/run_driver_core.dart` | R1: the phase-1 `_driveBehavior(...)` call passes `batchRefactor: true`, so every refactor spawn (phase 1 and phase 2b) opts into the pass-batch ledger. Doc comments on `batchRefactor` and `_refactorBatchArgs` updated. |

## Why this shape

- **R1** (#1624 criterion 1): phase 1 was the last refactor spawn shape
  that never opted into the #1588 ledger, so N green behaviors re-paid N
  full pipelines. The ledger's byte-identity check (same suite template,
  baseline content, suite configuration, exempt set, and `lib/` + `test/`
  digests) is the safety argument: an unchanged tree inherits the gate a
  previous spawn proved; anything else re-runs the pipeline.
- **R2** (#1624 criterion 2): the refactor did not write the tree, so
  there is no before/after fingerprint to diff — the gate keys on
  build_runner's own marker instead. The comparison is the conservative
  `>=` direction, a missing marker runs, and every unknown runs.
- **R3** (#1624 criterion 3): the preflight ran moments earlier on the
  byte-identical tree, so re-running the suite only re-observes the same
  bytes. The inherited verdict is named, never presented as a fresh green;
  `--full-reproof` and every failed/timed-out pass keep the old path.

## Expected effect

- A green behavior whose refactor changes no file: **preflight only** (no
  re-proof, and — after the first build — no `zfa build`: build_runner and
  the whole-project `dart analyze lib/` are skipped).
- The second-and-later refactor of a byte-identical batch (phase 1 or
  phase 2b): the ledger hit — no preflight, no pass registry, no re-proof.
- No behavior change on any non-green path: misfire-stop, refusal,
  regression, `not-green`, `--full-reproof` and `runner-error` are
  byte-identical to before.
