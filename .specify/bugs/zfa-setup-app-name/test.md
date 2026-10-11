# Bug Verification: `zfa setup`/`zfa app shell` name-derived shell file and class

- **Slug**: zfa-setup-app-name
- **Tested**: 2026-09-10
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: ./tdd/verification.md

## Summary

The original symptom no longer reproduces — a real (non-dry-run)
`zfa setup zik_zak` with `flutter create` behind it emits
`lib/src/app/zik_zak.dart` with `class ZikZakApp`, and the generated
`main.dart` imports and `runApp`s that symbol; `flutter analyze` on the
freshly generated app exits 0. No regressions were found in any suite
covering the changed surface; the only reds are three pre-existing
failures verified red on the base commit.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix, real command) | `dart run bin/zfa.dart setup zik_zak --no-git` in /tmp, then inspect emitted files + `main.dart` | pass | `lib/src/app/zik_zak.dart`, `class ZikZakApp`, `runApp(const ZikZakApp())` |
| Generated app compiles | `flutter analyze` in `/private/tmp/zik_zak` | pass | exit 0, 0 errors/warnings (2 pre-existing infos, unrelated) |
| New/updated tests | `dart test test/commands/setup_app_shell_naming_test.dart` | pass | +7 (was +1 −6 RED on base) |
| Fast-tier regression | `dart test` on setup/1444/pubspec_deps/package_mode/skeleton | pass | all green |
| Slow-tier regression | `--preset=all` on `test/plugins/app_shell/`, issue_469/512/181, docs-consistency | pass | all green |
| Type-check | `dart analyze lib test` | pass | 0 errors/warnings; 112 pre-existing infos in unrelated files |
| Pre-existing reds isolated | stash → rerun 3 failing tests → unstash | pass | same 3 failures on base; not introduced by this fix |

## Output Excerpts

```
[8/9] Generating app shell (ZuraffaApp)...
   ✓ lib/src/routing/app_router.dart
   ✓ lib/src/app/zik_zak.dart
...
   Run tests:    flutter test   (green day zero: test/bootstrap_smoke_test.dart asserts ZikZakContainer)

flutter analyze (generated app): 2 issues found. (ran in 63.0s) — exit 0
dart test test/commands/setup_app_shell_naming_test.dart → 00:02 +7: All tests passed!
```

## Residual Risks

- `zfa setup xyx` was verified through the in-process end-to-end test
  (A3), not a second real `flutter create` run — the code path is
  identical to the verified `zik_zak` run.
- `zfa tdd verify`'s mutation gates did not run: no registered artifacts
  exist for bug-dir features, and `zfa tdd run` cannot consume bug dirs
  yet (run-side gap of #1182 — filed as a follow-up in fix.md).
- The 3 pre-existing `app_shell_command_test` failures (coreImport
  expectations) remain red on master; untouched here.

## Recommendation

Close the bug — verified end-to-end (RED baseline → GREEN suite → real
`zfa setup` reproduction → generated app analyzes clean). Proceed to the
PR linking issue #1465.
