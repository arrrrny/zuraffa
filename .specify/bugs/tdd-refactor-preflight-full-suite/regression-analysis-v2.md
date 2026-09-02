# Regression Analysis v2: bug #734 reopened as #754 — refactor preflight refusal still deadlocks the run

- **Slug**: tdd-refactor-preflight-full-suite
- **Re-analysis**: 2026-09-02 (reopened-bug investigation, §4, session at 8869db5d)
- **Original fix**: 13172c00 (PR #743)
- **Unmerged prior v2 attempt**: 3bdb6123 on `origin/fix/734-v2-refactor-preflight-full-suite` (branched from 14651299, never merged into master — verified with `git merge-base --is-ancestor`)
- **Branch**: fix/754-v2-refactor-preflight-full-suite

## §4 Findings

| Question | Finding |
| --- | --- |
| Does the bug still reproduce on current master? | YES, at driver level. 3 of the 4 bug-734-v2 driver tests fail on pristine master (8869db5d) with the exact reopened signature: `[run] A1 refactor -> not-green` → `zfa tdd run: step failed — behavior=A1 step=refactor outcome=not-green` → `result=stopped pending=1 red=0 green=1 done=0 stopped_at=A1:refactor` — the pending behavior is never driven and the already-green behavior's refactor never completes. RED evidence captured in this session, pre-fix. The 4th test (a refactor `regression` still stops honestly) passes pre-fix, as it must both before and after. |
| What was the #743 fix commit? | 13172c00 — "fix(734): tdd refactor gates per-behavior on own test, not full suite (#743)". Driver layer only: phase-1 deferral while any behavior sits RED or PENDING with gen artifacts; phase-2b per-behavior gate on certified green evidence (skip with recorded reason). `refactor_command.dart` byte-untouched (spec 048 FR-001/FR-002 preserved for standalone invocations). |
| Is refactor_command.dart:181 still calling runner.runSuite()? | YES. `lib/src/plugins/tdd/commands/refactor_command.dart` still runs `final preflight = await runner.runSuite(...)` for the preflight (the issue's line 181; the full-suite `dart test` refusal path), with the intentional no-`--skip-preflight` note at the FR-002 comment. This is BY DESIGN for standalone `zfa tdd refactor` (spec 048 FR-001/FR-002); the fix belongs in the run driver, which spawns refactor in contexts where the suite is not guaranteed green. |
| Why didn't the original fix hold? | TWO causes. (1) MODEL GAP: the original fix's pre-spawn deferral (`_hasPendingWithArtifacts`) consults ONLY the artifact registry ("artifact-less pending rows contribute no red risk"), but the suite compiles and runs from DISK. A pending row whose generated stub test file exists on disk WITHOUT a registry record (interrupted gen between file-write and registry-flush, a wiped or never-written artifacts.json — the bug #720 family — or gen run outside the driver) contributes real redness the deferral cannot see. The issue's own state is "U3-U44 pending (NOT generated)" while their stubs throw `UnimplementedError` on disk. For such a row the deferral does not engage, refactor spawns into the knowingly-red suite, FR-001's preflight refuses (not-green), and the refusal takes the pass-fatal stop path — the #734 deadlock returns verbatim. (2) EXPOSURE WIDENED: 2e3f09e4 (#737) and 14651299 (#741) landed AFTER the fix and let make certify green while tolerating pre-existing suite failures (baseline-relative guard), so MORE runs legitimately reach a refactor spawn with the suite still red — every one deadlocks at the first refusal. Additionally, an unmerged prior v2 fix (3bdb6123) exists on a side branch and never reached master. |
| Is the root cause the same, or has it shifted? | SAME root, deeper. The driver's redness model (row states + registry records) is strictly narrower than the spawned refactor's actual redness contract (absolute full-suite green, spec 048 FR-001). The original fix closed ONE source of mismatch (pending-with-registry-record). The reopen exposes the CLASS: any unmodeled redness re-deadlocks the feature at the first spawned refusal. |

## v2 Remediation (root cause, driver layer only; refactor_command.dart byte-untouched)

1. **Widen the pre-spawn deferral model** (`_hasPendingWithArtifacts`): a PENDING row
   contributes red risk when it has a registry record OR its gen-default test file
   exists on disk (`test/tdd/<snake_id>_test.dart`). The suite runs from DISK, not
   from the registry — the registry-trust assumption was exactly the flawed half of
   the original fix. Fresh-run ordering is preserved (pending rows have no test
   files before gen runs), so the U19 artifact-less fresh-run contract is unchanged.
2. **Make the residual mismatch non-fatal** (the safety net): a spawned refactor's
   `not-green` refusal is side-effect-free (refactor refuses BEFORE any pass,
   modifying zero files), so it is per-behavior information, not a pass-fatal step
   failure:
   - Phase 1: DEFER the behavior (stays GREEN, FR-007 semantics) — pending rows may
     still flip the suite green this run, and the deferred refactor re-spawns in
     the phase-2b pass.
   - Phase 2b: SKIP with a recorded reason (stays GREEN, never a fake DONE,
     FR-008); the pass continues for every other behavior; the honest end-of-run
     stop names the skips and the resume path.
   - A `regression` (re-proof failure), `runner-error`, or missing-summary refactor
     outcome keeps the honest stop — those are NOT safe to continue past (passes
     already ran / spawn misfired).

**Files changed**: `lib/src/plugins/tdd/commands/run_command.dart`,
`test/plugins/tdd/run_command_test.dart` (4 added tests, zero edits to existing
assertions). `refactor_command.dart` untouched — verified byte-identical to master.

**Tests to add** (all RED pre-fix except the regression guard, which is green both
sides by design):

- Bug 734 v2: refactor defers while a pending behavior has a red stub on disk
  WITHOUT a registry record (the deferral widens to disk).
- Bug 734 v2: a phase-1 refactor whose preflight refuses (not-green) defers
  instead of stopping the run; the pending row is still driven; the deferred
  refactor completes in phase 2b.
- Bug 734 v2: a phase-2b refactor whose preflight refuses is skipped with a
  recorded reason while the rest of the pass completes.
- Bug 734 v2: a refactor regression (re-proof failure) still stops the run
  honestly (the safety net does not capture real failures).
