# Bug Fix: the refactor build pass resolves the PATH-installed zfa instead of the driving binary

- **Slug**: 1636-refactor-build-resolves-path-zfa
- **Fixed**: 2026-09-15T15:10:00+00:00
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: ../tdd/test-list.md, ../tdd/verification.md, ./red-evidence.md

## Summary

`StepRunner.resolveEntrypoint` now returns the RUNNING binary
(`Platform.resolvedExecutable`) ahead of the PATH tier whenever the driving
executable is a compiled (non-Dart-VM) binary, so the refactor build pass —
which delegates to the same chain — executes the binary the operator
invoked instead of a same-version/different-code PATH install. VM drivers
(`dart run`, `dart test`, `dartaotruntime`) fail the non-VM check and keep
the exact #690/#717 tier order, backward compatible.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/services/step_runner.dart` | modified | The #690 final `resolvedExecutable` fallback (old tier 6) is promoted to tier 4, ahead of the PATH tier (now 5), its condition byte-identical (`!_isDartVmName(basename) && File(resolvedExecutable).exists()`); the script-as-file tier becomes 6; library + `defaultZfaBin` + `resolveEntrypoint` docs renumbered and the #1636 rationale recorded. Behavior change is exactly the ordering. |
| `lib/src/plugins/tdd/services/refactor_passes.dart` | modified (doc-only) | The delegation-order doc comments updated to name the new running-binary tier. No executable-code change: `zfaBuildCommand` and `_pinToDrivingVersion` are untouched (hard constraint honored). |
| `test/plugins/tdd/services/bug_1636_running_binary_tier_test.dart` | added test | Tier tests for the cache-exe driver shape: B1/B2 the #1636 repro (compiled driver + PATH install → the running binary), B3/B4 VM-driver backward compat, B5 compiled driver + non-executable PATH candidate. |
| `test/plugins/tdd/services/step_runner_test.dart` | modified test | The #690 group re-labeled to the new tier numbering; the "tier 5 preserved" test re-shaped to the REAL JIT-snapshot driver (VM `resolvedExecutable`) — its pre-#1636 mixed shape (JIT-snapshot script + compiled `resolvedExecutable`) is unreachable in production per #864, and under the corrected order the running binary legitimately wins there; the executable-bit test re-shaped to a VM driver so the bit check is genuinely exercised (the compiled-driver companion lives in the new suite as B5). |

## Diff Highlights

The behavioral core — the #690 final fallback moved ahead of PATH:

```dart
// Tier 4 (bug #1636): the RUNNING binary. ... the same resolvedExecutable
// fallback bug #690 introduced, promoted AHEAD of the PATH tier ...
if (!_isDartVmName(p.basename(resolvedExecutable)) &&
    await File(resolvedExecutable).exists()) {
  return resolvedExecutable;
}
// Tier 5 (bug #690): the system-installed `zfa` binary on PATH —
final onPath = _findExecutableOnPath('zfa', environment['PATH']);
if (onPath != null) return onPath;
```

The old final `resolvedExecutable` block was removed: its condition is
identical to the promoted tier, so every input it resolved now resolves
earlier with the same result — except ordering relative to PATH/script,
which is the intended fix.

## Tests Added or Updated

- `bug_1636_running_binary_tier_test.dart::B1` — the issue's repro: cache-exe
  driver + PATH install → the running binary (#864 native-AOT shape).
- `bug_1636_running_binary_tier_test.dart::B2` — same with an unusable script.
- `bug_1636_running_binary_tier_test.dart::B3` / `::B4` — `dart run` /
  `dartaotruntime` drivers keep the PATH tier (acceptance criterion 2).
- `bug_1636_running_binary_tier_test.dart::B5` — the running-binary tier
  resolves before PATH is consulted (bit-check interaction).
- `step_runner_test.dart` #690 group — re-labeled + re-shaped as above
  (acceptance criterion 3: the order is documented and tested per shape).

## Local Verification

- Commands run and results: see ../tdd/verification.md (REAL runs: the new
  suite red pre-fix `+3 -2`, green post-fix `+5`; 1104 services tests,
  18 #1472 gate tests, 18 runner-adjacent tests, 5 no-JIT sweep tests —
  all passed; `dart analyze` on the changed files: No issues found!).
- Manual checks: the #1472 pin path re-read — with the fix, a compiled
  driver's candidate IS the driving binary, so the pin's version probe
  returns equal and no swap fires; the pin still swaps on a provably
  different candidate version (its code is untouched, and the #1472 gate
  suites prove both directions).

## Deviations from Assessment

- None in scope or direction. One addition beyond the letter of the
  assessment: the doc-only comment updates in `refactor_passes.dart`
  (the delegation-order description), recorded here for completeness —
  the build pass's executable code is unchanged.
- The existing "usable Platform.script wins" test required a re-shape (not
  just re-labeling) because its synthetic mixed driver shape directly
  contradicts the corrected order for a shape no production driver
  produces; the protective intent is preserved on the real JIT-snapshot
  shape. Anticipated in the assessment's Risks & Considerations.

## Follow-ups

- `PipelineRunner._resolveEntrypoint` (the #665 chain) has the same
  PATH-before-running-binary ordering; the issue scopes this fix to
  `StepRunner.resolveEntrypoint` (the build pass's path), so the pipeline
  chain is left untouched — worth a dedicated issue if the same
  same-version hazard matters for `tdd make`/`gen` spawns.
