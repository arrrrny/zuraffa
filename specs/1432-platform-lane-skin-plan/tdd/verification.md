# TDD Verification: 1432-platform-lane-skin-plan — platform rows are first-class SKIN lane rows

- **Slug**: 1432-platform-lane-skin-plan
- **Date**: 2026-09-09
- **Runner**: this session (fallback LLM-guided audit; deterministic `zfa tdd
  verify` unavailable — the repo has no `.zfa.json`)
- **Verdict**: **PASS**

## 1. Test-first evidence

**RED (Cycle 1 — recorded in-session against the unfixed tree, full output in
`tdd/cycle-log.md` §Cycle 1):** all six behaviors failed for the right
reasons — the renderer rows because the platform `LaneRow` matched no section
filter; the CLI rows because `04-SKIN.md`'s acceptance section lacked A1
while the route log claimed `route: A1 -> platform lane`, the meta-index
declared over dropped rows, and the theme row exited 0 instead of refusing.

Classification per `tdd-test-quality-rubric.md`: **PROVEN** — red output was
recorded against the unfixed tree in this session, and the regression tests
land in the same commit series as the fix.

## 2. Behavior assertions

The CLI rows drive the real CLI in-process (`CliRunner.runCapturing`) over a
hermetic temp project with a Lanes-declaring spec (mirroring
`plan_lanes_1000_test.dart`); the renderer rows drive `renderSkinPlan`/
`renderEnginePlan` directly. Assertions target observable contracts only:
exit codes, the emitted `04-SKIN.md` section content and row shape, the
meta-index↔artifact id agreement, the refusal text (id/kind/criterion), and
the no-artifacts-on-refusal guarantee.

## 3. Mutation results (rubric Q3)

The `mutation_test` dev-dependency is not installed in this repo, so
tool-driven mutation is **NOT_ASSESSED** — stated rather than inferred.
Deliberate mutant (highest-value, the bug's own root cause): reverting
`renderSkinPlan`'s acceptance filter to `acceptance`-only.

```console
# mutant applied (compile-valid, skin filter only):
$ dart test test/plugins/tdd/services/lane_split_platform_rows_test.dart
renderSkinPlan places a platform row … [E]                          ← KILLED
$ dart test --preset=all test/plugins/tdd/commands/bug_1432_platform_lane_rows_test.dart
A-1432-1 [E]  A-1432-2 [E]  A-1432-4 [E]                            ← KILLED
# A-1432-3 (the theme refusal) survives the mutant — correct: the guard is
# a separate behavior the mutant does not touch
# mutant reverted:
$ dart test test/plugins/tdd/services/lane_split_platform_rows_test.dart
00:00 +2: All tests passed!
$ dart test --preset=all test/plugins/tdd/commands/bug_1432_platform_lane_rows_test.dart
00:01 +4: All tests passed!
```

## 4. Acceptance-criteria coverage (spec FRs / SCs)

| Requirement | Evidence |
|----|----------|
| FR-001 routed ⇒ rendered (SC-002) | CLI rows A-1432-1 + A-1432-2 (log↔artifact agreement over every routed id) |
| FR-002 platform rows like acceptance | renderer rows (both plans, 4-column shape) + A-1432-1 |
| FR-003 refuse instead of dropping (SC-003) | CLI row A-1432-3 (theme → exit 2, no lane artifacts) + U-1432-3 guard exclusion of contract rows (open #1419) |
| FR-004 counts == rows (SC-001, SC-004) | CLI row A-1432-4 (meta-index declared ids == artifact data rows, platform counted) |
| FR-005 no regression | targeted sweep: 42 (lanes/stale/skin-parity/receipt/noFlutter) + 29 (ffi/1182/pipe-escape/contract-kind) all green |

## 5. Pre-existing failures

None introduced by this feature; the sweep ran clean. The known pre-existing
`bug_874`/`840` reds are tracked under issue #1250 and are untouched by this
branch (no delta).

## 6. Reproduction (post-fix)

```console
$ zfa tdd plan 004-login-ui   # fixture with A1 platform + A2 acceptance in SKIN
route: A1 -> platform lane [declared: type marker, spec line 6]
# 04-SKIN.md ## Outer loop: acceptance behaviors now carries BOTH rows;
# meta-index declares exactly the rendered ids; theme-typed rows refuse.
```
