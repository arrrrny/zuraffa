# Tasks 1318 — noFlutter false-positive on event prose (MVP-first, dependency-ordered)

Every behavior task below is driven by a failing test FIRST
(tdd/test-list.md). Non-behavioral tasks are handled by
speckit.implement after the green loop.

## Phase 0 — RED (test-first evidence)

- [x] T0.1 Add unit tests to
      `test/plugins/tdd/bug_1318_noflutter_event_prose_test.dart`:
      (a) the issue repro Then-clause ("the decision_made event shows
      outcome: clarify ... and the content_delta events contain the
      clarification") parses acceptance-kind; (b) the event-noun subject
      matrix (event shows/includes/carries, message shows, response
      includes, modifier forms, surface-noun-co-occurring payload) all
      parse acceptance; (c) the backward-compat matrix (screen shows,
      widget displays, dialog appears, renders, sidebar, the #936 trio)
      all parse widget. [SC-1, SC-3, SC-4]
- [x] T0.2 Add CLI-tier tests (same file): (a) the forklift repro —
      CORE lane, `flutter_allowed: false`, event-prose scenario → plan
      exits 0 and writes 04-ENGINE.md (no noFlutter refusal); (b) a
      classifier-routed widget behavior in a CORE lane → exit 2 and the
      refusal leads with the marker remedy; (c) a DECLARED
      `**Type**: widget` behavior in a CORE lane → exit 2 and the
      refusal keeps the lane-move remedy. [SC-1, SC-2, SC-5]
- [x] T0.3 Run the new tests against unmodified lib/, record RED
      evidence into `tdd/verification.md`. Kernel-cache cleanup
      before/after; per-file runs only.

## Phase 1 — GREEN (the fix)

- [x] T1.1 `spec_parser.dart`: remove `shows?|shown` from the
      unconditional `uiAcceptanceIntent` alternation; add `dialogs?`,
      `screens?` to the surface-noun alternation. [SC-3, SC-4]
- [x] T1.2 `spec_parser.dart`: add `_eventNounSubject` (event/protocol
      noun + content verb, optional modifier word) and re-gate
      `isUiAcceptance` on it (exclusion first, strong intent second).
      [SC-1, SC-3]
- [x] T1.3 `plan_command.dart`: thread `scenarioMarkers.keys.toSet()`
      into `_resolveLanes` as `declaredBehaviorIds` (named optional
      param, default const {}); branch the noFlutter guard's fix
      message — classifier-routed leads with the marker remedy,
      declared keeps the lane-move remedy byte-for-byte. [SC-2, SC-5]
- [x] T1.4 Re-run the new test file; all green; record GREEN evidence
      in `tdd/verification.md`.

## Phase 2 — compatibility sweep + implement (non-behavioral)

- [x] T2.1 Compatibility runs (per-file, kernel-cleaned):
      bug_830_widget_subject_kind_test.dart, spec_parser_test.dart,
      spec_parser_declarations_test.dart,
      spec_parser_hardening_1196_test.dart, plan_lanes_1000_test.dart,
      plan_routing_provenance_test.dart, spec_mutator_test.dart,
      spec_fuzz_auditor_test.dart, issue_990_migrate_spec_test.dart.
      All pass unmodified (backward-compat proof). [SC-4, SC-5]
- [x] T2.2 `speckit.analyze` cross-artifact drift pass: spec ↔ plan ↔
      tasks ↔ test-list consistency; fix drift, no scope growth.
- [x] T2.3 `dart analyze` on changed files; `dart format .`; zero
      remaining diffs. [SC-6]
- [x] T2.4 Disk housekeeping: remove kernel caches
      (`.dart_tool/test/`, `$TMPDIR/dart_test.kernel.*`, test
      fixtures/scratch dirs); confirm `df -h .` healthy.
- [x] T2.5 Write `tdd/verification.md` (test-first + mutation-strength
      evidence); commit spec artifacts + fix + tests together
      (`fix(1318):` Conventional Commits), push, open PR closing #1318
      with the SSE plan success demo.

## Dependency order

T0.1 → T0.2 → T0.3 (RED) → T1.1 → T1.2 → T1.3 → T1.4 (GREEN) →
T2.1 → T2.2 → T2.3 → T2.4 → T2.5. No parallelizable tracks
(two-file fix, single classifier choke point).
