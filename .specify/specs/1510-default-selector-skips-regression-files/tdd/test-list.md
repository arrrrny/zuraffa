---
feature: 1510-default-selector-skips-regression-files
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 6
planned_at: 46fe766e
updated_at: HEAD
suite_baseline: green
---

# Test List: Default selector skips make-command regression files (direct-path honesty)

Configuration-level bug: the failing "unit" is the INVOCATION
(`dart test <file>` under the default preset), so the loop is outside-in —
each behavior is a runner exit code + selected-test count against the real
selector config. One behavior per line, traced to the spec's success
criteria. Red evidence: exit 79 with `No tests match the requested tag
selectors: include: "<all>" exclude: "slow"` on untouched master
(commit 46fe766e).

## Inner loop: invocation behaviors

| id | behavior                                                                                     | traces  | kind    | state  | test                                                                                                        |
| --- | ------------------------------------------------------------------------------------------- | ------- | -------- | ---- | ---------------------------------------------------------------------------------------------------------- |
| B1  | `dart test test/plugins/tdd/make_command_test.dart` no longer silently empties: 38 runnable behaviors selected and executed under the default preset (33 pass, 5 pre-existing master-matching failures; exit 0 in a clean environment) | SC-1 | example | DONE   | `dart test test/plugins/tdd/make_command_test.dart` (default preset; failure baseline in `tdd/verification.md` §3) |
| B2  | `dart test test/plugins/tdd/make_command_declared_071_test.dart` exits 0 and runs 1 test under the default preset | SC-2 | example | DONE   | `dart test test/plugins/tdd/make_command_declared_071_test.dart` (default preset, no tags flags)           |
| B3  | `--preset=regression` selects both files (the regression lane covers them)                    | SC-4    | example | DONE   | `dart test --preset=regression test/plugins/tdd/make_command_declared_071_test.dart` + count check         |
| B4  | `--preset=all` still selects both files                                                       | SC-4    | example | DONE   | `dart test --preset=all test/plugins/tdd/make_command_declared_071_test.dart`                              |
| B5  | CI fast-lane shape excludes both files: `--exclude-tags "flutter \|\| e2e"` skips them          | SC-3    | example | DONE   | selector dry-run against the two files + fast-lane file untouched (`core_result_test.dart` still selected) |
| B6  | Regression-tier integrity pin unaffected: `test/tier_integrity_test.dart` passes              | SC-5    | example | DONE   | `dart test test/tier_integrity_test.dart`                                                                  |

## Outer ring (non-behavioural)

- W1: `dart analyze` clean on all changed files (SC-6).
- W2: `dart format` clean on changed Dart files (SC-6).
- W3: `e2e` tag declared in `dart_test.yaml` tags map — no unknown-tag
  warnings on any invocation in B1–B6 (SC-3).
- W4: No pubspec changes; no test-logic diffs beyond the two `@Tags`
  lines (hard constraints).
