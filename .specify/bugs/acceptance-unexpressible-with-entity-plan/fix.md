# Fix: acceptance composition composes against entity-wired unit subjects (issue #923)

## What changed

The acceptance composition surface equated "composable anchor" with "green
unit subject". An acceptance behavior whose prose is pure end-to-end flow
therefore stayed `unexpressible` whenever the feature's unit subjects were
entity-wired but not yet green — the exact spec-004 state issue #923
reports: `composition fallback disengaged: no green unit subjects to
compose against` → `outcome=unexpressible`, deferred phase 1 → phase 2a,
red forever.

`CompositionTargets.discover()` now anchors a unit-kind row on EITHER
precondition:

1. **green** — green cycle-log evidence + existing subject artifact
   (unchanged contract, including the fail-closed
   `missing-anchor-subject` stop); or
2. **entity-wired** (issue #923) — the registry subject artifact exists on
   disk and carries the `zfa tdd wire` implementation anchor
   (`final Type wiredEntityAnchor = <Entity>;`, bug #610) in EXECUTABLE
   code — line comments are stripped per line before matching (the same
   discipline as wire's `_hasExecutableUnimplementedError`), so a marker
   mentioned in a comment never anchors. A missing record or file in this
   branch is a normal not-yet-wired state (not an anomaly): the row is
   skipped, never a silent failure of another row's evidence.

`ComposableUnitSubject` carries the new `entityWired` flag and the audit
trails name the mix honestly:

- `zfa tdd compose` prints `anchors: U1 [entity-wired], U2 (0 green, 2
  entity-wired unit subject(s))` and stamps the composed subject's
  `composed against:` line with per-anchor `[entity-wired]` markers plus a
  note that an entity-wired anchor carries only wiring so far — the
  composed scenario's real green transition lands when those unit subjects
  are filled with business logic.
- the composition plan's step purpose and the make fallback's report print
  `N green, M entity-wired unit subject(s)`.

The honest stops are untouched: zero composable anchors still fails
`no-green-units` (code unchanged for machine-contract stability; message
updated to name both preconditions), non-acceptance targets still fail
closed, the certified-red precondition for compose is unchanged, and the
planner stays pure and description-keyed.

## Files

- `lib/src/plugins/tdd/services/composition_targets.dart` — the anchor
  contract (green OR entity-wired), `carriesWiredEntityAnchor`, honest
  `no-green-units` message.
- `lib/src/plugins/tdd/commands/compose_command.dart` — honest anchor
  audit line + composed-subject stamping.
- `lib/src/plugins/tdd/services/composition_planner.dart` — honest step
  purpose naming the green/entity-wired mix.
- `lib/src/plugins/tdd/commands/make_command.dart` — honest fallback
  report.
- `test/plugins/tdd/services/composition_targets_test.dart` — U6-U9 (the
  issue-#923 discovery contract).
- `test/plugins/tdd/commands/compose_command_test.dart` — A6b (compose
  against an entity-wired anchor).
- `test/plugins/tdd/make_command_test.dart` — A13b (the acceptance make
  composes and certifies green on an entity-wired, non-green unit).

## Behavior after the fix (real CLI, spec-004 shape)

```
$ zfa tdd make A1 --feature 004-cloud-agent-task-dispatch
   composition fallback: 0 green, 2 entity-wired unit subject(s) (U1, U2)
   plan: composition fallback — 2 step(s)
make: behavior=A1 outcome=green feature=004-cloud-agent-task-dispatch
```

The acceptance behavior is expressible via the composition surface the
moment its units are entity-wired; it is never stuck at `unexpressible`
while the units are wired.
