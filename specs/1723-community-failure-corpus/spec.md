# Feature Specification: Community failure corpus — anonymized TDD loop data sharing

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `feat/issue-824`

**Created**: 2026-10-18

**Status**: Draft

**Input**: Issue [#824](https://github.com/arrrrny/zuraffa/issues/824) — [VISION] 🌍 Community failure corpus: anonymized TDD loop data sharing (Pillar G: Meta-intelligence, VISION 2030, #804).

## Mission

Failure data is the scarcest resource in AI codegen. Every agent that hits a generation gap today produces private frustration. This feature packages anonymized spec→behavior→outcome triples from real TDD loops into a shareable community corpus so zuraffa's generators tune against the world's actual failure modes, not one team's imagination. Submitters receive a scorecard showing which generator surfaces their corpus improved. The dataset effect compounds: more corpora → better planning → more successful loops → more corpora.

This spec defines the v0 slice: an anonymizer that strips identifiers while keeping structure and outcome vectors, a corpus pack format, and a `zfa corpus merge` command that dedupes contributions and enforces quality gates (misfire-stop evidence required). It builds on `corpus_manifest_store`, `corpus_importer`, and `gap_ledger_store`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Export a local TDD loop as an anonymized corpus pack (Priority: P1)

A maintainer who has driven a TDD loop (red→green→refactor with cycle logs and a verdict envelope) runs `zfa corpus export --anonymize` against the feature or the whole project. The tool walks the loop artifacts (spec.md, test-list.md, cycle-log.md, verdict envelope, mutation results), strips all identifiers (entity names, file paths, author names, repo names, secrets), retains structural shape and outcome vectors (behavior counts, red/green durations, mutation kill rates, failure classes), and writes a corpus pack file that is safe to share publicly.

**Why this priority**: Without an export, no corpus exists to share; this is the single entry point for the whole dataset effect.

**Independent Test**: On a fixture feature with a completed TDD loop, run `zfa corpus export --anonymize --project <fixture>` and assert the output pack contains no identifier from the source (entity name, path, author) while retaining the outcome vector fields (behavior count, mutation kill rate).

**Acceptance Scenarios**:

1. **Given** a feature with a completed TDD loop (spec, test list, cycle log, verdict envelope), **When** the maintainer runs `zfa corpus export --anonymize`, **Then** a corpus pack file is written containing the anonymized triples and an outcome vector, and no source identifier appears in it.
   **Type**: acceptance
2. **Given** the same loop, **When** the export runs twice, **Then** both packs are byte-identical (deterministic anonymization).
   **Type**: acceptance
3. **Given** a feature with no TDD evidence, **When** the export runs, **Then** it refuses with a clear message naming the missing artifact, and writes no pack.
   **Type**: acceptance

### User Story 2 - Merge community corpus packs with dedupe and quality gates (Priority: P1)

A maintainer (or CI) receives community corpus packs and runs `zfa corpus merge <packs...>`. The command dedupes packs by structural fingerprint, enforces quality gates (each pack must carry misfire-stop evidence — a recorded stop-on-roadblock event — otherwise it is rejected), and writes the merged corpus into the local corpus store with a merge report (added, deduped, rejected counts and reasons).

**Why this priority**: Merging is the ingestion half of the dataset effect; without dedupe and gates the corpus rots.

**Independent Test**: Given two packs (one valid with misfire evidence, one duplicate, one missing evidence), run `zfa corpus merge` and assert the merged store contains exactly one entry and the report names the dedupe and the rejection reason.

**Acceptance Scenarios**:

1. **Given** N valid packs with misfire-stop evidence, **When** `zfa corpus merge` runs, **Then** all N are added to the merged corpus store and the report says `added=N`.
   **Type**: acceptance
2. **Given** a pack that is structurally identical to an already-merged pack, **When** merge runs, **Then** it is skipped as `deduped` and not double-counted.
   **Type**: acceptance
3. **Given** a pack with no misfire-stop evidence, **When** merge runs, **Then** it is rejected with reason `missing misfire-stop evidence` and excluded from the store.
   **Type**: acceptance
4. **Given** a malformed pack (unparseable), **When** merge runs, **Then** it is rejected with reason `malformed pack` and processing continues for the rest.
   **Type**: acceptance

### User Story 3 - Seed corpus from the repo's own historical bugs (Priority: P2)

The repository's own historical bugs (the `.specify/bugs/` tree and closed issue-derived specs) export as the seed corpus on first run, so the community corpus starts non-empty and zuraffa's planners have immediate failure data.

**Why this priority**: A corpus that starts empty cannot tune anything; seeding from first-party history proves the export path end-to-end.

**Independent Test**: Run `zfa corpus export --anonymize --seed` from the zuraffa repo root and assert at least one seed pack is produced under the corpus output directory.

**Acceptance Scenarios**:

1. **Given** the zuraffa repository with its historical bug specs, **When** `zfa corpus export --anonymize --seed` runs, **Then** one pack per eligible historical bug is written and a summary reports the count.
   **Type**: acceptance

### User Story 4 - Submitter scorecard (Priority: P3)

A submitter whose pack merged runs `zfa corpus scorecard <pack-id>` and sees which generator surfaces (planner, make, mock, route, ...) their corpus improved, based on before/after planner test deltas recorded at merge time.

**Why this priority**: The scorecard is the incentive loop; valuable but depends on merge landing first.

**Independent Test**: After a merge that records a planner test delta, `zfa corpus scorecard` prints the delta per generator surface.

**Acceptance Scenarios**:

1. **Given** a merged pack with a recorded planner test delta, **When** scorecard runs, **Then** it prints per-surface deltas (positive = improvement).
   **Type**: acceptance

## Edge Cases

- What happens when an export source contains a secret-looking token in a spec? The anonymizer must redact it (treat any high-entropy string matching a secret pattern as an identifier) and record a redaction count in the pack metadata.
- How does the system handle a pack whose structural fingerprint collides but content differs? It is treated as a distinct variant (fingerprint includes outcome vector), not a duplicate.
- What happens when merge is run with zero packs? It prints an empty report and exits 0 without mutating the store.
- What happens when the corpus store is missing? Merge creates it (idempotent, like corpus import creating manifests).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide `zfa corpus export` with an `--anonymize` flag and a `--project`/`--project-root` flag (consistent with the other corpus subcommands) that walks TDD loop artifacts and emits a corpus pack file. Export without `--anonymize` MUST NOT produce a shareable pack: it is limited to local/private inspection of the raw loop artifacts, and any pack intended to leave the repository MUST be produced with `--anonymize` (the only mode that yields a publicly shareable pack).
- **FR-002**: The anonymizer MUST strip identifiers (entity names, file paths, author/repo names, secrets) while preserving structural shape and outcome vectors.
- **FR-003**: The anonymizer MUST be deterministic: identical input produces byte-identical output.
- **FR-004**: System MUST define a corpus pack format (versioned, machine-readable) containing anonymized spec→behavior→outcome triples and an outcome vector.
- **FR-005**: System MUST provide `zfa corpus merge <packs...>` that dedupes by structural fingerprint and writes to the local corpus store.
- **FR-006**: `zfa corpus merge` MUST reject any pack lacking misfire-stop evidence (a recorded stop-on-roadblock event) with reason `missing misfire-stop evidence`.
- **FR-007**: `zfa corpus merge` MUST reject malformed packs with reason `malformed pack` and continue processing the rest.
- **FR-008**: `zfa corpus merge` MUST produce a merge report with added, deduped, and rejected counts plus per-pack reasons.
- **FR-009**: System MUST support `--seed` on export to walk the repository's historical bugs into seed packs.
- **FR-010**: System MUST provide `zfa corpus scorecard <pack-id>` printing per-generator-surface deltas from merge-time records.
- **FR-011**: The corpus pack format MUST align with the feature-packs idea if it lands; otherwise stand alone with a documented schema.
            traces: CorpusPack
- **FR-012**: The anonymizer MUST record a redaction count in pack metadata for every identifier stripped.
            traces: AnonymizedTriple

### Layer Contracts

**Function**:
- `Anonymizer`: `anonymize(LoopArtifacts) -> AnonymizedPack`
- `CorpusExporter`: `export(FeatureOrProject, anonymize: bool, seed: bool, project: Path?) -> List<CorpusPack>`
- `CorpusMerger`: `merge(List<CorpusPack>, store) -> MergeReport`
- `Scorecard`: `scorecard(packId, store) -> SurfaceDeltas`

**Domain**:
- `CorpusPack`: `load(path) -> CorpusPack`, `save(path) -> void`, `fingerprint() -> String`
- `CorpusStore`: `add(CorpusPack) -> void`, `list() -> List<CorpusPack>`, `find(id) -> CorpusPack?`

**Presentation**:
- `CorpusCommand`: `export`, `merge`, `scorecard` subcommands

### Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| CorpusPack | `version: String`, `fingerprint: String`, `triples: List<AnonymizedTriple>`, `outcomeVector: OutcomeVector`, `misfireEvidence: MisfireStopEvidence?`, `redactionCount: int` | Shareable anonymized unit of failure data |
| AnonymizedTriple | `specShape: String`, `behaviorId: String`, `outcome: String` | One spec→behavior→outcome triple with identifiers stripped |
| OutcomeVector | `behaviorCount: int`, `redToGreenMedianMs: int`, `mutationKillRate: double`, `failureClasses: List<String>` | Quantitative outcome summary |
| MisfireStopEvidence | `command: String`, `expected: String`, `actual: String`, `rootCause: String` | Required stop-on-roadblock record proving quality |
| MergeReport | `added: int`, `deduped: int`, `rejected: int`, `entries: List<MergeEntry>` | Result of a merge run |
| MergeEntry | `packId: String`, `status: String`, `reason: String?` | Per-pack merge outcome |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A maintainer can export a completed TDD loop to an anonymized pack in under 10 seconds on a typical feature.
- **SC-002**: 100% of exported packs pass a re-identification check (no source identifier present) on the seed corpus.
- **SC-003**: Merge dedupes exact duplicates so the merged store size is monotonically non-increasing relative to input count.
- **SC-004**: Every pack in the merged store carries misfire-stop evidence (quality gate enforced at 100%).
- **SC-005**: The repo's own historical bugs export as the seed corpus (at least one seed pack produced by `--seed`).

## Assumptions

- The anonymizer operates on existing TDD artifacts (spec.md, test-list.md, cycle-log.md, verdict envelope); it does not require new instrumentation.
- Misfire-stop evidence is sourced from the ZURAFFA MISFIRE RULE records that agents already produce; the export surfaces them, it does not invent them.
- Corpus packs are stored as JSON files under a configurable corpus directory (default `.zfa/corpus/`), consistent with other zfa stores.
- External contributions arrive as pack files; merge accepts file paths or a directory.
- The feature-packs idea (if it lands) subsumes the pack format; until then the format stands alone with a documented JSON schema.

## Builds on

- `corpus_manifest_store` — for feature enumeration and readiness marks
- `corpus_importer` — for corpus onboarding patterns reused by merge
- `gap_ledger_store` — for failure-class taxonomy in outcome vectors
