# Bug Fix: ModuleOrchestratorBuilder generates unparseable Dart (getter bodies without return)

- **Slug**: issue-247-bug-moduleorchestratorbuilder-generates-unparseable-dart-get
- **Fixed**: 2026-08-22T19:50:00+00:00 (verified — fix already present on origin/master)
- **Assessment**: ./assessment.md
- **Status**: verified-fixed (no new `lib/src` change required)

## Summary

The reported unparseable output (`{ 'todo' }` getters, one-lined
imports+class) is **not reproducible on current `origin/master` (`c0b3758`)**.
`lib/src/plugins/module/builders/module_orchestrator_builder.dart` now builds
the orchestrator via the `code_builder` AST API and runs `DartFormatter.format`
before writing, producing parseable, formatted Dart (e.g.
`String get pluginId => 'todo';`).

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/module/builders/module_orchestrator_builder.dart` | already fixed (no change made) | Uses `code_builder` `Library`/`Class`/`Method` + `DartFormatter.format`. |

## Diff Highlights

No new diff — the fix is already merged. The builder emits getters with arrow
syntax via `Code("return '...';")` / `Code('return const {};')` and formats the
result.

## Tests Added or Updated

- None required: `test/plugins/module/module_plugin_test.dart` already asserts
  the generated content contains `class TodoFeaturePlugin`, `extends ZuraffaPlugin`,
  and `'todo'`, and passes.

## Local Verification

- `dart test test/plugins/module/module_plugin_test.dart` →
  `00:00 +2: All tests passed!` (exit 0) on `origin/master` `c0b3758`.

## Deviations from Assessment

None — assessment concluded the fix is already applied.

## Follow-ups

- Close GitHub issue #247.
