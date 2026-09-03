# Bug Issue: widget-kind row with a func verb ("renders") routes to tdd func — generation-error; the #939 view lane never engages

- **Slug**: widget-func-verb-routing
- **Fetched**: 2026-09-03
- **Issue**: 950
- **URL**: https://github.com/arrrrny/zuraffa/issues/950
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: (none)

## Body

## Summary

A widget-kind behavior whose description contains a function-intent verb — **"renders"** being the single most natural widget-scenario verb — routes the primary generation plan to `zfa tdd func`, which refuses the widget stub shape: `generation-error` at make. The #939 widget view lane never engages because it lives in the composition **fallback**, which only runs when the primary plan is unexpressible — and `render(s|ed|ing)?` makes it "expressible" as a func scaffold.

## Repro

Spec scenario (present tense per the UI-intent contract): `**Then** the widget renders "Hello, shopper".` → plans as a widget-lane row (`## Outer loop: widget behaviors`, gen'd test `kind: widget`).

```
$ zfa tdd make A1 --feature 003-widget-probe --project ~/zik_zak_test
   plan: 2 step(s)
zfa tdd make: generation step failed at index 0 (scaffold the render function for behavior A1 from its description):
   command: ... zfa.dart tdd func A1 --feature 003-widget-probe
   exit: 1
   output (tail):
zfa tdd func: subject at ".../lib/tdd/003-widget-probe/a1_subject.dart" carries an UnimplementedError
in an unrecognized shape — refusing to rewrite a file this command did not generate.
make: behavior=A1 outcome=generation-error feature=003-widget-probe
```

## Root cause

`generation_planner.dart` consults `summary.kind` only for `ffi` (the #835 guard at the top of `plan()`). Widget-kind rows ride pure description keywords; `functionIntentVerbs` contains `render` with the `(s|ed|ing)?` suffix pattern (line 643-654), so "the widget renders X" takes branch 3 (`tdd func`) before the unexpressible fallback where #939's view lane lives. `tdd func` then honestly refuses the `Widget subject_a1() => throw ...` stub (correct refusal — wrong routing).

The #939 verification (3/3 mutants) pinned the fallback path with a description that carries no func verb, so the collision escaped the pins.

## Proposed fix

Kind must outrank prose — the same principle #835 applied to ffi:

```dart
if (summary.kind == BehaviorKind.widget) {
  return unexpressible('widget-kind behavior — routed to the tdd view lane by the composition fallback');
  // or plan the view lane directly: tdd view <id> + build
}
```

in `plan()` before the keyword branches (after the ffi guard). Acceptance pins:

1. A widget-kind row whose description contains `renders`/`rendered`/`rendering` plans the view lane (or falls through to the composition fallback), never `tdd func`.
2. A **unit-kind** row with "renders" still routes to func (no regression — units legitimately render/format/parse).

## Workaround

Phrase widget scenarios without func verbs — "the page shows X", "the app navigates to Y" — which is what the 004-login-ui spec already does.

## Environment

zuraffa `4952d359`; repro `~/zik_zak_test` feature `003-widget-probe` (A1).

## Comments

None.
