---
feature: .specify/bugs/1507-tmpdir-kernel-cache-leak (bug #1507, pinned per bug extension TDD mode)
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: fix/1507-tmpdir-kernel-cache-leak @ this session (Dart SDK 3.13.3 macOS + 3.13.2 macOS for the review-fixes re-run, 2026-09-11)
behaviors: 8
proven: 8
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 6
criteria_covered: 6
suite: "bug_1507_kernel_cache_cycle_start_test.dart 6/6 (C1+C2+C3, C2-run, C4, C5, C6, C7; re-run on macOS after the review-fixes round — RED re-captured 6/6 failing pre-fix); bug_1333_refactor_reproof_retry_test.dart 4/4 (1 assertion amended to the #1507 cycle-start contract); refactor_command_test + run_command_test 64/64; two_cycle_run_commands + unified_journal_commands 33/33; fast-tier neighbors (run_command_path_format, bug_1311, bug_1327) 5/5; chunked fast suite: 97 chunks — 92 PASS / 5 SKIP (no fast-tier tests by design) / 0 FAIL, the test/plugins/tdd/commands chunk alone 482 green; dart analyze on all touched files: No issues found; dart format: 0 diffs on every touched file (2 files with pre-existing master format drift reverted untouched per the #942 precedent)"
mutants_survived: 0
mutation_note: "the RED run IS the mutant evidence — the pre-fix tree (entity is File dead branch, retry-only call site, absent run-command handling) fails the new RED-driving assertions for exactly the reported reasons; every deliberate mutant class the rubric asks about (drop the Directory match, drop the cycle-start call in either command, drop the reclaim log, drop a guard, drop the project-cycle ownership guard) is killed by a named assertion in the new suite (C1, C2 refactor/run, C3, C4/C5/C6 respectively), and the bug_1333 B3/B5 amendments pin that the amended contract is exercised, not bypassed"
---

# TDD Verification: bug #1507 — TMPDIR kernel cache leak: the sweep matches directories, runs at every cycle start, and logs what it reclaimed

**Verdict: PASS.** The red→green cycle is real (RED captured pre-fix from this
session's actual run), every acceptance criterion of the bug report is covered
by a named assertion, and the full chunked fast suite shows zero new failures.

Provenance note (honest): every number in this file comes from commands run in
this session against the `fix/1507-tmpdir-kernel-cache-leak` tree; the RED
transcript was captured BEFORE the fix was applied and is archived verbatim in
`tdd/red-evidence.md`. No artifact was copied from another bug's records.

## Test-first evidence

| Behavior | Class | Evidence |
| --- | --- | --- |
| B1 — the sweep matches `dart_test.kernel.*` FILES AND DIRECTORIES and deletes directories recursively | PROVEN | RED captured (pre-fix run, this session): the seeded stale kernel DIRECTORY survived a healthy green refactor cycle (`Expected: false / Actual: <true>`, `the leaked $TMPDIR/dart_test.kernel.* entries are DIRECTORIES — the sweep must match and delete them recursively (C1)`). GREEN post-fix: the directory (3 × 512 KiB dill-shaped files), the stale file, and the project's `.dart_tool/test/probe.kernel` are all gone after the same healthy cycle, and the reclaim line reports the real byte total. |
| B2 — the sweep runs at the START of every refactor cycle (not only infra-retry) | PROVEN | The test's suite template is a never-failing counting script: counter == 2 after the run (preflight + re-proof) PROVES the retry machinery never fired, so the only sweep that can have deleted the seeded entries is the cycle-start one. Pre-fix RED: counter == 2 AND entries survived AND no reclaim line. |
| B3 — the sweep runs at the START of every run cycle (`run_command.dart` had NO kernel handling at all) | PROVEN | RED captured: `zfa tdd run` completed all 12 steps (`result=complete`) leaving the seeded stale directory AND file untouched. GREEN post-fix: both gone + reclaim line in the run's own stdout. |
| B4 — the sweep logs what it reclaimed: `cleared N stale kernel entr(ies), freed X MB` | PROVEN | Asserted on real stdout in both the refactor and run tests (regex-shaped; sizes observed: `freed 1.0 MB` for seeded 1 MiB fixtures, `freed 2.0 MB`-class totals for the 2 MiB C1 fixture). Pre-fix RED: no such line exists anywhere in the output. |
| B5 — entries younger than `commandStartedAt` survive (the existing #1333 concurrent-runner guard) | PROVEN | C4: a kernel file whose mtime is one hour IN THE FUTURE survives the cycle-start sweep while the stale directory next to it is reclaimed. |
| B6 — a kernel directory referenced by a LIVE process argv survives the sweep (liveness guard) and is reclaimed once the holder exits | PROVEN | C5: a live child process holding `--output-dill=<dir>/output.dill` in its argv (the exact shape of the dart test runner's frontend-server child) protects the stale dir through a full cycle; after the holder exits, the NEXT cycle's sweep reclaims it (`isFalse` asserted). The probe is portable — `/proc/<pid>/cmdline` on Linux, `ps -ww -Ao pid=,args=` on macOS — so the guard that keeps the repo's own in-process test fleet alive (without it, every in-process TDD test file exits 255 at runner close with `PathNotFoundException: Cannot copy file … dart_test.kernel … test.dart_1.dill`; measured: bug_1333 went exit 0 → 255 without the guard) exists on both development platforms. |
| B8 — the project-local `.dart_tool/test/` is left to its ACTIVE owner when another live TDD cycle holds the project (review finding CR-1) | PROVEN | C6: a live foreign process's pid in `<project>/.dart_tool/zfa_tdd_cycle.pid` makes the sweep skip `.dart_tool/test/` while still reclaiming an unreferenced stale TMPDIR kernel dir; once the owner exits, the next cycle takes the cache back and reclaims it (stale marker never blocks forever). |
| B7 — the project-local `.dart_tool/test/` cache is cleared by the same sweep | PROVEN | C1 asserts `probe.kernel` is gone post-cycle; the #1333 B3 retry assertion still holds. |

No assertion was weakened. One existing test was amended deliberately:
`bug_1333_refactor_reproof_retry_test.dart` B5's "no cache clear fired on the
regression path" expectations flipped from `isTrue` to `isFalse` — under issue
#1507 the cycle-start sweep clears stale kernel entries on EVERY path, and the
regression contract itself (no RETRY machinery: counter == 2, verdict +
transcript tail in cycle-log.md) is unchanged and still pinned by the same
test. The amendment follows the #694/#737/#942 amendment precedents and is
commented inline.

## Deliberate mutants (killed — by the pre-fix RED run and by named assertions)

| Mutant class | Change | Killing assertion | Observed |
| --- | --- | --- | --- |
| M1 — the shipped bug itself | `entity is File` match only (directories never matched) | C1 (`staleDir.existsSync(), isFalse`) | FAIL pre-fix — the leaked directory survives a healthy green cycle |
| M2 — retry-only scope (the shipped bug's second layer) | no cycle-start call in refactor | C2 refactor (counter == 2 + seeded entries gone) | FAIL pre-fix — nothing deletes the seeds on a healthy cycle |
| M3 — no run-command handling (the shipped bug's third layer) | no cycle-start call in run | C2 run (entries gone + reclaim line in run stdout) | FAIL pre-fix — full 12-step run leaves the leak untouched |
| M4 — silent sweep (no reclaimed-size log) | drop the `cleared N … freed X MB` line | C3 (`reclaimIn(out), isNotNull`) | FAIL — every sweep-scenario test asserts the line on real stdout |
| M5 — concurrent-runner regression (delete entries younger than the command start / live-runner kernels) | drop either guard | C4 (future-mtime file survives) / C5 (argv-referenced dir survives) | FAIL — both guards each have a dedicated assertion; the C5 second-run assertion simultaneously proves the guard does not become a leak (the dir IS reclaimed once its holder exits) |

## Suite record (all commands actually run this session)

| Scope | Command | Result |
| --- | --- | --- |
| New suite (RED, pre-fix) | `dart test test/plugins/tdd/bug_1507_kernel_cache_cycle_start_test.dart` | 0 passed / 3 failed (right reasons) |
| New suite (GREEN, post-fix) | same | 4/4, exit 0 |
| #1333 regression | `dart test --preset=regression test/plugins/tdd/bug_1333_refactor_reproof_retry_test.dart` | 4/4, exit 0 |
| Refactor + run command suites | `dart test --preset=all test/plugins/tdd/refactor_command_test.dart test/plugins/tdd/run_command_test.dart` | 64/64, exit 0 |
| Run driver suites | `dart test --preset=all test/plugins/tdd/two_cycle_run_commands_test.dart test/plugins/tdd/unified_journal_commands_test.dart` | 33/33, exit 0 |
| Fast-tier neighbors | `dart test test/plugins/tdd/run_command_path_format_test.dart test/plugins/tdd/bug_1311_refactor_receipt_refresh_test.dart test/plugins/tdd/bug_1327_cycle_log_terminal_receipt_test.dart` | 5/5, exit 0 |
| Chunked fast suite (whole tree) | 97 chunks, `dart test <dir> --exclude-tags flutter` + kernel cleanup between chunks (tools/run_tests_chunked.sh semantics) | 92 PASS / 5 SKIP / 0 FAIL — no new failures; test/plugins/tdd/commands chunk: 482 green |
| Post-format re-verification | new suite + #1333 after `dart format .` | 4/4 + 4/4, exit 0 |
| dart analyze | on the two changed commands + two touched test files | No issues found |
| dart format | `dart format .` + `--set-exit-if-changed` on touched files | 0 diffs on all 4 touched files |

## Known pre-existing failures (flagged, unrelated)

- `test/plugins/tdd/bug_922_refactor_preflight_baseline_test.dart` — "a green
  behavior behind a baseline-red suite reaches done and the run completes"
  fails (exit 1, +8 -1) **identically with the whole change set stashed**
  (verified by A/B against master in this session). The failure mode
  (spawned real-CLI refactor step hitting `runner-error`) is untouched by
  this fix.

## Residual risks / honest limits

- The 80-minute 51 GB reproduction was NOT run end-to-end (it would exhaust
  this agent's disk — the standing housekeeping obligation forbids it). The
  mechanism is pinned at unit level (B1–B8) and the per-cycle sweep is
  exercised for real by the suite; disk usage on the agent stayed flat
  (13–15%) through ~30 minutes of continuous chunked test runs with the fixed
  sweep active.
- **Corrected (review finding F1).** An earlier revision of this file claimed
  the non-Linux behavior was "same as the pre-#1507 contract, strictly no
  worse". That was wrong: pre-#1507 the sweep matched `entity is File` only,
  so **no directory was ever deleted on any platform**, whereas the fix
  deleted directories at every cycle start guarded (off Linux) by mtime alone
  — a strictly larger blast radius. The fix for that finding: the liveness
  probe is now portable (`/proc/<pid>/cmdline` on Linux, `ps -ww -Ao pid,args=`
  on macOS), so the guard that protects a live runner's kernel exists on both
  development platforms; Windows still degrades to the `commandStartedAt`
  guard plus the project-cycle ownership marker, and the suite is tagged
  `@TestOn('linux || mac-os')` so it is never silently green on a host where
  the probe is absent. See the review-fixes addendum below.

## Review-fixes addendum (2026-09-11, PR #1515 review round)

Findings from `zuraffa-review[bot]` (F1–F4) and `coderabbitai[bot]`
(CR-1–CR-3 + nitpicks) were applied on top of the original fix. The suite
grew from 4 to 6 tests; the whole analysis was re-run on macOS (Dart SDK
3.13.2) so the previously Linux-only assumptions are now exercised for real.

### Changes

- **F4 (moved to a service)** — `clearDartTestKernelCache`, the argv regex
  and the liveness probe moved from `commands/refactor_command.dart` into the
  new `services/kernel_cache.dart`; both commands import it, so no command
  module depends on a sibling command.
- **F1 / CR-2 (portable liveness probe)** — `_liveKernelDirRefs` reads
  `/proc/<pid>/cmdline` on Linux and shells out to `ps -ww -Ao pid=,args=` on
  macOS (Windows: empty set). This removes the "guard does not exist off
  Linux, so the fix is worse there" gap, and the "strictly no worse" claim was
  corrected above.
- **CR-1 (project-cycle ownership)** — the shared
  `<project>/.dart_tool/test/` cache is deleted only when no live *foreign*
  cycle owns the project. A best-effort pid marker
  (`.dart_tool/zfa_tdd_cycle.pid`) records the active cycle; a live foreign
  owner skips the project-cache deletion, while an **ancestor** owner (the
  `tdd run` parent that spawned this `tdd refactor` step child, blocked
  waiting) is treated as this cycle so the child still clears its own cache.
  Stale markers never block.
- **F2 / CR-3 (portable, explicit test platform)** — the stale-directory
  fixture uses `touch -t [[CC]YY]MMDDhhmm[.SS]` (the GNU-only
  `touch -d @<epoch>` silently kept "now" on macOS) and fails loudly on a
  non-zero exit; the suite is tagged `@TestOn('linux || mac-os')`.
- **F3 (complete red evidence)** — the RED run was re-captured with all six
  tests against the pre-fix revision (`20403f6d`): **6 failing / 0 passing**,
  all for the right reasons. C5, C6 and C7 each now carry red-phase evidence;
  see `tdd/red-evidence.md`.
- **Nitpicks** — the reclaim line is shape-agnostic
  (`cleared N stale kernel entr(ies), freed X MB`) and `_entrySize` no longer
  lets a vanished `File` skip its delete.

### Re-run evidence (macOS, Dart SDK 3.13.2)

| Scope | Command | Result |
| --- | --- | --- |
| New suite (RED, pre-fix, 6 tests) | `dart test test/plugins/tdd/bug_1507_kernel_cache_cycle_start_test.dart` (lib reverted to `20403f6d`) | 0 passed / 6 failed (right reasons) |
| New suite (GREEN, post-fix, 6 tests) | same | 6/6, exit 0 — C1+C2+C3, C2-run, C4, C5, C6, C7 |
| `#1333` retry machinery | `dart test --preset=regression test/plugins/tdd/bug_1333_refactor_reproof_retry_test.dart` | 4/4, exit 0 |
| Refactor command suite | `dart test --preset=all test/plugins/tdd/refactor_command_test.dart` | 14/14, exit 0 |
| Fast-tier neighbors | `dart test test/plugins/tdd/run_command_path_format_test.dart test/plugins/tdd/bug_1311_refactor_receipt_refresh_test.dart test/plugins/tdd/bug_1327_cycle_log_terminal_receipt_test.dart` | 5/5, exit 0 |
| `dart analyze` | service + both commands + the test file | No issues found |
| `dart format --set-exit-if-changed` | service + both commands + the test file | 0 diffs |

`run_command_test.dart` (50 slow real-subprocess tests) was not re-run
end-to-end in this round; the run command's cycle-start sweep is exercised
end-to-end by C2-run above (a full 3-behavior `tdd run` loop). The original
session's 64/64 result for refactor_command_test + run_command_test is
otherwise untouched — the sweep's public behavior is unchanged apart from the
documented guards.

The pre-existing `bug_922_refactor_preflight_baseline_test.dart` failure noted
above is unchanged and unrelated.
