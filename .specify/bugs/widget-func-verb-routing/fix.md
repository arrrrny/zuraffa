# Bug Fix: widget-kind row with a func verb ("renders") routes to tdd func — generation-error; the #939 view lane never engages

- **Slug**: widget-func-verb-routing
- **Fixed**: 2026-09-03
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: ./tdd/test-list.md, ./tdd/cycle-log.md, ./tdd/red-evidence.md

## Summary

`GenerationPlanner.plan()` now returns an honest unexpressible plan for
every widget-kind behavior (a `summary.kind == BehaviorKind.widget` guard
between the #835 ffi guard and the unit-id dispatch), so a func verb like
"renders" in the description can no longer capture the row into
`tdd func`. The make command's existing #939 composition-fallback widget
lane (already mutation-pinned by `make_command_widget_939_test.dart`)
then routes the row to the view-builder generation
(`tdd view <id> --feature <f>` + build) and reaches green.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/services/generation_planner.dart` | modified | +40 lines: the widget-kind guard in `plan()` (after the #835 ffi guard, before the `U<n>` id dispatch and all description-keyed branches) + one mapping-rules doc bullet |
| `test/plugins/tdd/services/generation_planner_widget_950_test.dart` | added test | Fast tier, 8 pins — mirrors `generation_planner_ffi_835_test.dart` |
| `test/plugins/tdd/make_command_widget_950_test.dart` | added test | Slow tier (`@Tags(['slow'])`), 1 end-to-end make pin — mirrors `make_command_widget_939_test.dart` |

## Diff Highlights

```dart
// generation_planner.dart, plan() — after the ffi guard:
if (summary.kind == BehaviorKind.widget) {
  return GenerationPlan(
    ...
    steps: const [],
    unexpressibleReason:
        'widget-kind behavior "${summary.behaviorId}" — the scenario '
        'is UI-observable ... The make composition fallback routes this '
        'row to the tdd view lane (issue #939): `zfa tdd view '
        '${summary.behaviorId} --feature ${summary.feature}` + build ...',
  );
}
```

Kindless summaries (`kind: null`) fall past the guard and keep the exact
pre-#835-style routing; unit-kind rows are untouched.

## Tests Added or Updated

Fast tier (`generation_planner_widget_950_test.dart`):
- `a widget-kind row whose description says "renders" is NOT routed to tdd func` — the bug verbatim; plan must be unexpressible, reason carries the behavior id
- `every render inflection (renders/rendered/rendering) stays off the func surface` — all three inflections unexpressible, no `func` step
- `the reason names the view lane (the fallback route)` — the refusal routes the fallback, not a dead end
- `the widget guard outranks the U<n> id-prefix dispatch` — contradictory metadata resolves kind-first (the test-list row is the kind source of truth)
- `the widget guard outranks the entity/CRUD description branches` — CRUD/`make`/`entity` steps never planned for a widget row (prose chosen with no "widget"/"view" literal so the reason assertion discriminates the guard from the #758 stop)
- `a unit-kind row with "renders" still routes to the func surface` — assessment pin #2 (no regression)
- `a kindless summary with "renders" keeps the legacy branch-3 func routing` — pre-#835 call sites / unreadable lists unchanged
- `the ffi guard keeps precedence and its own reason` — #835 untouched

Slow tier (`make_command_widget_950_test.dart`):
- `W-A1: a widget-kind make whose description says "renders" reaches green through the view-builder lane` — the issue's exact scenario literal (`the widget renders 'Hello, shopper'`) against the gen-shaped view-builder stub `tdd func` refuses; pins `outcome=green`, exit 0, `widget lane: view-builder generation` logged, dispatch `[tdd view A-100 …, build]`, `tdd func` never dispatched, green cycle evidence appended

## Local Verification

- RED (pre-fix): fast file `+4 -5` (guard pins red, regression pins green — see ./tdd/red-evidence.md for the verbatim failures); slow file `+0 -1` with the issue's exact CLI shape (`plan: 2 step(s)` → `tdd func` → `outcome=generation-error`, exit 1)
- GREEN (post-fix): fast file `+8: All tests passed!`; slow file `+1: All tests passed!`
- Scoped regression: `dart test test/plugins/tdd` fast tier → **879/879 passed**; `dart test --preset=all test/plugins/tdd/make_command_widget_939_test.dart` (the neighboring #939 lane) → **4/4 passed**
- Static analysis: `dart analyze` on the three touched files → `No issues found!`
- Mutation sampling (per profile: no mutation tool; deliberate mutants): guard kind-check disabled (`== BehaviorKind.widget` → `== BehaviorKind.theme`) → `+3 -5`, **caught by all five guard pins**; restored byte-exact (`git diff --stat` back to the 40-line fix), suite re-green. A first mutant run (`+4 -4`) exposed one surviving pin whose reason assertion matched a description literal; the pin's prose was sharpened (refactor-while-green) and the mutant re-run caught 5/5.

## Deviations from Assessment

- The assessment's Suspected Code Paths / Root Cause / Remediation sections were `[NEEDS CLARIFICATION]` scaffolds (fetched from the issue); this stage performed the code investigation they deferred. Resolution recorded here rather than by editing the assessment (it is the contract): reporter's pointers confirmed exactly — `plan()` consults kind only for ffi (line 176 pre-fix); `render` + `(s|ed|ing)?` in `functionIntentVerbs` (lines 643-654) takes branch 3 before the unexpressible fallback.
- **Routing decision (open question 1)**: the fix routes via `unexpressible()` + the composition fallback (the issue's option A), NOT by planning the view lane directly in `plan()`. Rationale: the view lane is shaped in `make_command._compositionFallback` (lines 924-965) — already verified by the #939 pins (3/3 mutants) — while the planner is pure by contract (never reads the spec's Presentation contract or spawns). Direct planning would duplicate that logic impurely.
- **Guard scope (open question 2)**: the guard covers `BehaviorKind.widget` only, per the issue and acceptance pins. The same collision class exists for `theme`/`platform` kinds (a theme row with "renders" would still hit branch 3), but no make-fallback lane exists for them — routing them to unexpressible would change behavior beyond the issue's contract without pins. Recorded as a follow-up, not expanded here.
- **Reproduction (open question 3)**: reproduced at the pre-fix tree with the issue's exact CLI failure shape (see RED evidence); the prevent-re-escape pins are the new fast/slow files above, plus the kept-green #939 suite.
- **TDD engine dispatch**: `tdd_enabled: true`, but the repo is not zuraffa-wired (no `.zfa.json`; `zfa tdd plan/run` Step 0 → `ZFA_MISSING`), so the tdd extension's own fallback loop drove the cycle (LLM-guided red-green with cycle-log evidence), the same shape as the #939 bug record. `.specify/feature.json` was therefore left untouched (`{}`) — pinning it only matters for engine dispatch, and it feeds other tooling (bone/spec-stats) as a side effect.
- Fixes also placed one doc bullet in the planner's mapping-rules comment (the rules list previously omitted kind-based routing; kept in sync with the new code).

## Follow-ups

- Consider the same kind-outranks-prose guard for `theme`/`platform` kinds once their make-side lanes are decided (same collision class: e.g. a theme-kind row whose description carries "renders" still routes to `tdd func` today).
- The issue's workaround note stays valid for pre-fix versions: phrase widget scenarios without func verbs ("the page shows X").
