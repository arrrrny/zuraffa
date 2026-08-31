# Contract: `corpus import` report and summary lines

**Feature**: 050-corpus-import (issue #627)
**Status**: pinned by `test/cli/services/corpus_importer_test.dart` (U15)
and the acceptance tests in `test/commands/corpus_command_test.dart`
(A1-A8); exercised end-to-end by quickstart.md scenarios 2-5.

This file was referenced by tasks.md as a plan-time prerequisite but
never committed; it is written down here (during implementation, at
green) exactly as the tests pin it, so the report surface is a stated
contract rather than an implementation accident.

## Per-feature report line

One line per feature, in manifest (lexicographic) order, printed by
`zfa corpus import` (and by `zfa setup --specs`'s import step, indented
under `[7/8]`):

```text
<feature-name>: <copy-outcome>[ foreign-artifacts-ignored (<entries>)][ not-ready (<reason>)]
```

- `<copy-outcome>` is one of:
  - `imported` — target spec was absent (or `--force` replaced a
    divergent copy) and the source content was written verbatim.
  - `skipped` — an identical copy was already present; nothing written.
  - `divergent (source sha256:<hex>, target sha256:<hex>)` — source
    differs from the imported copy; the target is KEPT (update requires
    `--force`) and both sha256 hex digests are printed.
- `foreign-artifacts-ignored (<entries>)` — the source feature carried
  speckit-era artifacts other than `spec.md`; entries are the ignored
  names, comma-separated (e.g. `checklists, tdd`). Never copied, never
  converted, never deleted.
- `not-ready (<reason>)` — the readiness mark failed; `<reason>` is the
  one-line derivation of the `SpecParser` failure (the exact parser
  `zfa tdd plan` uses), e.g. `no acceptance scenarios`.
- Flags combine on one line — never a single pigeonhole (data-model.md):
  e.g. `002-no-scenarios: skipped not-ready (no acceptance scenarios)`.

Every line is prefixed `[dry-run] ` under `--dry-run`.

## Summary line

Exactly one summary line after the feature lines:

```text
corpus import: <N> features — <X> imported, <Y> skipped, <Z> divergent, <R> not-ready (manifest: <projectRoot>/.zfa/manifests/corpus-manifest.json)
```

- `<N>` is the total number of features in the corpus (all of them —
  nothing is silently dropped, FR-005).
- `<X>/<Y>/<Z>` count copy outcomes; `<R>` counts not-ready features.
- The manifest path is the absolute project-rooted path.
- `[dry-run] `-prefixed under `--dry-run`.

## Exit codes

- `0` for a completed copy operation — not-ready features are reported,
  never fatal (FR-005).
- Non-zero (clean `❌ Error:` message, no stack trace without
  `--verbose`) for an invalid source: not found, a file, a
  single-feature directory, or an empty corpus.

## Manifest shape (the #628 batch-driving contract)

`.zfa/manifests/corpus-manifest.json` (via `ProjectPaths`):

```json
{
  "source_corpus": "/abs/path/corpus",
  "imported_at": "<ISO-8601 UTC>",
  "features": [
    {"name": "001-clean", "ready": true, "reason": ""},
    {"name": "002-no-scenarios", "ready": false, "reason": "no acceptance scenarios"}
  ]
}
```

Deterministic: features sorted lexicographically, fixed key order,
2-space-indented JSON — identical re-imports produce byte-identical
files except `imported_at` (SC-004). Readiness marks come from the same
`SpecParser` verdict `zfa tdd plan` applies, so a consumer (#628) can
rely on `ready`/`reason` without re-deriving them.
