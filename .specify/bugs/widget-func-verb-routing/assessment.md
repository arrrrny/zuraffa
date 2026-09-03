# Bug Assessment: widget-kind row with a func verb ("renders") routes to tdd func — generation-error; the #939 view lane never engages

- **Slug**: widget-func-verb-routing
- **Created**: 2026-09-03
- **Source**: https://github.com/arrrrny/zuraffa/issues/950
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

A widget-kind behavior whose description contains a function-intent verb (e.g. "renders") routes the primary generation plan to `zfa tdd func`, which refuses the widget stub shape — `generation-error` at make. The #939 widget view lane never engages because it lives in the composition **fallback**, which only runs when the primary plan is unexpressible; `render(s|ed|ing)?` in `functionIntentVerbs` makes the row "expressible" as a func scaffold. Reporter traces the collision to `generation_planner.dart`: `plan()` consults `summary.kind` only for `ffi` (the #835 guard); widget-kind rows ride pure description keywords (branch 3, `tdd func`), and the #939 verification (3/3 mutants) pinned the fallback with a description carrying no func verb, so the collision escaped the pins.

## Symptom

`zfa tdd make` fails with `outcome=generation-error` for a widget-kind behavior whose scenario text contains "renders" — `tdd func` refuses to rewrite the `Widget subject_a1() => throw UnimplementedError(...)` stub it did not generate.

## Reproduction

1. Create a feature whose scenario uses the present-tense UI-intent contract, e.g. `**Then** the widget renders "Hello, shopper".` → plans as a widget-lane row (`## Outer loop: widget behaviors`, gen'd test `kind: widget`).
2. Run: `zfa tdd make A1 --feature 003-widget-probe --project ~/zik_zak_test`
3. Observe: generation step fails at index 0 with `zfa tdd func` refusing the unrecognized stub shape (`generation-error`), instead of engaging the #939 view lane.

(Repro from the issue: zuraffa `4952d359`, project `~/zik_zak_test`, feature `003-widget-probe`, behavior A1. Needs reproduction in this repo.)

## Suspected Code Paths

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to locate the code, or fill in manually.]

Reporter's pointers: `generation_planner.dart` — the `ffi` kind guard at the top of `plan()` (#835), the `functionIntentVerbs` table with `render` + `(s|ed|ing)?` suffix pattern (~lines 643-654), and the keyword branches that precede the unexpressible composition fallback (#939 view lane).

## Root Cause Hypothesis

[NEEDS CLARIFICATION — not yet analyzed.]

From the issue: kind does not outrank prose. Widget-kind rows are planned from description keywords alone; `render` matches as a func-intent verb, so the primary plan takes branch 3 (`tdd func`) before the unexpressible fallback where the widget view lane lives. `tdd func` then honestly refuses the widget stub — correct refusal, wrong routing.

## Proposed Remediation

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to propose a fix, or apply a fix directly with /skill:speckit-bug-fix.]

Issue's proposal: extend the same principle #835 applied to ffi — in `plan()`, after the ffi guard and before the keyword branches, return unexpressible (or plan the view lane directly) when `summary.kind == BehaviorKind.widget`. Acceptance pins: (1) a widget-kind row containing `renders`/`rendered`/`rendering` plans the view lane (or falls to the composition fallback), never `tdd func`; (2) a unit-kind row with "renders" still routes to func (no regression).

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.
- Fix must not regress unit-kind rows that legitimately use render/format/parse verbs (pin #2).
- The #939 fallback lane and the possibility of planning the view lane directly (instead of unexpressible) are both on the table — decision needed on which routing the fix takes.

## Open Questions

- [NEEDS CLARIFICATION: Should widget-kind rows route to the view lane directly in `plan()`, or via `unexpressible()` + composition fallback?]
- [NEEDS CLARIFICATION: Are there other kind-vs-verb collisions beyond `render` (e.g. `navigates`, `displays`) that the same guard should cover?]
- [NEEDS CLARIFICATION: Does the repro reproduce at the current HEAD, and where does the widget lane pin need to be added to prevent re-escape?]
