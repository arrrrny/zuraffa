# RED Evidence — Issue #1271 (tdd-run-widget-lane-stalls-engine)

Date: 2026-09-07
Branch: fix/1271-tdd-run-widget-lane-stalls-engine
Base: d3679e0f (master)
Toolchain: Dart SDK 3.13.3 (stable) linux_x64

## Test-first RED

New test (written BEFORE the fix, run against the unmodified runner):
`test/plugins/tdd/commands/bug_1271_widget_lane_engine_deferral_test.dart`

```
dart test --preset=all test/plugins/tdd/commands/bug_1271_widget_lane_engine_deferral_test.dart
→ 00:29 +0 -3: Some tests failed.        (0 passed, 3 failed)
```

All three tests failed for the RIGHT reason — the engine lane genuinely
routes widget-kind behaviors through the engine steps and stalls:

### T1 — run-engine drives the widget-kind BOTH row and stalls (exit 1)

Fixture: `004-login-ui` — U1/U2 `[core]` acceptance rows; `## Outer loop:
widget behaviors` section with A1 (`[both]`, widget-kind), W1/W2 (`[skin]`,
widget-kind). Scripted (fake zfa): `verify-red A1 → unexpected-green`,
`make A1 → not-certified-red`.

```
zfa tdd run-engine: feature 004-login-ui — 3 behavior(s)
   suite baseline: dart test (once per run — issue #741)
[run] U1 gen -> ok
[run] U1 verify-red -> certified
[run] U1 make -> green
[run] U1 refactor -> clean
[run] U2 gen -> ok
[run] U2 verify-red -> certified
[run] U2 make -> green
[run] U2 refactor -> clean
[run] A1 gen -> ok
[run] A1 verify-red -> unexpected-green
[run] A1 verify-red -> skipped (already green)
[run] A1 make -> not-certified-red
zfa tdd run-engine: step failed — behavior=A1 step=make outcome=not-certified-red
   resume: fix the failing step, then re-run `zfa tdd run-engine 004-login-ui`
run-engine: feature=004-login-ui lane=engine result=stopped pending=1 red=0 green=0 done=2 stopped_at=A1:make
```

Byte-for-byte the issue's stall transcript (`A1 gen -> ok` → `verify-red ->
unexpected-green` → `skipped (already green)` → `make -> not-certified-red`,
honest stop at `A1:make`, exit 1, engine receipt red, W-lane and U2-adjacent
work blocked). Wait — order note: in the fixture U1/U2 precede A1 in list
order, so the stall blocks "the remaining behaviors" (here the skin lane's
rows W1/W2 stay undriven; with A1 first in list order — the issue's shape —
every subsequent behavior is blocked, as filed).

### T2 — meta run routes the widget-kind BOTH row through the ENGINE lane

```
Expected: Set:['U1', 'U2']
  Actual: Set:['U1', 'U2', 'A1']
  Which: larger than expected
```
The engine receipt owned A1 (widget-kind) — engine-lane work, not deferred
to the skin lane.

### T3 — untagged widget-kind row (CORE default bucket) driven by run-engine

```
Expected: empty
  Actual: ['gen W2', 'verify-red W2', 'make W2', 'refactor W2']
```
An untagged widget-kind row (legacy CORE default → engine bucket) is driven
through the engine steps by `run-engine` instead of being deferred.

## Post-fix GREEN (same tests, same commands)

```
dart test --preset=all test/plugins/tdd/commands/bug_1271_widget_lane_engine_deferral_test.dart
→ 00:20 +3: All tests passed!
```

- T1: exit 0, zero A1 invocations, U1/U2 driven exactly as before, engine
  receipt `verdict: green` naming `{U1, U2}`.
- T2: A1's steps land in the SKIN phase (after the last U1/U2 step); engine
  receipt `{U1, U2}` green; skin receipt `{A1, W1, W2}` green.
- T3: run-engine defers the untagged widget row (receipt `{U1}`); the
  standalone run-skin picks it up behind the green engine receipt and
  drives `W2, W1` (receipt `{W1, W2}` green).
