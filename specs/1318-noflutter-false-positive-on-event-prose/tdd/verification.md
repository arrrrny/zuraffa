# TDD Verification — Spec 1318 noFlutter false-positive on event prose

## Test-first evidence (RED recorded before implementation)

The new behaviors (tdd/test-list.md B1–B10) were written to
`test/plugins/tdd/bug_1318_noflutter_event_prose_test.dart` and run
BEFORE any lib/ change. Red runs were executed after
`rm -rf .dart_tool/test/ && rm -f $TMPDIR/dart_test.kernel.*`
kernel-cache cleanup, per the cloud-agent protocol. Single-file runs
only — never the full suite.

Command:

```
rm -rf .dart_tool/test/ && rm -f $TMPDIR/dart_test.kernel.*
dart test test/plugins/tdd/bug_1318_noflutter_event_prose_test.dart
```

RED observation: `00:00 +3 -7: Some tests failed.` — exactly the seven
new-behavior tests failed; the three regression pins (B6 #936 trio,
B7 marker escape hatch, B10 declared-path remedy) passed pre-fix, as
the test list predicted:

| Behavior | RED observation |
|---|---|
| B1 issue repro Then-clause | `Expected: 'acceptance' Actual: 'widget'` — the exact #1318 misroute |
| B2 event-noun matrix | `"the event shows the outcome" ... Actual: <true>` — classifier routed event prose widget-kind |
| B3 surface noun in payload | `the event shows the dialog id in its payload → true` — exclusion missing |
| B4 verb-only weak match | `the app shows a spinner → true` — bare `shows` sufficed |
| B5 surface-noun subjects | `the dialog appears with the title → false` — no unconditional `dialog` noun |
| B8 CLI all-CORE SSE spec | `Expected: <0> Actual: <2>` — `lane contract FAILED — noFlutter guard: behavior "A2" (AC-2) is routed widget-kind ... but declared CORE. --> fix: declare it SKIN (or BOTH), or add \`**Type**: acceptance\` to the scenario.` — the remedy buried third, the issue's exact refusal |
| B9 remedy ordering | the leading marker remedy absent from the refusal |

The red output pins the root cause verbatim: `shows` matched the
#830/#936 alternation with no subject context and the guard's fix
message led with the lane move.

## Green evidence (after implementation)

