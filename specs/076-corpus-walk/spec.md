# Feature Specification: CORPUS-WALK — walk a spec corpus, ledger as merge gate

**Feature Branch**: `076-corpus-walk` (driven on `epic/1017-corpus-walk`)

**Created**: 2026-09-05

**Status**: Draft

**Input**: Epic [#1017](https://github.com/arrrrny/zuraffa/issues/1017) "CORPUS-WALK: Walk ZikZak 120 specs — ledger as merge gate" (Track: Validation; depends on LOOP-RUNTIME and MOCK-CERTIFICATION). Child work items: catalog ZikZak specs with CORE/SKIN classification; `zfa corpus run --target=zik_zak` with configurable failure budget; `zfa corpus ledger --target=zik_zak` as merge gate.

## Mission

Epic 045's target app carries zik_zak's 120 extracted feature specs, and
spec 050 + spec 051 got them imported and batch-driven — but the WALK
(the one-command validation sweep across the whole corpus with a
tolerance for known gaps) and the LEDGER (the committed record that
turns contract regressions into CI failures) do not exist. Today,
"did the corpus survive this PR?" is answered by a human reading a
stop-on-roadblock log. This feature closes that: the walk finishes and
reports `green: N | partial: M | blocked: K` under a configurable
failure budget, and the committed ledger makes "new features that break
existing contracts" a machine-detected CI failure — a diff, never prose.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Catalog the corpus; classify CORE/SKIN (child #1015; Priority: P1)

A maintainer preparing the walk runs
`zfa corpus catalog --target zik_zak` on the driven app. The command
resolves the target's features from the corpus manifest (or walks a
`--source` corpus root directly), classifies each spec CORE (engine
seam: entities, mocks, repositories, DI, use cases) or SKIN
(presentation seam: views, routes, adaptive layouts, platforms) with a
deterministic signal classifier, and writes the committed catalog
`corpus/catalogs/zik_zak.json` — committed, so the classification is
reviewable and manual edits survive regeneration.

**Why this priority**: every later verdict (walk tallies, ledger rows)
is keyed by classification; without the catalog the walk has no input
contract and the ledger has no reviewable provenance.

**Acceptance Scenarios**:

1. **Given** a driven app whose manifest lists N features, **When** the
   maintainer catalogs target `zik_zak`, **Then** every feature lands in
   `corpus/catalogs/zik_zak.json` with a CORE/SKIN classification, a
   readiness mark with reason, and the spec's sha256, and the summary
   line reports `features=N core=<c> skin=<s> result=ok`.
2. **Given** a committed manual classification edit (CORE->SKIN) whose
   spec hash is unchanged, **When** the catalog regenerates, **Then**
   the edit is preserved (and the report names it preserved);
   `--reclassify` discards edits and recomputes.
3. **Given** no manifest and no `--source`, **When** the catalog runs,
   **Then** it stops with exit 2 naming the import (or `--source`) as
   the recovery — never a silent empty catalog.
4. **Given** a manifest feature whose `specs/<f>/spec.md` is missing,
   **When** the catalog runs, **Then** it stops with exit 2 naming the
   feature and the `--> fix:` recovery.

### User Story 2 — The walk: run the whole corpus under a failure budget (child #1016; Priority: P1)

The maintainer runs `zfa corpus run --target zik_zak --budget 5`. The
walk drives EVERY cataloged feature through the loop runtime's
per-feature machine contract (`zfa tdd run` + `zfa tdd verify` — the
same spawn contract spec 051 established), classifying each feature
green / partial / blocked. Unlike spec 051's STOP-ON-ROADBLOCK, the walk
NEVER stops at a failing feature: it walks the whole corpus, because the
budget — `partial + blocked <= budget` — is the gate.

**Acceptance Scenarios**:

1. **Given** a cataloged corpus where 1 feature is green, 1 partial
   (`verify` gate non-pass), and 1 blocked (`run` fails), **When** the
   walk runs with `--budget 2`, **Then** every feature is driven in
   catalog order (the partial and blocked ones included), the summary
   line reports `features=3 green=1 partial=1 blocked=1 budget=2
   used=2 result=ok`, and the exit code is 0.
2. **Given** the same corpus with `--budget 1`, **When** the walk runs,
   **Then** the summary reports `result=over-budget`, the report names
   the non-green features, and the exit code is 1 (a CI failure).
3. **Given** a not-ready feature, **When** the walk runs, **Then** the
   feature is `blocked (not-ready: <reason>)` and never spawned.
4. **Given** no catalog for the target, **When** the walk runs, **Then**
   it stops with exit 2 and a `--> fix:` pointing at
   `zfa corpus catalog --target zik_zak`.
5. **Given** an invalid `--budget` value, **When** the walk runs,
   **Then** it stops with exit 2 naming the budget contract (default 5).

### User Story 3 — The ledger as merge gate (child #1017; Priority: P1)

The maintainer runs `zfa corpus ledger --target zik_zak`. The command
walks the corpus (same walk), then records the verdicts in the committed
ledger `corpus/ledgers/zik_zak.json`. The first run writes the baseline
(exit 0). Every subsequent run is a DIFF against the committed ledger:
additions and renewals are reported and recorded; REGRESSIONS — a
committed green contract now partial/blocked, or a green feature that
vanished — are CI failures (exit 1). The ledger advances only on a clean
diff, so a break cannot be absorbed by the run that detected it.

**Why this priority**: this is the epic's exit criterion — "New features
that break existing contracts are CI failures." A new feature that
breaks an existing contract shows up as the previously-green feature it
broke regressing in the diff.

**Acceptance Scenarios**:

1. **Given** no committed ledger, **When** the ledger runs, **Then** the
   baseline is written (verdict + spec sha256 + classification per
   feature) and the exit code is 0 (`result=baseline`).
