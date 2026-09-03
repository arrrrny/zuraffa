# RED evidence — bug #939 (captured pre-fix, 2026-09-03)

## Real-CLI reproduction (`repro_939_red.dart`, feature 002-login, widget-kind A1)

```
--- TestListReader resolution (the kind source of truth)
reader: A1 kind=widget
reader: U1 kind=unit
--- REAL CLI: zfa tdd make A1 --feature 002-login
zfa tdd make: behavior A1
   feature: 002-login
   test: /tmp/zfa_939_red_UGHINR/test/a1_test.dart
   suite baseline: dart test
   baseline exit: 1, failed: 1
   composition fallback disengaged: behavior "A1" is unit-kind: compose composes acceptance subjects against the feature's green unit subjects, and a unit subject implements its own logic (spec 052 Out of Scope).
zfa tdd make: cannot plan a generation for behavior "A1". behavior "A1" requires an implementation the zuraffa generation pipeline cannot express: no generator surface maps the behavior description "the app shows a loading indicator and navigates to the home screen." to a `zfa entity create` / `zfa make` / `zfa build` invocation. File a zuraffa gap per the STOP-ON-ROADBLOCK policy.
make: behavior=A1 outcome=unexpressible feature=002-login
exit: 1
```

Both defects visible verbatim:
- defect 1 — `outcome=unexpressible`, exit 1 (no generator surface for the widget-kind row);
- defect 2 — `behavior "A1" is unit-kind` while the shared reader resolves the SAME row as `kind=widget` (the gate's message mislabels; `_rowKind`/`TestListReader` do not).

## Committed-test RED at the pre-fix tree (lib/ stashed, 2026-09-03)

Fast tier (`view_command_test.dart` + `composition_targets_widget_939_test.dart`):
`+4 -11: Some tests failed.` — every widget-lane pin and both gate pins red
(U-V1..U-V10 minus the reader/shape pins that must stay green; the
theme-kind refusal and the no-green-units-for-widget pins fail because
the pre-fix gate refuses widget with the hardcoded unit-kind message).

Slow tier (`make_command_widget_939_test.dart`, `--preset=all`):
`+1 -3: Some tests failed.` — A14 (lane reaches green), A15 (no anchor
precondition), A16 (no mislabel) red; A17 (unit-kind honest stop, the
unchanged contract) green.

Post-fix both tiers flip green: fast 15/15 (view 10 + gate 5), slow 4/4 —
plus the real-CLI repro exiting 0 with green evidence appended
(`outcome=skipped` via the #737/#694 tolerance on the fixture's
missing-build_runner build step; `outcome=green` in provisioned
projects).
