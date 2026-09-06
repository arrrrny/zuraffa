## Summary

Master's `dart_core` lane went red at `350e2d8e` (merge of #1206): **5381 passed / 3 failed**, all three in `test/regression/issue_891_example_meta_resolution_test.dart`. #1206 deliberately dropped `dependency_overrides: meta: ^1.18.3` from `example/pubspec.yaml` (Flutter 3.47.x re-pinned meta; resolution now proven by `tools/flutter_smoke_gate.sh` / `flutter_consumer_smoke`) but left the #891 regression test asserting the override must exist. This PR flips that test to the post-#1206 contract so `dart_core` returns to green.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `test/regression/issue_891_example_meta_resolution_test.dart` | rewritten | Old tests 1–3 (override REQUIRED) → one guard: `dependency_overrides` MUST be absent (blocks both version and `path:` re-introduction). Old test 4 (analyzer-floor heuristic) → guard that the delegated proof `tools/flutter_smoke_gate.sh` exists and still covers `example/`. `_versionFloor` helper dropped; #891 → #1189 → #1206 history preserved in the doc comment |
| `.specify/bugs/pr-1210-ci-red/**` | added | Bug workflow records: assessment, spec, TDD test-list/cycle-log/verification, fix/test reports |

## TDD evidence (tdd/verification.md: PASS)

- **RED (pre-fix)**: `dart test test/regression/issue_891_example_meta_resolution_test.dart` → 3 failures, matching master CI run 34027280435 exactly
- **GREEN (post-fix)**: `+3: All tests passed!` (re-verified after `dart format`; `dart analyze` clean)
- **Mutants**: re-adding the override → A2 kills it; removing the smoke gate → A3 kills it. Restores verified green.
- **Regression scope**: `dart test test/regression/` → the only other failures are `issue_1059` subprocess timeouts, stash-bisect-proven pre-existing on pristine HEAD (env flakes; CI passes them on the same commit)

## Scope note

This does NOT touch `engine_check_command_test.dart` — that failure is PR #1210's own regression (mandatory engine receipt vs. receipt-less fixture) and is fixed on `spec/1109-make-engine-preset`.

Assessment: `.specify/bugs/pr-1210-ci-red/assessment.md`

Closes #1211.
