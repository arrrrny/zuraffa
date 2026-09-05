# Contract: `zfa corpus catalog` / `zfa corpus run` / `zfa corpus ledger` (epic #1017 CORPUS-WALK)

## CLI

```text
zfa corpus catalog --target <name> [--source <dir>] [--reclassify] [--project <dir>]
zfa corpus run    --target <name> [--budget <n>] [--project <dir>] [--zfa-bin <path>] [--timeout <minutes>]
zfa corpus ledger --target <name> [--project <dir>] [--zfa-bin <path>] [--timeout <minutes>]
```

- `--target` — the corpus target being walked (e.g. `zik_zak`). Names the
  catalog/ledger files under `corpus/`. Required. Lowercase letters,
  digits, dashes, underscores.
- `--project` — the driven app's root (containing `specs/`,
  `.zfa/manifests/`). Defaults to the current working directory (the
  corpus import's rule).
- `--source` (catalog only) — a corpus root to walk directly (feature
  directories with `spec.md`) instead of the project's corpus manifest.
  Explicit beats implicit.
- `--reclassify` (catalog only) — discard preserved manual
  classifications and recompute every verdict from the spec signals.
- `--budget` (run only) — the configurable failure budget: the maximum
  non-green count (`partial + blocked`) the walk tolerates. Default 5
  (the epic's exit criterion M+K <= 5).
- `--zfa-bin` / `--timeout` — the spec 049/051 spawn-contract options,
  verbatim: the entrypoint for the per-feature `tdd run` / `tdd verify`
  spawns, and the per-step deadline (default 10 minutes).

## Committed artifacts (the reviewable state)

| Path | Written by | Role |
|------|-----------|------|
| `corpus/catalogs/<target>.json` | catalog | the walk's input contract: features, CORE/SKIN, readiness, spec sha256 |
| `corpus/ledgers/<target>.json` | ledger | the merge gate: recorded verdicts the next run diffs against |
| `.zfa/corpus/walks/<target>.json` | run + ledger | runtime walk results (gitignored — transient evidence) |

`.zfa/` is gitignored by the repo's `.gitignore`; the catalog and ledger
live under the tracked `corpus/` tree precisely because they are
committed state (the epic: "Ledger committed; subsequent runs are
diffs").

## catalog

1. Resolve features: `--source` corpus root (readiness from the same
   `SpecParser` verdict `zfa tdd plan` uses) or the corpus manifest
   (readiness from its `ready`/`reason` marks).
2. For each feature: read `spec.md`, hash it (sha256 of bytes), classify
   CORE/SKIN (signal scoring: skin signals vs core signals, word
   boundary, case-insensitive, over feature name + spec content; strict
   majority SKIN, ties CORE).
3. Preserve committed manual classifications for unchanged spec hashes
   (unless `--reclassify`).
4. Write `corpus/catalogs/<target>.json` deterministically (fixed key
   order, features sorted by name; byte-identical across regenerations
   except `generated_at`).

Per-feature line: `[corpus] <name> -> <CORE|SKIN>[ (preserved)][ [not-ready: <reason>]]`

Summary line (final stdout line):

```text
corpus catalog: target=<t> source=<manifest|source> features=<n> core=<c> skin=<s> result=ok
```

Exit codes: `0` ok; `2` runner/usage error (no manifest and no
`--source`, missing spec, invalid target, empty `--source` corpus).

## run (the walk)

1. Load the committed catalog (no catalog -> exit 2 with the catalog
   guidance). An empty catalog is a misfire (exit 2).
2. Parse `--budget` (default 5; invalid -> exit 2).
3. For EVERY cataloged feature, in catalog order:
   - not-ready -> `blocked`, never spawned;
   - hash `specs/<f>/spec.md` at WALK TIME (missing -> `blocked`);
   - spawn `zfa tdd run <f> --project <root>`; failure -> `blocked`;
   - spawn `zfa tdd verify --feature <f> --project <root>`; pass ->
     `green`; non-pass gate -> `partial`.
   - The walk NEVER stops at a failing feature (the budget is the gate).
4. Persist the results to `.zfa/corpus/walks/<target>.json`.
5. Print the tallies.

Per-feature line: `[corpus-walk] <name> -> green (gate=pass) | partial (gate=<label>) | blocked (<detail>)`

Over-budget breach line: `zfa corpus run: over budget — <used> non-green (budget: <b>): <name> (partial), ...`

Summary line (final stdout line):

```text
corpus run: target=<t> features=<n> green=<g> partial=<m> blocked=<k> budget=<b> used=<u> result=<ok|over-budget>
```

Exit codes: `0` within budget (`partial + blocked <= budget`); `1` over
budget; `2` runner/usage error.

## ledger (the merge gate)

1. Load the catalog (same rules as run: no/empty catalog -> exit 2).
2. Read the committed ledger BEFORE walking (corrupt -> exit 2 with the
   recovery; absent -> baseline mode).
3. Walk (identical to run).
4. Baseline mode: write the ledger, `result=baseline`, exit 0.
5. Diff mode — compare the walk against the committed ledger:
   - regression: committed `green` now non-green, or a committed green
     feature absent from the walk (`[ledger] <name>: green -> <verdict>
     (REGRESSION)`, `[ledger] removed: <name> (was green — REGRESSION…)`);
   - renewed: spec hash changed, still green;
   - added: new feature (`[ledger] added: <name> (<verdict>)`);
   - removed (non-green): reported.
6. The ledger advances (is rewritten) ONLY on a clean diff — a
   contract-break leaves the committed ledger untouched, so the break
   cannot be absorbed by the run that detected it.

Summary line (final stdout line):

```text
corpus ledger: target=<t> features=<n> green=<g> partial=<m> blocked=<k> regressions=<r> added=<a> removed=<x> result=<baseline|clean|contract-break>
```

Exit codes: `0` baseline or clean; `1` contract-break (the CI gate:
new features that break existing contracts are CI failures); `2`
runner/usage error.

## CI wiring (the epic's exit criteria)

```yaml
# walk finishes; green: N | partial: M | blocked: K (M+K <= 5)
- run: dart run bin/zfa.dart corpus run --target zik_zak --budget 5
# ledger as merge gate; subsequent runs are diffs
- run: dart run bin/zfa.dart corpus ledger --target zik_zak
```

The committed `corpus/catalogs/zik_zak.json` and
`corpus/ledgers/zik_zak.json` ride the PR; a PR that regresses a green
contract fails the ledger gate; a PR whose walk exceeds the budget
fails the run gate.
