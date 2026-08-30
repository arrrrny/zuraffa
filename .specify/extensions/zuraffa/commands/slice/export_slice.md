---
name: "speckit.zuraffa.slice.export_slice"
description: "Export a slice as a tar.gz archive or a GitHub repo, and import it back over the sandbox."
category: "slice"
---

# Slice Export/Import: Hand a slice to an external agent

## Usage

```bash
zfa slice export <name> --format <tar.gz|github> [--repo <name>]
zfa slice import <name> --from github
```

## When to Use

Use `export` to package a verified slice for an external agent (a tar.gz archive
or a throwaway GitHub repo whose README is the slice's `SLICE.md`), and `import`
to pull the agent's repo back over the sandbox. Export verifies the slice first
and refuses to export an unverifiable slice.

## Required Parameters

- `<name>` — the slice name (matches the sandbox under `.zuraffa/slices/<name>/`).
- `--format <fmt>` — required for export; `tar.gz` or `github`.

## Flags

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--format` | enum | Yes (export) | — | `tar.gz` or `github`. |
| `--repo` | string | No | auto | Target GitHub repo (github format); auto-named when omitted. |
| `--from` | enum | Yes (import) | — | Import source; currently only `github`. |

## Output

For export: a tar.gz archive or a pushed GitHub repo URL (with `SLICE.md` as the
README). For import: the repo pulled back over the sandbox. Exits non-zero when
the slice is not exportable or the push/pull fails.
