---
feature: 020-skeleton-plugin-bones
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 30be42a1
behaviors: 49
proven: 0
likely: 49
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 11
criteria_covered: 11
mutation_score: unmeasured # no mutation tool in profile; 8 deliberate mutants across 2 passes, all caught after remediation
mutants_survived: 0
suite: 57 passed, 0 failed, ~20s (scoped: test/plugins/skeleton/)
---

# TDD Verification: Skeleton Plugin — Bare-Bones Feature Scaffold

**Verdict: PASS_WITH_GAPS.** Pass 2 (remediation re-audit). Both pass-1 surviving
mutants are now caught by new failing-path tests (U37, U38), all 6 smell findings
are remediated, and every behavior has recorded red evidence. The gap that caps
the verdict: the loop ran **uncommitted**, so git history cannot corroborate
test-first ordering — `PROVEN` is unreachable for this feature, and 20 behaviors
earned their reds retroactively in an evidence-completion pass (cycle 46), which
proves the tests can fail but not that they were written first.

This audit was NOT fully independent: the orchestrating session directed the
loop. The smell pass was delegated to a fresh-context subagent; every cited line
was vetted by the auditor. Remediation work was re-verified by the auditor
(mutants re-run, fixed smells spot-checked against the files as they stand).

## Test-first evidence

| Behavior(s) | Class | Evidence |
| --- | --- | --- |
| U1, U5, U9, U13, U15, U17, U18, U20, U23–U30, U32–U36, A1–A6 | LIKELY | red command + output recorded per cycle (cycles 1–43); no git history (uncommitted loop) |
| U2–U4, U6–U8, U10–U12, U14, U16, U19, U22 | LIKELY | pass 1: batched entries with only the first red; pass 2: per-behavior mutant reds recorded in cycle 46 (ordering not re-provable, disclosed) |
| U21, U31 | LIKELY | pass 1: `red: N/A`; pass 2: U21 now cites the U37 rejection test + the T042 package-policy test (cycle 47 red); U31's stderr leg pinned (cycle 48 red) |
| A7–A11 | LIKELY | pass 1: no red recorded; pass 2: targeted mutant reds recorded in cycle 46 |
| U37, U38 | LIKELY | remediation cycles 44–45, mutant-checked reds recorded |

No existing tests were weakened at any point. `tasks.md`: all 45 tasks `[X]`,
every behavior-marked task's markers DONE on the list; pass-1 checkbox clobber
(T015–T018/T032) was corrected after verifying the behaviors DONE.

## Findings

All pass-1 findings are closed; each was re-verified against the files as they
stand and, where applicable, by re-running the surviving mutant.

| # | Severity | Pass-1 finding | Disposition |
| --- | -------- | -------------- | ----------- |
| 1 | HIGH | U21 rejection path untested (mutant survived) | CLOSED — U37 test fails when the check is neutralized (re-run by auditor: caught); T042 added package:-import rejection (cycle 47) |
| 2 | HIGH | spec_version format unpinned (mutant survived) | CLOSED — U38 test fails on the `'sha1:'` mutant (re-run by auditor: caught) |
| 3 | MED | 20 behaviors without recorded reds | CLOSED — cycle 46 evidence-completion pass, with ordering disclaimer |
| 4 | MED | U14 asserted class name, not path | CLOSED — asserts `lib/entities/cart_item.dart` + barrel-export path flow |
| 5 | MED | `package:` imports silently skipped (tests + production) | CLOSED — declared-dependency policy enforced in `_validate` and in the A2/A11 scans |
| 6 | MED | A3 redundant with A4 | CLOSED — A3 is now a three-feature chain (C→B→A) asserting transitive structure |
| 7 | MED | A8 string-presence only | CLOSED — adds `dart format --output=none` parse check on every emitted stub |
| 8 | LOW | duplicated `captureOutput`/`copyFixture` | CLOSED — extracted to `test/plugins/skeleton/helpers/` |

New sub-gap found during remediation, closed in the same pass: U31's
stderr-message leg was unpinned (cycle 48 red recorded, assertions strengthened).

## Mutation results

No mutation tool in the profile; deliberate mutants only. Pass 1 sampled 6
high-risk behaviors; pass 2 re-ran the 2 survivors after remediation.

| Mutant | Behavior | Pass 1 | Pass 2 |
| --- | --- | --- | --- |
| cycle throw removed (`dependency_graph.dart`) | U3/U4 | Caught | — |
| import rejection → `if (false)` (`bone_command.dart`) | U21/U37 | **Survived** | Caught by U37 |
| specVersion → constant (`spec_reader.dart`) | U7 | Caught | — |
| missing-entity throw removed (`dependency_resolver.dart`) | U20 | Caught | — |
| `'sha256:'` → `'sha1:'` (`bone_generator.dart`) | U12/U38 | **Survived** | Caught by U38 |
| CycleException with empty members (`dependency_graph.dart`) | U25/A5 | Caught | — |

Plus the cycle-46/47/48 targeted mutants (one per remediated behavior), each
caught by its behavior's test. Sample of 8+ behaviors of 49 — not exhaustive.
Every mutant was restored exactly and the suite re-confirmed green (57/57).

## Traceability

| Criterion | Behaviors | Tests | End to end |
| --- | --- | --- | --- |
| US1.1 (bone contents) | A1, U13–U18 | sc_001, builder/generator tests | Yes |
| US1.2 (self-contained) | A2, U21, U37 | sc_001 + rejection tests | Yes (policy enforced, no skips) |
| US1.3 (dep recorded) | A3, U11, U23 | sc_002 (three-feature chain) | Yes |
| US2.1 (cross-ref edge) | A4, U23 | sc_002 | Yes |
| US2.2 (cycle error) | A5, U3, U4, U25 | sc_002, graph/resolver tests | Yes |
| US2.3 (empty deps) | A6, U2, U10 | sc_002 | Yes |
| US3.1 (from specify spec) | A7, U5, U27 | sc_003 | Yes |
| US3.2 (valid test stubs) | A8, U17 | sc_003 (incl. parse check) | Yes |
| US3.3 (xray preserved) | A9, U33 | sc_003 | Yes |
| US4.1 (single artifact) | A10, U28 | sc_004 | Yes |
| US4.2 (standalone use) | A11, U30, U37 | sc_004 | Yes |

Untested criteria: none. Tests tracing to nothing: none. All 57 tests exist and
run green.

## What was not audited

- Repo-wide suite: final run 2440 passed, 1 failed — the only red is the
  pre-existing `issue_495_core_commands_no_flutter_import_test.dart` load error
  (red at the cycle-0 baseline, untouched by this feature). The
  `sc_003_overhead_test` threshold flake and the parallel-execution flakes seen
  in earlier runs (`extension_command_parity_test`, `plugin_command_mcp_test`,
  issue #506 class) passed in the final run.
- Mutation was deliberate-mutant sampling (8+ mutants), not a tool run; ~40
  behaviors were not mutant-sampled.
- Performance criteria SC-001/SC-003 (timing): no harness; quickstart generation
  of the real bone was sub-second.
- The xray marker format (`<!-- xray: key: value -->`) was invented by the loop
  (documented in cycle log); compatibility with real xray-plugin output is
  unverified.
- U22's cleanup-on-failure path is structurally unreachable in current failure
  modes (failures precede directory creation); recorded in cycle 46 rather than
  proven by test.
- `zfa bone` at SC-003 scale (20-bone graphs): untested.
