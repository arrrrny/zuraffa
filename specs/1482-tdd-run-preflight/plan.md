# Plan: 1482-tdd-run-preflight

## Technical Context

- **Command under change**: `zfa tdd run <feature>` ONLY
  (`lib/src/plugins/tdd/commands/run_command.dart`). `zfa tdd plan`,
  `zfa tdd verify`, `RunDriverCore`, and every loop step keep their exact
  semantics — the preflight is a NEW refusal in front of the existing
  pipeline, not a change to it.
- **Routing provenance access**: `zfa tdd plan` already writes the durable
  provenance artifact — the `## Routing provenance` section of
  `tdd/test-list.md` (`plan_command.dart` `_renderTestList`, lines
  `route: <id> -> <lane> [declared: ...]` / `[fallback: legacy description
  classifier matched — ...]` / `[refused: ...]`), rendered identically into
  the lane plans `tdd/04-ENGINE.md` / `tdd/04-SKIN.md` when the list is a
  lane meta-index (`LaneSplitFiles.find`). The preflight READS this
  section; it does not re-run the `RoutingResolver` ladder (FR-006).
- **Row data**: `TestListReader(featureDir).read()` — the single format
  contract for `tdd/test-list.md` (bug #617) — yields
  `BehaviorRow{id, description, traces, state, kind}` and already follows
  the lane meta-index transparently.
- **Assertion predicate**: `contentIsVacuousGreen` from
  `services/vacuous_guard.dart` (issue #1259) — the SAME predicate the
  make step's vacuous-green refusal uses. "No derivable assertion" for a
  fallback-routed unit = no generated test, or a generated test whose
  assertion set is only the UnimplementedError guard. A hand-completed
  test (real expects) is evidence the row CAN pass make — never listed.
- **Existing preflight patterns** (the house shape this feature follows):
  - #1303 `DependencyOverridePreflight` (`services/dependency_override_preflight.dart`):
    a self-contained service returning a report; the command prints
    findings, journals `preflight_red` at the `gate` phase, prints the
    summary line with all-zero counts, exits 3.
  - #1001 cert gate (`RunEngineCommand.checkFeature`): stderr + journal
    `preflight_red` + exit 1.
  - This preflight follows the #1303 shape but with the run's `stopped`
    exit class (exit 1): the refusal IS the honest stop the loop would
    reach at `<first-offender>:make`, detected before the loop starts —
    the issue's own framing ("the first fatal condition should be detected
    before the loop starts, not 19 certifications in").
- **Feature resolution**: `TddFeaturePaths.resolveWithPin` (issue #1471)
  already resolves bug features under `.specify/bugs/<slug>/` — the
  preflight receives the resolved `featureDir` and works for every feature
  layout (SC-4).

## Design

### New service — `services/routing_provenance_preflight.dart`

```
RoutingProvenancePreflight({required String projectRoot, required String featureDir})
  Future<RoutingProvenancePreflightReport> check()
```

`check()` (O(1) reads only — no subprocess, no spec parse, no planning):

1. `TestListReader(featureDir).read()` → rows. `TestListReadException` →
   fail-open (`ok: true`, empty findings — the driver's own missing-list
   handling names the real problem; AC-6).
2. Parse the `route:` lines of the `## Routing provenance` section from
   `tdd/test-list.md`; when the list is a lane meta-index, also (and
   primarily) from `tdd/04-ENGINE.md` + `tdd/04-SKIN.md`. Map:
   behavior id → fallback-routed? A line is fallback-routed when its
   bracket tag starts with `[fallback:`. Missing section / missing id →
   NOT fallback (declared, legacy, or unknown — never invented).
3. Offending row (FR-001) — ALL of:
   - `row.kind == BehaviorKind.unit`
   - provenance marks the id `[fallback: ...]`
   - `row.state != BehaviorState.done` (a done row's loop is complete —
     evidence beats state; refusing would block legitimate resumption)
   - generated test absent OR vacuous: the same candidate paths
     `RunDriverCore` resolves (`test/tdd/<feature>/<snake-id>_test.dart`,
     `test/tdd/<snake-id>_test.dart`), `contentIsVacuousGreen` decides.
4. Report: `{ok, offending: [RoutingPreflightFinding]}` where each finding
   carries id, description, and the FR-shaped criterion tokens
   (`^(FR|AC|SC)[-]?\d+` — the resolver's own criterion shape) parsed from
   the row's traces cell.

### Command wiring — `run_command.dart`

- New `--force` flag (help names issue #1482): bypasses ONLY this
  preflight; the #1303 and #1001 gates keep their semantics (FR-003).
- Placement: immediately AFTER the #1303 dependency-overrides preflight
  and BEFORE the `--baseline-scope` validation / cert gate / first lane
  drive — every existing position untouched.
- On `!report.ok` (FR-002 / FR-004):
  1. print `run: preflight failed — N unit behaviour(s) cannot pass make:`
  2. print `  <id> — <description> (no declared contract trace, fallback
     to FR-00N)` per finding (the `, fallback to ...` suffix only when the
     row traces at least one criterion token)
  3. print `Suggested: fix routing in plan, or run \`zfa tdd run --force\`
     to skip preflight.`
  4. journal `preflight_red` / phase `gate` / result `stopped` with one
     violation per finding
  5. print the final summary line `run: feature=<f> result=stopped
     pending=0 red=0 green=0 done=0` (all-zero counts — the #1303
     precedent: the run did no work)
  6. verdict envelope: `exitClass=stopped`, `outcome=VerdictOutcome.stopped`,
     explain block naming the preflight refusal and both remedies
  7. `exitCode = 1`; return — zero steps spawned.

### Non-goals (hard constraints)

- No change to `tdd plan` (the companion plan-time gate is a separate
  issue), `tdd verify`, `RunDriverCore`, `verify-red`, `make`, or any
  receipt/journal format beyond the new `preflight_red` meta entries the
  existing `JournalWriter.append` already supports.
- No re-implementation of the routing ladder: the provenance SECTION is
  the plan's decision record; the preflight reads it verbatim.

## Verification Plan

- Fast tier (no subprocess): `test/plugins/tdd/issue_1482_run_preflight_test.dart`
  drives the service + the command through `CliRunner.runCapturing` over
  seeded test lists + provenance sections.
- Driver tier (scripted fake zfa): `--force` proceeds into the engine lane
  and the honest vacuous-green stop stays byte-identical (SC-2).
- Regression scope: `run_command_test.dart`, `run_engine_command_test.dart`,
  `run_skin_command_test.dart`, `bug_1259_vacuous_green_test.dart` (SC-3).
