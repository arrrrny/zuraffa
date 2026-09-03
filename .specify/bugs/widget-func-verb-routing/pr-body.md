## Summary

A widget-kind behavior whose description carries a function-intent verb — "renders" being the single most natural widget-scenario verb — routed the primary generation plan to `zfa tdd func`, whose scaffold refuses the gen-shaped view-builder stub: `generation-error` at make. The #939 widget view lane never engaged because it lives in the composition **fallback**, which only runs when the primary plan is unexpressible — and `render(s|ed|ing)?` made the row "expressible" as a func scaffold.

This PR applies the same principle #835 applied to ffi: **kind outranks prose**. `GenerationPlanner.plan()` now returns an honest unexpressible plan for every `BehaviorKind.widget` row (guard placed after the #835 ffi guard, before the `U<n>` id dispatch and every description-keyed branch), naming the view lane — so make's existing, mutation-pinned #939 fallback routes the row through `tdd view <id> --feature <f>` + build and reaches green.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/services/generation_planner.dart` | modified | +40 lines: the widget-kind guard in `plan()` + one mapping-rules doc bullet |
| `test/plugins/tdd/services/generation_planner_widget_950_test.dart` | added | Fast tier, 8 pins — mirrors `generation_planner_ffi_835_test.dart` |
| `test/plugins/tdd/make_command_widget_950_test.dart` | added | Slow tier, end-to-end make pin with the issue's exact scenario literal — mirrors `make_command_widget_939_test.dart` |
| `.specify/bugs/widget-func-verb-routing/` | added | Bug record: assessment, spec, TDD artifacts (test list, cycle log, red evidence, verification), fix/test/PR reports |

Kindless summaries (`kind: null` — pre-#835 call sites and unreadable lists) and unit-kind rows keep their exact prior routing; the #835 ffi guard is untouched.

## Test plan (TDD, red → green)

- **RED pre-fix** (recorded verbatim in `.specify/bugs/widget-func-verb-routing/tdd/red-evidence.md`, test-only commit `becca94b` precedes the fix commit `9abc40e4`):
  - planner: `+4 -5` — widget + renders/rendered/rendering were expressible via the func branch;
  - real CLI surface: the issue's exact shape — `plan: 2 step(s)` → `tdd func` → `outcome=generation-error`, exit 1.
- **GREEN post-fix**: planner pins 8/8; make pin 1/1 (`widget lane: view-builder generation`, `tdd view` dispatched, never `tdd func`, exit 0, green cycle evidence appended).
- **Regression**: tdd plugin fast tier **879/879** (two full runs at HEAD); #939 lane **4/4**; `dart analyze` clean on touched files.
- **Mutation sampling** (no mutation tool in profile; deliberate mutants, byte-exact restorations): guard disabled → caught by all five guard pins (`+3 -5`); wrong-route-command in the refusal reason → caught (`+7 -1`) after pin 3 was strengthened during the audit; a phrasing-only mutant survives by design (the fallback routes on `summary.kind`, not reason prose).
- **TDD audit**: `PASS` — 6/6 behaviors PROVEN, 4/4 acceptance criteria covered (`.specify/bugs/widget-func-verb-routing/tdd/verification.md`).

## Acceptance pins from the issue

1. A widget-kind row whose description contains `renders`/`rendered`/`rendering` never plans `tdd func` — it plans unexpressible and the make's composition fallback routes the view lane. ✅ (planner + make pins)
2. A **unit-kind** row with "renders" still routes to func — units legitimately render/format/parse. ✅ (regression pin)

## Notes

- Routing decision: via `unexpressible()` + the composition fallback (the issue's option A), not direct view-lane planning — the planner stays pure by contract; the #939 lane in `_compositionFallback` already owns view routing and is mutation-pinned.
- Same collision class for `theme`/`platform` kinds is intentionally out of scope (no make-fallback lane exists for them); filed as a follow-up in the fix report.

Assessment: `.specify/bugs/widget-func-verb-routing/assessment.md` · Fix report: `.specify/bugs/widget-func-verb-routing/fix.md` · Verification: `.specify/bugs/widget-func-verb-routing/test.md`

Closes #950.
