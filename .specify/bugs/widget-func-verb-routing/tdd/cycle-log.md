# Cycle Log

## Cycle: W-U1 (red)

- behavior: W-U1 — planner returns unexpressible for widget-kind + renders (all inflections); reason names the view lane
- kind: red
- classification: assertionFailure
- criterion: AC1 (spec.md)
- test: test/plugins/tdd/services/generation_planner_widget_950_test.dart
- command: `dart test test/plugins/tdd/services/generation_planner_widget_950_test.dart`
- exit: 1
- at: 2026-09-03
- output:
```
Expected: false
  Actual: <true>
  the func scaffold cannot express a view-builder subject; the row must
  fall to the composition fallback view lane
```
(+4 -5 total: W-U1 x2 pins, W-U2 via reason assertion, W-U3 reason pin, and the reason-names-the-lane pin — see red-evidence.md; W-U4/W-U5/ffi pins green pre-fix as required)

## Cycle: W-A1 (red)

- behavior: W-A1 — a widget-kind make whose description says "renders" reaches green through the view-builder lane, never tdd func
- kind: red
- classification: assertionFailure
- criterion: AC1 (spec.md)
- test: test/plugins/tdd/make_command_widget_950_test.dart
- command: `dart test --preset=all test/plugins/tdd/make_command_widget_950_test.dart`
- exit: 1
- at: 2026-09-03
- output:
```
   plan: 2 step(s)
   target test exit: 1
zfa tdd make: target test still fails after generation (exit 1).
make: behavior=A-100 outcome=generation-error feature=090-tdd-fixture
```

## Cycle: W-U1 (green)

- behavior: W-U1 (+ W-U2, W-U3 — same guard) — planner returns unexpressible for widget-kind + renders; reason names the view lane
- kind: green
- criterion: AC1/AC4 (spec.md)
- test: test/plugins/tdd/services/generation_planner_widget_950_test.dart
- command: `dart test test/plugins/tdd/services/generation_planner_widget_950_test.dart`
- exit: 0
- at: 2026-09-03
- output: `+8: All tests passed!` (5 guard pins + 3 regression pins)
- smallest change: a `summary.kind == BehaviorKind.widget` guard in
  `GenerationPlanner.plan()` between the #835 ffi guard and the unit-id
  dispatch, returning the unexpressible plan whose reason names the tdd
  view lane (issue #939) — the fallback's existing, mutation-pinned
  widget lane does the routing.

## Cycle: W-A1 (green)

- behavior: W-A1 — a widget-kind make whose description says "renders" reaches green through the view-builder lane, never tdd func
- kind: green
- criterion: AC1 (spec.md)
- test: test/plugins/tdd/make_command_widget_950_test.dart
- command: `dart test --preset=all test/plugins/tdd/make_command_widget_950_test.dart`
- exit: 0
- at: 2026-09-03
- output: `+1: All tests passed!` — `widget lane: view-builder generation` logged, dispatch log `[tdd view A-100 …, build]`, no `tdd func` anywhere, `## Cycle: A-100 (green)` appended

## Cycle: refactor (clean)

- kind: refactor
- at: 2026-09-03
- change: W-U3's prose swapped to carry no "widget"/"view" literal (the
  first version's reason assertion could match the description text
  embedded verbatim in the #758 refusal — a surviving-mutant smell caught
  during deliberate-mutant sampling). Suite stayed green throughout
  (`+8: All tests passed!` before and after).

## Cycle: mutation sampling (deliberate mutant)

- mutant: the guard's kind check disabled (`== BehaviorKind.widget` →
  `== BehaviorKind.theme`) — widget rows fall through to the func
  surface again
- result: CAUGHT — `+3 -5: Some tests failed.` (all five guard pins red)
- restoration: byte-exact copy-back; `git diff --stat` shows only the
  intended 40-line fix insertions; suite re-green (`+8: All tests passed!`)

