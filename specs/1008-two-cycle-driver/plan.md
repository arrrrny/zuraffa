# Technical Plan: 1008-two-cycle-driver

## Problem

`zfa tdd run` drives every behavior of a feature's test list through one uniform
two-phase loop. The ZIKZAK-REBUILD engine/skin split (#1000) separates pure-Dart
CORE behaviors from Flutter SKIN behaviors, so a lane-scoped runner is needed:
engine first (its certified mocks feed the skin), skin second, one command to
chain both, and a status line reading the two receipts.

## Constraints

- The three commands MUST share the existing two-phase driver core (spec
  049 semantics: state resume, journal replay, reconciliation, deferrals,
  evidence misfires, machine summary). Duplicating loop logic is forbidden.
- `zfa tdd run`'s output contract (summary line shape, exit codes 0/1/2/3/4,
  step progress lines) is load-bearing for the existing 40-test suite and CI —
  legacy features must behave byte-compatibly.
- #1000 is NOT merged: no feature in the wild has 04-ENGINE.md/04-SKIN.md yet.
  Lane resolution must work today (row tags / CORE default) and after #1000
  lands (plan files win).
- Exit code 2 for run-skin's missing/not-green engine receipt (issue #1008).

## Design

### 1. Lane resolution (`services/lane_plans.dart`)

`TddLane { core, skin, both }` + `LaneAssignment { engineIds, skinIds, source }`.

Resolution order:
1. `tdd/04-ENGINE.md` / `tdd/04-SKIN.md` exist -> behavior ids parsed from each
   plan file's markdown table rows (first cell) and `- <id>` bullets. An id in
   both files is BOTH (the natural CORE+BOTH / SKIN+BOTH union #1000 defines).
   Ids in neither file default to engine (CORE).
2. Else: row-level lane tags in the test list's behavior cell — ` [core]`,
   ` [skin]`, ` [both]` — parsed and stripped by `TestListReader` exactly like
   `[persistence]` (the single-format-contract way, bug #617).
3. Else (legacy): every row is CORE. run-engine drives everything; the skin
   lane is vacuously green.

### 2. Driver core extraction (`commands/run_driver_core.dart`)

Move the entire driving body of `RunCommand.run()` (state load, journal replay,
reconcile, phase 0/6a/6b baseline, phase 1/2a/2b loops, `_driveBehavior` and
its helpers) into `RunDriverCore.drive(request)`. The request carries:

- `feature`, `projectRoot`, `zfaBin`, `timeout`
- `rows` — the lane's rows (what gets driven)
- `suiteRows` — all rows (deferral semantics consult the whole suite: a red or
  pending-with-artifacts SKIN row reds the suite exactly like an engine row,
  bugs #635/#734)
- `activeIds` — ALL test-list ids (dropped-row computation stays global)
- `label` + `resumeCommand` — output text (`zfa ttd <label>: ...`, resume hints)

The core prints every progress/failure line it prints today (with the label
parameterized; the meta run keeps label `run` so its output is unchanged) but
returns the outcome instead of printing the final summary line and setting
exitCode — the commands own that.

`RunDriverOutcome { result, exitCode, stoppedAt, message, state, drove, counts }`
counts are computed over the request's `summaryRows` (lane rows for lane
commands; all rows for the meta run).

Lane runs share `tdd/run-state.json` and `tdd/cycle-log.md` with the full
feature: the skin lane resumes BOTH behaviors already DONE by the engine lane
(evidence beats state, FR-003), so they are skipped, never re-driven.

### 3. Receipts (`services/lane_receipts.dart`)

`specs/<feature>/tdd/04-engine-receipt.json` / `04-skin-receipt.json`, schema 1:

```json
{
  "schema": 1, "feature": "<f>", "lane": "engine|skin",
  "verdict": "green|red|error", "result": "<driver result>",
  "behaviors": ["<ids in list order>"],
  "counts": {"total": n, "pending": n, "red": n, "green": n, "done": n},
  "stopped_at": null, "at": "<ISO-8601>"
}
```

Written after the driving phase begins (complete -> green; stopped ->
red; runner-error during driving -> error). Pre-driving misfires (corrupt
state, concurrent run, missing dir/list) write nothing — the lane did not run.

### 4. Commands

- `run-engine` (RunEngineCommand): resolve lanes, drive engine rows via the
  core, write the engine receipt, print `run-engine: feature=<f> lane=engine
  result=... pending=... red=... green=... done=...`, exit by outcome.
- `run-skin` (RunSkinCommand): gate on the engine receipt (missing or not
  green -> message + `result=engine-required` summary + exit 2, zero steps),
  then drive skin rows, write the skin receipt, print the lane summary.
- `run` (RunCommand, now the meta-driver): drive engine lane (label `run`) —
  on non-zero outcome print the unified `run: ...` summary over ALL rows and
  fail fast; on green drive the skin lane; on full success append the unified
  journal entry to `tdd/cycle-log.md` (no `- behavior:` field, so evidence
  parsing is untouched) naming both receipts, print the final summary line,
  exit 0. Both lanes' receipts are written by their lane runs inside the meta
  invocation.
- `status` (StatusCommand): read both receipts, print exactly one line
  `status: feature=<f> engine=<green|red|error|absent> skin=<...>`, exit 0 iff
  both green. Missing feature dir -> misfire-stop like the run commands.

### 5. Vacuous lanes

An empty lane subset (legacy skin, or an all-skin engine) is not an error: the
lane completes with zero behaviors, writes a green receipt with
`behaviors: []`, and prints a note naming the vacuity. The test-list-level
"no behaviors" check (runner-error) still fires when the FULL list is empty.

## Risks & mitigations

- Regression risk on the 40-test run suite -> the core is a mechanical move;
  the meta run keeps label/summary/output shape; the suite is re-run in full
  as the green gate (plus `tools/run_tests_chunked.sh` and `dart analyze`).
- Receipt staleness (green receipt, then plan edited) -> the receipt is
  rewritten by every lane run that drives; pre-driving misfires leave the last
  honest verdict standing, and run-skin's gate re-checks greenness at every
  invocation.
- #1000 format drift (plan file format not final) -> plan-file parsing accepts
  the same table-row shape the test list uses plus simple bullets; tags remain
  the fallback.

## TDD plan

RED first: `test/plugins/tdd/two_cycle_run_commands_test.dart` drives a
fixture feature `004-login-ui` (the issue's exit-criteria feature) with tagged
CORE/SKIN/BOTH rows through the four commands; before implementation every
test fails (commands not found — UsageException). Then implementation, then
the full verification gates.
