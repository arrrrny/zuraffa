feature: specs/1309-stale-lane-plans-after-spec-edit (issue #1309, branch feat/1309-stale-lane-plans-after-spec-edit)
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: working tree @ feat/1309-stale-lane-plans-after-spec-edit
behaviors: 11 (7 acceptance + 7 unit spec rows; 11 suite tests covering them)
proven: 8
likely: 0
test_after: 0
no_test: 0
high_smells: 0
mutation_score: 5/5 killed # scope: plan_command.dart (_splitReceiptIsStale comparison inversion, heuristic collapse, receipt-refresh removal, receipt-ignored legacy demotion) + split_command.dart (force flag disabled) — deliberate manual mutants, each applied to the working tree, each killed by a named test in test/plugins/tdd/commands/issue_1309_stale_lane_plans_test.dart, then reverted (restoration verified by dart analyze + full-suite re-run)
mutants_survived: 0
equivalent_mutants: 1 # first M4 attempt moved `!force` into the outer guard condition — behaviorally identical for the refusal path (the --force note line is unasserted cosmetics); replaced by the detectable force-flag-disabled mutant
suite: "issue_1309_stale_lane_plans_test.dart 11/11 (B1-B11); tdd/commands directory 373/373 (all neighbors green: split_command_1000 6, plan_lanes_1000, plan_command_ffi_835, plan_skin_contract_1004, plan_marker_emission_1186, bug_1271, corpus_run_plan, bug_1261 22); split-touching root suites (bug_840, bug_969, explain_flag, issue_990, bug_1264) 45/45; dart analyze: no issues in the three touched files; dart format: `dart format --set-exit-if-changed lib test` exit 0 (CI gate scope), 0 diffs"

---

# TDD Verification: issue #1309 — stale lane plans after a spec edit

**Verdict: PASS.** The red→green cycle is real: the RED phase ran the new
suite against the unmodified tree (`00:00 +3 -8: Some tests failed` — the
8 new-behavior tests fail, the 3 backward-compat guards pass), the GREEN
phase was driven by the two command files only, and five deliberate
mutants were each killed by a named test. The hard constraints hold: the
core engine cycle, the test-list generation (`_render`), the lane
derivation algorithm (`_resolveLanes`, `SplitCommand._heuristic`, the
`render*Plan` emitters) and `TestListReader` are untouched
(`git diff --stat`: `plan_command.dart` +166/-25, `split_command.dart`
+85 lines, the new spec artifacts, the new test file — nothing else).

## RED evidence (unmodified tree)

```
00:00 +3 -8: Some tests failed.
```

The 8 failures are exactly the new behaviors: receipt format
(`spec_hash`/`spec_mtime` absent), refusal without the remedy, no
`--force` flag (usage refusal), no stale detection (plan demoted the
meta-index and rewrote only test-list.md — the live deadlock symptom
visible in the RED transcript:
`zfa tdd plan: wrote .../test-list.md with 2 acceptance + 3 unit
behaviors (6 total)` printed against a meta-index feature), no ghost-row
cleanup, no refresh bookkeeping. The 3 passes are the backward-compat
guards (never-split legacy path, Lanes-declared path) — green before and
after, as required.

## GREEN evidence

```
00:00 +11: All tests passed!        (issue_1309_stale_lane_plans_test.dart)
01:09 +373: All tests passed!       (test/plugins/tdd/commands/ — full directory)
00:01 +45: All tests passed!        (split-touching root suites)
```

## Mutation evidence (manual mutants, each killed then reverted)

| # | Mutant | Killed by |
|---|--------|-----------|
| M1 | `_splitReceiptIsStale`: `!=` → `==` (staleness inverted) | "a spec edit after the split is reported stale and the new FR appears in the regenerated engine plan" fails |
| M2 | `_heuristicLaneResolution`: every row classified SKIN | same test — the engine-plan assertions (`\| U1 \|`, `\| U3 \|` in 04-ENGINE.md) fail |
| M3 | receipt refresh block disabled (`if (false && …)`) | "the receipt refresh stops the stale report from re-firing" fails (second plan run re-reports stale) |
| M4 | `split`: force flag hardcoded `false` | "--force re-splits over the existing receipt" fails (exit 1) |
| M5 | plan ignores the receipt (lane resolution → null, legacy path) | "an unchanged spec is not reported stale but the lane plans still regenerate" fails (corrupted 04-ENGINE.md survives, meta-index demoted) |

Score: 5/5 killed, 0 survived, 1 equivalent discarded by construction.

## Live CLI staleness demo (real transcript, from the PR body)

```
$ zfa tdd split demo                       # one-shot migration
zfa tdd split: wrote tdd/04-ENGINE.md (1 CORE), … — receipt: …
  04-ENGINE.md carries U1: 1

$ # ...user edits the spec: adds FR-002...
$ zfa tdd plan demo                        # the deadlock is broken
  zfa tdd plan: stale lane split detected — spec.md changed since
  specs/demo/tdd/split-receipt.json was written; regenerating the lane
  plans from the current behavior set (issue #1309).
  04-ENGINE.md now carries U2: 1

$ zfa tdd split demo                       # the refusal now names the remedy
  zfa tdd split: REFUSED — demo is already split (… exists) — use
  `zfa tdd split --force` to re-split, or `zfa tdd plan demo` to refresh
  lane plans from the current spec (issue #1309).

$ zfa tdd split demo --force               # the escape hatch
  zfa tdd split: wrote tdd/04-ENGINE.md (3 CORE), …
```

## Success-criteria scorecard

| Criterion | Status |
|---|---|
| AC-1 stale split detected on re-plan, new FR regenerated into the lane plans | PROVED (test 1 of "plan regenerates stale lane plans" + live demo) |
| AC-2 deleted FR leaves no ghost row in any lane plan; reader resolves the current set | PROVED (ghost-row test) |
| AC-3 `split --force` re-splits over the receipt; refusal names `--force`/plan | PROVED (force tests + refusal-remedy test + live demo) |
| AC-4 lane plans reflect the current behavior set after plan/split; mtimes ≥ spec | PROVED (unchanged-spec refresh test + mtime test); the one-time `**Type**` marker emission rewrites the spec AFTER the lane writes — the flow's own "Re-run `zfa tdd plan`" guidance restores the mtime ordering, and the behavior set itself is unchanged by markers |
| AC-5 (issue AC-4) never-split unchanged; `## Lanes` path unchanged; detection fires only with receipt + changed spec | PROVED (backward-compat group: never-split test asserts no lane artifacts; Lanes-declared test asserts the declared path; unchanged-spec test asserts no stale report) |
| Legacy receipt (no `spec_hash`) mtime fallback | PROVED (downgraded-receipt test) |
| Refresh bookkeeping stops re-firing | PROVED (refresh test) |

## Known edge (documented, not a failure)

The one-time `**Type**` marker emission (issue #1186) persists the spec
AFTER the lane plans are written, so in that specific flow the lane
mtimes momentarily trail the spec. Markers do not change the behavior
set (the lane plans still reflect it), and the emission message
instructs a re-run — on which the refreshed lane plans restore the mtime
ordering. The AC-4 mtime test covers the normal (no-emission) flow via
`--no-emit-markers`.
