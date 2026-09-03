# RED evidence — bug #950 (captured pre-fix, 2026-09-03)

Branch `fix/widget-func-verb-routing` at af2f9e7c (pre-fix lib/).

## Fast tier — `test/plugins/tdd/services/generation_planner_widget_950_test.dart`

Command: `dart test test/plugins/tdd/services/generation_planner_widget_950_test.dart`
Result: `+4 -5: Some tests failed.`

RED (5 pins, the bug verbatim):
- `a widget-kind row whose description says "renders" is NOT routed to tdd func` — `Expected: false Actual: <true>` (the row IS expressible — as a func scaffold; this is the routing bug)
- `every render inflection (renders/rendered/rendering) stays off the func surface` — same, for all three inflections
- `the reason names the view lane (the fallback route)` — `Actual: <null>` (no unexpressible plan exists for widget rows)
- `the widget guard outranks the U<n> id-prefix dispatch` — `Expected: false Actual: <true>` (a U<n> widget-kind row routes to func)
- `the widget guard outranks the entity/CRUD description branches` — unexpressible pre-fix but by the WRONG branch (the #758 acceptance-CRUD stop); the added `contains('widget')` reason assertion fails

GREEN pre-fix (regression pins — expected):
- `a unit-kind row with "renders" still routes to the func surface`
- `a kindless summary with "renders" keeps the legacy branch-3 func routing`
- `the ffi guard keeps precedence and its own reason`

## Slow tier — `test/plugins/tdd/make_command_widget_950_test.dart`

Command: `dart test --preset=all test/plugins/tdd/make_command_widget_950_test.dart`
Result: `+0 -1: Some tests failed.` (exit 1)

RED (the issue's exact CLI failure shape):

```
zfa tdd make: behavior A-100
   feature: 090-tdd-fixture
   baseline exit: 1, failed: 1
   plan: 2 step(s)                      ← the FUNC plan (tdd func + build)
   target test exit: 1
zfa tdd make: target test still fails after generation (exit 1).
make: behavior=A-100 outcome=generation-error feature=090-tdd-fixture
```

The fixture seeds the gen-shaped view-builder stub (`Widget subject_a_100()
=> throw UnimplementedError(...)`); the primary plan dispatches `tdd func`
whose rewrite refuses that shape in production (the issue's repro), the
target test stays red, and the make dead-ends `generation-error`. The
`tdd view` side effect never fires (the view lane never engages).

## Post-fix expectation

Both files flip green: fast tier 8/8, slow tier 1/1 — the widget guard
returns the unexpressible plan naming the view lane, and the make's
composition fallback routes `tdd view A-100 --feature <f>` → `build`,
certifies the target test, exits 0.
