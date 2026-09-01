# Contract: `zfa tdd run`

## CLI

```text
zfa tdd run <feature> [--project <path>] [--zfa-bin <path>]
```

- `feature` — required positional; the feature directory name under `specs/`.
- `--project` — target project root; defaults to the current directory.
- `--zfa-bin` — optional explicit zfa entrypoint for step sub-processes;
  default resolves the running CLI's own entrypoint.

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | `complete` — every behavior DONE with complete red+green evidence |
| ≠0 | `stopped` / `corrupt-state` / `concurrent-run` / `runner-error` |

## Progress lines (human + machine skimmable)

One line per completed step, printed immediately:

```text
[run] <behavior> <step> -> <outcome>
```

Example:

```text
[run] A1 gen -> ok
[run] A1 verify-red -> assertion
[run] A1 make -> green
[run] A1 refactor -> clean
```

## Summary line (machine-readable)

Final stdout line, stable key=value format:

```text
run: feature=<f> result=<complete|stopped|corrupt-state|concurrent-run|runner-error> pending=<n> red=<n> green=<n> done=<n> [stopped_at=<behavior>:<step>]
```

Examples:

```text
run: feature=049-tdd-run result=complete pending=0 red=0 green=0 done=3
run: feature=049-tdd-run result=stopped pending=1 red=1 green=0 done=1 stopped_at=B-002:make
```

## Step consumption contract

Each step is spawned as `zfa tdd <step> <behavior-id> --feature <f>
--project <dir>` and judged by exit code AND its documented summary line:

| Step | Success condition |
|------|-------------------|
| `gen` | exit 0 |
| `verify-red` | exit 0 AND `certified=true` |
| `make` | exit 0 AND `outcome=green` |
| `refactor` | exit 0 AND `outcome=clean|refactored` |

A step that is still a stub (non-zero with not-implemented output) is a step
failure: the run stops and names it (spec edge case).

## Integrity guarantees

- The driver writes only `run-state.json` (atomic) and its own stdout.
- State saves happen after every completed step; an interruption loses at
  most the in-flight step.
- DONE requires both red and green cycle-log evidence; state-file claims
  without evidence are demoted on load.
