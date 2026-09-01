# Contract: `zfa tdd make`

## CLI

```text
zfa tdd make [behavior-id] [--feature <feature-dir-name>] [--zfa-bin <path>]
```

- `behavior-id` — optional positional; same resolution rules as
  `zfa tdd verify-red` (spec 046 FR-002).
- `--feature` — optional feature override (same conventions as gen/verify-red).
- `--zfa-bin` — optional explicit path/command for the zfa entrypoint used by
  pipeline sub-processes; default resolves the running CLI's own entrypoint,
  falling back to `zfa` on PATH. Unresolvable → misfire-stop.

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | green certified: implementation generated, target test passes, suite guard clean, evidence appended |
| ≠0 | not certified: named outcome printed, no green entry |

## Summary line (machine-readable)

Final stdout line, stable key=value format, mirroring the verify-red contract:

```text
make: behavior=<id> outcome=<green|not-certified-red|drift|unexpressible|generation-error|regression|runner-error> feature=<feature>
```

Examples:

```text
make: behavior=B-003 outcome=green feature=047-tdd-make
make: behavior=B-003 outcome=regression feature=047-tdd-make
```

## Green-evidence cycle-log entry (append-only)

On certification, one entry appended to `specs/<feature>/tdd/cycle-log.md`:

```markdown
## Cycle: B-003 (green)

- behavior: B-003
- kind: green
- criterion: FR-007
- test: test/B-003_test.dart
- command: `dart test test/B-003_test.dart --plain-name "..."`
- exit: 0
- at: 2026-08-30T12:00:00.000Z
- generation:
  - `zfa entity create -n Product --field name:String` (exit 0)
  - `zfa make Product --preset=crud --methods=get` (exit 0)
  - `zfa build` (exit 0)
- suite: 128 passed, 0 failed (baseline 127 passed, 0 failed; 0 new failures)
- output:
```text
+1: All tests passed!
```
```

Field order fixed; `generation` lists every pipeline step in execution order;
`suite` records baseline vs guard counts (spec FR-007/FR-008).

## Errors

All rejections print `zfa tdd make: <outcome> — <detail>` to stderr before
the summary line, with remediation hints: run `verify-red` first
(not-certified-red), behavior drifted (drift), name the unmet capability
(unexpressible), name the failing step (generation-error), name the regressed
tests (regression).

## Integrity guarantees

- Writes to `cycle-log.md` only on certification, append-only.
- Never modifies any file under `test/`.
- Modifies `lib/` only through recorded pipeline sub-process invocations —
  every change to production source is attributable to a logged generation
  step.
