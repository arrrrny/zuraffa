# Verification — Spec 1324 resume stale-artifacts wedge

Test-first evidence, per tdd/test-list.md. Every number below is an
ACTUAL run result on this branch
(`feat/1324-resume-re-drives-green-behaviors-wedge`), Dart SDK 3.13.3
(stable). Runs are single-file / single-batch only (cloud-agent disk
ceiling), each with pre/post kernel-cache cleanup
(`rm -rf .dart_tool/test/; rm -f $TMPDIR/dart_test.kernel.*`).

## Test-first protocol

The behaviors were written and run against the PRE-FIX tree first.
RED was an assertion red (the wedge and the healthy verdict survive),
exactly as the test-list predicted:

| Run | Command | Result |
|-----|---------|--------|
| RED | `dart test --preset=all test/plugins/tdd/bug_1324_resume_stale_artifacts_wedge_test.dart` | `+5 -4` — B1, B2, B3, B4 RED; B5a, B5b, B5c, B6, B7 green (guards over pre-fix behavior) |

RED highlights (the issue's exact dead-ends, reproduced):

- B1: the resume re-drove A1 from gen over the certified pair and
  wedged —
  `run: feature=1324-resume-skip result=stopped pending=1 red=0
  green=1 done=0 stopped_at=A1:make` with the generic
  `resume: fix the failing step, then re-run` hint.
- B4: `zfa tdd doctor` on the stale-artifacts state printed
  `{"command":"doctor","verdict":"healthy","prescription":"none",...}`
  — doctor's healthy verdict for exactly the wedged state, verbatim the
  issue's complaint.

## Green evidence

| Run | Command | Result |
|-----|---------|--------|
| GREEN | `dart test --preset=all test/plugins/tdd/bug_1324_resume_stale_artifacts_wedge_test.dart` | `+9` — all 9 tests pass (B1..B7, B5 split a/b/c) |
| ANALYZE | `dart analyze` on the changed files + the new test | No issues found |
| FORMAT | `dart format` over the changed/new files | 0 changed (format-clean) |

Regression coverage over the touched surfaces (driver resume windows,
stop arms, doctor priority order) — all `--preset=all`:

| Batch | Suites | Result |
|-------|--------|--------|
| 1 | run_command_test, two_cycle_run_commands_test, run_command_path_format_test | `+76` all passed |
| 2 | issue_1308 driver, issue_1323 driver, bug_1331 make-adopted, bug_1264 phantom-done | `+18` all passed |
| 3 | bug_840 recovery, bug_874 doctor cross-feature, bug_828 evidence integrity, bug_911 version skew, bug_969 verdict envelope | `+51 -13` — the failing set is BYTE-IDENTICAL to a clean-master baseline run of the same batch (pre-existing, environment-dependent suites that spawn real `dart` children; zero regressions from this change) |

## The interrupted-run resume demonstration (issue #1324's acceptance)

B1 reproduces the wedge state end-to-end and proves the resume path:

1. Feature state = the post-interruption wedge: A1 green-but-not-done
   (red+green evidence in cycle-log, certified test on disk, run-state
   `green`), U6 fresh-pending (the #1323 dead-end class),
   `tdd/artifacts.json` CORRUPT (the kill-mid-write shape — gen's
   non-atomic append truncated).
2. One `zfa tdd run` RESUMES to `result=complete`:
   - the step log contains NO `gen A1` and NO `make A1` — the certified
     pair is never clobbered; A1 completes its ladder at refactor
     (phase 2);
   - U6 gets its full normal cycle (gen → verify-red → make →
     refactor);
   - the scripted contradiction (verify-red `unexpected-green`, make
     `subject-drift`) is never reached because the re-drive never
     happens.
3. B2/B3 prove the residual contradiction class is NAMED when it does
   surface: `result=stale-artifacts`, `stopped_at=A1:make`, the
   `--> fix: zfa tdd reset <feature>` prescription with the why, the
   generic hint gone, and the #1329 diagnostic discipline intact
   (cycle-log `- kind: error` / `- outcome: subject-drift`).
4. B4 proves the doctor's verdict for the contradiction:
   `verdict=stale-artifacts`, `prescription=reset`, the same fix line,
   exit 1 — never healthy. B5a/b/c pin the fail-open guards and the
   evidence-without-artifact priority. B6/B7 pin backward
   compatibility (truly-red behaviors still re-enter at gen; the
   summary line shape is unchanged).
