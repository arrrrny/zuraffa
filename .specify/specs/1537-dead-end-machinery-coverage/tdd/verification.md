# TDD Verification — Spec 1537 (dead-end machinery: keep and pin)

- **Feature**: `1537-dead-end-machinery-coverage` (issue #1537 — the #1481
  dead-end fallback machinery left uncovered by PR #1527 after feature
  #1484's FR manual routing)
- **Generated**: FRESH from the actual runs in this session (2026-09-13) —
  not a copy of a prior verification.
- **Command path**: `/speckit.specify` → `/speckit.plan` → `/speckit.tasks`
  → `/speckit.analyze` → `/speckit.tdd.plan` → `/speckit.tdd.run`
  (mutant red → restored green, evidence logs recorded) →
  `/speckit.implement` (non-behavioural provenance-doc correction) →
  this audit.
- **Scope note**: Option B (keep and pin) — the unreachability claim of
  issue #1537 was DISPROVED by probe before any code change
  (`scripts/probe_1537.sh` equivalents: persistence route + flag route,
  both exit 0 with the tally rendered); `plan_command.dart` behavior is
  byte-identical to HEAD, only its provenance documentation changed.

## Verdict: **PASSED** (green suite 11/11 + 26 neighbor, mutant killed)

| Gate | Result |
| --- | --- |
| Unreachability probe (pre-work, live CLI) | **FALSIFIED** — `traces: FR-001` + `[persistent]` → exit 0, tally printed (default flags); same + `--allow-unit-fallback` → exit 0, tally printed; control (default flags, no mark) → #1480 refusal exit 1 (why the original three probes missed it) |
| Red evidence (deletion mutant, `tdd/red-1537.log`) | **3/3 pinning tests FAIL** against the Option-A mutant (`deadEnds.add`, fatal prefix, both tally calls, both verdict keys removed; mutant residue check all-False; test file loaded and ran — not a compile error) |
| Green evidence (`tdd/green-1537.log`) | **11/11 pass** on restored HEAD machinery (8 legacy #1481 guards + P1/P2/P3 pins), analyze clean |
| Neighbor suites | `plan_routing_provenance_test.dart` + `plan_marker_emission_1186_test.dart` + the 1481 file = **37/37 pass** |
| `dart analyze` (changed files) | No issues found (pre- and post-format) |
| `dart format` | Applied to the two touched files; re-analyzed + re-run green after formatting |
| Verdict envelope (P3) | `details.dead_end_behaviors == 1` asserted on the `--json` run of the SC-1 fixture |
| Existing #1481 guards (SC-5) | Unchanged and green: manual-routed unbound FRs render no fatal prefix/tally; `--no-emit-markers` repairable scenario renders the REPAIRABLE class |

## Success criteria audit

- **SC-1** — P1: `[persistent]` + criterion-only `traces: FR-001`, default
  flags → exit 0, `route: U1 -> unit lane [fallback: no declared trace —
  make will dead-end ...]` and `zfa tdd plan: 1 behavior will dead-end at
  make ... (U1)` both asserted. **MET**
- **SC-2** — P2: same spec minus the mark under `--allow-unit-fallback` →
  exit 0, fatal prefix + tally with `(U1)` asserted. **MET**
- **SC-3** — P3: `--json` envelope `details.dead_end_behaviors == 1`.
  **MET**
- **SC-4** — Red evidence: the pinning group fails 3/3 against the
  machinery-deletion mutant and passes 3/3 on HEAD — the tests guard the
  machinery, not the happy path. **MET**
- **SC-5** — The legacy #1481 groups pass unchanged in the same file run.
  **MET**
- **SC-6** — `plan_command.dart` provenance docs corrected (three comment
  blocks: the `_provenanceLines` dead-end doc, the `RoutingUndeclared`
  fallback comment, the `_printDeadEndTally` doc) + the test-file header's
  "out of reach" claim amended; no rendered string, exit code, or routing
  decision changed (behavior identical to HEAD). **MET**

## Hard constraints audit

- `plan_command.dart` changed (out of scope for test-only PR #1527): the
  documentation correction above — the file's provenance claims now match
  the proven liveness. **SATISFIED**
- `dart analyze` with no new warnings: clean on both touched files.
  **SATISFIED**
- `RoutingResolver` / `SpecParser` semantics untouched: both files are
  byte-identical to HEAD. **SATISFIED**

## Follow-up candidates (out of scope here)

- Refusing criterion-only trace bindings at plan time with a
  `--> fix:` line (a behavior change; the pinned tally would then need a
  new route — deliberately deferred).
- The resolver's criterion-token skip is shared with make/gen cell
  tokenization; any tightening must be scoped to the plan-time author
  surface, not the cell shape.

## Recorded evidence (excerpts — raw logs are `*.log`, gitignored)

Red run (`tdd/red-1537.log`, deletion mutant applied, 2026-09-13):

```
MUTANT RESIDUE CHECK (all must be False): [False, False, False, False]
00:00 +0 -3: Some tests failed.

Failing tests:
  test/plugins/tdd/commands/plan_command_bug_1481_test.dart: #1537: the fatal
  dead-end machinery is LIVE (criterion-only trace bindings) a
  persistence-marked FR with a criterion-only traces binding renders the
  fatal route line and the tally (default flags, exit 0)
  ... the flag route — --allow-unit-fallback reaches the same tally ...
  ... the verdict envelope counts the dead end (dead_end_behaviors == 1)
```

Green run (`tdd/green-1537.log`, machinery restored from HEAD):

```
machinery sites restored: 5
Analyzing plan_command.dart, plan_command_bug_1481_test.dart...
No issues found!
00:00 +11: All tests passed!
```
