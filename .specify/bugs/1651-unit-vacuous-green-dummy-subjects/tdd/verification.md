---
feature: 1651-unit-vacuous-green-dummy-subjects
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: c722dbb5 (base) → fix/1651-unit-vacuous-green-dummy-subjects
behaviors: 5
proven: 3
likely: 2
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: n/a # no registry artifacts (bug-fix flow); the pre-fix tree replayed as the deliberate mutant — killed 3/3
mutants_survived: 0
suite: e2e 4/4 + writer/parser units 17/17 + tdd/commands 687/0 (11 groups) + loose tier 226 files (29 groups, pre-existing failures only) + fast tier 104 chunks green; analyze 0 issues; format clean
---

# TDD Verification: the engine lane certifies vacuous greens over dummy subjects (#1651)

**Verdict: PASS_WITH_GAPS.** All four acceptance criteria are proven end
to end against the REAL CLI: the pre-fix tree reproduces the issue
verbatim (`+1 -3` — the scaffold pair `(0, 0)` + `isA<int>()`, the
`return 0;` dummy PASSING the generated test, make certifying the
placeholder green), and the fix branch flips all three to green while
AC4 (real implementations certify unchanged) stays green on BOTH trees.
Gaps: test-first evidence is `LIKELY` for two driver-side behaviors
(their suites import the fix's API and cannot compile on the pre-fix
tree; the behavior-level red is covered by the e2e replay), and the
formal mutation audit was not run (no registry artifacts in the bug-fix
flow) — the pre-fix tree serves as the deliberate mutant instead.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| B1 (AC1) — gen derives the scenario's concrete values (`(2, 3)` + `equals(5)`) | PROVEN | Pre-fix RED: the generated test contains NO `(2, 3)` — the actual content is the post-#1259 scaffold shape (`subject_u1(0, 0)` + `isA<int>()`), verbatim the issue's complaint. Post-fix green: U1 asserts and passes on the real CLI run. |
| B2 (AC2) — the dummy FAILS the generated test (the assertion discriminates) | PROVEN | Pre-fix RED: the fixture's real `dart test` run exits 0 (`+1: All tests passed!`) over the `return 0;` dummy. Post-fix green: exit non-zero with `Expected:` (the `equals(5)` vs 0 assertion failure), never a compile error. |
| B3 (AC3) — make refuses the placeholder green (`outcome=vacuous-green`, exit 1, no green evidence) + the driver stop names the placeholder remedy | PROVEN | Pre-fix RED: make certifies (exit 0, `target test already passes — skipping generation`). Post-fix green: exit 1, `outcome=vacuous-green`, the refusal names the placeholder body + both artifact paths, the cycle log carries NO green entry; the driver-level pin (U5) proves `stopped_at=B-1651:make` with the placeholder remedy and no GUARD-ONLY vocabulary. |
| B4 (AC4) — real implementations with discriminating tests certify green unchanged | PROVEN | Green on BOTH trees: U4 passes on the pre-fix run AND on the fix branch (`outcome=skipped`, green evidence appended). The 687-test tdd/commands tier (incl. the #1310 U6 certification and the #1259/#1488 refusal suites) confirms no over-refusal. |
| B5 — the #1310 declared floor stays intact (scenario-less declared pairs keep the typed assertion) | LIKELY | plan_traces_cell_1310 U6 was RED against the first gate cut (real run recorded in the cycle log) and is GREEN under the reconciled predicate; the detector pins (U7/U8) grade both sides. LIKELY because the U6 suite itself cannot express the pre-fix red (the gate did not exist before this fix). |

No pre-existing test was weakened. Two suites were RETAGGED to the tier
policy they always belonged to (the e2e file → `['regression', 'e2e']`
per the #1510 make-command class; the driver remedy file → `['slow']`
per the #1626 precedent) — same tier_integrity contract, no assertion
changed.

## Findings

Ordered by severity. No `HIGH` findings.

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | MED | The scenario resolver is first-match: two scenarios naming the same declared method resolve to the spec's first — a spec whose second scenario carries the sharper example needs the traces hand-delta or a spec edit | `scenario_example.dart` `firstForTarget` (deterministic and documented) |
| 2 | MED | The gate exempts the declared-routed pair whose scenario yields no derivable value — a spec whose scenario prose mentions the method but carries no typed literal keeps the `isA<T>()` floor and certifies over a dummy. This is the #1310 contract by design, but it means scenario-literal-free specs are not protected by THIS gate (they keep the #1259 guard-only gate) | `scalar_dummy_subject.dart` `scalarDummyGreenMustRefuse`, plan_traces_cell_1310 U6 |
| 3 | LOW | The type-only classifier reads top-level `expect`/`expectLater` matcher arguments with a paren-depth scanner; exotic hand-authored assertion forms (custom matcher variables bound to value matchers) classify type-only and can trip the gate on a value-honest test — fail-safe direction (a false refusal is visible and remedied, a false green is not) | `vacuous_guard.dart` `_matcherExpressions` |
| 4 | LOW | The run driver's placeholder arm re-resolves declared routing + spec scenarios per stop (bounded reads); fixtures with huge specs pay a small one-shot cost at the stop | `run_driver_core.dart` `_placeholderGreenDetected` |

## Mutation results

No formal mutation run (the bug-fix flow produces no
`tdd/artifacts.json` for the spec-044 auditor). The pre-fix tree
replayed as the deliberate mutant — the strongest single mutant for
this fix, the bug itself:

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| pre-fix tree (`66103851`) + the e2e suite copied in verbatim | B1, B2, B3 | No | `+1 -3`: the scaffold pair survives (B1 red), the dummy passes (B2 red), make certifies the placeholder green (B3 red). Restoring the fix flips all three green and keeps B4 green — the mutant is verified both ways. |

## Traceability

| Criterion | Tests | End to end |
| --------- | ----- | ---------- |
| AC1 — scenario-derived assertions/arguments | U1 (e2e) + writer/parser units | Yes — real `zfa tdd plan`/`gen` on a real fixture |
| AC2 — the dummy fails the generated test | U2 (e2e) | Yes — real `dart test` subprocess in the fixture |
| AC3 — the placeholder green is refused + the driver stop | U3 (e2e) + U5 (driver, real `RunDriverCore` over the scripted fake zfa) | Yes — real CLI make; real driver core |
| AC4 — real implementations certify unchanged | U4 (e2e) + the 687-test commands tier | Yes |

## Regression coverage

| Batch | Suites | Result |
|-------|--------|--------|
| 1 | `test/plugins/tdd/commands` — 104 files, 11 kernel-cleaned groups | 687 passed / 0 failed |
| 2 | `test/plugins/tdd` + `services` loose tier — 226 files, 29 groups | green except bug_1259 U4-U6 + make_command_test ×10 — both BYTE-IDENTICAL on a pristine `66103851` worktree (pre-existing: uncommitted `lib/tdd/090-tdd-fixture/` residue; the #1587 build-skip vs #942/#1530 build-guard pins) |
| 3 | fast tier, 104 folder chunks (`agent` … `zap`, `tools/run_tests_chunked.sh` semantics) | all green (skips are the `slow`/`flutter`-tagged tiers by design) |
| 4 | `dart analyze lib test` | no issues in `lib/src` or `test` (only the pre-existing `lib/tdd/` fixture infos) |
| 5 | `dart format` (all changed/new files) | clean |

## Recommendation

Close the bug — verified end to end: the issue's repro reproduces on
the pre-fix tree and is dead on the fix branch, the #1259/#1310/#1488
contracts all hold, and the two pre-existing failure classes are
master-inherited (worktree-verified).
