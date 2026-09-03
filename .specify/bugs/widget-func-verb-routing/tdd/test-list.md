# Test List: widget-func-verb-routing (bug #950)

Derived from ./spec.md. Driven by the LLM-guided loop (repo is not
zuraffa-wired: no `.zfa.json`, `tdd.plan`/`tdd.run` Step 0 fallback).

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| W-A1 | a widget-kind make whose description says "renders" reaches green through the view-builder lane (`tdd view` dispatched, never `tdd func`, `widget lane` logged, exit 0) | AC1 | PENDING |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| W-U1 | the planner returns unexpressible for a widget-kind row whose description carries renders/rendered/rendering; the reason names the view lane and the behavior id | AC1 | PENDING |
| W-U2 | the widget guard outranks the `U<n>` id-prefix dispatch: a widget-kind U-id row with "renders" is unexpressible, not routed to tdd func | AC4 | PENDING |
| W-U3 | the widget guard outranks the description-keyed branches: a widget-kind row with entity/CRUD prose plus "renders" is unexpressible | AC4 | PENDING |
| W-U4 | a unit-kind row with "renders" still routes to the func surface (`tdd` + `func` steps) | AC2 | PENDING |
| W-U5 | a kindless summary with "renders" keeps the legacy branch-3 func routing | AC3 | PENDING |

## Test artifacts

- W-U1..W-U5 → `test/plugins/tdd/services/generation_planner_widget_950_test.dart` (fast tier, mirrors `generation_planner_ffi_835_test.dart`)
- W-A1 → `test/plugins/tdd/make_command_widget_950_test.dart` (slow tier, mirrors `make_command_widget_939_test.dart`)
