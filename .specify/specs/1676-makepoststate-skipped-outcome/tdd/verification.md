# TDD Verification — Spec 1676 (MakePostState records on the skipped outcome)

- **Feature**: `1676-makepoststate-skipped-outcome` (issue #1676 — the
  #1652 MakePostState fast path never engages on the post-#1651
  hand-step flow)
- **Generated**: FRESH from the actual run in this session (2026-09-17,
  branch `fix/1676-makepoststate-skipped-outcome`) — not a copy of a
  prior verification.
- **Command path**: spec context read → red tests first (test-first, RED
  evidence captured with the fix NOT yet written) → single-point fix →
  GREEN → full affected-suite sweep → this audit.
- **Scope note**: the recording condition + verdict wording in
  `run_driver_core.dart` only (plus `MakePostState` library doc); the
  refactor-side consumer, the pass-batch ledger, and every full-suite
  gate are untouched.

## Verdict: **PASSED** (gate green, 3/3 mutants killed, 25/25 affected tests)

| Gate | Result |
|------|--------|
| Preflight (affected suites green) | ✅ the three #1652 suites (driver-level, command-level, defer-phase-1) green on the branch |
| Test-first evidence | ✅ revised `U5b` + new `U5b2` written BEFORE the fix; first run exit 1, `+3 -2` — both new behaviors failed, `tdd/red-1676.log` |
| Red-phase evidence | ✅ both failed for the RIGHT reason: the record still described B-001's green make — no record was written on the `skipped` outcome (the pre-fix condition `outcome == 'green'`), exactly the #1676 root cause |
| Green | ✅ `tdd/green-1676.log` — exit 0, `+5: All tests passed!` (U5a/U5b/U5b2/U5c/U6) |
| Test-smell rubric | ✅ no sleeps/order deps; isolated `Directory.systemTemp` fixtures with `tearDown` disposal; digests recomputed via `TreeSnapshot.capture` + `PassBatchLedger.treeDigest` (not echoed from the code under test); verdict asserted with both `contains` and `isNot(contains('outcome=green'))` — the dishonest label is pinned, not just the token |
| Mutation testing (changed file) | ✅ 3/3 mutants killed: M1 recording gate without `skipped` (= the pre-fix code, killed by U5b+U5b2, `red-1676.log`); M2 dishonest verdict (always `outcome=green`, killed by U5b+U5b2 — real run, both failed); M3 exit-gated skip recording (`result.exitCode == 0` added to the gate, killed by U5b2 — real run, failed) |
| Acceptance-criteria coverage | ✅ SC-1→U5b, SC-2→U5b2, SC-3→A1s, SC-4→U5c+U6+A2/U1a/U1b/U1c/U2/U2b/U3/U7/U8+U4, SC-5→U5a+A1b/A1c (see §4) |
| `dart analyze` (changed files) | ✅ `dart analyze` on all 4 changed `.dart` files: **No issues found!** |
| `dart format` | ✅ 4/4 changed files format-clean after one pass (`Formatted 4 files (0 changed)` on re-check); repo-wide `dart format --output=none --set-exit-if-changed .`: `Formatted 2943 files (0 changed)`, exit 0 — zero formatting diffs remain |

## 1. Test-first evidence (this session)

Order of operations, before any implementation existed:

1. Revised `U5b` in
   `test/plugins/tdd/run_driver_1652_make_post_state_test.dart` — the old
   contract ("the #741 already-green skip writes nothing") is exactly the
   premise #1676 overturns; the revised test pins the skip transition's
   OWN certification: record exists, `behavior_id` names the skipping
   behavior, digests match the on-disk trees, verdict contains
   `outcome=skipped` and NOT `outcome=green`.
