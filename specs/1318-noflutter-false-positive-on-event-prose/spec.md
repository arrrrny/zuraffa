# Spec 1318 — fix: noFlutter false-positive on event prose — SSE/event-schema "shows" must not route widget-kind

GitHub issue: arrrrny/zuraffa#1318 (severity high — every SSE/spec-prose
spec that uses "shows" for event fields is rejected by plan)

## Problem

`zfa tdd plan <feature>` on an all-CORE pure-Dart spec (forklift
009-conversation-streaming, re-run through the new lane format)
hard-refused with a lane violation naming acceptance scenario A10 as
"routed widget-kind ... but declared CORE". A10's prose is an SSE event
schema assertion:

```gherkin
Given an ambiguous message, When the engine decides to clarify,
 Then the decision_made event shows outcome: clarify with the
 question, and the content_delta events contain the clarification.
```

The word "shows" matched the #830/#936 UI-intent regex
(`shows?|shown`), so a server-side streaming behavior was classified as
a Flutter widget behavior and the spec-1000 noFlutter guard rejected
the entire plan (exit 1, zero artifacts written).

Root cause: `spec_parser.dart` `uiAcceptanceIntent` regex matches
`shows?` with no subject context; `_extractAcceptance` applies it to
any undeclared scenario (#830 fallback, #936 added the verb).
Event-schema assertions are a common false positive for server-side
specs ("event shows/includes/carries a field" is not UI intent).

## Deliverables

1. **Exclude event-noun subjects from UI-intent match.** When the
   scenario's Then-clause subject is an event/protocol noun (e.g.
   `event shows`, `event includes`, `event carries`, `message shows`,
   `response includes`), the UI-intent classifier MUST NOT route it
   widget-kind. Concretely: `SpecParser.isUiAcceptance` first tests an
   event-noun-subject pattern (`events?|messages?|responses?|payloads?|streams?|frames?|notifications?`
   directly followed by a content verb
   `shows?|shown|includes?|contains?|carries?|presents?|returns?|holds?|has?`,
   with an optional modifier word: `decision_made event shows`,
   `content_delta events contain`, `SSE response includes`); a match is
   protocol prose, never UI intent.
2. **Guard message leads with marker remedy for classifier-routed
   behaviors.** When the noFlutter guard fires on a classifier-routed
   (undeclared — no `**Type**` marker) behavior, the fix message MUST
   lead with the marker remedy:
   `--> fix: add **Type**: acceptance to the scenario (classifier guess, not a declaration)`
   instead of burying it as the third option. A DECLARED widget-kind
   behavior (the author's explicit `**Type**: widget`) keeps the
   lane-move remedy (the marker is not a guess there).
3. **Event-schema scenarios route CORE by default.** Scenarios whose
   prose describes event/protocol schema (fields, payloads, SSE
   events) MUST route CORE unless explicitly declared SKIN: the
   classifier must not default to widget-kind for event-schema
   assertions. The verb-only weak matches (`shows`, `shown`) no longer
   route widget-kind on their own — they survive only when a UI
   surface noun (widget/shell/bar/dialog/screen/page/sidebar) or a
   strong UI verb (render/navigate/display) co-occurs.
4. **Backward compatibility.** Existing specs with genuine UI
   scenarios ("the screen shows", "the widget displays",
   "the page shows the settings form", "a loading indicator
   is shown and I am navigated") continue to route widget-kind
   correctly. The fix only narrows the classifier for event-noun
   subjects and surface-less verb-only matches, with one deliberate
   widening: `appears?` was NOT in the pre-#1318 alternation, so
   "the dialog appears with the title" parsed acceptance before this
   change and now routes widget — new routing, not compat. The
   unconditional strong grammar (render/navigate/display verbs + the
   #830 layout nouns) is unchanged, and the surface-noun co-occurrence
   set gains exactly the nouns the repo's own pinned prose requires
   (dialog/screen/page).
5. **Scope fence.** Only `spec_parser.dart` (the `uiAcceptanceIntent`
   regex, the new event-noun pattern, `isUiAcceptance`) and the
   noFlutter guard's fix message ordering (plus the declaration context
   the message needs) change. The core engine cycle, the lane
   derivation algorithm, the TDD runner, and the verify gate are
   untouched. The `**Type**: acceptance` marker feature remains the
   escape hatch for ambiguous prose — not removed, not weakened.

## Success criteria (measurable)

- **SC-1** — The issue repro routes CORE: parsing a spec whose
  acceptance scenario reads "Then the decision_made event shows
  outcome: clarify with the question, and the content_delta events
  contain the clarification." yields kind `acceptance` for that
  behavior, and `zfa tdd plan` on the forklift lane shape
  (CORE lane, `flutter_allowed: false`, all behaviors listed) exits 0
  with artifacts written and no noFlutter refusal.
- **SC-2** — Guard remedy ordering: a classifier-routed widget-kind
  behavior in a CORE lane produces a refusal whose `--> fix:` clause
  LEADS with `add **Type**: acceptance to the scenario (classifier
  guess, not a declaration)`; a declared `**Type**: widget` behavior in
  a CORE lane keeps the `declare it SKIN (or BOTH)` remedy.
- **SC-3** — Event-noun subjects never classifier-widget: `event
  shows`, `event includes`, `event carries`, `message shows`,
  `response includes` (and modifier forms) all parse to
  `acceptance` — including when a UI surface noun co-occurs in the
  payload description ("the event shows the dialog id in its payload").
- **SC-4** — Backward compat: "the screen shows a spinner", "the
  widget displays the badge", "renders the brand theme", "the sidebar
  is visible", and the #936 trio (shown+navigated, rendered, displayed)
  all still parse to `widget`. ("the dialog appears with the title" is
  excluded from this list — it is the `appears?` widening of
  deliverable 4, not backward compat.)
- **SC-5** — The `**Type**: acceptance` / `**Type**: widget` marker
  escape hatch is untouched: declared scenarios keep outranking the
  prose classifier (declaration wins, classifier never consulted).
- **SC-6** — Scope fence holds: `dart analyze` on the changed files
  reports no issues; the only lib/ diffs are
  `spec_parser.dart` + `plan_command.dart` (guard message + its
  declaration context).
