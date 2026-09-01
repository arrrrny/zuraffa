# Contract: `zfa tdd corpus run`

## CLI

```text
zfa tdd corpus run [--project <dir>] [--zfa-bin <path>]
```

- `--project` — project root containing `specs/`, `.zfa/manifests/`, and
  `lib/`. Defaults to CWD.
- `--zfa-bin` — path to the zfa CLI entrypoint for spawning per-feature
  commands. Defaults to this package's `bin/zfa.dart`.

## Behavior

1. Load corpus manifest from `.zfa/manifests/corpus-manifest.json`.
   Exit non-zero if missing.
2. Check corpus-level in-flight marker. If another run is live, refuse
   with a clear message.
3. Load or create `.zfa/corpus/progress.json`.
4. Compute resume point: first feature NOT in `done`/`not-ready`/`dropped`
   state. Skip all features before it.
5. For each `ready` feature from the resume point:
   a. Mark feature `driving` in progress, persist.
   b. Spawn `zfa tdd run <feature> --project <root>`.
   c. If exit ≠ 0: mark `stopped`, append gap ledger entry, halt corpus.
   d. Spawn `zfa tdd verify --feature <feature> --project <root>`.
   e. If exit = 0 and gate = PASS: mark `done`, record provenance.
   f. If gate = NOT_ASSESSED or any failure: mark `stopped`, append
      gap ledger entry, halt corpus.
   g. If explicit waiver exists for this feature: mark `waived`, record.
   h. Persist progress after each feature.
6. On completion: clear in-flight marker, print final report.

## Per-feature progress line

```text
corpus run: <name> -> done (gate=PASS)
corpus run: <name> -> stopped (gate=FAIL_SURVIVED, step=verify)
corpus run: <name> -> waived (reason="mutation tool unavailable")
corpus run: <name> -> skipped (not-ready)
```

## Summary line (machine-readable, final stdout line)

```text
corpus run: done=<n> stopped=<n> waived=<n> skipped=<n> pending=<n> total=<n> resume=<name|none>
```

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | all manifest features done (or not-ready skipped) |
| 1 | stopped on a feature (gap ledger entry created) |
| 2 | runner error (manifest missing, corrupt state, etc.) |
| 3 | corrupt progress state |
| 4 | concurrent run refused |

## In-flight marker

```json
{
  "in_flight": true,
  "owner_pid": 12345,
  "started_at": "2026-08-31T12:00:00.000Z"
}
```

Cleared on completion or when pid is dead on resume.
