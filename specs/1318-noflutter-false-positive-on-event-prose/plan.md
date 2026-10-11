# Plan 1318 — noFlutter false-positive on event prose (SSE "shows" misroutes widget-kind)

GitHub issue: arrrrny/zuraffa#1318 · Spec: `spec.md` (same directory)

## Technical Context

- **Language/SDK**: Dart 3.13 (pubspec `sdk: ^3.11.0`), pure-Dart package.
- **Touch surface** (scope fence from the issue):
  - `lib/src/plugins/tdd/services/spec_parser.dart`
    — `uiAcceptanceIntent` (the #830/#936 regex), a new event-noun-subject
    pattern, and `isUiAcceptance` (the static classifier consumed ONLY by
    `_extractAcceptance`'s undeclared-scenario fallback at the
    `markers['A$n']?.declaredType ?? ...` site).
  - `lib/src/plugins/tdd/commands/plan_command.dart`
    — the noFlutter guard's refusal message (`_resolveLanes`, the
    `lane == Lane.core && (widget||theme)` branch) and the declaration
    context that message needs (`scenarioMarkers` is already parsed at the
    call site; pass the declared-id set through).
- **Not touched** (hard constraints): the core engine cycle, the lane
  derivation algorithm (`_resolveLanes` classification logic itself), the
  TDD runner, the verify gate, the `**Type**` marker feature (escape hatch
  stays), `parseScenarioTypeMarkers`, the marker emitter.

## Root cause (code-level)

`uiAcceptanceIntent` (spec_parser.dart:147) alternates
`...|display(?:s|ed|ing)?|shows?|shown)\b` with **no subject context**:
`shows?` matches any Then-clause containing "shows". `_extractAcceptance`
(spec_parser.dart:981-985) applies `isUiAcceptance` to every UNDECLARED
scenario (the #830 fallback; feature 071 declarations outrank it). The
repro's Then-clause — "the decision_made event shows outcome: clarify
with the question, and the content_delta events contain the
clarification" — carries no UI surface noun, but `shows` alone routed
`BehaviorKind.widget`, and the #1000 noFlutter guard
(plan_command.dart:1861-1869) then refused the CORE lane with a fix
message that buries the marker remedy third.

## Remediation design

1. **Tiered classifier** (`isUiAcceptance`):
   - Tier A (exclusion): a new `_eventNounSubject` regex — an optional
     modifier word + an event/protocol noun
     (`events?|messages?|responses?|payloads?|streams?|frames?|notifications?`)
     directly followed by a content verb
     (`shows?|shown|includes?|contains?|carries?|presents?|returns?|holds?|has?`)
     — marks event-schema prose. A match returns `false` BEFORE any UI
     signal is consulted (criterion: "MUST NOT route widget-kind" holds
     even when a surface noun co-occurs in the payload description).
     Render/navigate/display are deliberately NOT in the content-verb
     list: they are the backbone of the #936 backward compat and out of
     the issue's named scope (shows/includes/carries).
   - Tier B (strong intent): `uiAcceptanceIntent` keeps the #830/#936
     grammar EXACTLY as-is minus the weak verbs — `render(s|ed|ing)`,
     `navigate(...)`, `display(s|ed|ing)` and the #830 layout nouns
     stay unconditional.
   - Tier C (co-occurrence): the weak appearance verbs
     `shows?|shown|appears?` (`appears?` joins so "the dialog appears
     with the title" routes widget) route widget-kind ONLY when a
     `_uiSurfaceNoun` co-occurs — the #830 layout nouns plus
     `dialogs?|screens?|pages?` (nouns the repo's own pinned fallback
     prose requires: "the page shows the settings form"). A noun alone
     ("they see the home screen") stays acceptance; widening the
     co-occurrence set can only restore pre-#1318 routing, never
     exceed it, because pre-fix the bare verb already sufficed.
2. **Guard message ordering** (`plan_command.dart`):
   - `_resolveLanes` gains `Set<String> declaredBehaviorIds = const {}`
     (named optional; call site passes `scenarioMarkers.keys.toSet()` —
     the map is already parsed before the call). No classification logic
     changes.
   - Classifier-routed (`!declaredBehaviorIds.contains(b.id)`): the
     refusal's fix clause LEADS with
     `--> fix: add **Type**: acceptance to the scenario (classifier
     guess, not a declaration)`.
   - Declared: the existing message is kept byte-for-byte (the marker is
     the author's word there; the remedy is the lane move).

## Risks / compatibility

- Bare "the app shows X" (no surface noun) narrows widget→acceptance:
  this is the prescribed mechanism ("require a UI surface noun for the
  verb-only matches"); the marker remains the escape hatch.
- "message shows" prose is excluded even when genuinely UI (e.g. "the
  error message shows a snackbar") — per the issue's explicit MUST; the
  escape hatch (`**Type**: widget`) covers it.
- Existing suites pinned to current behavior and verified compatible:
  bug_830 (classifier + plan widget section + #936 trio),
  plan_lanes_1000 (noFlutter guard, incl. the classifier-routed refusal
  test — its `contains('A1')` assertion stays satisfied), spec_parser
  hardening/declarations, 1183 template markers, 990 migrate-spec
  (marker emission reuses the classifier consistently).

## Migration/Draft-risk plan

No data migration. No config. The classifier is plan-time only; re-run
`zfa tdd plan` on affected specs re-derives lanes (issue #1309's
staleness machinery already covers re-plans).

## Validation plan (cloud-agent protocol)

- Per-file test runs only (never the full suite): kernel-cache cleanup
  (`rm -rf .dart_tool/test/ && rm -f $TMPDIR/dart_test.kernel.*`)
  before/after each `dart test <file>`.
- RED first: the new `test/plugins/tdd/bug_1318_noflutter_event_prose_test.dart`
  runs against unmodified lib/ and must fail exactly on the new
  behaviors (B1-B9) while the declared-path pin (B10) passes.
- GREEN: same files after the fix; then the compatibility set:
  bug_830, spec_parser_test, spec_parser_declarations_test,
  spec_parser_hardening_1196_test, plan_lanes_1000_test,
  plan_routing_provenance_test, spec_mutator_test, spec_fuzz_auditor_test,
  issue_990_migrate_spec_test.
- `dart analyze` on changed files; `dart format .` with zero remaining
  diffs; disk housekeeping per phase.
