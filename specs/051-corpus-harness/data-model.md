# Data Model: `zfa tdd corpus`

## Entities

### CorpusFeature (value object — input, owned by #627)

- `name` (String) — feature directory name under `specs/`, e.g.
  `001-app-bootstrap`
- `ready` (bool) — loop-ready per the manifest's readiness mark
- `reason` (String) — one-line not-ready reason; empty when ready

### CorpusManifest (model — input, read-only)

- `features` (List<CorpusFeature>) — manifest order (lexicographic from
  import; the harness preserves file order verbatim and never re-sorts:
  order IS the driving order)
- `sourceCorpus` (String?) — provenance of the import
- `importedAt` (String?) — ISO-8601
- `fromJson` / `read(projectRoot)` — decodes
  `.zfa/manifests/corpus-manifest.json`; malformed JSON, a non-object
  root, non-list features, or a row missing `name`/`ready` is a
  corrupt-state stop naming the file and recovery path

### FeatureCorpusState (enum)

| Value | Meaning |
|-------|---------|
| `pending` | manifest feature not yet driven |
| `driving` | in-flight (crash marker; resume re-enters it) |
| `done` | loop complete AND verify gate passed (gate recorded) |
| `waived` | loop complete AND gate outcome explicitly waived (waiver recorded) |
| `stopped` | a roadblock stopped this feature (ledger entry exists) |

### CorpusWaiver (value object — maintainer-authored input)

- `feature` (String) — the manifest feature name
- `gate` (String) — the gate label the waiver covers (`not_assessed`,
  `fail_timeout`, …) — exact-match only
- `reason` (String) — why the gate outcome is accepted
- `actor` (String) — who waived
- `at` (String) — ISO-8601 timestamp

File: `.zfa/corpus/waivers.json` (array). Absent file = no waivers.

### CorpusProgress (model — runner-owned state)

- `features` (Map<String, FeatureProgress>) keyed by feature name:
  - `state` (FeatureCorpusState)
  - `gate` (String?) — the recorded verify gate label when evaluated
  - `stoppedAt` (String?) — `<behavior>:<step>` from the run summary, or
    `verify` / `gate:<label>` for gate stops
  - `waiver` (CorpusWaiver?) — copied in full when a waiver applied
- `inFlight` ({feature, ownerPid}?) — the corpus-level concurrency marker
- `dropped` (List<String>) — progress features absent from the current
  manifest (append-only audit trail, mirroring `run`'s dropped semantics)
- `toJson` / `fromJson`; persisted by `CorpusProgressStore` atomically
  (temp + rename) after every feature; a crash mid-write leaves the
  previous file intact

File: `.zfa/corpus/progress.json`.

### GapLedgerEntry (model — append-only)

Gap entries (runner-appended):

- `id` (String) — `gap-001`, monotonic across the file
- `kind` (String) — `gap`
- `at` (String) — ISO-8601 UTC
- `feature` (String) — manifest feature name
- `behavior` (String?) — the behavior id the stop hit (from run's
  `stopped_at`; null for gate/manifest-level stops)
- `step` (String) — the second token of run's `<behavior>:<step>` stop point,
  or `verify` for a verify-gate failure
- `outcome` (String) — run `result=` token (`stopped`, `runner-error`,
  `corrupt-state`, `concurrent-run`) or the verify gate label
  (`fail_survived`, `not_assessed`, …)
- `expectedResult` (String) — the success token the failed command was
  expected to report: `complete` for `run`, `pass` for `verify`
- `failingCommand` (String) — the spawned argv joined (e.g.
  `zfa tdd run 001-app-bootstrap --project …`)
- `issueLink` (String?) — null placeholder until the maintainer files the
  issue
- `status` (String) — `open` when appended; `filed`/`merged` are
  maintainer edits (the ledger file is maintainer-editable in exactly
  these two fields)

Resolution entries (runner-appended when a previously-stopped feature
later completes — a NEW entry, never an edit):

- `kind`: `resolution`
- `resolves` (String) — the gap entry id it closes
- `feature`, `at`, plus `outcome: resolved`

File: `.zfa/corpus/gap-ledger.json` (JSON array). Load → append → atomic
rename; history is never rewritten.

### ProvenanceRecord (value object — input, owned by #626/#627)

- `command` (String) — the recorded zfa invocation (e.g.
  `zfa setup zik_zak_tdd --platforms=…`)
- `at` (String?) — ISO-8601
- `files` (List<String>) — files the command created/owns
  (project-relative or absolute)

Files: `.zfa/provenance/*.json`, each a single record (or an array of
records). Absent directory = no setup/import provenance.

### CarveOutEntry (value object — maintainer-authored input)

- `path` (String) — project-relative path (exact file path; `lib/` prefix
  implied by scope but recorded in full)
- `reason` (String) — why this file is manual-UI

File: `.zfa/manifests/corpus-carveout.json` —
`{carveouts: [{path, reason}]}`. The audit's sole exemption path.

### CorpusStepResult (value object — service output)

- `step` (`run` | `verify`), `exitCode`, `outcome` (the parsed machine
  token: run's `result=`, verify's `gate=`), `success` (exit 0 AND
  outcome ok per the step's contract), `output` (combined stdout+stderr),
  `stoppedAt` (String? — run's `stopped_at=` when present)

## Invariants

- Evidence beats state (house rule): a `done` progress claim requires the
  verify gate PASS recorded in the same progress entry; the runner never
  fabricates it.
- The runner writes ONLY: `progress.json`, `gap-ledger.json`,
  `audit-report.json`. It never edits the manifest, waivers, carve-out,
  specs/, lib/, or test/.
- A feature is corpus-done ONLY through `done` (gate pass) or `waived`
  (recorded waiver) — worked-around progress never counts (FR-004).
- Any feature-level stop halts the corpus before any later feature starts
  (FR-002); the stop is ledgered with all six FR-007 fields.
- Ledger entries are immutable once written except the maintainer-only
  `issueLink`/`status` edits; resolutions are new entries.
- Not-ready features are skipped and reported, never spawned (FR-003).
- Concurrent corpus runs on the same app are refused via the in-flight
  pid marker (FR-010); no state corruption.
- The audit fails on ANY unattributed `lib/` file, by name (FR-005) — the
  carve-out manifest is the only exemption path (US3.AC3).

## State Transitions

Per feature across corpus runs:

```text
(absent)          --manifest ready, driven--> driving --run 0, gate pass--> done
driving           --crash (marker)--> resumed as driving on next run
driving           --run stop / gate fail / not_assessed--> stopped + ledger gap
stopped           --gap fixed, re-run passes--> done + ledger resolution (new entry)
(any)             --gate outcome == waiver--> waived (waiver recorded)
done|waived       --never re-driven (resume skips)
not-ready         --never driven (reported only)
```

Across manifest edits:

```text
progress entry + feature removed from manifest --> dropped list (entry kept)
feature added to manifest                      --> pending, driven next run
```

## File Contracts

| Path | Owner | Writer |
|------|-------|--------|
| `.zfa/manifests/corpus-manifest.json` | #627 import | import (051 reads) |
| `.zfa/manifests/corpus-carveout.json` | maintainer | maintainer (051 reads) |
| `.zfa/corpus/waivers.json` | maintainer | maintainer (051 reads) |
| `.zfa/corpus/progress.json` | corpus runner | corpus runner (atomic) |
| `.zfa/corpus/gap-ledger.json` | corpus runner + maintainer edits | append-only |
| `.zfa/corpus/audit-report.json` | corpus audit | corpus audit |
| `.zfa/provenance/*.json` | #626/#627 setup/import | those features (051 reads) |
