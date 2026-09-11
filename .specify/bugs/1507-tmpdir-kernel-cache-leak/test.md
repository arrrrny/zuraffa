# Bug Verification: the kernel sweep is a start-of-cycle obligation

- **Slug**: 1507-tmpdir-kernel-cache-leak
- **Tested**: 2026-09-11
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: full red→green loop — see ./tdd/verification.md

## Summary

The reported leak is fixed at both layers. The sweep now matches
`dart_test.kernel.*` DIRECTORIES as well as files and deletes them recursively
(the leaked shape — a per-invocation directory of dill files — was dead code
under the pre-fix `entity is File` match), and it runs at the START of every
TDD cycle in BOTH `refactor_command.dart` and `run_command.dart` — not only on
the `ReproofFailureClass.infraRunner` retry path. The sweep logs what it
reclaimed (`cleared N stale kernel dir(s), freed X MB`). A liveness guard was
added on top of the preserved `commandStartedAt` guard so the sweep can never
delete a kernel directory a live dart test runner still holds.

## Checks Performed (all runs from this session, Dart SDK 3.13.3)

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| RED (pre-fix) | `dart test test/plugins/tdd/bug_1507_kernel_cache_cycle_start_test.dart` | fail 3/3 — RIGHT reasons | Stale kernel DIRECTORY survives a healthy green refactor cycle; `zfa tdd run` completes all 12 steps leaving stale entries untouched; no reclaim line. Full transcript: ./tdd/red-evidence.md |
| GREEN (post-fix) | same command | pass | 4/4 (C1+C2+C3 healthy-green sweep, C4 mtime guard, C2 run-command sweep, C5 liveness guard), exit 0, no loader crash at close. |
| Reclaim log shape | asserted in-test on real stdout | pass | `cleared N stale kernel dir(s), freed X MB` observed with real byte counts (e.g. `cleared 2 stale kernel dir(s), freed 1.0 MB` for seeded 2 MiB fixtures). |
| Regression — #1333 retry machinery | `dart test --preset=regression test/plugins/tdd/bug_1333_refactor_reproof_retry_test.dart` | pass | 4/4. B3 retry-clear contract intact (cycle-start sweep deletes the seeded markers earlier; retry still recovers, counter==3); B5 amended: on the regression path the markers are now gone by cycle start (issue #1507 housekeeping) while the no-retry contract (counter==2) is unchanged. |
| Regression — refactor command suite | `dart test --preset=all test/plugins/tdd/refactor_command_test.dart test/plugins/tdd/run_command_test.dart` | pass | 64/64. |
| Regression — run driver suites | `dart test --preset=all test/plugins/tdd/two_cycle_run_commands_test.dart test/plugins/tdd/unified_journal_commands_test.dart` | pass | 33/33. |
| Regression — fast-tier neighbors | `dart test test/plugins/tdd/run_command_path_format_test.dart test/plugins/tdd/bug_1311_refactor_receipt_refresh_test.dart test/plugins/tdd/bug_1327_cycle_log_terminal_receipt_test.dart` | pass | 5/5. |
| Chunked fast suite (full tree) | 97 chunks per `tools/run_tests_chunked.sh` semantics (`dart test <dir> --exclude-tags flutter`, kernel caches cleared between chunks) | pass | 92 chunks PASS, 5 SKIP (no fast-tier tests by design: test/benchmark, test/core/proof, test/integration, test/plugins/tdd/scenarios, test/tdd/077-make-engine-preset), 0 chunks failed. The `test/plugins/tdd/commands` chunk alone: 482 tests green. |
| Lint / type-check | `dart analyze` on the two changed commands + the two touched test files | pass | No issues found. |
| Formatting | `dart format .` then `dart format --set-exit-if-changed --output=none <touched files>` | pass | 0 diffs on all 4 touched files. `dart format .` also reflowed 2 files with PRE-EXISTING master drift (`example/test/tdd/004-login-ui/u1_test.dart`, `tool/generate_openwiki_cli_docs.dart`) — reverted untouched per the #942 precedent, so the PR carries zero unrelated churn. |
| Pre-existing failure A/B | `dart test --preset=all test/plugins/tdd/bug_922_refactor_preflight_baseline_test.dart` on the fix branch AND with the whole change set stashed | pre-existing | One test fails ("a green behavior behind a baseline-red suite reaches done and the run completes") **identically on master** (exit 1, +8 -1, same test name) — unrelated to this fix, flagged per protocol. |

## Success criteria: PROVED vs not

| Criterion (from the bug report) | Status |
| --- | --- |
| Cleanup matches directories (not just files) and deletes recursively | **PROVED** — C1: seeded `dart_test.kernel.bug1507-*` directory (3 × 512 KiB dill-shaped files) and file both deleted by a healthy green cycle |
| Cleanup called at the start of every TDD cycle, not only infra-retry | **PROVED** — C2 (refactor): healthy green cycle (counter==2, retry machinery never fired) still sweeps; C2 (run): `zfa tdd run` sweeps with no retry path at all |
| `$TMPDIR/dart_test.kernel.*` cleaned after every cycle | **PROVED** — C1/C2; per-cycle reclamation exercised by C5's second run after the holder exits |
| Must log what was reclaimed | **PROVED** — C3: `cleared N stale kernel dir(s), freed X MB` on real stdout |
| Must not break concurrent runners (`commandStartedAt` guard) | **PROVED** — C4: future-mtime entry survives; C5: argv-referenced live kernel survives; the #1333 suite (retry + concurrent-marker semantics) passes unchanged |
| Bounded, roughly flat temp-disk usage for a long TDD loop | **PROVED by construction + unit evidence** — every cycle start reclaims all kernels of dead invocations; entries the sweep leaves are exactly the live ones (C4/C5). A full 80-minute 51 GB reproduction was NOT run (would exhaust this agent's disk — the standing housekeeping obligation forbids it); the unit suite pins the mechanism. |
| Fix confined to kernel cache cleanup in the two named commands | **PROVED** — `git diff` touches `refactor_command.dart`, `run_command.dart`, the new test file, and the amended `bug_1333` assertions; no runner semantics/state machine/loop logic changed |

## Disk housekeeping record

`df -h .` before and after every phase stayed healthy (9.9G rootfs; 1.3–1.4G
used, 8.0–8.1G free, 13–15% throughout). Kernel caches were cleared between
chunk runs and post-test (`rm -rf .dart_tool/test/`, `rm -f
$TMPDIR/dart_test.kernel.*` / `/tmp/dart_test.kernel.*`); no fixtures or build
outputs were left behind (the TDD fixture disposes its temp root in
`tearDown`).
