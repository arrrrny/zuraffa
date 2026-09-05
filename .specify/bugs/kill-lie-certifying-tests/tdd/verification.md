---
feature: kill-lie-certifying-tests (bug #997)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 77e69f24 # baseline audited; the fix lands as this PR's commit on top
behaviors: 4
proven: 3
likely: 0
test_after: 0
no_test: 0
na: 1 # cli onDisk gate already landed green via #1033; this PR renames + documents
high_smells: 0
med_smells: 0
low_smells: 1 # compile-gate sandbox runs dart pub get (network/pub-cache dependent, 2 min timeout, mirrors the #1022 precedent)
criteria_total: 4
criteria_covered: 4
mutants_applied: 3
mutants_killed: 3
mutants_survived: 0
suite: 74/74 chunked fast-tier folders OK; analyze parity 345/345 issues vs baseline (0 new); format clean (0 changed)
audit_mode: fallback # same session wrote fix + tests + audit; no independent auditor — disclosed, not hidden
---

# TDD Verification: Kill 3 lie-certifying test suites (bug #997)

**Verdict: PASS_WITH_GAPS.** All four exit criteria are covered by tests
that now assert the truth: the xray deck suite pins the real runtime API
and passes a real `dart analyze` compile gate in a self-contained sandbox;
the TUI generator suite pins relative entity/use-case imports and
entity-qualified class names (and pins the *absence* of
`package:zuraffa/domain/`); the cli suite's analyze gate is real and
green. Three deliberate mutants — reintroducing the fictional symbol, the
broken package import, and a nonexistent import path — were each killed
by the reformed assertions. The full chunked fast suite (74 folders) is
green with zero new failures, `dart analyze` output is byte-identical to
baseline (345 pre-existing issues, all in untouched code), and `dart
format .` reports zero remaining diffs. The verdict is not `PASS` for two
disclosed reasons: (1) the audit is not independent — the same session
wrote the fixes, the tests, and this report; (2) one exit criterion
(`zfa make --with=tui` producing files end-to-end) is NOT PROVED at the
CLI level because the make pipeline does not invoke the TUI capability at
all (pre-existing wiring gap, out of this spec's mandated scope) — the
criterion is instead proved at the capability-output level, exactly where
the issue's demanded assertion lives.

## Behaviors and test-first evidence

Test list (4 behaviors) and their evidence classes. The reds were recorded
during this session's RED phase (verbatim outputs summarized below); the
fix + tests land in one commit, which per the rubric is `PROVEN` because
the cycle log (this file) holds the red.

| Behavior (bug #997 acceptance)                                                       | Class          | Evidence                                                                                                    |
| ------------------------------------------------------------------------------------ | -------------- | ----------------------------------------------------------------------------------------------------------- |
| 1. xray deck output uses the real runtime API and compiles (`dart analyze` gate)     | PROVEN         | R-1 red: 6/6 green while emitted file had 10 analyzer errors (uri_does_not_exist ×2, undefined_identifier ×4, undefined_function ×2, non_constant_list_element ×2, exit 3). G-1 green: 7/7 incl. new compile-gate test. Mutants 1 + 3 killed. |
| 2. TUI screens reference the target project via relative imports, never package:zuraffa/domain | PROVEN | R-2 red: 6/6 green while emitted imports were `package:zuraffa/domain/...` (unresolvable — zuraffa has no lib/domain; entity lives in the target project) and class names were fictional. G-2 green: 7/7 with exact relative-import assertions + `isNot(contains('package:zuraffa/domain/'))`. Mutant 2 killed. |
| 3. `zfa cli Foo` writes a file to disk (or is documented deprecated)                 | NOT_APPLICABLE | The onDisk + dart-analyze gate already exists and is green (landed via #1022/#1033 — verified 11/11 in this session's RED run). This PR's contribution: the misleadingly-named in-memory test was renamed to its actual string-contract role and the #997/#1022/#R7 trail is documented in-file. Not weakened: zero assertions removed or loosened. |
| 4. All three reformed suites pass                                                    | PROVEN         | G-3: 25/25 across the three files; 74/74 chunked fast-tier folders green; analyze parity; format clean. |

### Recorded red evidence (RED phase, before any fix)

R-1 — `zfa xray deck` (generated in a temp sandbox, then analyzed):

```
error - barcodes_xray_deck.dart:5:8 - Target of URI doesn't exist: 'package:flutter/foundation.dart'.
error - barcodes_xray_deck.dart:6:8 - Target of URI doesn't exist: 'package:zuraffa/src/presentation/xray/xray_control_deck.dart'.
error - barcodes_xray_deck.dart:10:7 - Undefined name 'kReleaseMode'.
error - barcodes_xray_deck.dart:11:3 - Undefined name 'XRayControlDeckRegistry'.
error - barcodes_xray_deck.dart:14:7 - The function 'XRayMockEntry' isn't defined.
error - barcodes_xray_deck.dart:14:7 - The values in a const list literal must be constants.
error - barcodes_xray_deck.dart:17:15 - Undefined name 'XRayMockType'.
... (10 issues, ANALYZE_EXIT=3) ... while: dart test test/commands/xray_deck_cli_test.dart → 6/6 All tests passed!
```

R-2 — TUI generator (same shape of lie): the emitted screens imported
`package:zuraffa/domain/product/product.dart` and
`package:zuraffa/domain/product/usecases/getlistusecase.dart` and
referenced classes `GetListUseCase` / `GetUseCase` — none of which exist
in any real scaffold — while
`dart test test/plugins/tui/generator/tui_screen_generator_test.dart`
reported 6/6 All tests passed.

R-3 — cli plugin: 11/11 pass including the onDisk dart-analyze gate
(already honest post-#1033); the remaining lie was the in-memory test's
*name* claiming analyzer coverage it never had.

### Recorded green evidence (GREEN phase, after the fix)

G-1: `dart test test/commands/xray_deck_cli_test.dart` → 7/7, including
`#997: generated deck passes dart analyze (compile gate)` — the generated
deck is dropped into a temp project that depends on zuraffa via path,
`dart pub get` runs, then `dart analyze <deck>` must exit 0 ("No issues
found!" observed).

G-2: `dart test test/plugins/tui/generator/tui_screen_generator_test.dart`
→ 7/7, including
`#997: entity + use-case imports are relative paths into the target project — never package:zuraffa/domain`.

G-3: combined run of all three files → 25/25 All tests passed.

## Deliberate mutants (no automated mutation tool scoped to these files)

| # | Mutant (source-level)                                                    | Killed by                                                                                       |
| --- | ------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------- |
| 1 | Reintroduce `XRayControlDeckRegistry.registerEntries(` in the deck template | xray suite: 3 failing matches (`[E]`); `contains('XRayControlDeck.instance.registerEntries')` + `isNot(contains('XRayControlDeckRegistry'))` fire |
| 2 | Reintroduce `package:zuraffa/domain/$entitySnake/...` entity import        | tui suite: 2 failing tests (relative-import assertion + `isNot(contains('package:zuraffa/domain/'))`) |
| 3 | Corrupt emitted import to `src/presentation/xray/xray_mock_entry.dart`     | compile-gate test fails (`dart analyze` exit ≠ 0 inside the test) — proves the gate catches *any* unresolvable output, not just the three fixed lies |

All three mutants were reverted; the restored tree re-verified green
(14/14 on the two affected files) before this report was written.

## Test smell audit

- **Compile-gate sandbox cost** (low): the new xray compile-gate test
  runs `dart pub get` + `dart analyze` in a temp project (2-minute
  timeout, ~10 s warm). This mirrors the accepted #1022 precedent in
  `test/cli/standard/cli_plugin_generator_test.dart`; without it the
  suite can only certify shape, which is precisely the lie this spec
  kills.
- **String-level assertions retained** (info): the TUI import assertions
  are exact-string `contains` checks. They are the assertions the issue
  explicitly demanded ("asserts the generated entity import uses a
  relative path ... not `package:zuraffa/...`") and are pinned with
  paired `isNot` guards, but they are shape checks, not a compile gate —
  a full TUI sandbox gate would additionally need nocterm + entity +
  use-case + repository stubs and is out of this spec's scope.
- No pre-existing assertion was removed, loosened, skipped, or renamed
  to dodge a filter; the one rename (`U48: generated file passes dart
  analyze` → string-contract name) makes the name *more* honest and is
  accompanied by an in-file pointer to the real analyze gate.

## Exit criteria — PROVED vs NOT PROVED

| Criterion                                                                | Status      | Where                                                                                                                             |
| ------------------------------------------------------------------------ | ----------- | --------------------------------------------------------------------------------------------------------------------------------- |
| All three reform'd tests pass                                           | **PROVED**  | 25/25 across the three files; chunked fast suite 74/74 folders green                                                              |
| `zfa xray deck` output passes `dart analyze`                            | **PROVED**  | compile-gate test (real analyzer run, exit 0) + manual sandbox reproduction ("No issues found!")                                   |
| `zfa make --with=tui` produces file not referencing `package:zuraffa/domain/` | **PROVED at capability-output level / NOT PROVED end-to-end** | The capability's emitted screens carry only relative domain imports (pinned by test). BUT the make pipeline never invokes `TuiPlugin`'s capability (`plugin_manager.dart` generate loop only runs `FileGeneratorPlugin`; `TuiPlugin extends ZuraffaPlugin`), so `zfa make --with=tui` currently emits no TUI files at all. Wiring the capability into the pipeline is a feature-completion change, beyond this spec's hard constraint ("do not change the production generators beyond fixing the lie-certifying assertions"). Root cause documented here for the follow-up. |
| `zfa cli Foo` writes a file or is documented deprecated                  | **PROVED**  | Writes a file: onDisk test asserts existence + `dart analyze` exit 0 (landed #1033, re-verified this session); NOT deprecated — documented in-file with the #997/#1022/#R7 trail |

## Suite health

- `tools/run_tests_chunked.sh`: 74/74 chunk folders pass (fast tier,
  `--exclude-tags flutter`). One transient failure observed mid-run
  (`dead_positional_grammar_test.dart` FR-1, process-spawning test under
  parallel folder load) reproduces neither in isolation nor on a clean
  checkout — classified flaky-environment, unrelated to this diff.
- `dart analyze`: 345 issues before == 345 issues after (sorted output
  diff is empty; the 31 error/warning-level items are pre-existing in
  `examples/todo_tdd/`, untouched by this PR).
- `dart format .`: second run reports 0 changed files.
