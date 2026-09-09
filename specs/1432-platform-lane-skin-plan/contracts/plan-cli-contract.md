# Contract: `zfa tdd plan` lane-split emission (issue #1432)

## CLI surface (unchanged shape, new guarantee)

```console
$ zfa tdd plan <feature> [--project <dir>] [--strict-routing]
```

- Exit 0: every routed behavior id renders as a row in its lane plan.
- Exit 2: refusal (no artifacts written) — includes any routed behavior
  whose kind no section of its destination lane plan renders.

## Artifact contract

### `tdd/04-SKIN.md` (and `tdd/04-ENGINE.md`)

The `## Outer loop: acceptance behaviors` table carries one 4-column row per
acceptance-class behavior routed to the lane:

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |

- acceptance-typed rows: unchanged shape.
- **platform-typed rows (new): same table, same columns, same PENDING
  state** — the loop's reader resolves them exactly like acceptance rows.

### Route log ↔ artifact agreement (new invariant)

For every `route: <id> -> <lane>` line the plan prints, the named lane plan
contains a row whose first cell is `<id>`. Zero routed-but-absent ids.

### Refusal message shape (new refusal class)

```text
zfa tdd plan: refused — behavior "<id>" (<criterion>) is <kind>-kind, which
no section of the <lane> lane plan renders — the row would be dropped from
the split plan while the route log claims it (issue #1432).
   --> fix: <remedy naming the Type marker / lane declaration to change>
```

## Non-goals

- Contract-kind row rendering (open issue #1419).
- The single-file (non-lane) plan path.
- `zfa tdd split`'s kind heuristic (widget/theme → SKIN stays).
