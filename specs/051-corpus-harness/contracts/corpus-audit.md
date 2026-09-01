# Contract: `zfa tdd corpus audit`

## CLI

```text
zfa tdd corpus audit [--project <dir>]
```

- `--project` — project root. Defaults to CWD.

## Behavior

1. Scan all files under `lib/` recursively.
2. For each file, check three provenance sources in order:
   a. **Cycle logs**: parse `specs/<feature>/tdd/cycle-log.md` for `make`
      step entries that record generated file paths.
   b. **Setup/import provenance**: check the import records from #627
      (scaffold files like `main.dart`).
   c. **Carve-out manifest**: check `.zfa/corpus/carve-out.json` for
      declared manual-UI exemptions.
3. A file found in at least one source is "attributed".
4. A file not found in any source is "unattributed" and reported by name.
5. Write `.zfa/corpus/provenance.json` with the full attribution map.
6. Print per-file lines and the final summary.

## Per-file report line

```text
corpus audit: <path> attributed (cycle-log: zfa make Product)
corpus audit: <path> attributed (carve-out: manual UI layout)
corpus audit: <path> UNATTRIBUTED
```

## Summary line (machine-readable, final stdout line)

```text
corpus audit: attributed=<n> carve-out=<n> unattributed=<n> total=<n>
```

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | 100% attribution (attributed + carve-out = total) |
| 1 | unattributed files exist |

## Carve-out manifest format (`.zfa/corpus/carve-out.json`)

```json
{
  "entries": [
    {
      "path": "lib/src/features/home/home_page.dart",
      "reason": "manual widget composition per epic 045 carve-out",
      "added_by": "maintainer",
      "added_at": "2026-08-31T12:00:00.000Z"
    }
  ]
}
```
