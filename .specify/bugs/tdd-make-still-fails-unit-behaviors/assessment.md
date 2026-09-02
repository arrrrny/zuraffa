# Bug Assessment: [BUG] zfa tdd make still fails on unit behaviors (U5+)

- **Slug**: tdd-make-still-fails-unit-behaviors
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/723
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

`zfa tdd make` for unit behaviors (U1, U2, U3, etc.) still fails. When the run loop reaches a unit behavior, it stops with `outcome=generation-error` because the make step tries to run `zfa make <behaviorId>` (lowercased), treating the behavior ID as an entity name. Confirmed on v6.1.0 rebuilt, fresh project.

Issue URL: https://github.com/arrrrny/zuraffa/issues/723

## Symptom

`zfa tdd make U5` plans `[make u5 --no-entity]` instead of `[tdd func U5, build]`, then the target test still fails after generation → `outcome=generation-error`. The run loop stops at the first unit behavior.

## Reproduction

1. `zfa setup --platforms=ios,android,macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy spec, run `zfa tdd plan 001-app-bootstrap`
4. `zfa tdd run 001-app-bootstrap` → exit 1: stops at `U5:make -> generation-error`

Observed output:
```
[run] U5 gen -> ok
[run] U5 verify-red -> certified
[run] U5 make -> generation-error
zfa tdd run: step failed — behavior=U5 step=make outcome=generation-error
   zfa tdd make: behavior U5
   plan: 2 step(s)
   target test exit: 1
zfa tdd make: target test still fails after generation (exit 1).
```

## Suspected Code Paths

- `lib/src/plugins/tdd/services/generation_planner.dart:118-140` — **confirmed**. The planner has a unit-kind dispatch gate (`isUnitBehaviorId`, line 110-111) that returns `_functionSurfacePlan` for `U<n>` ids (lines 135-140). This gate exists in the current master source, so the planner *should* route unit behaviors correctly. The bug is that the planner is not receiving the correct `BehaviorSummary` — specifically, the `description` field is falling back to `record.behaviorId` (line 92: `description ?? record.behaviorId`), which lets the description-keyed entity/CRUD branches below the unit-kind gate win when the summary's description is empty or the kind is not resolved.
- `lib/src/plugins/tdd/services/generation_planner.dart:82-95` — **confirmed**. `BehaviorSummary.fromRecord` falls back to `record.behaviorId` for `description` when no description is passed. For a unit behavior whose record has no description prose, the description becomes `"U5"` — which does NOT contain entity/use-case/service keywords, so the description-keyed branches should NOT fire. This means the bug is elsewhere: the planner is likely being called with a summary whose `behaviorId` is NOT `U<n>` (e.g. a kindless or dashed id), so the unit-kind gate at line 135 is skipped.
- `lib/src/plugins/tdd/commands/make_command.dart` — the make command constructs the `BehaviorSummary` from the registry record and passes it to the planner. If the record's `behaviorId` is not `U<n>` (e.g. it was normalized or the test-list row uses a different id convention), the unit-kind gate is bypassed and the description-keyed entity/CRUD routing fires.
- `lib/src/plugins/tdd/services/test_list_reader.dart` — the kind source of truth. The #723 fix commit (`264b4dea`) makes `MakeCommand` resolve the kind from the test-list row via `TestListReader`. If the current master's `MakeCommand` does not resolve the kind from the row, the planner's unit-kind gate is bypassed.

## Root Cause Hypothesis

The fix for #723 exists on branch `fix/723-tdd-make-fails-unit-behaviors-v2` (commit `264b4dea`, "fix(723): tdd make routes unit behaviors to plain-function generator (v2)") but is **NOT on master**. The fix modifies `generation_planner.dart` (+81 lines) and `make_command.dart` (+49 lines) to dispatch on the behavior's loop kind BEFORE description matching: kind=unit plans `zfa tdd func <id>` + `build`. `MakeCommand` resolves the kind from the test-list row (`TestListReader`, the kind source of truth) with the `A<n>/U<n>` id convention as fallback.

On master, the planner's unit-kind gate exists (lines 135-140) but `MakeCommand` does not resolve the kind from the test-list row — so for unit behaviors whose test-list row kind is not `unit`, or whose `behaviorId` in the summary is not `U<n>`, the gate is bypassed and the description-keyed entity/CRUD routing fires, producing `zfa make u5` (the slugified behavior id as an entity name). High confidence: the fix commit and its diff are verified; the master source shows the planner gate but the make command lacks the kind resolution.

## Proposed Remediation

**Preferred**: Merge the fix from `fix/723-tdd-make-fails-unit-behaviors-v2` (commit `264b4dea`) into master. The fix:

1. `GenerationPlanner` dispatches on the behavior's loop kind BEFORE description matching: kind=unit plans `zfa tdd func <id>` + `build`.
2. `MakeCommand` resolves the kind from the test-list row via `TestListReader` (the kind source of truth), with the `A<n>/U<n>` id convention as fallback and null keeping the pre-#723 description-keyed dispatch (the #696 contract for kindless summaries).

**Files likely to change**:
- `lib/src/plugins/tdd/commands/make_command.dart` (+49 lines)
- `lib/src/plugins/tdd/services/generation_planner.dart` (+81 lines)
- `test/plugins/tdd/make_command_test.dart` (+123 lines)
- `test/plugins/tdd/services/generation_planner_test.dart` (+86 lines)

**Tests to add or update**:
- U-723a: planned `['make','u5','--no-entity']` vs expected `['tdd','func','U5']` (RED pre-fix).
- U-723e: reproduces the issue's exact failure shape (plan: 2 step(s) → target test still fails after generation (exit 1) → outcome=generation-error).
- Post-fix: unit behaviors route to `zfa tdd func <id>` + `build`, target test passes, outcome=green.

## Risks & Considerations

- The fix branch (`fix/723-tdd-make-fails-unit-behaviors-v2`) also removes several bug directories that exist on master (e.g. `tdd-gen-hangs-second-behavior`, `tdd-make-fails-unit-behaviors`, `tdd-make-plan-build-false-negative`, `tdd-make-regression-false-positive`, `tdd-make-u4-hangs-no-timeout`, `tdd-refactor-preflight-full-suite`, `tdd-run-per-behavior-slow-cold-binary`, `tdd-suite-template-truncation`). Merging the branch will delete those directories — ensure their content is preserved in the merge commit or the verification records are referenced.
- The fix is a re-report of #718 (confirmed on v6.1.0); it must not regress the #696 contract for kindless summaries.

## Open Questions

- [NEEDS CLARIFICATION: Why is the fix on a separate branch and not on master? Is there a blocking dependency or an open review?]