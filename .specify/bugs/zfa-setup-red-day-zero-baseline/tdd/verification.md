---
feature: zfa-setup-red-day-zero-baseline (bug #626)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: af1e3b0
behaviors: 2
proven: 2
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: 100 # deliberate-mutant sampling, 4/4 caught, scope: changed files
mutants_survived: 0
suite: fast tier 2668 passed, 0 failed, 1 skipped (chunked); slow-tier gates 2 passed; dart analyze clean; dart format 0 changed
---

# TDD Verification: zfa setup ships a green day-zero baseline (issue #626)

**Verdict: PASS_WITH_GAPS.** Both assessment-required behaviors are `PROVEN`
end-to-end with red-first evidence and all four sampled deliberate mutants were
caught; the gaps are process-level, not evidential: the work was not planned
through the loop driver (no `tdd/test-list.md`), one supplementary assertion was
added test-after, and this audit was written by the same session that wrote the
tests.

`FEATURE_DIR` note: spec-kit's feature resolver
(`check-prerequisites.sh --json --paths-only`) errors on this branch — no
`.specify/feature.json` exists and this is a bug-triage fix, not a feature. The
audit target is the bug directory
`.specify/bugs/zfa-setup-red-day-zero-baseline/` per the bug extension's
per-bug report contract; the audited criteria come from `assessment.md`
("Tests to add or update") plus spec 041 FR-001/FR-006 and the naming contract
recorded in the maintainer decision on #626.

## Test-first evidence

| Behavior                                                                   | Class  | Evidence                                                                                                                                             |
| -------------------------------------------------------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| B1: fresh `zfa setup` → `lib/app.dart` + `<AppName>Container` → `flutter test` exit 0 (FR-001 + FR-006) | PROVEN | cycle 1 red recorded (live repro: exit 1, `app.dart` missing, `AppContainer` not found; committed gate: `Expected: true / Actual: <false> / zfa setup must emit lib/app.dart`); commit `af1e3b0` adds test + fix in one commit with the red in `tdd/cycle-log.md` |
| B2: `zfa app shell` succeeds on a fresh setup (bootstrap DI) and the smoke test stays green | PROVEN | cycle 2 red recorded (exit 1: `does not declare setupDependencies(...)`); same commit; same gate run green (`01:16 +2: All tests passed!`)             |

Changed-tests audit (the highest-signal check): one existing test was updated —
`test/cli/writers/tdd/smoke_test_writer_test.dart` asserted
`contains('AppContainer')` and now asserts
`contains('MyappContainer')` / `final container = MyappContainer();` plus a
negative check `isNot(contains('AppContainer()'))`. This is the #626 naming
contract (maintainer decision: the symbol derives from the app name), not a
weakening — the assertion stays strong and gains a stricter negative. No test
was renamed out of a filter, skipped, or excluded; no threshold was lowered.

Supplementary tests (not on the assessment's required list, disclosed):

- `app_module_writer_test.dart` (new, fast tier): writer contracts, naming
  table, skip-if-exists, dry-run, stub detection — PROVEN within cycle 1-2
  scope.
- `setup_command_test.dart::dry-run previews the day-zero app module and
  app-shell next step` — TEST_AFTER (cycle 3): the assertion was added after
  the Next Steps behavior existed. Recorded as finding 2.

## Findings

| # | Severity | Finding                                                                                                   | Evidence                                             |
| - | -------- | --------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| 1 | MED      | Gate-1 integration test is eager: setup success, app-module existence, symbol, attribution, smoke content, and flutter-test exit-0 in one test — several reasons to fail | `test/integration/day_zero_smoke_gate_test.dart:44-102` |
| 2 | MED      | Next-Steps dry-run assertion was added test-after (behavior existed before its test)                       | `test/commands/setup_command_test.dart:413-429`, cycle 3 |
| 3 | LOW      | The two gate tests duplicate the sandbox + setup fixture construction instead of sharing a factory        | `test/integration/day_zero_smoke_gate_test.dart:46-63, 110-125` |
| 4 | LOW      | `_runFlutterTest` hand-rolls a supervised subprocess runner; the profile's `helpers` cover CLI fakes but no flutter-test subprocess helper exists — hand-rolling was necessary, consider promoting it to `test/helpers/` | `test/integration/day_zero_smoke_gate_test.dart:170-202` |
| 5 | INFO     | The upgraded app reports 5 INFO-level `depend_on_referenced_packages`/`type_init_formals` analyzer notes; the zuraffa/go_router transitive imports mirror what the pre-existing app-shell and route generators already emit (main.dart, app_router.dart predate this fix) — not introduced by #626 | live `flutter analyze` on an upgraded app, this session |

No HIGH smells. The smell pass found the new tests naming behaviors as
sentences, deterministic (temp sandboxes with `tearDown` cleanup, no real clock
or network in assertions), specific about what broke (labeled `reason:` on the
critical expects), and using the recorded `runZfaSource` helper for CLI
subprocesses.

## Mutation results

No mutation tool is wired (per `.specify/memory/tdd-profile.md`); the rubric's
deliberate-mutant fallback was used on the highest-risk behaviors. One small
change each, run, restore exactly, re-run to confirm green. Never batched.

| Mutant                                                                     | Behavior            | Survived | Judgment                                            |
| -------------------------------------------------------------------------- | ------------------- | -------- | ---------------------------------------------------- |
| `app_module_writer.dart` — `containerSymbolFor` drops the `Container` suffix | B1 (naming contract) | No       | Caught: 7 unit failures (`+17 -7`), restore verified `+24` |
| `app_module_writer.dart` — app module drops `final GetIt di = GetIt.instance;` (bootstrap DI surface) | B1 (FR-001 DI container) | No       | Caught: 1 failure, restore verified                  |
| `app_shell_builder.dart` — `isFlutterCreateHelloWorldStub` returns `false` always (upgrade disabled) | B2 (upgrade path)   | No       | Caught: 1 failure, restore verified                  |
| `app_module_writer.dart` — bootstrap DI renames `setupDependencies` → `setupDeps` (preflight contract) | B2 (bootstrap DI)   | No       | Caught: 1 failure, restore verified                  |

Auditor procedure note: one earlier M3 attempt was discarded — `dart format`
had re-wrapped the target expression, so the mutation never entered the tree
(a no-op, not a survivor); it was re-applied with an `assert old in s` guard
and caught as recorded above.

Sampling scope: 4 of the 6 changed source files' behaviors (the symbol
contract, the FR-001 DI surface, the FR-006 upgrade gate, and the preflight
declaration). Not sampled: Next Steps text (cosmetic output), cycle-log
plumbing (data only).

## Traceability

| Criterion                                                  | Tests                                                                                                    | End to end |
| ---------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ----------- |
| FR-001 (smoke test asserts the generated app module + DI container can be constructed) | gate 1 (`day_zero_smoke_gate_test.dart`), smoke-test writer unit tests, app-module writer unit tests | Yes (`zfa setup` subprocess → `flutter test` subprocess) |
| FR-006 (after `zfa setup`, `flutter test` MUST exit 0)     | gate 1                                                                                                    | Yes         |
| Assessment: `zfa app shell` succeeds on a fresh setup + smoke green after upgrade | gate 2                                                                                            | Yes         |
| Naming contract (`<AppName>Container`, zfa-attributable)   | gate 1 (file content + `Generated by zfa`), `containerSymbolFor` unit table, negative `AppContainer()` check | Yes (symbol asserted in the running smoke test's source) |
| Refactor artifact: Next Steps include the app shell        | dry-run preview test (test-after — finding 2)                                                             | No (output text) |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- The full fast-tier suite was run **chunked** (per-folder `dart test` with
  kernel-cache cleanup): the whole-suite kernel compile peaks ~6.5G and does
  not fit this 9.9G disk. All fast-tier tests executed and passed (2668+1),
  but never in a single invocation. One `test/plugins` chunk initially
  reported 22 failures — all `No space left on device` (environmental);
  re-run sub-chunked, all green, including `test/plugins/skeleton`.
- Mutation was deliberate-mutant sampling on changed files only, not a tool
  score over the whole change surface.
- The xray branch of the app shell and the `--dart` (pure-Dart) setup path are
  untouched by this fix and were not re-audited. Known pre-existing, out of
  scope: `zfa tdd init` on a pure-Dart project still writes a smoke test that
  asserts an app module nothing generates (red there today, red before this
  fix) — flagged for a follow-up issue, not fixed inside #626's blast radius.
- Performance and load behavior: no criterion, no test, not assessed.
- Independence: the audit was performed by the session that wrote the tests
  (Hard Rule 2 disclosure). Every cited line was re-read from the files as
  they stand, and all mutants were executed fresh in this session, but the
  audit is not independent.

## Verdict summary

`PASS_WITH_GAPS` — the day-zero contract (FR-001 + FR-006 + the upgrade path)
is proven end-to-end, red-first, with the strong assertion intact and every
sampled mutant caught; the gaps are the absent loop-driven test list, one
test-after supplementary assertion, and the non-independent audit.
