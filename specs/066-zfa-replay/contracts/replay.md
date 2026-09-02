# Contract: `zfa replay` CLI + machine output (spec 066)

## Invocations

```text
# Primary (house TDD surface)
zfa tdd replay <feature> [--behavior <id>] [--project <dir>] [--zfa-bin <path>]
                [--timeout <minutes>] [--events <path>] [--keep-sandbox]

# Dream surface (issue #806) — same capability, delegates
zfa replay <feature> [same flags]
zfa replay <path/to>/tdd/cycle-log.md [same flags]   # feature derived from the path
```

- `<feature>` — a feature directory under `specs/` (accepts the bare id or a
  `specs/<id>` prefix, like `zfa tdd run`).
- Cycle-log path form: the containing directory must be `<…>/specs/<feature>/tdd`
  and the file must be named `cycle-log.md`; the nearest project root is found by
  the standard pubspec walk-up.
- Usage errors (missing `<feature>`, unknown flag) → `usageException` → exit 64.

## Stdout contract

Header (always, first line):

```text
[replay] feature=<feature> project=<projectRoot> sandbox=<sandboxPath>
```

Per-stage progress lines (in execution order):

```text
[replay] <behavior> integrity -> verified            # chain + red checks pass
[replay] <behavior> integrity -> diverged (chain mismatch: green)
[replay] <behavior> gen -> identical (0 paths)
[replay] <behavior> gen -> drift (2 paths: test/a_test.dart modified; lib/b.dart added)
[replay] <behavior> gen -> skipped (no generation block)
[replay] <behavior> verify -> green (exit 0)
[replay] <behavior> verify -> diverged (exit expected 0, actual 1)
[replay] <behavior> verify -> skipped (no package resolution)
[replay] <behavior> refactor -> recorded, not re-executed (1 entry)
```

Warnings (`unverified: schema-0`, skip reasons) are printed as
`[replay] warning: …` lines before the summary.

Final line (machine summary, EVERY code path — the last stdout line):

```text
replay: feature=<feature> result=<clean|divergent|partial> replayed=<n> skipped=<n> diverged=<k> [sandbox=<path>]
```

(`sandbox=` suffix only with `--keep-sandbox`.)

Error paths (before the summary, human context):

```text
zfa tdd replay: no recorded history for feature <feature> at specs/<feature>/tdd/cycle-log.md
zfa tdd replay: unknown behavior <id> — recorded behaviors: <a, b, c>
zfa tdd replay: <n> behaviors recorded but none carry machine-format entries (narrative log?)
```

## Exit codes (#778 vocabulary, spec FR-013)

| Exit | Result      | Meaning                                                             |
|------|-------------|---------------------------------------------------------------------|
| 0    | `clean`     | Every replayed stage reproduced; skips allowed as warnings          |
| 1    | `divergent` | ≥1 divergence (integrity / artifact drift / verify) or infra failure (missing log, unknown behavior, sandbox failure) |
| 2    | `partial`   | No divergences but nothing was replayable (zero machine entries, or every behavior skipped) |
| 64   | —           | Usage error                                                         |

## NDJSON event log (`--events <path>`)

See data-model.md §ReplayEvent for the exact shapes. Guarantees:

1. One JSON object per line, UTF-8, `\n`-terminated.
2. Starts with `replay.start`, ends with `replay.end`.
3. Written on every outcome (clean, divergent, partial, infra failure) — an agent
   harness can always read the outcome.
4. `replay.end.exit` equals the process exit code.
5. Without `--events`, no event file is created and stdout carries only the house
   contract lines above.

## Read-only guarantees

- Nothing under the real project root is created, modified, or deleted by replay.
- The real cycle-log is never appended to (a replay is not a cycle).
- Sandbox: `Directory.systemTemp.createTemp('zfa_replay_')`; deleted in a
  `finally` unless `--keep-sandbox` (then its path is in the header + summary).
