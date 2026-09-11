# Test Plan: BUG 1511 — unexpressible message drift (bug 657)

- **Slug**: 1511-unexpressible-message-drift
- **Target file**: `test/plugins/tdd/make_command_test.dart`
- **Test-group**: `US4 — misfire-stop on unexpressible behaviors`

## Test list

| # | Test (name filter `-n "bug 657"`) | Kind | Status before fix | Status after fix |
| --- | --- | --- | --- | --- |
| T1 | `bug 657: an unexpressible make …` (unexpressible refusal path, behavior B-042, description "provision bespoke DSL syntax with no generator surface") | assertion update | RED — expects `no generator for 'provision'` (stale) | GREEN — pins current behavior-phrased refusal + STOP-ON-ROADBLOCK policy |
| T2 | `bug 657: a render-type behavior plans the `tdd func` step through the pipeline (no longer unexpressible)` | regression guard | GREEN | GREEN (untouched — regression guard that render-type prose is no longer unexpressible) |

## What T1 must assert (current message contract)

1. Exit code non-zero (honest misfire) — unchanged assertion.
2. The refusal names the behavior and the unexpressible wording:
   `contains('no generator surface maps the behavior')`.
3. The refusal quotes the full behavior description:
   `contains('description "provision bespoke DSL syntax with no generator surface"')`.
4. The refusal cites the policy:
   `contains('STOP-ON-ROADBLOCK policy')`.
5. The summary line contract is unchanged:
   `contains('make: behavior=B-042 outcome=unexpressible feature=${fx.featureName}')`.

## Out of scope (hard constraints)

- No change to `make_command.dart`, `generation_planner.dart`, or any `lib/` file.
- No change to T2 (render-type green path) — it already pins the correct contract.
- No new tests beyond the updated assertion set; this is an assertion-drift repair,
  not a behavior change.

## Evidence

- RED capture: `red-evidence.md` (this directory).
- GREEN + fresh verification run: `tdd/verification.md` (repo root).
- Full fast-suite chunked re-run (no new failures): recorded in `tdd/verification.md`.
