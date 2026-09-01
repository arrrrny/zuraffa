# Cycle Log: tdd-run-clean-state-skips-gen (bug 720)

Append-only. One entry per cycle. All evidence below is from real runs in the
session that produced the branch `fix/720-tdd-run-clean-state-skips-gen`.

## Baseline

- Date: 2026-09-01 — HEAD: `d6f7f517` — suite baseline: green (fast tier)
- `tools/run_tests_chunked.sh` at `d6f7f517` working state → exit 0, all
  chunks passed (2,527 passing in total across 61 folder chunks).
- `dart test --preset=all test/plugins/tdd/run_command_test.dart` at
  `d6f7f517` → `00:02 +25 -1` — the one failure is
  `bug #691: verify-red reporting unexpected-green ...` and reproduces
  identically on unmodified master (B-001's red+green cycle-log evidence is
  promoted to DONE by the #682 bootstrap, so the #691 scenario is
  unreachable through that seeding). Pre-existing, unrelated to #720,
  reported to the PR — not fixed here (hard constraint: sequencing only).
- The issue's clean-state signature reproduces deterministically at
  `d6f7f517` with the real compiled binary: `[run] A1 make -> runner-error`,
  `result=runner-error ... stopped_at=A1:make`, exit 2 (full transcript in
  `../red-evidence.md`).

## Cycle 1 — U1: clean state with residual red evidence re-enters at gen

- RED (fix stashed from the working tree via `git stash push`, base
  `d6f7f517`):
  - Command: `dart test --preset=all test/plugins/tdd/run_command_test.dart --plain-name 'bug 720: a clean state'`
  - Output:
    ```
    Expected: ['gen B-001', 'verify-red B-001', 'make B-001', ...]
      Actual: ['make B-001', ...]
     Which: at location [0] is 'make B-001' instead of 'gen B-001'
    00:00 +0 -1: Some tests failed.
    ```
  - The actual sequence is the bug: `make` first, gen/verify-red skipped —
    exactly the issue's `[run] A1 make -> runner-error` signature at the
    step-spawn level (the fixture's fake zfa answers make `ok`, so the
    driver-level observable is the invocation order).
- GREEN (fix restored):
  - Command: `dart test --preset=all test/plugins/tdd/run_command_test.dart --plain-name 'bug 720: a clean state'`
  - Output: `00:00 +1: All tests passed!`
- Refactor: none required.

## Cycle 2 — U2: green and red claims without gen artifacts re-enter at gen

- RED (same stashed run as cycle 1):
  - Command: `dart test --preset=all test/plugins/tdd/run_command_test.dart --plain-name 'bug 720: green and red'`
  - Output:
    ```
    Actual: ['gen B-001', 'verify-red B-001', 'make B-001', 'gen B-002', ...]
      Which: at location [1] is 'make B-002' instead of 'gen B-002'
    00:00 +0 -1: Some tests failed.
    ```
- GREEN (fix restored):
  - Command: `dart test --preset=all test/plugins/tdd/run_command_test.dart --plain-name 'bug 720: green and red'`
  - Output: `00:00 +1: All tests passed!`
- Refactor: none required.

## Cycle 3 — U3: red claim WITH gen artifacts still re-enters at make

- RED (same stashed run as cycle 1):
  - Command: `dart test --preset=all test/plugins/tdd/run_command_test.dart --plain-name 'bug 720: a red claim'`
  - Output:
    ```
    Actual: ['make B-001', 'make B-002', 'refactor B-002', ...]
      Which: at location [1] is 'make B-002' instead of 'refactor B-001'
    00:00 +0 -1: Some tests failed.
    ```
    (B-001's make-first was correct under the old contract; B-002 — red
    claim, no artifacts — wrongly followed at make. Post-fix B-002 enters at
    gen while B-001 keeps the make re-entry.)
- GREEN (fix restored):
  - Command: `dart test --preset=all test/plugins/tdd/run_command_test.dart --plain-name 'bug 720: a red claim'`
  - Output: `00:00 +1: All tests passed!`
- Refactor: none required.

## Cycle 4 — A1: real binary, end to end (the issue's own reproduction)

- RED (binary compiled from `d6f7f517` + stashed-tree base):
  - Command: `zfa tdd run 990-bug720-repro --project . --zfa-bin zfa`
    (scratch project: gen + verify-red executed with the real binary, then
    run-state.json / artifacts.json / test files wiped, cycle-log red
    evidence retained — the issue's clean state)
  - Output:
    ```
    [run] A1 make -> runner-error
    zfa tdd run: step failed — behavior=A1 step=make outcome=runner-error
       zfa tdd make: behavior "A1" is planned in the 990-bug720-repro test list but has no gen artifacts. Run `zfa tdd gen A1` first.
    run: feature=990-bug720-repro result=runner-error pending=0 red=1 green=0 done=0 stopped_at=A1:make
    EXIT=2
    ```
- GREEN (binary recompiled with the fix):
  - Command: same
  - Output:
    ```
    [run] A1 gen -> ok
    [run] A1 verify-red -> certified
    [run] A1 make -> green
    [run] A1 refactor -> clean
    run: feature=990-bug720-repro result=complete pending=0 red=0 green=0 done=1
    EXIT=0
    ```
- Refactor: none required.

## Existing tests re-anchored (assertions unchanged)

The pre-#720 contract was encoded artifact-blind in seven existing driver
tests (a red/green claim re-entered at make/refactor with NO gen artifacts
registered). They were re-anchored by registering gen artifacts via the
fixture's `registerBehavior` — every expected invocation sequence,
exit-code, and state assertion is byte-identical:

- `run_command_test.dart` U21 (part 1), U22, bug-682 bootstrap, bug-682
  green-only misfire
- `sc_014_run_resumes_test.dart` A4, bug-625 resume
- `sc_015_run_stops_on_failure_test.dart` A9

Post-change results: `run_command_test.dart` + `run_command_path_format_test.dart`
→ `00:02 +33 -1` (the -1 is the pre-existing #691); sc_014/sc_015/sc_016 →
`00:01 +12: All tests passed!`.

## Test strength sampling (deliberate mutants, post-green)

No mutation tool is wired for this repo (tdd-profile), so deliberate mutants
were sampled on the changed sequencing logic. Each mutant was restored
exactly and the suite re-run to its baseline state before the next step.

| Mutant | Expected guard | Result |
| ------ | -------------- | ------ |
| Remove the gen-artifact guard (`else if (!hasGenArtifacts) start = 0;`) — the whole fix stashed | U1 (and the issue signature) | CAUGHT — `at location [0] is 'make B-001' instead of 'gen B-001'` |
| Invert the artifact condition (`else if (hasGenArtifacts) start = 0;`) | U3 (artifacts-exist resume path), U22, #682 | CAUGHT — `at location [0] is 'gen B-001' instead of 'make B-001'` (U3 fails; behaviors WITH artifacts would be pointlessly re-driven from gen) |
| Drop the in-flight marker precedence (remove the `if (inFlightStep ...)` block) | U23 (crashed-run re-execution), A5 | CAUGHT — U23 `Which: is different.` (the crashed marker would no longer re-enter at its step) |

Post-restore suite state: `00:02 +33 -1` on the driver files (baseline
state; the -1 is the pre-existing #691), mutants verified out of the tree
(`git diff` shows only the intended fix).
