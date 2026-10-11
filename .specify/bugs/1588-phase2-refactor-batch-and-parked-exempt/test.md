# Test — BUG 1588

## TDD cycle (red → green → refactor-n/a → verify)

- **RED**: `test/plugins/tdd/commands/bug_1588_phase2_refactor_batch_and_parked_exempt_test.dart`
  run against the un-patched tree: **1 passed / 8 failed** — the 8 failures
  are exactly the new-contract assertions (unknown `--exempt-behaviors` /
  `--pass-batch` options; missing `--pass-batch` in the phase-2b spawn
  argv). The 1 passing test is the contract guard ("without the flag the
  refusal stands"), which is expected to be green before and after.
- **GREEN**: same file against the patched tree: **9 passed / 0 failed**
  (twice — before and after `dart format`).

## Test file

`test/plugins/tdd/commands/bug_1588_phase2_refactor_batch_and_parked_exempt_test.dart`
(`@Tags(['slow'])` — command-level tests spawn real `dart test` subprocesses
in fixture projects; driver-level tests are fast-tier fake-zfa runs).

Command level — parked-behavior exemption (`--exempt-behaviors`):

1. a parked behavior's red test does not poison the gate — the refactor
   proceeds (exit 0), the exclusion is named (`1588`, `C1`), zero files
   modified;
2. without the flag the refusal stands (`outcome=not-green`) — the
   absolute-green contract is preserved;
3. the exemption never masks a NON-exempt failure (second red test outside
   the exempt set still refuses, failure named);
4. an exempt id with no registered artifact is ignored (fail-open) and does
   not weaken the gate.

Command level — pass-batch ledger (`--pass-batch`, suite-spawn counting via
a logging suite wrapper):

5. the second `--pass-batch` invocation of an unchanged tree inherits the
   gate — zero suite runs (preflight + re-proof both skipped), exit 0,
   ledger file exists, hit named in output;
6. tree drift invalidates the ledger — the next invocation re-runs the
   full pipeline (suite spawn count grows);
7. a flag-less invocation never reads the ledger — preflight + re-proof
   run again (standalone contract).

Driver level — phase-2b refactor spawn argv (fake zfa, fast tier):

8. with a parked BLOCKED contract in the lane (#1544 receipt seeding), the
   phase-2b refactor spawn carries `--pass-batch` and
   `--exempt-behaviors contract:C1`; the green behavior reaches done while
   the parked contract stays blocked (exit 1, `result=blocked`);
9. with no parked behaviors, both per-behavior phase-2b spawns carry
   `--pass-batch` and NO `--exempt-behaviors`; both behaviors reach done.

## Chunked regression sweep (no NEW failures)

| Suite | Result |
|-------|--------|
| `test/plugins/tdd/refactor_command_test.dart` | 14/14 PASS |
| `test/plugins/tdd/run_command_test.dart` | PASS (grouped run) |
| `test/plugins/tdd/commands/bug_1544_run_continue_after_blocked_test.dart` | PASS (grouped run) |
| `test/plugins/tdd/commands/bug_1551_no_green_units_defers_test.dart` | PASS (grouped run) |
| `test/plugins/tdd/run_baseline_cache_test.dart` | 7/7 PASS |
| `test/plugins/tdd/services/step_runner_test.dart` | 18/18 PASS |
| `test/plugins/tdd/corpus_economics/incremental_verify_test.dart` | 10/10 PASS |
| `test/plugins/tdd/bug_922_refactor_preflight_baseline_test.dart` | 8/9 — 1 PRE-EXISTING failure |

The single `bug_922` failure ("a green behavior behind a baseline-red suite
reaches done and the run completes") was **stash-bisected to the base
commit** `e260a59b`: the identical `runner-error` failure reproduces with
the fix stashed, so it is a pre-existing, environment-dependent failure
(the test provisions real build_runner codegen in the fixture), NOT a
regression of this fix. All of that file's other 8 tests — including the
#922 argv handoff (`--suite-baseline` still passed to refactor steps) —
pass.

## Static analysis + format

- `dart analyze` (whole repo): **112 issues, all `info`** — byte-identical
  to the documented pre-change baseline (0 errors, 0 warnings).
- `dart format --set-exit-if-changed --output=none lib test`: exit 0,
  0 changed (CI gate).
