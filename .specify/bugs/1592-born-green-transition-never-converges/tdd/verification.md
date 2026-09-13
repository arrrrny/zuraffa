# TDD Verification — 1592-born-green-transition-never-converges

- **Slug**: 1592-born-green-transition-never-converges
- **Verified**: 2026-09-13
- **Mode**: the tdd-verify fallback path (LLM-guided audit) — the formal
  `zfa tdd verify` mutation gate targets generated subject features and its
  mutation budget does not apply to the CLI repo itself; every command below
  was executed for real in this session, outputs captured verbatim.
- **Verdict**: **passed**

## 1. Test-first evidence (git history)

- The reproduction commit (`822b3733` "WIP: red — bug 1592 reproduction
  (B1 fails: blocked re-enters verify-red)") precedes the fix commit
  (`cde7d368` "WIP: green — guard extended to blocked state") on this branch;
  the reconciled green (`8eb6e3f9`) re-lands the guard in its final
  born-green-certified scope and merges the suites.
- Session-level RED evidence (captured before any fix was applied to the
  working tree):

```
00:07 +0 -1: U-1592-1 (issue #1592): a born-green-certified BLOCKED contract
converges — ... [E]
  Expected: not contains '--born-green` — then re-run'
...
  [run] contract:A7 verify-red -> unexpected-green
  [run] contract:A7 verify-red -> skipped (already green)
  [run] contract:A7 make -> not-certified-red
     hand step: contract:A7:hand — ... the designed hand step was completed
     BEFORE the first red certification (issue #1411) — verify-red saw the
     test already green (skipped) and make found no certified red (the
     catch-22).
     Certify the born-green hand transition: `zfa tdd make contract:A7
     --born-green` — then re-run `zfa tdd run 1592-born-green-convergence`.
  run: feature=1592-born-green-convergence result=stopped pending=0 red=0
  green=0 done=0 blocked=1 stopped_at=contract:A7:hand
```

The prescription names the command whose green entry is ALREADY on the
journal — the #1592 loop, reproduced.

## 2. Real-CLI end-to-end A/B (no fake, real step children)

Fixture: a session-built real temp project (an ad-hoc fixture — there is no
committed script; it is reproducible by hand from this description) — one
contract behavior parked `blocked`, the born-green green entry on the
journal with its `- subject-hash:` binding the hand-written subject, the
attested passing test on disk, `build_runner` present. Driver AND step
children are the real CLI (`dart bin/zfa.dart`).

**PRE-FIX driver** (`819cfcf9`'s `run_driver_core.dart`), same fixture:

```
[run] contract:A1 verify-red -> unexpected-green
[run] contract:A1 verify-red -> skipped (already green)
[run] contract:A1 make -> not-certified-red
   hand step: contract:A1:hand — ... (the catch-22).
   Certify the born-green hand transition: `zfa tdd make contract:A1
   --born-green` — then re-run `zfa tdd run 1592-e2e`.
run: feature=1592-e2e result=stopped pending=0 red=0 green=0 done=0
blocked=1 stopped_at=contract:A1:hand
```

**POST-FIX driver** (this branch), same fixture, after the one-time build
scaffold:

```
[run] contract:A1 refactor -> clean
run: feature=1592-e2e result=complete pending=0 red=0 green=1 done=0
exit=0
```

The child ran REAL passes (build / format / fix, all exit 0) and a REAL
`dart test` re-proof (exit 0). No verify-red, no make, no prescription —
the loop is dead. The behavior lands GREEN (the bug #682 reconcile shape
the #1542 family accepts).

## 3. Suites (all executed this session, post-fix)

| Suite | Command | Result |
|-------|---------|--------|
| the #1592 merged suite (U-1592-1..7) | `dart test --preset=all test/plugins/tdd/commands/bug_1592_born_green_blocked_convergence_test.dart` | **7/7 pass** (U-1592-6/7 added by the review round — see §7) |
| pinned born-green family | `dart test --preset=all test/plugins/tdd/bug_1542_born_green_contract_refactor_test.dart test/plugins/tdd/commands/bug_1373_scaffolded_hand_off_driver_test.dart test/plugins/tdd/commands/bug_1411_born_green_hand_transition_test.dart` | **19/19 pass** (incl. U-1542-1's pinned window); merged suite + pinned family together: 26/26 |
| fast guard batch | `dart test test/plugins/tdd/bug_1324_resume_stale_artifacts_wedge_test.dart test/plugins/tdd/commands/bug_1544_run_continue_after_blocked_test.dart test/plugins/tdd/two_cycle_run_commands_test.dart test/plugins/tdd/unified_journal_commands_test.dart` | **all pass** (original session; the review round re-ran `bug_1324` under `--preset=all` — B1 fails identically on the pristine head, see §7) |
| chunked fast suite, blast radius | chunks `test/plugins/tdd/{commands,corpus_economics,models,scenarios,services/ci_referee,services/tier2_firestore,theater}` + `test/commands` via the per-chunk kernel-cache discipline of `tools/run_tests_chunked.sh` | **557 + 67 + 81 + (0 fast — slow-only chunk) + 35 + 33 + 15 + 392 = 1180 pass, 0 fail** |
| pre/post failure-set comparison | `make_command_test.dart` (real-pipeline suites) run against pre-fix and post-fix trees, failure lists diffed | **byte-identical 4 failures** (U-829g/h, A11/U17, A15 — environment-dependent real entity/compose pipelines), i.e. NO NEW failures |

## 4. Static checks (executed this session)

| Check | Command | Result |
|-------|---------|--------|
| analyze, changed files | `dart analyze lib/src/plugins/tdd/commands/run_driver_core.dart test/plugins/tdd/commands/bug_1592_born_green_blocked_convergence_test.dart` | No issues found! |
| analyze, tdd subtree | `dart analyze lib/src/plugins/tdd test/plugins/tdd` | No issues found! |
| format | `dart format` (changed files), then `dart format --output=none --set-exit-if-changed lib/ test/` | 0 changed, exit 0 |

## 5. Test-smell rubric

- No sleeps/waits; the fake-zfa harness is deterministic (the repo's own
  driver-test convention).
- Every test asserts the OUTCOME CONTRACT (`result=` token, step invocation
  list, run-state) — no implementation-detail mirrors.
- The regression tests (U-1592-2..5) pin the untouched windows byte-for-byte
  (including the #1324 prescription line), so the guard's blast radius is
  observable.

## 6. Remediation tasks

None — the gate passed. Follow-up suggestions live in `fix.md`
(→ Follow-ups).

## 7. Review round (#1608) — re-verification after the fixes

The PR's review round applied four findings: the subject binding behind the
#1592 guard (CodeRabbit — the certifying entry's `- subject-hash:` must
match the registered subject file's sha256, hashless or mismatched entries
refuse the short-cut), the `CycleEvidence.bornGreenCertifiedEntries()`
batch accessor with the per-behavior probe delegating to it (zuraffa-review
— the last-green + anchored-marker rule in one home), the documented
re-entry corrections (issue/assessment/fix), and the U-1592-6/7 regression
cases. `_evidenceMisfire`'s #1542 acceptance is deliberately unchanged (it
is the certification contract the pinned hashless fixtures pin; the guard
is the stricter re-entry gate).

| Check | Command | Result |
|-------|---------|--------|
| the #1592 suite | `dart test --preset=all test/plugins/tdd/commands/bug_1592_born_green_blocked_convergence_test.dart` | **7/7 pass** (U-1592-1 seeds the transition's real subject + `- subject-hash:` shape; U-1592-6/7 pin the absent/mismatched rejections) |
| pinned born-green family | `dart test --preset=all test/plugins/tdd/bug_1542_born_green_contract_refactor_test.dart test/plugins/tdd/commands/bug_1373_scaffolded_hand_off_driver_test.dart test/plugins/tdd/commands/bug_1411_born_green_hand_transition_test.dart` | **19/19 pass** |
| evidence services | `dart test --preset=all test/plugins/tdd/services/cycle_evidence_test.dart test/plugins/tdd/bug_1430_refresh_evidence_test.dart` | **pass** |
| analyze, changed files | `dart analyze lib/src/plugins/tdd/commands/run_driver_core.dart lib/src/plugins/tdd/services/cycle_evidence.dart test/plugins/tdd/commands/bug_1592_born_green_blocked_convergence_test.dart` | No issues found! |
| analyze, tdd subtree | `dart analyze lib/src/plugins/tdd test/plugins/tdd` | No issues found! |
| format | `dart format --output=none --set-exit-if-changed lib/ test/` | 0 changed, exit 0 |

Pre-existing failure (NOT from this change): with `--preset=all`,
`bug_1324_resume_stale_artifacts_wedge_test.dart`'s `B1` fails with the bug
#1470 corrupt-registry error — its fixture seeds a deliberately truncated
`artifacts.json` and the fail-loud reader refuses it. The failure is
byte-identical with the review fixes reverted
(`git checkout HEAD -- lib/src/plugins/tdd/commands/run_driver_core.dart
lib/src/plugins/tdd/services/cycle_evidence.dart`), so the review round
introduces no new failure; the contradiction between that fixture and the
#1470 fail-loud reader is a separate, pre-existing issue on the branch.
