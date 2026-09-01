# Contract: `zfa tdd corpus status`

## CLI

```text
zfa tdd corpus status [--project <dir>]
```

- `--project` — project root. Defaults to CWD.

## Behavior

1. Load corpus manifest from `.zfa/manifests/corpus-manifest.json`.
   Exit non-zero if missing.
2. Load corpus progress from `.zfa/corpus/progress.json`.
   Use empty progress if absent.
3. Load gap ledger from `.zfa/corpus/gap-ledger.json`.
   Use empty ledger if absent.
4. Compute per-state counts: done, stopped, waived, pending, not-ready,
   dropped.
5. Determine resume point: first feature NOT in done/not-ready/dropped.
6. Compute ledger totals: total entries, unresolved (no resolution field),
   resolved.
7. Print per-feature status lines.
8. Print summary.
9. Exit 0 when all manifest features are done+gated; non-zero otherwise.

## Per-feature status line

```text
corpus status: <name> done (gate=PASS)
corpus status: <name> stopped (gate=FAIL_SURVIVED) — 1 unresolved gap
corpus status: <name> waived (reason="mutation tool unavailable")
corpus status: <name> pending
corpus status: <name> not-ready (no acceptance scenarios)
```

## Summary line (machine-readable, final stdout line)

```text
corpus status: done=<n> stopped=<n> waived=<n> pending=<n> not_ready=<n> dropped=<n> total=<n> gaps=<n> unresolved=<n> resume=<name|none>
```

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | all manifest features done+gated |
| ≠0 | incomplete (some features not done) |

## Machine-readable contract

The final stdout line is the CI-parseable contract. Exit 0 means "corpus
complete". Any non-zero means incomplete. The summary fields are
space-separated `key=value` pairs matching the format above.
