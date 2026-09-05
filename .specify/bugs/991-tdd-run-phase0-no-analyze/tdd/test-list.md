---
feature: .specify/bugs/991-tdd-run-phase0-no-analyze (bug #991, pinned per bug extension TDD mode)
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 2
planned_at: 77e69f2
updated_at: 77e69f2
suite_baseline: green
---

# Test List: `zfa tdd run` phase-0 build must not fail on pre-existing analyze warnings

Bug fix for runbook bug #991. The phase-0 build (bug #829's once-per-run
generation build) spawned a bare `zfa build` and inherited the CLI's
default `--analyze` gate — a target repo's pre-existing analyzer findings
made every run die at phase 0 with `runner-error` before any behavior was
driven.

Test level: driver-level, same harness as the bug-829 group —
`RunCommand` in-process through `CliRunner.runCapturing` against a temp
project, with the scripted fake zfa binary as real subprocesses. The fake
keys non-driver invocations by their argv (`build-` for a bare
`zfa build`, `build---no-analyze` for `zfa build --no-analyze`), so the
analyze-gate failure and the genuine build failure are scripted
separately and deterministically.

| id      | behavior                                                                                                                                                                                             | traces        | kind  | state | test |
| ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- | ----- | ----- | ---- |
| U-991   | With pre-existing analyze warnings failing the bare `zfa build` gate, the run completes: the phase-0 build spawn carries `--no-analyze`, phase-0 reports `build -> ok`, and behaviors are driven      | issue-expect  | unit  | DONE  | `test/plugins/tdd/run_command_test.dart::U-991` |
| U-991b  | A genuine build failure on the `--no-analyze` invocation still stops the run honestly (`runner-error`, `stopped_at=phase-0:build`, no behavior driven) — the fix removes only the analyze gate       | issue-constraint | unit | DONE | `test/plugins/tdd/run_command_test.dart::U-991b` |
| U-829c* | The phase-0 spawn order is unchanged: entity create first, then exactly one `build --no-analyze`, before the first gen (argv assertion amended to the fixed argv)                                    | no-regression | unit  | DONE  | `test/plugins/tdd/run_command_test.dart::U-829c` |
| U-829d* | An existing entity is reused with no build spawn at all (argv assertion amended: no line starts with `build`)                                                                                        | no-regression | unit  | DONE  | `test/plugins/tdd/run_command_test.dart::U-829d` |
| U-829e  | A failed entity create still stops the run (unaffected control)                                                                                                                                      | no-regression | unit  | DONE  | `test/plugins/tdd/run_command_test.dart::U-829e` |
| U-829f* | A feature with no declared entities runs no phase-0 spawn (argv assertion amended)                                                                                                                   | no-regression | unit  | DONE  | `test/plugins/tdd/run_command_test.dart::U-829f` |

\* amended deliberately: the expected argv changed with the fix (bare
`build` → `build --no-analyze`); each amendment asserts a strictly
more-specific argv.
