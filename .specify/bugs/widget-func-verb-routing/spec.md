# Bug Spec: widget-kind row with a func verb routes to tdd func (issue #950)

- **Slug**: widget-func-verb-routing
- **Source issue**: https://github.com/arrrrny/zuraffa/issues/950
- **Parent lane**: #939 (the widget view lane in the make composition fallback), #835 (kind outranks prose, ffi precedent)
- **Synthesized from**: ./assessment.md

## Problem

A widget-kind behavior whose description contains a function-intent verb —
"renders" being the most natural widget-scenario verb — routes the primary
generation plan to `zfa tdd func` (branch 3, `functionIntentVerbs`), whose
scaffold refuses the gen-shaped view-builder stub: `generation-error` at
make. The #939 view lane never engages because it lives in the composition
fallback, which only runs when the primary plan is unexpressible — and
`render(s|ed|ing)?` makes the row "expressible" as a func scaffold.

## Required (fixed) behavior — acceptance criteria

1. **Kind outranks prose (AC1).** A widget-kind behavior row whose
   description contains `renders` / `rendered` / `rendering` is NEVER
   planned to `tdd func`. The planner returns an unexpressible plan whose
   reason names the widget view lane, so `zfa tdd make` routes the row
   through the composition fallback's view-builder lane
   (`tdd view <id> --feature <f>` → `build`, issue #939) and reaches green.
2. **Unit regression pin (AC2).** A **unit-kind** behavior whose
   description contains "renders" still routes to the func surface —
   units legitimately render/format/parse.
3. **Kindless regression pin (AC3).** A kindless summary (`kind: null` —
   every pre-#835 call site and unreadable lists) keeps the legacy
   description-keyed routing exactly as before.
4. **Guard precedence (AC4).** The widget guard sits after the #835 ffi
   guard and before the id-prefix and description-keyed branches: a
   widget-kind row is never captured by the `U<n>` id dispatch or by
   entity/CRUD prose either.

## Failing-test scenario (reproduction)

Spec scenario (present tense per the UI-intent contract):
`**Then** the widget renders "Hello, shopper".` → plans as a widget-lane
row (`## Outer loop: widget behaviors`, gen'd test `kind: widget`).

```
$ zfa tdd make A1 --feature 003-widget-probe --project ~/zik_zak_test
   plan: 2 step(s)
zfa tdd make: generation step failed at index 0 (scaffold the render function ...):
   command: ... zfa.dart tdd func A1 --feature 003-widget-probe
   exit: 1
make: behavior=A1 outcome=generation-error feature=003-widget-probe
```

Post-fix the same make must log `widget lane: view-builder generation`,
dispatch `tdd view A1 --feature 003-widget-probe` then `build`, certify the
target test, and exit 0.

## Out of scope

- `theme` / `platform` kind collisions with func verbs (same class, but no
  fallback lane exists for them — needs its own lane decision; recorded as
  a follow-up).
- Changing the acceptance-kind composition path (#642/#923) or the ffi
  guard (#835).
