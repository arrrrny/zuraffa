# TDD Test List — Spec 1318 noFlutter false-positive on event prose

One behavior per line, traced to the acceptance criteria (SC-n) in
spec.md. Every behavior is written as a failing test FIRST (RED), then
made to pass (GREEN). Red for this feature is an assertion red: the
classifier routes the event-schema repro widget-kind (the #830/#936
`shows?` fallback fires with no subject context) and the guard's fix
message buries the marker remedy third.

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | The issue repro parses CORE: Then-clause "the decision_made event shows outcome: clarify with the question, and the content_delta events contain the clarification." → kind `acceptance` (not widget) | SC-1, SC-3 | test/plugins/tdd/bug_1318_noflutter_event_prose_test.dart |
| B2 | Event-noun subject matrix routes acceptance: "event shows", "event includes", "event carries", "message shows", "response includes", modifier forms ("SSE response includes", "the message shows the payload"), plural ("events contain") | SC-3 | test/plugins/tdd/bug_1318_noflutter_event_prose_test.dart |
| B3 | Event-noun exclusion holds even when a UI surface noun co-occurs in the payload description: "the event shows the dialog id in its payload" → acceptance | SC-3 | test/plugins/tdd/bug_1318_noflutter_event_prose_test.dart |
| B4 | Verb-only weak matches no longer route widget: "the app shows a spinner" (no surface noun, no strong verb) → acceptance | SC-3 | test/plugins/tdd/bug_1318_noflutter_event_prose_test.dart |
| B5 | Backward compat — surface-noun subjects stay widget: "the screen shows a spinner", "the widget displays the badge", "the dialog appears with the title", "the sidebar is visible on macOS" | SC-4 | test/plugins/tdd/bug_1318_noflutter_event_prose_test.dart |
| B6 | Backward compat — #936 trio stays widget: shown+navigated, rendered, displayed (the exact bug_830 scenarios) | SC-4 | test/plugins/tdd/bug_1318_noflutter_event_prose_test.dart |
| B7 | Marker escape hatch untouched: the repro scenario with an explicit `**Type**: widget` marker parses widget (declaration outranks prose, both directions) | SC-5 | test/plugins/tdd/bug_1318_noflutter_event_prose_test.dart |
| B8 | CLI end-to-end repro: CORE lane (flutter_allowed: false) over an event-prose acceptance scenario → `zfa tdd plan` exits 0, 04-ENGINE.md written, no noFlutter refusal | SC-1 | test/plugins/tdd/bug_1318_noflutter_event_prose_test.dart |
| B9 | Guard remedy ordering (classifier-routed): an UNDECLARED scenario whose prose routes widget ("renders the authenticated user badge") in a CORE lane → exit 2, refusal leads with `--> fix: add **Type**: acceptance to the scenario (classifier guess, not a declaration)` | SC-2 | test/plugins/tdd/bug_1318_noflutter_event_prose_test.dart |
| B10 | Guard remedy ordering (declared): a `**Type**: widget`-declared scenario in a CORE lane → exit 2, refusal keeps `declare it SKIN (or BOTH)` and never claims a classifier guess | SC-2, SC-5 | test/plugins/tdd/bug_1318_noflutter_event_prose_test.dart |
| B11 | Regression: plan_lanes_1000 noFlutter guard suite (classifier-routed refusal names the behavior; artifacts absent on refusal) passes UNMODIFIED | SC-4, SC-5 | test/plugins/tdd/commands/plan_lanes_1000_test.dart |

## Red protocol

Run per file, never the full suite (disk ceiling):

```
rm -rf .dart_tool/test/ && rm -f $TMPDIR/dart_test.kernel.*
dart test test/plugins/tdd/bug_1318_noflutter_event_prose_test.dart
```

Expected RED: B1-B9 fail (repro + matrix still route widget-kind; the
guard remedy still buries the marker third). B10 fails too pre-fix
(the declared-path message is unchanged but B10 asserts the NEW
lead-with-marker message is NOT shown — actually B10 pins the KEPT
lane-move remedy, so it must pass both before and after; it is the
regression pin). B11 (existing suite) stays green pre-fix by
definition.

## Green protocol

Same single-file command after the fix lands in
`lib/src/plugins/tdd/services/spec_parser.dart` +
`lib/src/plugins/tdd/commands/plan_command.dart`. Then the
compatibility sweep (T2.1), targeted `dart analyze`, `dart format .`,
kernel-cache cleanup.
