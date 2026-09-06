# Bug Fix: issue_891 regression test must assert the post-#1206 zero-overrides contract

- **Slug**: pr-1210-ci-red
- **Fixed**: 2026-09-06
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: ./tdd/test-list.md, ./tdd/cycle-log.md

## Summary

Rewrote `test/regression/issue_891_example_meta_resolution_test.dart` to assert
the contract #1206 established (example/pubspec.yaml carries ZERO
`dependency_overrides`; resolution proof delegated to
`tools/flutter_smoke_gate.sh`), turning master's 3 red dart_core tests green
(issue #1211).

## Changes

| File | Change | Notes |
|------|--------|-------|
| `test/regression/issue_891_example_meta_resolution_test.dart` | rewritten | Old tests 1–3 (override REQUIRED) flipped to one zero-overrides guard; old test 4 (analyzer-floor heuristic) replaced by an assertion that the delegated smoke gate exists and covers example/; `_versionFloor` helper dropped; #891 → #1189 → #1206 history preserved in the doc comment |

## Diff Highlights

Contract flip, in one assertion:

```dart
// OLD: override must exist
final overrides = doc['dependency_overrides'];
expect(overrides, isA<Map>(), reason: '...has NO dependency_overrides...');

// NEW: section must be absent
expect(doc['dependency_overrides'], isNull, reason:
    '...the committed example must resolve with ZERO overrides...');
```

## Tests Added or Updated

- `example/pubspec.yaml exists (the file-shape guard needs it)` — retained A1 guard
- `example/pubspec.yaml carries ZERO dependency_overrides (issue #891 contract flipped by #1206)` — A2; subsumes the path-override prohibition (no section → nothing can override)
- `the zero-overrides resolution proof is delegated to tools/flutter_smoke_gate.sh` — A3; pins the #1206 delegation target

## Local Verification

- `dart test test/regression/issue_891_example_meta_resolution_test.dart` → pre-fix RED (3 failures, matching master CI run 34027280435) → post-fix GREEN (`+3: All tests passed!`), re-verified after `dart format`
- `dart format` on the file → formatted (1 change)
- `dart analyze` on the file → No issues found

## Deviations from Assessment

- **TDD engine**: `zfa tdd plan/run` could not drive this bug — `.zfa.json` is
  absent and the engine resolves features only under `specs/`, while this bug
  lives at `.specify/bugs/pr-1210-ci-red/`. Ran the sanctioned LLM-guided
  fallback (red-green-refactor by hand, evidence in `tdd/cycle-log.md`).
  Candidate zfa gap worth an issue: TDD extension cannot address bug dirs.
- Scope held to Failure A (the master-side fix). Failure B (the
  `engine_check_command_test.dart` receipt fixture) is PR #1210's own
  regression, fixed on `spec/1109-make-engine-preset` per `./issue.md`.

## Follow-ups

- Re-run master CI after merge to confirm `dart_core` green at 5381+ passed / 0 failed.
- PR #1210 still needs its own one-line fix (receipt fixture in
  `writeCanonicalSlice()`) plus a rebase onto post-#1206 master.