2. Added `U5b2` — the exit-disagreeing skip token (`outcome=skipped`,
   exit 1, the bug #986 terminal classification) records under the same
   gate, verdict carries the real exit code.
3. Added command-level `A1s` in
   `test/plugins/tdd/commands/bug_1652_refactor_make_post_state_test.dart`
   — a skip-written record inherits the pipeline (zero suite spawns), the
   printed evidence names `outcome=skipped`.
4. First run: **exit 1, `+3 -2`** — U5b and U5b2 failed for the right
   reason (no record written on skipped; the standing record still named
   B-001's green make), U5a/U5c/U6 passed as characterization guards.
   `A1s` passed pre-fix as predicted (the refactor-side consumer was
   already verdict-agnostic — the plan documented this as a
   characterization guard, not red evidence).
   Reproducible artifact: `tdd/red-1676.log`.

## 2. Red → green (the fix)

The single-point fix in `run_driver_core.dart`:

- Recording condition widened:
  `result.outcome == 'green' || result.outcome == 'skipped'` (was
  `== 'green'`).
- `_recordMakePostState` gained the `outcome` parameter and builds the
  verdict honestly per outcome — the `green` wording stays BYTE-IDENTICAL
  (`make <id> outcome=green exit <n> (post-generation green evidence)`);
  the skip verdict names its own evidence:
  `make <id> outcome=skipped exit <n> (skip-transition target-test green
  evidence on the current tree; issue #1676)`.
- Block comment + `MakePostState` library doc updated (the "deliberately
  writes nothing" rationale is what #1676 overturns).

Second run: **exit 0, `+5: All tests passed!`** (`tdd/green-1676.log`).

## 3. Full-suite gate preservation (SC-4) — proved, not assumed

No gate or consumer code changed (`git diff` on `lib/` = the recording
condition, the verdict construction, and doc comments only). The
preservation is additionally pinned by the untouched guard suites, all
green on this branch after the fix:

- `A2` (lib/ tree drift), `U7` (test/ drift), `U1a` (baseline rewrite),
  `U1b` (config rewrite), `U1c` (exempt-set difference) → full pipeline.
- `U2`/`U2b` (corrupt / partially-mistyped record) → full pipeline
  (safe failure).
- `U3` (flag-less standalone refactor; `--full-reproof`) → full pipeline.
- `U4` → the refactor-proved pass-batch ledger keeps precedence over the
  make record.
- `U5c` → a record write failure is a warning; the run completes.
- The inheritance output itself (untouched in `refactor_command.dart`)
  keeps naming that the full suite did NOT run at this tree and still
  runs at the phase-2b batch pass, feature completion + nightly
  (spec 069 T001).
- `A1b`/`A1c` (defer suite) → the skip and exit-disagreeing skip
  transitions defer the following refactor exactly like a green make —
  scheduling unchanged.

## 4. Success-criteria → behavior map

| SC | Behavior(s) | Evidence |
|----|-------------|----------|
| SC-1 | U5b (revised) | skip records its own certification; digests recomputed and matched; honest verdict |
| SC-2 | U5b2 | exit-1 skip token records; verdict carries `exit 1` |
| SC-3 | A1s (+ A1's record-match machinery) | skip-written record inherits: zero suite spawns, honest evidence printed, ledger untouched |
| SC-4 | U5c, U6, A2, U1a, U1b, U1c, U2, U2b, U3, U7, U8, U4 | every mismatch dimension, staleness, corruption, ledger precedence, warning-not-error — all unchanged and green |
| SC-5 | U5a, A1b, A1c, U1c-adjacent adoption classes untouched | green verdict byte-identical; green-path recording unchanged; no other token's recording behavior changed |

## 5. Mutation analysis (changed file: `run_driver_core.dart`)

| Mutant | Change | Result | Killed by |
|--------|--------|--------|-----------|
| M1 | drop `\|\| result.outcome == 'skipped'` from the gate (= the pre-fix code) | KILLED (exit 1, `+3 -2`) | U5b, U5b2 (`tdd/red-1676.log`) |
| M2 | verdict construction: always emit the `outcome=green` wording | KILLED (both target tests failed on the real run) | U5b (`isNot(contains('outcome=green'))`), U5b2 (`exit 1` missing) |
| M3 | gate the skip branch on `result.exitCode == 0` | KILLED (U5b2 failed on the real run) | U5b2 |

All mutants were restored before the final green confirmation
(`+5: All tests passed!` re-run after restoration).

## 6. Test inventory actually executed in this session

| Suite | Count | Result |
|-------|-------|--------|
| `test/plugins/tdd/run_driver_1652_make_post_state_test.dart` | 5 | 5 pass / 0 fail (clean-cache re-run) |
| `test/plugins/tdd/commands/bug_1652_refactor_make_post_state_test.dart` | 13 | 13 pass / 0 fail (clean-cache re-run) |
| `test/plugins/tdd/issue_1652_defer_phase1_refactor_test.dart` | 7 | 7 pass / 0 fail (clean-cache re-run) |

No unrelated pre-existing failures were observed in any executed suite.
The repo's `slow`-tagged tiers (`run_command_test.dart`,
`two_cycle_run_commands_test.dart`) are excluded from the fast tier by
`dart_test.yaml` and were not run (out of scope per the change surface:
only test what changed).

## 7. Verdict

The gate is green: the #1651 hand-step flow's terminal `skipped` outcome
now writes the `MakePostState` record (honestly named), the next
`--pass-batch` refactor inherits instead of re-paying the full pipeline,
every full-suite gate and fallback rule is preserved, and the
`green`-outcome contract is byte-identical. Issue #1676's success
criteria are all covered by executed, mutation-hardened tests.
