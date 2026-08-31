# Research: `zfa corpus import`

Phase 0 findings, resolved against master@`fa2c501b`. No NEEDS CLARIFICATION
remain.

## Decision 1: One shared `CorpusImporter`; `setup --specs` delegates

- **Decision**: `lib/src/cli/services/corpus_importer.dart` holds all import
  logic; `zfa corpus import <source>` is its primary command surface, and
  `zfa setup <name> --specs <dir>` calls the same service after the TDD
  baseline step (step numbering 7/7 → 8/8 when present).
- **Rationale**: spec FR-001 demands both entry points with identical
  semantics; one service prevents drift.
- **Alternatives considered**: separate setup-only copy — rejected;
  duplication of idempotency/divergence logic.

## Decision 2: `corpus` as a new top-level command family

- **Decision**: `lib/src/commands/corpus_command.dart` (name `corpus`,
  subcommand `import <source>`) registered in `cli_runner.dart`'s command
  list, mirroring existing top-level command patterns.
- **Rationale**: the corpus will host `status`/`run`/`audit` (#628) —
  a family, not a one-off flag.
- **Alternatives considered**: nesting under `tdd corpus` — rejected; the
  corpus spans setup/verification tooling beyond the tdd plugin's scope,
  and #628 needs sibling subcommands at the same level.

## Decision 3: idempotent copy with sha256 divergence + `--force`

- **Decision**: per-feature copy: identical → `skipped`; different →
  `divergent` (both hashes in the report) unless `--force`; absent → copied.
  Write path uses `FileUtils.writeFile` (dry-run/verbose aware); hashing with
  `package:crypto` sha256 like `TreeSnapshot`.
- **Rationale**: spec FR-003/FR-004/FR-005; the "refuse different content"
  idempotency pattern is the codebase norm
  (`TddProfileWriter`, `tdd init`).
- **Alternatives considered**: timestamp/version-based compare — rejected;
  content hashes are the audit-truth currency everywhere else in the loop.

## Decision 4: loop-readiness via the existing `SpecParser`

- **Decision**: readiness = `SpecParser` succeeds on the spec (`parse`
  extracts Given/When/Then scenarios + FRs); failure → `not-ready` with the
  parser's reason (e.g. "no acceptance scenarios").
- **Rationale**: spec FR-006 — same parser `zfa tdd plan` uses, so the mark
  and plan's behavior can never disagree.
- **Alternatives considered**: regex-only scenario sniffing — rejected;
  a second parser is exactly the dialect-drift bug class #617 was.

## Decision 5: manifest at `.zfa/manifests/corpus-manifest.json`

- **Decision**: `lib/src/core/project/corpus_manifest.dart` writes/reads the
  manifest via `ProjectPaths.manifestsDirectory` (.zfa/manifests per the
  AGENTS.md canonical memory layout): ordered `CorpusFeature` list
  (`name`, `ready`, `reason`), `source_corpus`, `imported_at`. Deterministic
  lexicographic order; re-import regenerates byte-identically except
  `imported_at` (spec SC-004).
- **Rationale**: AGENTS.md fixes `.zfa/manifests/` as the manifest home; the
  file is the #628 batch-driver contract.
- **Alternatives considered**: `specs/corpus-manifest.json` inside the
  corpus tree — rejected; loop tooling must not confuse manifest with
  feature content, and `.zfa/` is the documented memory surface.

## Decision 6: foreign artifacts reported, never converted

- **Decision**: source features may carry speckit-era artifacts (checklists,
  `tdd/test-list.md` in foreign formats); import copies `spec.md` only and
  reports `foreign-artifacts-ignored`. No conversion, no deletion of target
  content.
- **Rationale**: spec FR-007; format unification is #617's contract.
- **Alternatives considered**: migrating foreign lists — rejected (out of
  scope, risk of silent rewrites).

## Testing approach

- Fast unit: manifest model round-trip + deterministic order;
  importer (3-feature fixture: clean / no-acceptance / foreign-artifact)
  covering copy, tdd-dir creation (never touching existing), idempotency,
  divergence + `--force`, `--dry-run`, readiness marks, per-feature report;
  command-level: `corpus import` arg parsing + registration (+ `setup
  --specs` wiring where cheap).
- Slow tier: none — file operations only.
- Baseline is green (fast tdd tier 116+ tests); recorded in the cycle log.