---
bug: 986
slug: 986-tdd-run-make-skipped-misclass
verdict: PASS
verified_at: fix/986-tdd-run-make-skipped-misclass (pre-PR)
suite: tdd plugin fast tier 1091 passed / chunked fast suite 75/75 chunks green / dart analyze baseline-identical
---

# TDD Verification: #986 tdd run treats make=skipped as terminal success

## Root cause

The run driver's make-outcome handling lost its already-green mapping when
issue #694 renamed the outcome. Under the #657-era contract the already-green
report was `drift` and exited NON-ZERO; bug #693's remediation taught the
driver to map `drift -> green` (record the green evidence the drift path never
wrote, advance the behavior GREEN, let refactor proceed). Issue #694 then
renamed the outcome to the skip transition `skipped` with exit 0 + green
evidence, and StepRunner's make success set gained `skipped` — but the
driver's own mapping was dropped with the old token. A `skipped` token that
reaches the driver through the failure branch (exit code disagreeing with the
token — binary skew, or the #657/#694-era non-zero contract) has no
driver-side terminal-success mapping and falls through to the honest stop:
the run halts on an already-green behavior, which the reporter observed as
the generation-error family (`result=stopped ... stopped_at=A2:make`). That
is the exact mapping-table gap #693 closed for `drift`, re-opened for
`skipped` by the rename.

## Remediation

Driver-layer only (make's #694 skip-transition semantics are untouched): in
`_driveBehavior`'s failure branch, `make` + `outcome=skipped` is recognized
as a TERMINAL success regardless of the exit code — make's outcome token is
the step's own terminal classification of an already-green target. The
driver records the green evidence when make's write did not land (idempotent
— never a duplicate — and provenance-labeled `bug #986`, the #693
driver-recorded pattern), advances the behavior to GREEN via
`_targetStateFor('make')`, prints `[run] <id> make -> green (skipped)`, and
continues the step window so refactor proceeds as usual (pre-spawn deferral
and the phase-2 pass handle a not-yet-green suite as before). When the exit
code disagrees with the token, the run says so explicitly:

```
   exit code 1 disagrees with outcome=skipped — the token is the terminal
   skip transition (issue #694); advancing (bug #986).
```

## RED evidence (pre-fix, real driver tests)

`test/plugins/tdd/run_command_test.dart` (fake scripted zfa, the spec 049
harness); the fake's literal `skipped` token prints
`make: behavior=B-001 outcome=skipped feature=...` and exits 1 — the
disagreeing-exit shape:

```
00:00 +0 -1: bug #986: make reporting skipped is a terminal success even when its
  exit code disagrees — the run advances instead of stopping [E]
  Expected: <0>
    Actual: <1>
  [run] B-001 make -> skipped
  zfa tdd run: step failed — behavior=B-001 step=make outcome=skipped
     make: behavior=B-001 outcome=skipped feature=090-run-driver
  run: feature=090-run-driver result=stopped pending=2 red=1 green=0 done=0 stopped_at=B-001:make
00:10 +0 -2: bug #986: an existing green evidence entry is not duplicated when make reports skipped [E]
  Expected: <0>
    Actual: <1>
  run: feature=090-run-driver result=stopped pending=2 red=0 green=1 done=0 stopped_at=B-001:make
```

The pre-fix driver hard-stopped the whole feature at `B-001:make` with the
already-green behavior RED — the bug, reproduced deterministically. (The
exit-0 skip path was already proven advancing on this tree — a real-binary
end-to-end probe with pre-existing-green acceptance behaviors printed
`[run] A1 make -> skipped` / `[run] A2 make -> skipped` and advanced both —
so the fall-through that remained was the failure branch, which the two new
tests pin.)

## GREEN evidence (post-fix, same tests)

```
00:05 +1: bug #986: an existing green evidence entry is not duplicated when make reports skipped
00:11 +2: All tests passed!
```

The first test asserts the full post-fix contract: no step-failure line, the
`[run] B-001 make -> skipped` outcome line followed by
`[run] B-001 make -> green (skipped)`, refactor spawned for B-001, B-002 and
B-003 still driven, B-001 DONE, the driver-recorded provenance-labeled green
evidence present in `tdd/cycle-log.md` (`bug #986`), and
`result=complete pending=0 red=0 green=0 done=3` with exit 0. The second
asserts evidence idempotence: an existing green entry is not duplicated.

## Suite

| Suite | Result |
| ----- | ------ |
| `dart analyze` | 345 issues found — byte-identical to the unmodified-parent baseline (verified by stash/compare); ZERO issues in the changed files (`run_command.dart`, `run_command_test.dart`). The 345 are pre-existing `examples/`-tree errors (Flutter-dependent generated files absent in a pure-Dart checkout) and infos. |
| `dart test --preset=all test/plugins/tdd/run_command_test.dart` | 41/42 — the only failure is `bug #691: verify-red reporting unexpected-green ...`, which fails IDENTICALLY on the unmodified parent (39/42 there; the +2 are the new #986 tests). That test expects the legacy `verify-red -> unexpected-green` progress line the driver no longer prints (it prints `-> skipped (already green)`); it is a pre-existing stale expectation, not a regression. |
| `dart test test/plugins/tdd/` (fast tier, whole plugin) | 1091/1091 passed |
| `dart test --preset=all test/plugins/tdd/services/step_runner_test.dart` | 17/17 passed (incl. U14 — the exit-0 `skipped` success contract) |
| `--preset=all` driver scenarios sc_013–sc_016 | 16/16 passed |
| `--preset=all` make scenarios sc_006, sc_008, sc_009 | passed (incl. A6 — the real make #694 skip transition: exit 0, `outcome=skipped`, green evidence, no generation) |
| `tools/run_tests_chunked.sh` (fast suite, chunked) | 75/75 chunks green, 0 failures. The single script run was cut off by the sandbox's 10-minute foreground ceiling after 62 green chunks (it was mid-flight in chunk 63, `test/secure_storage`, which re-ran green: 11/11); the remaining 12 chunks ran through the script's IDENTICAL loop body (same `dart test <chunk> --exclude-tags flutter < /dev/null` + kernel-cache cleanup between chunks) and finished `OK: remaining chunks passed.` |
| `dart format .` | clean — re-running it after the run changes nothing; `git diff --stat` shows only the two intended files (`run_command.dart` +49, `run_command_test.dart` +73, zero deletions) |

## Scope disclosure

- The reporter's exact child-side transcript (why the spawned make reported
  `generation-error` instead of `skipped` in their environment — the drift
  check observed non-green in that spawn while the direct re-run observed
  green) is not reproducible from this repository; no forklift checkout
  exists here. What IS proven: on this tree the driver halted on a
  `skipped` token reaching the failure branch (RED evidence above), and the
  demanded contract — `skipped` is a terminal make success, the run
  advances to refactor/next behavior — now holds on every driver path
  (StepRunner exit-0 success, phase-1/phase-2 deferral flow, and the new
  failure-branch mapping).
- Make's skip-transition semantics (#694) are untouched: `make_command.dart`
  and `step_runner.dart` are byte-identical to the parent; the fix lives
  entirely in the run driver's outcome handling.
- `sc_012` (2 failures) and the `bug #691` driver test fail IDENTICALLY on
  the unmodified parent (sandbox `zfa build` pass limitations and a stale
  legacy-expectation line respectively) — pre-existing, not regressions.
- sc_022's FFI golden lane needs a native toolchain this sandbox lacks and
  was not run (fast-tier-only coverage applies to it, as to the #693
  verification).
- The mutation-verify audit was not run — bug-fix verification, not a
  feature audit.