2. **Given** a committed baseline and an unchanged corpus, **When** the
   ledger runs, **Then** the diff is empty (`result=clean`, exit 0) and
   the summary reports `regressions=0 added=0 removed=0`.
3. **Given** a committed green feature, **When** a new feature lands
   whose change breaks that contract (the green feature regresses),
   **Then** the diff prints `[ledger] <name>: green -> <verdict>
   (REGRESSION)`, the added feature is reported, the exit code is 1, and
   the committed ledger is left untouched.
4. **Given** a committed green feature whose spec evolves but stays
   green, **When** the ledger runs, **Then** the hash is renewed
   (`renewed` reported, exit 0).
5. **Given** a green feature removed from the walk, **When** the ledger
   runs, **Then** the removal is a REGRESSION (the contract vanished) —
   exit 1.
6. **Given** a corrupt committed ledger, **When** the ledger runs,
   **Then** it stops with exit 2 before walking, with the `--> fix:`
   recovery.

### Edge Cases

- A walk target name that is not a safe filename (`../evil`, empty) is
  rejected with exit 2 — the target names files under `corpus/`.
- An empty catalog (zero features) is a misfire: exit 2, never a silent
  zero-feature success.
- A spec that drifts between cataloging and walking is hashed at WALK
  TIME (the walk never trusts the catalog's recorded hash) — drift
  surfaces as renewal (green) or as changed verdict evidence.
- A spec missing at walk time is `blocked (spec missing)`, never a
  silent skip.
- The per-feature spawn honors `--zfa-bin` (the spec 049 fake-zfa
  contract) so the whole walk is testable without driving real TDD
  loops.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `zfa corpus catalog --target <name>` MUST resolve the
  target's features from the corpus manifest (or `--source`), classify
  each spec CORE/SKIN deterministically (signal scoring over feature
  name + spec content; ties CORE), and write the committed catalog at
  `corpus/catalogs/<target>.json` with per-feature classification,
  readiness + reason, and spec sha256.
- **FR-002**: Catalog regeneration MUST preserve committed manual
  classifications whose spec hash is unchanged, unless `--reclassify`
  is passed; the report MUST name preserved rows.
- **FR-003**: `zfa corpus run --target <name>` MUST drive every
  cataloged feature through `zfa tdd run` + `zfa tdd verify` (the spec
  051 spawn contract) and classify each green / partial / blocked;
  it MUST NOT stop at a failing feature.
- **FR-004**: The walk MUST enforce the configurable failure budget
  (default 5): exit 0 exactly when `partial + blocked <= budget`,
  else exit 1 with the non-green features named.
- **FR-005**: Not-ready features MUST be reported blocked with the
  manifest's reason and never spawned.
- **FR-006**: The walk results MUST persist to
  `.zfa/corpus/walks/<target>.json` (verdict, gate, outcome, walk-time
  spec sha256 per feature).
- **FR-007**: `zfa corpus ledger --target <name>` MUST write the
  committed ledger at `corpus/ledgers/<target>.json` recording each
  feature's verdict, walk-time spec sha256, and classification; the
  first run is the baseline (exit 0).
- **FR-008**: Subsequent ledger runs MUST be diffs against the
  committed ledger, reporting added / removed / renewed rows; a
  regression (committed green now non-green, or a green feature
  removed) MUST exit 1 and MUST leave the committed ledger untouched.
- **FR-009**: Every catalog/walk/ledger misfire (missing catalog, empty
  catalog, corrupt JSON, invalid target or budget, missing spec) MUST
  stop with exit 2 and a message naming the recovery path with a
  `--> fix:` hint — never a silent success.

### Key Entities

- **Corpus Catalog** (`corpus/catalogs/<target>.json`, committed): the
  walk's input contract — features, classification, readiness, hashes.
- **Walk Verdict**: green / partial / blocked — one per cataloged
  feature per walk.
- **Walk Ledger** (`corpus/ledgers/<target>.json`, committed): the
  merge gate — the recorded verdicts the next run diffs against.
- **Failure Budget**: the maximum `partial + blocked` the walk
  tolerates (epic exit criterion: M+K <= 5).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A fixture corpus (core spec / skin spec / not-ready /
  missing-spec) catalogs with correct CORE/SKIN marks, preserved manual
  edits, and deterministic output (100% classified, 0 silent drops).
- **SC-002**: A scripted walk over green/partial/blocked features
  reports exact tallies (`green: N | partial: M | blocked: K`) and exits
  by the budget rule (0 iff M+K <= budget; 1 over) — the walk finishes
  in every case.
- **SC-003**: The ledger baseline commits; the diff detects a green
  regression (and a removal of green) as contract-break with exit 1,
  and leaves the committed ledger untouched on a break.
- **SC-004**: All 43 acceptance/unit behaviors pass red-to-green (the
  red phase compiled against missing commands: +0/-43).

## Out of Scope

- Walking the real ZikZak 120-spec corpus (the driven app's repo owns
  that run; this feature ships the machinery + fixture-level proof).
- Dependency-ordered walking (spec 051's `--plan` owns ordering; the
  walk follows catalog order).
- The gap ledger (spec 051's append-only stop ledger stays the
  stop-on-roadblock record; the walk ledger is the committed diff
  record).
- Mutation scoring of the walk itself (`zfa tdd verify` owns per-feature
  gates).

## Assumptions

- The driven app is corpus-imported (spec 050's manifest exists) before
  cataloging; `--source` covers the pre-import case.
- The loop runtime (`zfa tdd run` / `zfa tdd verify`) honors the machine
  summary-line contract spec 051/049 established (it does —
  `CorpusStepRunner` is reused verbatim).
