# TDD test list — SPEC 1689: scenario × zero-scaffold fast stop (skip the guaranteed-failing make attempt)

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| U-1689-b1 | test/plugins/tdd/services/scaffold_attempt_forecast_test.dart | unit | an `int` gen stub (`return`-predicted `0`) + a test asserting `equals(5)` — the forecast fires: int / `0` / `5` (the issue's zcalc3 U1 shape) | issue #1689 constraint 1 | RED → GREEN |
| U-1689-b2 | test/plugins/tdd/services/scaffold_attempt_forecast_test.dart | unit | a `double` stub + `equals(2.0)` fires; `String` stub + `equals('Hello Alice')` fires (the name-dummy differs); `bool` stub + `equals(false)` fires | the literal-dummy vocabulary | RED → GREEN |
| U-1689-b3 | test/plugins/tdd/services/scaffold_attempt_forecast_test.dart | unit | zero-matching literals stay SILENT: `equals(0)` vs int, `equals(0.0)` vs int (Dart `num` equality), `equals(true)` vs bool, `equals('<fn name>')` vs String — the attempt may legitimately pass | FR-004, acceptance 2 | RED → GREEN |
| U-1689-b4 | test/plugins/tdd/services/scaffold_attempt_forecast_test.dart | unit | non-literal scaffolds stay silent: `void`, `num`, `int?` (nullable), `Object`, entity tokens — the still-red UnimplementedError branch, not a zero value | FR-001 fail-open | RED → GREEN |
| U-1689-b5 | test/plugins/tdd/services/scaffold_attempt_forecast_test.dart | unit | a marker-less (hand-authored) subject never fires — the gen provenance marker is part of the proof | FR-001 provenance safety | RED → GREEN |
| U-1689-b6 | test/plugins/tdd/services/scaffold_attempt_forecast_test.dart | unit | a legacy no-arg stub never fires — the description-derived body is a different scaffold the gate must not speak for | FR-001 | RED → GREEN |
| U-1689-b7 | test/plugins/tdd/services/scaffold_attempt_forecast_test.dart | unit | non-stub subjects never fire: a dummy `return 0;` body, a real implementation, the contract-derived entity-typed stub (#1565) — `funcRewritableStubPattern` misses | acceptance 4 | RED → GREEN |
| U-1689-b8 | test/plugins/tdd/services/scaffold_attempt_forecast_test.dart | unit | guard-only and type-only+marker tests (the non-scenaried shapes) never fire — no `equals(<literal>)` in the assertion set | constraint 3, acceptance 3 | RED → GREEN |
| U-1689-b9 | test/plugins/tdd/services/scaffold_attempt_forecast_test.dart | unit | unparseable matcher args (`equals(result)`, escaped-quote strings) never discriminate — fail-open, the attempt runs | FR-004 | RED → GREEN |
| U-1689-b10 | test/plugins/tdd/services/scaffold_attempt_forecast_test.dart | unit | mixed-kind literals discriminate (`equals('5')` vs an int dummy) and the forecast reports the FIRST offending literal verbatim | FR-004 | RED → GREEN |
| U-1689-b11 | test/plugins/tdd/services/scaffold_attempt_forecast_test.dart | unit | escape-bearing string args are UNDECODABLE and never discriminate: `equals('\u0067reet')` (the value `greet`) vs the `greet` String dummy, `equals('It\'s')` — the raw matched text is not the value, so the comparator fails open (review fix: escaped literals) | FR-004 | RED → GREEN |
| E-1689-e1 | test/plugins/tdd/commands/bug_1689_scenario_zero_scaffold_fast_stop_e2e_test.dart | e2e | the scenaried make (stub + `equals(5)`) stops `outcome=would-never-pass` BEFORE the pipeline: zero zfa spawns in the argv log, the #1689 diagnosis + hand-step remedy printed, exit 1, no green evidence, subject byte-identical, wall time printed | SC-001/SC-002, acceptance 1 | RED → GREEN |
| E-1689-e2 | test/plugins/tdd/commands/bug_1689_scenario_zero_scaffold_fast_stop_e2e_test.dart | e2e | guard-only behavior: `outcome=vacuous-green` at the 3c preflight — unchanged fast refusal, no func spawn | SC-003, acceptance 3 | GREEN (pin) |
| E-1689-e3 | test/plugins/tdd/commands/bug_1689_scenario_zero_scaffold_fast_stop_e2e_test.dart | e2e | type-only + marker over a dummy subject: `outcome=vacuous-green` at the 9b gate — unchanged refusal shape | SC-003, acceptance 3 | GREEN (pin) |
| E-1689-e4 | test/plugins/tdd/commands/bug_1689_scenario_zero_scaffold_fast_stop_e2e_test.dart | e2e | zero-matching `equals(0)` over the stub: the gate stays silent — `tdd func` SPAWNS (the #1587 argv log observes it), the outcome is not `would-never-pass` | acceptance 2 | RED → GREEN |
| E-1689-e5 | test/plugins/tdd/commands/bug_1689_scenario_zero_scaffold_fast_stop_e2e_test.dart | e2e | a real implementation with a discriminating scenario test certifies via the unchanged skip transition: `outcome=skipped`, green evidence appended | acceptance 5 | GREEN (pin) |

Guard pins (pre-existing, unchanged and green against the fix):

| id | suite | description |
| -- | ----- | ----------- |
| #1651 U1/U2 | test/plugins/tdd/commands/bug_1651_vacuous_green_e2e_test.dart | the scenario-derived assertion derivation + the dummy-fails-value-assertion pair — untouched |
| #1651 U3/U4 | test/plugins/tdd/commands/bug_1651_vacuous_green_e2e_test.dart | the 9b placeholder refusal + the real-implementation skip — untouched |
| #1651 services | test/plugins/tdd/bug_1651_scenario_assertions_test.dart, test/plugins/tdd/services/scenario_example_1651_test.dart, test/plugins/tdd/commands/bug_1651_make_dummy_green_refusal_test.dart | the #1679 derivation and the #1651 gate pins — untouched |

## Red evidence (pre-fix, this session)

Recorded in `tdd/verification.md` § Red (the e2e probe run against base
`a9329746` and the unit suite's compile-error red for the new seam).
