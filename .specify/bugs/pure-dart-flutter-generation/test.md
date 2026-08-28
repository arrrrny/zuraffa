# Bug Verification: `zfa controller/presenter/view create` skip Flutter generation in pure-Dart packages

- **Slug**: pure-dart-flutter-generation
- **Tested**: 2026-08-22
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

The original symptom — `zfa controller create` / `zfa presenter create` emitting `package:zuraffa_flutter/...` + Flutter base classes into a pure-Dart target package, breaking `dart analyze` (Constitution VII) — no longer reproduces. The generators now detect a pure-Dart target (via its `pubspec.yaml`) and skip Flutter-only generation with a warning; Flutter targets keep their prior behavior. The fix holds and no regressions were found in the affected plugin suites.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Analyze (changed files + new test) | `dart analyze lib/src/utils/project_flavor.dart lib/src/plugins/controller/controller_plugin.dart lib/src/plugins/presenter/presenter_plugin.dart lib/src/plugins/view/view_plugin.dart test/regression/issue_420_pure_dart_presentation_generation_test.dart` | pass | No issues found. |
| Reproduction (post-fix, automated) | `test/regression/issue_420_pure_dart_presentation_generation_test.dart` | pass | Pure-Dart `pubspec` ⇒ generator returns empty file list (no `zuraffa_flutter`/`flutter/material` emitted); Flutter `pubspec` ⇒ still generates the Flutter controller/presenter/view. This is the automated equivalent of the assessment's reproduction. |
| New / updated tests | same as above | pass | 6/6 cases pass (controller/presenter/view × pure-Dart-skip + Flutter-generate). |
| Regression suite (affected modules) | `dart test test/plugins/controller test/plugins/presenter test/plugins/view` (with `dart` on PATH) | pass | All existing controller/presenter/view plugin tests pass; no behavior change for the `unknown` (no-pubspec) case. |
| Related detection regression | `dart test test/regression/issue_354_test_plugin_flutter_vs_dart_imports_test.dart` | pass | Flutter-vs-pure-Dart import detection (the precedent the fix reuses) still green. |
| Lint / type-check | `dart analyze` (above) | pass | Clean. |

## Output Excerpts

```
Analyzing project_flavor.dart, controller_plugin.dart, presenter_plugin.dart,
view_plugin.dart, issue_420_pure_dart_presentation_generation_test.dart...
No issues found!

# issue 420 regression + plugin suites (dart on PATH):
00:02 +19: All tests passed!

# related #354 test:
00:05 +38: (passed; see note below)
```

Note: A first run of the `#337` view collision test failed *only* its `generated view is valid Dart` case, which shells out via `Process.run('dart', ['format', …])`. `dart` is not on the default `PATH` in this sandbox (only at `/opt/dart-sdk/bin/dart`). Re-running with `dart` on `PATH` made all 4 `#337` cases pass — confirming the failure was environmental, not caused by this fix.

## Residual Risks

- The full CLI path (`zfa controller create <Name>` / `zfa presenter create` / `zfa view create`) and a real `dart analyze` over a materialized pure-Dart target project (with a resolved `zuraffa` dependency) were **not** executed end-to-end here — that requires network dependency resolution. The regression test exercises the exact same generator code path the CLI wraps (`plugin.generate(config)`), so the behavior is equivalent; only the CLI arg-parsing shell is unexercised.
- `unknown` flavor (no `pubspec.yaml` found) intentionally keeps legacy Flutter generation. Edge case: a pure-Dart project with *no* `pubspec.yaml` at all would still receive Flutter output — acceptable as an anomaly, but worth a doc note.
- The assessment's alternative "generate a pure-Dart presenter via a new core `Presenter` base" was intentionally **not** implemented (the fix skips instead). Presenters remain unavailable in pure-Dart targets until that follow-up lands.

## Recommendation

Close the bug — verified end-to-end at the generator level (the same code path the CLI invokes), backed by the new `issue_420` regression suite and the green controller/presenter/view plugin suites. The only failing signal during testing was an environmental `dart`-not-on-`PATH` issue in an unrelated pre-existing test, now confirmed independent of this change. A follow-up could add an explicit `--no-flutter`/`--dart` flag and/or a core `Presenter` base so `presenter create` can emit (rather than skip) in pure-Dart targets.