Fix: `spec_parser.dart` — `shows?|shown` removed from the unconditional
`uiAcceptanceIntent` alternation; new `_eventNounSubject` exclusion
checked FIRST; weak appearance verbs (`shows?|shown|appears?`) gated on
a co-occurring `_uiSurfaceNoun` (#830 layout nouns + `dialogs?|screens?|pages?`).
`plan_command.dart` — `_resolveLanes` gains `declaredBehaviorIds`
(declaration context from the already-parsed `scenarioMarkers`); the
noFlutter guard's fix message LEADS with the marker remedy for
classifier-routed behaviors and keeps the lane-move remedy byte-for-byte
for declared ones. Only these two lib/ files changed (scope fence —
engine cycle, lane derivation algorithm, TDD runner, verify gate, marker
feature untouched).

Same command after the fix (kernel cache cleaned before the run):

```
00:00 +10: All tests passed!
```

| Suite | Result |
|---|---|
| test/plugins/tdd/bug_1318_noflutter_event_prose_test.dart (10 behaviors) | 10 passed, 0 failed |

## Compatibility sweep (existing suites, UNMODIFIED)

All per-file/per-batch runs with kernel-cache cleanup before/after:

| Batch | Suites | Result |
|---|---|---|
| 1 | bug_830_widget_subject_kind_test.dart, services/spec_parser_test.dart, services/spec_parser_declarations_test.dart, services/spec_parser_hardening_1196_test.dart, commands/plan_lanes_1000_test.dart (+ the #1318 file) | `00:03 +85: All tests passed!` |
| 2 | commands/plan_routing_provenance_test.dart, services/spec_mutator_test.dart, services/spec_fuzz_auditor_test.dart, issue_990_migrate_spec_test.dart (+ the #1318 file) | `00:03 +66: All tests passed!` |
| 3a | bug_1183_speckit_template_version_marker_test.dart, bug_1261_visual_contract_surface_test.dart, commands/spec_1142_adaptive_layout_test.dart, services/routing_resolver_test.dart, services/function_contracts_parsing_test.dart, bug_965_i18n_key_contracts_test.dart | `00:06 +72: All tests passed!` |
| 3b | property/spec_corpus_fuzz_1196_test.dart, cli/services/corpus_importer_test.dart, commands/corpus_command_test.dart | `00:05 +27: All tests passed!` |

Total: 250 targeted test results, 0 failures. Post-format re-run of the
#1318 file: 10 passed, 0 failed.

Two mid-loop findings fixed during the green loop (refactor step of
red-green-refactor):

1. The first cut added `dialogs?|screens?` to the UNCONDITIONAL noun
   alternation — broke spec_parser_test's pinned
   "they see the home screen" → acceptance. Moved the nouns into the
   co-occurrence set only.
2. plan_routing_provenance_test pins the repo's own fallback contract
   "the page shows the settings form" → widget (legacy classifier). Added
   `pages?` (and `appears?`) so genuine UI prose keeps its pre-#1318
   routing — the co-occurrence set can only restore pre-fix routing,
   never exceed it (pre-fix the bare verb already sufficed).

## Acceptance-criteria coverage

| SC | Proof |
|---|---|
| SC-1 repro routes CORE, plan succeeds | B1 (unit: repro Then-clause → acceptance) + B8 (CLI: the forklift lane shape — CORE lane, `flutter_allowed: false` — plans clean: exit 0, `04-ENGINE.md` written with 4 CORE behaviors, no `noFlutter guard` in output) |
| SC-2 remedy ordering | B9 (classifier-routed refusal contains `--> fix: add **Type**: acceptance to the scenario (classifier guess, not a declaration)` and NOT `declare it SKIN`) + B10 (declared `**Type**: widget` refusal contains `declare it SKIN (or BOTH)` and NOT `classifier guess`) |
| SC-3 event-noun subjects never classifier-widget | B2 (13-member matrix incl. modifier forms `decision_made event shows`, `content_delta events contain`, `SSE response includes`) + B3 (`the event shows the dialog id in its payload` stays acceptance) + B4 (verb-only `shows` without surface noun → acceptance) |
| SC-4 backward compat | B5 (screen shows / widget displays / dialog appears / sidebar / page shows) + B6 (the exact #936 trio from bug_830, unmodified) + the 4 compatibility batches above (250 results, all green) — incl. plan_lanes_1000's guard suite and plan_routing_provenance's fallback-window pins |
| SC-5 marker escape hatch untouched | B7 (repro prose + explicit `**Type**: widget` → widget; explicit `**Type**: acceptance` on UI prose → acceptance — declaration outranks prose in both directions) + B10 (declared path keeps its remedy) + hardening_1196/declarations suites green |
| SC-6 scope fence + analyze/format | `dart analyze lib/src/plugins/tdd/services/spec_parser.dart lib/src/plugins/tdd/commands/plan_command.dart test/plugins/tdd/bug_1318_noflutter_event_prose_test.dart` → `No issues found!`; `git status` shows exactly the two lib/ files + the new test + spec artifacts; `dart format` on the three changed Dart files → `0 changed` (idempotent) |

## Test-strength / mutation evidence

The full mutation engine (`zfa tdd verify`'s MutationAuditor) was NOT
run: the cloud-agent protocol forbids the full suite (≈6.5 GB kernel
cache overflow) and the auditor mutates scope subjects beyond this
fix's two files. Honest compensating evidence:

- The RED run itself is the primary mutant killed: pre-fix lib/ IS the
  mutant "event-noun exclusion absent + bare shows routes widget", and
  it failed exactly the 7 new-behavior tests while the pins stayed
  green — the test suite detects the bug the fix removes.
- The trivial mutant `isUiAcceptance → always false` is killed by B5/B6
  (they demand widget for genuine UI prose).
- The trivial mutant `isUiAcceptance → uiAcceptanceIntent only` (drop
  the exclusion) is killed by B1/B2/B3 (event prose would route widget).
- The mutant "guard message unchanged (remedy buried third)" is killed
  by B9; the mutant "both branches lead with the marker remedy" is
  killed by B10.
- The mutant "drop `declaredBehaviorIds` (always treat as declared)" is
  killed by B9 (classifier-routed case would print the lane-move
  remedy).

## Disk housekeeping

Kernel caches removed before/after every `dart test` invocation
(`.dart_tool/test/`, `$TMPDIR/dart_test.kernel.*`); test temp dirs are
created under `Directory.systemTemp` and deleted in `tearDown`/`finally`
by the suites themselves; `dart format .` formatting of three
PRE-EXISTING unformatted records (corpus/regression/*/u2-flow/u1_test.dart
×2, specs/1256-.../tdd/red_repro.dart) was REVERTED — byte-compared
regression-corpus/red-repro records outside #1318 scope (the spec-1312
precedent). Final `df -h .` recorded in the delivery report.
