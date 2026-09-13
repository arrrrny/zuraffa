# tdd.verify — Bug #1588 phase-2 refactor batch + parked exemption

- **Verified**: 2026-09-13, this session, on
  `fix/1588-phase2-refactor-batch-and-parked-exempt` (working tree, pushed)
- **Toolchain**: Dart 3.13.3 (stable) on linux_x64
- **Scope**: `lib/src/plugins/tdd/commands/refactor_command.dart`,
  `lib/src/plugins/tdd/commands/run_driver_core.dart`,
  `lib/src/plugins/tdd/services/step_runner.dart`, the new
  `lib/src/plugins/tdd/services/pass_batch_ledger.dart`, and the new
  `test/plugins/tdd/commands/bug_1588_phase2_refactor_batch_and_parked_exempt_test.dart`,
  then the chunked regression sweep below.

## Verdict: PASS (with the recorded pre-existing-failure caveat in §3)

## 1. Static analysis

```
dart analyze <changed files + new files>
→ No issues found!

dart analyze            (whole repo)
→ 112 issues found      (all `info`)
→ errors/warnings: 0    (baseline: 0 — no new warnings)
```

The whole-repo count is byte-identical to the pre-change baseline (112 info
lints, 0 errors, 0 warnings).

## 2. The bug suite (REAL runs in this session)

```
dart test --preset=all \
  test/plugins/tdd/commands/bug_1588_phase2_refactor_batch_and_parked_exempt_test.dart

RED  (un-patched tree):  1 passed / 8 failed  — exactly the 8 new-contract
                         assertions (unknown --exempt-behaviors /
                         --pass-batch options; missing --pass-batch in the
                         phase-2b spawn argv). The 1 pass is the contract
                         guard ("without the flag the refusal stands").
GREEN (patched tree):    9 passed / 0 failed   (~01:04 wall clock)
GREEN (post-format rerun, fresh): 9 passed / 0 failed
```

The suite proves, against real `dart test` fixtures and the fake-zfa
driver harness:

- a parked BLOCKED behavior's red test no longer poisons the refactor gate
  (`--exempt-behaviors` exclusion, named in the output, non-exempt
  failures still refuse, unknown ids fail open);
- the second and later `--pass-batch` invocations of an unchanged tree run
  ZERO suite processes and ZERO pass spawns (counted through a logging
  suite wrapper) — one pipeline per batch, not per behavior;
- tree drift and flag-less invocations fall back to the full pipeline
  (safe failure; the standalone absolute-green contract stands);
- the driver hands `--pass-batch` (+ `--exempt-behaviors <parked ids>`)
  on every phase-2b refactor spawn; phase-1 spawns and all other steps
  keep byte-identical argv; per-behavior spawn honesty and the #1544
  blocked-park terminal state are unchanged.

## 3. Chunked regression sweep (no NEW failures)

```
refactor_command_test.dart ......... 14/14 PASS
run_command_test.dart .............. PASS   (grouped run)
bug_1544_run_continue_after_blocked  PASS   (grouped run)
bug_1551_no_green_units_defers ...... PASS   (grouped run)
run_baseline_cache_test.dart .......  7/7 PASS
step_runner_test.dart .............. 18/18 PASS
incremental_verify_test.dart ....... 10/10 PASS (spec 069 T001 scoped re-proof)
bug_922_refactor_preflight_baseline   8/9 — 1 PRE-EXISTING failure
```

The single `bug_922` failure ("a green behavior behind a baseline-red
suite reaches done and the run completes") was **stash-bisected to the
base commit e260a59b**: the identical `runner-error` at
`stopped_at=B-001:refactor` reproduces with this fix fully stashed, so it
is a pre-existing, environment-dependent failure (the test provisions real
build_runner codegen in its fixture and dies mid-preflight on this host) —
NOT a regression of this change. That file's other 8 tests, including the
`--suite-baseline` argv handoff to refactor steps, pass.

## 4. Format (CI gate)

```
dart format --set-exit-if-changed --output=none lib test
→ Formatted 2615 files (0 changed) — exit 0
```

## 5. Host/environment caveats

- The sandbox provides no Flutter SDK; `example/` does not resolve. The
  touched code is pure-Dart CLI + test code; no Flutter surface is
  involved.
- The `bug_922` end-to-end test in §3 requires the host to run the real
  codegen pipeline inside a throwaway fixture; it fails identically at
  base and HEAD on this host (see the bisect note above).
