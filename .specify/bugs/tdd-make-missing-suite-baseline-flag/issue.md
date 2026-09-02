# Bug Issue: [zfa tdd run] driver passes --suite-baseline to make but make command does not accept the flag

- **Slug**: tdd-make-missing-suite-baseline-flag
- **Fetched**: 2026-09-02
- **Issue**: 750
- **URL**: https://github.com/arrrrny/zuraffa/issues/750
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

## Bug Description

`zfa tdd run` passes `--suite-baseline <path>` to spawned `zfa tdd make` subprocesses, but `zfa tdd make` does not register `--suite-baseline` in its argParser. The make command rejects the unknown flag with `Could not find an option named "--suite-baseline"` and exits 1, causing the run to fail at the first `make` step with `outcome=failed`.

This was introduced by the suite-baseline caching feature (issue #741): the driver was updated to pass the cached baseline, but the make command itself was not updated to accept the new flag.

## Steps to Reproduce

1. `zfa tdd init` on a pure Dart package
2. `zfa tdd run <feature>` — runs successfully through `gen` and `verify-red`
3. Driver spawns `zfa tdd make U1 ... --suite-baseline specs/<feature>/tdd/run-baseline.json`
4. Make exits 1 with `Could not find an option named "--suite-baseline"`
5. Run stops at `U1:make` with `outcome=failed`

## Expected Behavior

`zfa tdd make` should accept `--suite-baseline <path>` and use the cached baseline instead of re-running the full suite. When the flag is given, the suite baseline (step 5 in `make_command.dart`) is read from the cached file rather than re-executed.

## Root Cause

**File**: `lib/src/plugins/tdd/commands/make_command.dart`

`MakeCommand.argParser` registers `--feature`, `--project`, and `--zfa-bin` (lines 82–106) but does NOT register `--suite-baseline`. Meanwhile, `StepRunner.run()` (in `lib/src/plugins/tdd/services/step_runner.dart`, lines 241–245) always passes `--suite-baseline <path>` to make subprocesses when the run has a cached baseline.

The contract is asymmetric: the driver promises to pass the flag, the command doesn't promise to accept it.

## Suggested Fix

In `lib/src/plugins/tdd/commands/make_command.dart`, add:

```dart
argParser.addOption(
  'suite-baseline',
  help:
      'Path to a cached run-baseline.json file from zfa tdd run. When set, '
      'make reads the suite baseline from this file instead of re-running the '
      'full suite (issue #741).',
);
```

Then in the make command's step 5 (`Pre-run suite baseline`), check for the option:

```dart
final suiteBaselinePath = argResults?['suite-baseline'] as String?;
if (suiteBaselinePath != null && suiteBaselinePath.isNotEmpty) {
  // Read from cached file
  final file = File(suiteBaselinePath);
  if (!await file.exists()) {
    // fall through to running the suite
  } else {
    // parse the cached snapshot
  }
}
```

## Severity

high — `zfa tdd run` is completely blocked on every feature with a fresh `run-state.json` because the make step fails on the first behavior with this argument mismatch

## Affected Versions

zfa v6.1.0+ (after issue #741's suite-baseline caching landed in step_runner but not in make_command)

## Related Issues

- #751 — duplicate report with additional reproduction detail (forklift spec 004, U8:make)
- #752 — duplicate report with additional context (#741 + #746 regression)
- #741 — the suite-baseline caching feature that introduced the asymmetric contract
- #746 — the PR that fixed this (commit 14651299) — **already on master**

## Comments

None.