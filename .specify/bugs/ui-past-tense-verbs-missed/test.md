# Bug Test: [TDD-130] UI-intent classifier misses past-tense outcome verbs

- **Slug**: ui-past-tense-verbs-missed
- **Tested**: 2026-09-03
- **Result**: verified

## Reproduction (re-run after fix)

Past-tense Then-clauses ("is shown / is navigated / is rendered / is displayed") now route to the **widget** kind — verified by the new test `bug 936: past-tense outcome verbs (shown, navigated, rendered, displayed) are UI intent too`.

## Tests Run

| Command | Result |
| --- | --- |
| `dart test test/plugins/tdd/bug_830_widget_subject_kind_test.dart` | 19/19 pass |
| `dart test test/plugins/tdd/bug_830_widget_subject_kind_test.dart test/plugins/tdd/commands/func_command_test.dart test/plugins/tdd/wire_command_test.dart test/plugins/tdd/services/generation_planner_test.dart` | 69/69 pass |
| `dart analyze lib/src/plugins/tdd/services/spec_parser.dart test/plugins/tdd/bug_830_widget_subject_kind_test.dart` | clean |
| `dart test test/plugins/tdd/` (full plugin suite) | failures ONLY in pre-existing, unrelated subprocess tests |

## Pre-existing failure evidence (not caused by this fix)

- `test/plugins/tdd/verify_red_subdirectory_test.dart` (3 tests) fails **identically on the clean tree** (changes stashed, commit 31b3ad62 = master HEAD): all three hit the 75s zfa-subprocess child timeout running `zfa tdd verify-red`. Same failure shape observed during the #920 cycle before this branch existed.
- `test/plugins/tdd/services/subprocess_timeout_test.dart` fails only under full-suite parallel load; it **passes in isolation** (verified on the clean tree).
- Neither file exercises `SpecParser.uiAcceptanceIntent`.

## Notes

- The first draft of the non-UI guard fixture ("the receipt is shown in the logs") was corrected: "shown" is a UI outcome verb by design (documented acceptable over-match in the assessment); the issue's own non-UI example ("the result is returned") is what the test now pins.
