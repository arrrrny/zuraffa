# Data Model: `zfa corpus import`

## Entities

### CorpusFeature (value object — new)

- `name` (String) — feature directory name, e.g. `001-app-bootstrap`
- `ready` (bool) — loop-ready: `SpecParser` succeeds on its spec
- `reason` (String) — one-line explanation when not ready (e.g. "no
  acceptance scenarios"), empty when ready

### CorpusManifest (model — new)

- `features` (List<CorpusFeature>) — deterministic lexicographic order
- `sourceCorpus` (String) — absolute path of the imported corpus
- `importedAt` (String) — ISO-8601 UTC; the only field that differs across
  identical re-imports
- `toJson()` / `fromJson()` / `read(projectRoot)` / `write(projectRoot,
  {dryRun})` — stored at `.zfa/manifests/corpus-manifest.json` via
  `ProjectPaths.manifestsDirectory`

### ImportOutcome (enum — new, per feature)

| Value | Meaning |
|-------|---------|
| `imported` | spec copied (new) |
| `skipped` | identical copy already present |
| `divergent` | content differs; kept unless `--force` |
| `not-ready` | spec copied but not loop-ready (reason set) |
| `foreign-artifacts-ignored` | source had extra artifacts; `spec.md` only copied |

A feature may carry both `divergent` and `not-ready`; the report lists every
applicable flag on the outcome line, never a single pigeonhole.

### CorpusImportResult (value object — new)

- `features` (List of per-feature results in manifest order)
- Convenience sets: `imported`, `skipped`, `divergent`, `notReady`

## Invariants

- `spec.md` content is copied byte-for-byte; no normalization of requirement
  text (report normalization counts separately, never content).
- Existing `specs/<feature>/tdd/**` in the target is never read, written, or
  deleted by import.
- Deterministic order: lexicographic by feature directory name.
- Manifest and report must agree on readiness (both derived from the same
  `SpecParser` call).

## State Transitions

Per feature across re-imports:

```text
absent        --import--> imported (ready|not-ready)
imported      --identical re-import--> skipped
imported      --changed source, no --force--> divergent (target kept)
divergent     --re-import --force--> imported
```

## File Contracts

- Source: `<corpus>/<feature>/spec.md` (+ ignored extra artifacts).
- Target: `<app>/specs/<feature>/spec.md` (copy), `<app>/specs/<feature>/tdd/`
  (create if absent — contents never touched).
- Manifest: `<app>/.zfa/manifests/corpus-manifest.json`.