# Bug Fix: [TDD-130] UI-intent classifier misses past-tense outcome verbs

- **Slug**: ui-past-tense-verbs-missed
- **Fixed**: 2026-09-03
- **Branch**: fix/936-ui-past-tense-verbs-missed
- **Issue**: 936
- **Status**: applied

## Changes Made

1. `lib/src/plugins/tdd/services/spec_parser.dart` — extended `uiAcceptanceIntent`:
   - `render(?:s|ed|ing)?` (was `renders?` — could not match "rendered")
   - `navigat(?:e|es|ed|ion|ing)` (adds the `ed` conjugation)
   - added `display(?:s|ed|ing)?` and `shows?|shown` (absent outcome verbs)
   - Word boundaries kept; the concept set is not widened ("navigation" already matched).
2. `test/plugins/tdd/bug_830_widget_subject_kind_test.dart` — added two tests:
   - past-tense fixture rows ("is shown / is navigated", "is rendered", "is displayed") land in the widget kind;
   - a non-UI past-tense sentence ("the result is returned ... row count matches") still routes to acceptance.

## TDD Evidence

- RED: the past-tense test failed before the fix (A1/A2/A3 routed to `acceptance`).
- GREEN: after the regex extension both new tests pass (19/19 in the file).
- The first non-UI fixture ("the receipt is shown in the logs") was corrected to the issue's own example shape — "shown" is a UI outcome verb by design (documented acceptable over-match in the assessment).

## Local Checks

- `dart test test/plugins/tdd/bug_830_widget_subject_kind_test.dart` → 19/19 pass.
- `dart analyze lib/src/plugins/tdd/services/spec_parser.dart test/plugins/tdd/bug_830_widget_subject_kind_test.dart` → clean.
- `dart format` applied to both touched files.
- Full `dart test test/plugins/tdd/` regression run recorded in `test.md`.
