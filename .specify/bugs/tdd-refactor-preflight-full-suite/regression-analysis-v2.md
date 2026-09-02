# Regression Analysis v2: bug #734 reopened — refactor preflight refusal still deadlocks the run

- **Slug**: tdd-refactor-preflight-full-suite
- **Re-analysis**: 2026-09-02 (reopened-bug investigation, §4)
- **Original fix**: 13172c00 (PR #743)
- **Branch**: fix/734-v2-refactor-preflight-full-suite

## §4 Findings

| Question | Finding |
| --- | --- |
| Does the bug still reproduce on current master? | YES. The driver treats a spawned `refactor` reporting `not-green` as a pass-fatal step failure (run_command.dart failure path → honest stop at `<id>:refactor`). Any suite redness the pre-spawn deferral cannot model reaches the spawn, FR-001's preflight refuses, and the run stops — blocking every other green behavior's refactor. Reproduced at driver level by the two new v2 tests (RED pre-fix) and by the real-CLI scratch repro (red stub on disk, no registry record). |
| What was the original fix commit? | 13172c00 — "fix(734): tdd refactor gates per-behavior on own test, not full suite (#743)". Driver layer only: phase-1 deferral while any behavior sits RED or PENDING with gen artifacts; phase-2b per-behavior gate on certified green evidence (skip with recorded reason). refactor_command.dart byte-untouched (spec 048 FR-001/FR-002 preserved). |
| Is the original fix still present in the code? | YES. Phase-1 deferral (run_command.dart refactor-deferral branch + `_hasRedBehavior`/`_hasPendingWithArtifacts`), the phase-2b paper gate (`certifiedGreen`/`skippedRefactors`), and the honest skipped-refactors ending are all intact. The two original #734 driver tests still pass (29/30 in run_command_test.dart on current master; the single failure is the KNOWN pre-existing bug-691 failure documented in the original verification, Findings #3 — fails on pristine master too). |
| Why didn't the original fix hold? | PARTIAL FIX. The deferral's redness model (a) trusts the REGISTRY as the artifact source of truth ("artifact-less pending rows contribute no red risk") and (b) only looks at the feature's OWN rows. The issue's state is "U3-U44 pending (NOT generated)" while "the full suite has U3+ stubs throwing UnimplementedError" — stubs ON DISK WITHOUT registry records (interrupted gen between file-write and registry-flush, a wiped/never-written artifacts.json — the bug #720 family — or gen outside the driver). For those rows `_hasPendingWithArtifacts` returns false, the deferral does not engage, the refactor spawns into the knowingly-red suite, the preflight refuses (not-green), and the refusal takes the pass-fatal step-failure path — the deadlock returns verbatim. Additionally, 2e3f09e4 (#737) and 14651299 (#741) landed AFTER the fix and widened the exposure without creating it: make now certifies green while tolerating pre-existing suite failures by design (#731 baseline-relative guard, #741 cached-baseline scoped guard, #737 tolerated terminal build step), so MORE runs legitimately reach a refactor spawn with the suite still red — every one deadlocks at the first refusal. |
| Is the root cause the same, or has it shifted? | SAME root, deeper. The driver's redness model (row states + registry records) is strictly narrower than the spawned refactor's actual redness contract (absolute full-suite green, spec 048 FR-001). The original fix closed ONE source of mismatch (pending-with-record). The reopen exposes the CLASS: any unmodeled redness re-deadlocks the feature at the first spawned refusal. |

## v2 Remediation (root cause, driver layer only; refactor_command.dart untouched)

1. **Widen the pre-spawn deferral model** (`_hasPendingWithArtifacts`): a PENDING row contributes red risk when it has a registry record OR its gen-default test file exists on disk (`test/tdd/<snake>_test.dart`). The suite compiles and runs from DISK, not from the registry — the registry-trust assumption was exactly the flawed half of the original fix. Fresh-run ordering is preserved (pending rows have no test files before gen runs).
2. **Make the residual mismatch non-fatal** (the safety net): a spawned refactor's `not-green` refusal is side-effect-free (refactor refuses BEFORE any pass, modifying zero files), so it is per-behavior information, not a pass-fatal step failure:
   - Phase 1: DEFER the behavior (stays GREEN, FR-007 semantics) — pending rows may still flip the suite green this run, and the deferred refactor re-spawns in phase 2b.
   - Phase 2b: SKIP with a recorded reason (stays GREEN, never a fake DONE, FR-008); the pass continues for every other behavior; the honest end-of-run stop names the skips and the resume path.
   - A `regression` (re-proof failure), `runner-error`, or `missing-summary` refactor outcome keeps the honest stop — those are NOT safe to continue past.
