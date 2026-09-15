---
feature: 1418-mock-force-regen-interface
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: this working tree (lib fix uncommitted at audit time; RED committed at fecda600)
behaviors: 11
proven: 11
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: 2/2 hand-built mutants killed (guard-revert, wrong-surface delegate); deterministic mutation tool not applicable — zfa tdd verify gate returned not_assessed (no behavior artifacts registered, see below)
mutants_survived: 0
engine_gate: not_assessed (no behavior artifacts registered — bug workflow produces no feature behavior artifacts; fallback LLM-guided audit per .specify/extensions/tdd/commands/speckit.tdd.verify.md)
suite: scoped sweep +229 -0 (mock lane, barrel-surface utils, 1530/942/417 pins) + datasource lane +73 -0 + focused 1418 set +37 -0; dart analyze changed files: No issues found; dart format: 1299 files, 0 changed on the stability pass
---

# TDD Verification: mock create --force regenerates the pair; hide verified per-library (#1418)

**Verdict: PASS.** `--force` with a changed `--methods` selection now
regenerates the datasource interface together with the mock (T1), the pair
is structurally conforming and passes a real scoped `dart analyze` (T5 +
compile test), the mock lane hides only names the MOCK barrel actually
exports (T7/T10), and the non-force / append / revert / fresh-create
contracts are byte-preserved (T2/T3/T4). The issue's exact two-command
sequence passes live E2E certification (`mock-cert:deal@cd05085d — conforms`).

## Deterministic engine gate (recorded honestly)

`dart run bin/zfa.dart tdd verify --feature 1418-mock-force-regen-interface`
returned **`not_assessed` — no behavior artifacts registered**
(`mutation_was_run: false`, `restoration_verified: true`). The zfa-native
mutation audit keys off feature-workflow behavior artifacts, which the bug
workflow does not produce. Per the tdd.verify command, the fallback
LLM-guided audit below applies: test-first evidence, red-phase evidence,
test-smell rubric, hand-built mutants over the changed files, and
acceptance-criteria coverage.

## Cycle evidence (fresh from real runs)

| phase | command | evidence |
| ----- | ------- | -------- |
| red | `dart test test/plugins/mock/mock_builder_1418_force_interface_test.dart` (lib fix stashed) | `+3 -2` — T1 and T5 fail on the stale interface (`Expected: contains 'getList(ListQueryParams<Deal>'` / still `list(NoParams)`); T2/T3/T4 (the preserved contracts) green |
| red | `dart test test/plugins/mock/mock_builder_1418_force_compile_test.dart` (lib fix stashed) | `+0 -1` — setUpAll: after `--methods getList --force` the interface still declares `list(NoParams)` |
| red | `dart test test/utils/zuraffa_barrel_exports_mock_surface_test.dart` (lib fix stashed) | load error — `Member not found: 'EntityUtils.mockBarrelHideNames'` (fix API absent on master) |
| green | the same three files | all pass (interface suite 5/5, compile test 1/1, surface suite 11/11) |
| verify | scoped sweep: `dart test test/plugins/mock/ test/utils/zuraffa_barrel_exports_test.dart test/utils/zuraffa_barrel_exports_mock_surface_test.dart test/plugins/datasource/barrel_hide_unverified_1530_test.dart test/regression/issue_942_entity_name_collides_framework_export_test.dart test/regression/issue_417_mock_datasource_missing_interface_test.dart` | `+229 -0` |
| verify | `dart test test/plugins/datasource/` | `+73 -0` (the other `barrelHideNames` consumer lane) |
| verify | `bash scripts/repro_1418.sh` (sandbox project, path-dep on the checkout) | step 2 (`--methods getList --certify --force`): interface regenerates to `getList(ListQueryParams<Deal>)`, `✅ mock certification: Deal conforms to DealDataSource (mock-cert:deal@cd05085d)`, receipt `(conforms)`; pre-fix the same script dead-ended `unsatisfied: list` (receipt DRIFT) |
| analyzer | `dart analyze` over the 5 changed lib files + 3 changed test files | `No issues found!` |
| format | `dart format` changed files, then `dart format --output=none --set-exit-if-changed lib/ test/plugins/mock/ test/utils/zuraffa_barrel_exports_mock_surface_test.dart test/regression/issue_942_entity_name_collides_framework_export_test.dart` | 1299 files, 0 changed on the stability pass; suites re-run green after formatting |

## Mutation audit (hand-built mutants over the changed files)

| mutant | change | result | killed by |
| ------ | ------ | ------ | --------- |
| A — guard reverted | remove `\|\| forceRegeneratesInterface` from the `mock_builder.dart` interface emission guard | KILLED — `+3 -2` (T1, T5 fail) | T1 (force-regen behavior), T5 (structural conformance); T2/T3/T4 correctly still pass (the mutant preserves the pre-fix contracts) |
| B — wrong surface | `filterMock` delegating to `filter` (the pre-fix zuraffa-surface check) | KILLED — T7, T8, T10 fail | T7 (show-restricted re-export drops the name), T8 (mock-local declarations), T10 (builder-level emission) |

Deleting the two-surface resolution entirely (mutant C = full lib revert)
is the RED phase itself: the interface suite and compile test fail and the
surface suite does not compile. Both one-line mutants reproduce the bug and
are discriminated by the suite; no mutant survived.

## Acceptance-criteria coverage

| AC | Proven by |
| -- | --------- |
| 1. `--force` regenerates both interface and mock when `--methods` changes | T1 (MockPlugin sequence), compile test (real analyze on the regenerated pair), live repro step 2 |
| 2. `undefined_hidden_name` eliminated from generated datasource files | T7/T10 (no hide for a name the mock barrel does not export), T6/T8 (verified names still hidden), T9 (unresolved barrel → no combinator); #1530 pin stays green |
| 3. Certification passes on a force-regenerated pair with changed methods | compile test (`dart analyze` exit 0 — the gate's compile bar), live repro with `--certify` (`conforms` receipt) |
| 4. No regressions on non-force path | T2 (byte-identical non-force), T3 (append), T4 (fresh-create), T11 (seedForTest both surfaces), regression pins R1–R4 (#942, #1530, #1570, #417) all green, datasource lane 73/73 |

## Rubric notes

- Test-first: genuine red → green. The RED tests were committed first
  (fecda600, "TDD red") with the lib fix held back; the failures above were
  re-observed first-hand in this audit by stashing the lib fix and re-running
  the tracked suites against master code.
- Assertion strength: T1 asserts presence of the new contract AND absence of
  the stale member; T2/T3 assert byte-identity (not "still exists"); T10
  asserts the emitted import shape (`import 'package:zuraffa/mock.dart';`
  with no `hide Credentials`) not just "no exception"; the compile test
  asserts the real analyzer bar the certification gate dies on.
- No test smells: no sleeps, no order dependence, temp fixtures and barrel
  fixtures disposed in tearDown/tearDownAll, `ZuraffaBarrelExports` reset in
  tearDown to avoid cross-test static leakage, subprocess suites run with
  the repo-standard helpers.
- Mutation analog: both hand-built mutants killed (table above); the
  deterministic mutation tool is not runnable for a bug-scoped change
  (no behavior artifacts) — recorded as `not_assessed`, not as a pass.
