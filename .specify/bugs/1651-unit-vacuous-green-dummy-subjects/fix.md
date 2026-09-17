# Fix Report: 1651-unit-vacuous-green-dummy-subjects

- **Slug**: 1651-unit-vacuous-green-dummy-subjects
- **Fixed**: 2026-09-16
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: ./tdd/cycle-log.md, ./tdd/verification.md

## Summary

The unit test generator now derives the scenario's concrete values
(remediation 1): a declared contract whose spec acceptance scenario
carries example values generates `subject_u1(2, 3)` +
`expect(result, equals(5))` instead of the scaffold representatives
`(0, 0)` + `isA<int>()`, so a func-scaffolded `return 0;` dummy FAILS
the generated test (the honest red). Green certification no longer
trusts a type-only assertion over a placeholder body (remediation 2):
make refuses with `outcome=vacuous-green` (exit 1, no green evidence)
and the run driver's stop names the placeholder remedy while preserving
the `stopped_at=<id>:make` machine contract (remediation 3). Real
implementations with discriminating tests keep certifying green
unchanged (AC4). The #1310 dead-end removal stays intact: a
declared-routed pair whose scenario carries no derivable value keeps
the typed `isA<T>()` floor and certifies (plan_traces_cell_1310 U6).

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/services/scenario_example.dart` | added | The scenario value model (`ScenarioValue`, `fitsType`) + `ScenarioResolver` (`firstForTarget`, `claimArgumentForType`, `expectedForType`). Pure data + parsing helpers. |
| `lib/src/plugins/tdd/services/spec_parser.dart` | modified | `parseScenarioExamples` — the Given/When/Then block walk reusing the acceptance-lane header recognition; extracts quoted strings, boundary-checked numbers, booleans. |
| `lib/src/plugins/tdd/services/behavior_test_writer.dart` | modified | `scenarioExample` field; `_declaredAssertion` prefers the scenario's expected literal (`equals(5)`) and scenario-claimed arguments; byte-identical legacy fallback when no scenario value fits. Acceptance rows untouched. |
| `lib/src/plugins/tdd/commands/gen_command.dart` | modified | Resolves the scenario naming the declared method from `specs/<feature>/spec.md` (fail-open) and threads it into the unit writer. |
| `lib/src/plugins/tdd/services/scalar_dummy_subject.dart` | added | `contentCarriesScalarDummyBody` (parametrized scalar literal bodies), `scalarDummyGreenMustRefuse` (the ONE gate decision incl. the #1310 floor), `scalarDummyGreenRemedy` (single-sourced `--> fix:` line). |
| `lib/src/plugins/tdd/services/vacuous_guard.dart` | modified | `contentIsTypeOnlyAssertion` — every expect's matcher carries no value; `isTrue`/`isFalse` are the declared-boolean VALUE pins (#1310 class). |
| `lib/src/plugins/tdd/commands/make_command.dart` | modified | Step 9b: unit rows refuse the placeholder green (`vacuous-green`, exit 1, no evidence append) via the shared decision predicate; declared routing + spec scenarios resolved fail-open for the #1310 floor. |
| `lib/src/plugins/tdd/commands/run_driver_core.dart` | modified | The vacuous-green stop's placeholder arm fires on the SAME predicate; remedy single-sourced; machine contract unchanged. |
| `test/plugins/tdd/services/scenario_example_1651_test.dart` | added test | Parser boundaries + resolver contract (9 tests). |
| `test/plugins/tdd/bug_1651_scenario_assertions_test.dart` | added test | Writer scenario derivation, legacy fallback, acceptance non-leak, detector pins (8 tests). |
| `test/plugins/tdd/commands/bug_1651_vacuous_green_e2e_test.dart` | added test | AC1-AC4 end to end through the real CLI (regression+e2e tier). |
| `test/plugins/tdd/commands/bug_1651_driver_remedy_test.dart` | added test | The driver stop's placeholder arm over the real driver core (slow tier). |

## Local Verification

- Commands run: `dart test` (the suites recorded in ./tdd/cycle-log.md
  and ./tdd/verification.md) → the four ACs green; 687 tdd/commands
  tests + the chunked fast tier + the 226-file loose tier green except
  the two pre-existing classes verified byte-identical on the pristine
  base worktree.
- `dart analyze lib test` → no issues in `lib/src` or `test` (only the
  pre-existing `lib/tdd/` fixture infos).
- `dart format` over all changed/new files → clean.
- Manual checks: the pre-fix RED run (base `66103851` + the e2e suite
  copied in verbatim) reproduced the issue verbatim: the generated test
  carries `(0, 0)` + `isA<int>()`, the `return 0;` dummy passes it, and
  make certifies the placeholder green.

## Deviations from Assessment

1. The remediation-1 shape is the scenario's FIRST derivable literal
   (first-match, deterministic) rather than a full example table — the
   assessment's `subject_u1(2, 3)` + `equals(5)` contract is met for
   the reported spec shape; multi-scenario disambiguation beyond
   first-match is left to the traces hand-delta seam.
2. The make gate EXEMPTS the declared-routed pair whose scenario
   carries no derivable value (the #1310 floor, plan_traces_cell_1310
   U6) — the assessment's "type-only ⇒ refuse" reading was too broad
   and broke the #1310 contract; the reconciled predicate
   (`scalarDummyGreenMustRefuse`) refuses only when the spec
   positively names a derivable outcome or the pair is not
   declared-routed at all.
3. `isTrue`/`isFalse` classify as VALUE matchers (the declared-boolean
   pins — the twins of `equals(true)`/`equals(false)`), keeping the
   #1310 U6 certification intact.

## Follow-ups

- The mutation audit (`zfa tdd verify`, spec 044 FR-012..023) requires
  registry artifacts (`tdd/artifacts.json`) that the bug-fix flow does
  not produce; the verification instead cross-checks the full tier
  matrix and replays the pre-fix tree as the deliberate mutant.
- The pre-existing `lib/tdd/090-tdd-fixture/` residue dependency
  (bug_1259 U4-U6) and the #1587-vs-#942 build-guard pin drift
  (make_command_test) are unrelated failures confirmed on master —
  separate issues, not touched here.
