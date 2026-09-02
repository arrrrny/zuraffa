# Bug Assessment: [zfa tdd run] driver passes --suite-baseline to make but make command does not accept the flag

- **Slug**: tdd-make-missing-suite-baseline-flag
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/750
- **Verdict**: valid (fix already merged)
- **Severity**: high

## Report (verbatim or summarized)

`zfa tdd run` passes `--suite-baseline <path>` to spawned `zfa tdd make` subprocesses, but `zfa tdd make` does not register `--suite-baseline` in its argParser. The make command rejects the unknown flag with `Could not find an option named "--suite-baseline"` and exits 1, causing the run to fail at the first `make` step with `outcome=failed`. Introduced by issue #741's suite-baseline caching.

Issue URL: https://github.com/arrrrny/zuraffa/issues/750

## Resolution

**Fix already merged on master** via commit `14651299` (PR #746, "fix(741): tdd run caches full-suite baseline and skips on already-green behaviors"):
- `MakeCommand.argParser` now registers `--suite-baseline` (make_command.dart:126-135)
- `RunBaselineCache` service reads/writes `specs/<feature>/tdd/run-baseline.json` (run_baseline_cache.dart)
- `make` consumes the cached baseline at step 5 (make_command.dart:293-299), falling back to the live suite when the cache is missing/corrupt/unparseable

The issues (#750, #751, #752) were filed against a pre-#746 binary. The fix is present on master at HEAD.

## Symptom

`zfa tdd run <feature>` stops at the first `U*:make` step with `outcome=failed` because the spawned `zfa tdd make` subprocess rejects the `--suite-baseline` flag.

## Reproduction

1. `zfa tdd init` on a pure Dart package
2. `zfa tdd run <feature>` — runs successfully through `gen` and `verify-red`
3. Driver spawns `zfa tdd make U1 ... --suite-baseline specs/<feature>/tdd/run-baseline.json`
4. Make exits 1 with `Could not find an option named "--suite-baseline"`
5. Run stops at `U1:make` with `outcome=failed`

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/make_command.dart:82-106` — **confirmed**. `MakeCommand.argParser` registers `--feature`, `--project`, and `--zfa-bin` but does NOT register `--suite-baseline`.
- `lib/src/plugins/tdd/services/step_runner.dart:241-245` — **confirmed**. `StepRunner.run()` always passes `--suite-baseline <path>` to make subprocesses when the run has a cached baseline.
- `lib/src/plugins/tdd/commands/make_command.dart` (step 5, "Pre-run suite baseline") — the suite baseline logic needs to check for the `--suite-baseline` option and read from the cached file when present.

## Root Cause Hypothesis

Asymmetric contract: the run driver (`StepRunner.run()`) promises to pass `--suite-baseline <path>`, but `MakeCommand.argParser` doesn't declare the option. The flag is rejected at argparse time before any make logic runs. High confidence: both code paths are explicitly identified in the issue and verified in source.

## Proposed Remediation

**Already fixed on master** (commit `14651299`, PR #746):
1. `MakeCommand.argParser` registers `--suite-baseline` (make_command.dart:126-135)
2. `RunBaselineCache` service reads/writes `run-baseline.json`
3. Step 5 of make consumes the cached baseline (make_command.dart:293-299)

No further action needed unless the fix has regressed. Verify with:
```bash
zfa tdd make --help | grep suite-baseline
```