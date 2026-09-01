# Contract: Gap Ledger

## File

`.zfa/corpus/gap-ledger.json`

## Format

```json
{
  "entries": [
    {
      "feature": "003-broken-gen",
      "behavior": "U1",
      "step": "make",
      "outcome": "stopped",
      "command": "zfa tdd run 003-broken-gen --project /app",
      "issue_link": null,
      "timestamp": "2026-08-31T12:05:00.000Z",
      "resolution": null
    }
  ]
}
```

## Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `feature` | String | yes | feature directory name |
| `behavior` | String? | no | behavior id (e.g. `U1`, `A2`) if stopped during loop driving |
| `step` | String? | no | step that failed (gen/verify-red/make/refactor/verify) |
| `outcome` | String | yes | stop outcome (stopped/runner-error/FAIL_SURVIVED/FAIL_TIMEOUT/PREFLIGHT_RED/NOT_ASSESSED) |
| `command` | String | yes | the failing command string |
| `issue_link` | String? | no | GitHub issue URL; null until filed |
| `timestamp` | String | yes | ISO-8601 UTC when the stop occurred |
| `resolution` | String? | no | null while blocking; set to `"resolved"` when a later run passes the feature |

## Semantics

- **Append-only**: entries are never edited or removed.
- **Resolution**: when a previously-stopped feature passes on re-run, a
  NEW entry with the same `feature` name and `resolution: "resolved"` is
  appended. The original entry remains.
- **Ledger totals** (for status/report):
  - `total`: all entries
  - `unresolved`: entries where `resolution` is null and `issue_link` is null
  - `filed`: entries where `issue_link` is non-null
  - `resolved`: entries where `resolution` is `"resolved"`
  - `blocking`: entries that are unresolved AND block corpus completion

## Integrity

- Atomic writes via temp+rename (same pattern as RunStateStore).
- Never edit past entries — the ledger is the audit trail.
