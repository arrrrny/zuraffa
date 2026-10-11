# Fix — BUG 1588 (phase-2 refactor batch economics + parked exemption)

## Change surface (hard constraint honored: make step, state machine, suite
## runner untouched)

| File | Change |
|------|--------|
| `lib/src/plugins/tdd/services/pass_batch_ledger.dart` | NEW — the feature pass-batch ledger (`specs/<feature>/tdd/pass-batch.json`): context keys (suite template, baseline-file content hash, sorted exempt ids) + `lib/`/`test/` whole-tree digests + honest verdict strings; fail-safe read; stable `TreeSnapshot` digest helper. |
| `lib/src/plugins/tdd/commands/refactor_command.dart` | Two driver-only flags: `--pass-batch` (ledger opt-in) and `--exempt-behaviors <ids>`. Ledger-hit fast path: the gate a previous invocation of the same batch proved on a byte-identical tree is inherited — no preflight, no pass registry, no re-proof; clean no-op + honest evidence. Gate restructure: exempt behaviors' registered tests (resolved through `ArtifactRegistry`, fail-open on unknown ids) are removed from the preflight/re-proof failing sets BEFORE the #922 verdict (with baseline: no NEW failures after exclusion; without baseline: tolerate only when EVERY failure is exempt). Exclusions named in output and evidence. Ledger written best-effort on the green path. |
| `lib/src/plugins/tdd/services/step_runner.dart` | `run()` gains `List<String> extraArgs = const []` appended verbatim after baseline/timeout flags. Default empty → every existing call site spawns byte-identical argv. |
| `lib/src/plugins/tdd/commands/run_driver_core.dart` | Phase-2b refactor spawns pass `batchRefactor: true` → `--pass-batch` plus the lane's parked BLOCKED ids as `--exempt-behaviors` (sorted, stable). Phase-1 refactors and all gen/verify-red/make spawns unchanged. |

## Why this shape

- **Economics** (#1588 criterion 1 + 3): the pass registry is batched per
  feature by construction — the FIRST phase-2b spawn pays the pipeline and
  records the proved gate; every subsequent spawn of the same batch on an
  unchanged tree inherits it at the cost of two tree snapshots. N green
  behaviors cost ONE preflight + ONE build + ONE re-proof instead of N
  (the calculator corpus: ~2.7 min of zero-pass preflights → zero).
- **Coupling** (#1588 criterion 2): the parked BLOCKED contract's red test
  is the DESIGNED park state (#1007/#1544); the #741 baseline cannot know
  it (gen created the test after the baseline capture), so #922's diff
  counts it as NEW and every preflight refuses. The exemption removes only
  those registered tests from the verdict; a non-exempt failure still
  refuses; an unparseable transcript still refuses.
- **Full gate preserved** (spec 069 T001): `zfa tdd verify`'s preflight and
  the nightly corpus lane still run the full suite; the ledger only removes
  redundant re-proofs of a byte-identical tree within one phase-2 pass.
- **Standalone contract preserved** (spec 048 FR-001): a flag-less
  `zfa tdd refactor` never reads or writes the ledger and keeps the
  absolute-green gate.

## Measured effect

- Second-and-later `--pass-batch` invocations on an unchanged tree: 0 suite
  spawns, 0 pass spawns (asserted by the spawn-counting wrapper test).
- Parked-red fixture: `--exempt-behaviors C1` → exit 0 (clean);
  without the flag → `not-green` refusal (both asserted).
