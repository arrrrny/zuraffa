# Bug Issue: [TDD-133] widget lane dead-ends at make: no generator surface for widget-kind behaviors (unexpressible) + _rowKind misreports widget rows as unit-kind

- **Slug**: tdd-133-widget-make-path
- **Fetched**: 2026-09-03
- **Issue**: 939
- **URL**: https://github.com/arrrrny/zuraffa/issues/939
- **State**: open
- **Severity**: high (the loop stops with `stopped_at=<id>:make` on the first widget behavior of every UI-rich spec)
- **Author**: arrrrny
- **Labels**: bug

## Body

## Summary

The widget lane (bug #830/#912) drives a UI behavior to an honest RED and then **dead-ends**: `zfa tdd make` reports `unexpressible` for every widget-kind behavior — no generator surface can take it to green. A UI-rich spec can never complete the loop.

## Repro

```
$ zfa tdd make A1 --feature 002-login --project ~/zik_zak_test
zfa tdd make: behavior A1
   feature: 002-login
   test: .../test/tdd/002-login/a1_test.dart
   suite baseline: flutter test
   baseline exit: 1, failed: 7
   composition fallback disengaged: behavior "A1" is unit-kind: ...
zfa tdd make: cannot plan a generation for behavior "A1". behavior "A1" requires an implementation
the zuraffa generation pipeline cannot express: no generator surface maps the behavior description
"the app shows a loading indicator and navigates to the home screen." to a `zfa entity create` /
`zfa make` / `zfa build` invocation. File a zuraffa gap per the STOP-ON-ROADBLOCK policy.
make: behavior=A1 outcome=unexpressible feature=002-login
```

A1 is a `## Outer loop: widget behaviors` row (`kind: widget` in both the registry record and the gen'd test header). Preconditions met: scaffold marker removed, scenario-derived finders authored, verify-red certified.

## Two defects

### 1. No make path for widget-kind behaviors (structural)

`generation_planner.dart` and `composition_planner.dart` contain zero references to the widget kind — the planner is description-keyed and UI prose never maps to `entity create`/`make`/`build`. The composition fallback (`make_command.dart` issue #642 gate) engages for acceptance-kind rows only. So widget behaviors are unexecutable past RED, always — the loop stops with `stopped_at=<id>:make` on the first widget behavior of every UI-rich spec.

### 2. `_rowKind` reports widget rows as unit-kind

The fallback's disengage message says `behavior "A1" is unit-kind` — but A1 is widget-kind in the test list (`## Outer loop: widget behaviors` sets `BehaviorKind.widget` in `TestListReader.read()`). Either `_rowKind` fails to resolve the row and defaults to unit, or the resolution path drops the widget kind. The message is wrong on its face and hides defect 1's real shape.

## Proposed fix

- **Widget make path**: a deterministic minimal view-builder generator driven by the spec's declared Presentation layer contract (the zuraffa-1.0 template's `### Layer Contracts → **Presentation**` section — e.g. "Login page section; ShadInput for email and password, ShadButton for Sign In"). `make` on a widget-kind row emits a compiling minimal view composed of the declared components (the same information `zfa make --with=vpc` uses for presenters), runs the target test, and certifies green. Scenario-specific behavior inside the view remains the sanctioned handcraft seam — but the loop must be able to REACH green through a generated skeleton, exactly as func subjects do.
- **`_rowKind`**: resolve widget rows as widget; the composition-fallback gate should then treat widget like acceptance (compose against green unit subjects) instead of mislabeling as unit.

## Workaround (unblocking the 002-login experiment)

Hand-implement the view-builder subject (sanctioned manual territory: "view composition details"), then re-run make — the drift check takes the #694 skip transition with green evidence.

## Environment

zuraffa `31b3ad62` + the #937 worktree fix; repro project `~/zik_zak_test` feature `002-login`.
