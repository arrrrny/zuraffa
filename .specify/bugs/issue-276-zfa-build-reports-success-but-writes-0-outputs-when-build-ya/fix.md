# Bug Fix: zfa build reports success but writes 0 outputs when build.yaml is missing

- **Slug**: issue-276-zfa-build-reports-success-but-writes-0-outputs-when-build-ya
- **Fixed**: 2026-08-22T19:50:00+00:00 (verified — build guard present on origin/master)
- **Assessment**: ./assessment.md
- **Status**: verified-fixed (no new `lib/src` change required)

## Summary

The reported silent false-success (`✅ Build completed successfully` with 0
outputs when `build.yaml` was missing) is **not reproducible on current
`origin/master` (`c0b3758`)**. `lib/src/commands/build_command.dart` now runs
`ensureBuildYaml()` before the build (failing fast when the zorphy builder is
not registered) and `verifyOutputsOrFail()` / `verifyDeclaredPartsOrFail()`
after it, each calling `exit(1)` on a 0-output / misconfigured result instead
of reporting success.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/commands/build_command.dart` | already fixed (no change made) | Pre-flight `ensureBuildYaml()` + post-build `verifyOutputsOrFail()`/`verifyDeclaredPartsOrFail()` safety nets. |

## Diff Highlights

No new diff — the guards are already merged. The relevant flow:

```dart
final guardResult = await ensureBuildYaml();
if (!guardResult) { /* actionable error printed */ exit(1); }
...
if (!verifyOutputsOrFail() || !verifyDeclaredPartsOrFail()) { exit(1); }
```

## Tests Added or Updated

- None required: `test/commands/build_command_unit_test.dart` and
  `test/commands/build_command_test.dart` cover the guard and pass.

## Local Verification

- `dart test test/commands/build_command_unit_test.dart` →
  `+40: All tests passed!` (exit 0) on `origin/master` `c0b3758`.

## Deviations from Assessment

The full `build.yaml` *scaffolding* bootstrap is tracked separately under #275;
this issue's standalone robustness ask (fail loudly on 0 outputs) is satisfied.

## Follow-ups

- Close GitHub issue #276.
