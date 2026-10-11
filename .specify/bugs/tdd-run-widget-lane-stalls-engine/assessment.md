# Assessment — Issue #1271 (tdd-run-widget-lane-stalls-engine)

## Root cause

The two-cycle runner's lane resolution (`RunDriverCore.drive`,
`lib/src/plugins/tdd/commands/run_driver_core.dart`) buckets behaviors per
lane via `LanePlanReader.resolve` (split receipt → 04-ENGINE.md/04-SKIN.md
plan pair → ` [core]`/` [skin]`/` [both]` row tags → legacy CORE default).
The ENGINE bucket is CORE + BOTH. Widget-KIND behaviors (rows under
`## Outer loop: widget behaviors`, `BehaviorKind.widget`) that carry a
` [both]` tag — or that land in the engine bucket through the plan files or
the CORE default — are then driven through the engine steps
(gen → verify-red → make → refactor).

Engine steps on widget subjects misfire: verify-red sees the widget test as
already green (the skin implementation is in place), refuses with
`unexpected-green` → the driver's skip transition advances past verify-red,
then `make` refuses `not-certified-red` (no certified red history for the
subject) and the driver stops honestly (FR-007) at `<id>:make`. The engine
lane stalls at the first widget-lane behavior, blocking every subsequent
behavior — the exact transcript in issue.md:

```
[run] A1 gen -> ok
[run] A1 verify-red -> unexpected-green
[run] A1 verify-red -> skipped (already green)
[run] A1 make -> not-certified-red
```

Per spec 1008 (two-cycle driver), widget-lane behaviors are skin-lane work:
`run-skin` runs them only after a green engine receipt.

## Remediation

When the runner drives the ENGINE lane and encounters a widget-kind behavior
in its bucket:

1. Detect widget-kind rows in the engine bucket (`BehaviorKind.widget`).
2. Defer them: mark `pending` (they simply keep their pending state — no
   engine step is spawned), skip the engine steps entirely.
3. Queue them for the skin lane: the SKIN bucket widens by exactly the
   widget-kind rows that were in the engine bucket, so `run-skin` (and the
   meta `run`'s second lane) drives them after the engine receipt is green.
4. The engine lane keeps processing every non-widget behavior in its bucket
   (CORE + BOTH acceptance/unit/ffi/platform/contract rows — the BOTH seam's
   engine half is untouched), and the skin lane keeps processing its own
   SKIN+BOTH rows exactly as before.

The lane receipts stay honest: the engine receipt names exactly the
behaviors the engine drove (verdict green when all of those are DONE); the
skin receipt names the skin bucket including the deferred widget rows.

## Hard constraints

- Fix ONLY the two-cycle runner routing logic (the lane resolution in the
  driver core).
- Do NOT change the engine lane's step semantics or the skin lane's
  conformance cycle.
- One PR per bug.
- The fix must: (1) detect widget-kind behaviors in the engine lane bucket,
  (2) defer them to skin lane (mark pending, skip engine steps), (3) not
  break existing engine-lane CORE behavior processing, (4) not break
  existing skin-lane widget behavior processing.

## Out of scope (recorded, not fixed here)

The issue's secondary observation (unexpressible acceptance behaviors
leaving `done=0` accounting) is a separate accounting concern and is NOT
addressed by this fix.
