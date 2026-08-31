# Feature Specification: `zfa setup --specs` — import an extracted spec corpus into a greenfield app

**Feature Branch**: `050-corpus-import`

**Created**: 2026-08-31

**Status**: Draft

**Input**: Issue [#627](https://github.com/arrrrny/zuraffa/issues/627), derived from epic `045-tdd-full-app-cycle` (precondition 5, harness). User description: "a purely zfa-generated app targeting an existing spec corpus (zik_zak's 120 extracted features) currently has no way to onboard those specs: setup scaffolds the app + TDD baseline, but the specs/ tree must be copied and wired by hand. Requested: a setup flag (e.g. `zfa setup zik_zak_tdd --platforms=ios,android,macos --specs <dir>`) or a `zfa corpus import` command that copies/normalizes a spec corpus into the fresh app so `zfa tdd plan/run/verify` operate across all features immediately, with a corpus manifest emitted for batch driving."

## Mission

Close the last manual gap between "zfa generated the app" and "the loop can
drive it": onboarding an existing requirements corpus. Epic 045's target is
a greenfield app built **only** by zfa commands, carrying zik_zak's 120
extracted feature specs. Today `zfa setup` produces the app, the TDD
baseline, and deps — but the corpus itself (the `specs/` tree, per-feature
loop scaffolding, and the ordered list of features to drive) must be copied
and wired by hand, which is exactly the kind of unattributed manual work the
epic's provenance contract forbids.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - One-command corpus onboarding at setup time (Priority: P1)

A maintainer creating the epic's target app runs
`zfa setup zik_zak_tdd --platforms=ios,android,macos --specs ~/corpus/zik_zak`
(or imports into an existing zfa app with `zfa corpus import <dir>`). The
tool copies every feature spec from the source corpus into the app's
`specs/` tree, normalizes what the loop needs (each feature directory
contains a `spec.md` with acceptance scenarios and functional requirements),
creates the per-feature `tdd/` working directories, and emits a **corpus
manifest**: an ordered list of the imported features that batch driving
(#628) consumes. The command reports what was imported, skipped, and any
feature whose spec is not loop-ready.

**Why this priority**: Without corpus onboarding, the epic's from-scratch
target requires a manual copy step — unattributed, error-prone, and outside
the zfa-only contract.

**Independent Test**: On a fixture corpus of 3 feature specs (one clean, one
missing acceptance scenarios, one with a speckit-era `tdd/` dir), run the
import into a fresh `zfa setup` app; confirm copied trees, per-feature
`tdd/` dirs, a manifest listing all 3 in a stable order, and a report naming
the non-loop-ready spec.

**Acceptance Scenarios**:

1. **Given** a fresh `zfa setup` app and a source corpus of N feature
   directories each containing `spec.md`, **When** the maintainer imports
   the corpus, **Then** every feature directory exists under the app's
   `specs/` with its `spec.md`, a `tdd/` working directory, and the corpus
   manifest lists all N features in a deterministic order.
2. **Given** the imported corpus from scenario 1, **When** the maintainer
   runs `zfa tdd plan <feature>` for any imported feature, **Then** planning
   succeeds without any manual file edits (the spec content was copied
   verbatim; normalization creates structure, never rewrites requirements).
3. **Given** a corpus feature whose `spec.md` has no acceptance scenarios,
   **When** the import runs, **Then** the feature is imported anyway and the
   report names it as not loop-ready (plan will refuse it), rather than
   silently dropping or mutating it.

---

### User Story 2 - Idempotent, non-destructive import (Priority: P1)

A maintainer re-runs the import (e.g. after the corpus gained features).
Existing feature directories in the target are never overwritten or deleted;
unchanged specs are skipped; new specs are added; a spec whose source content
changed is reported as changed with both versions' hashes, and the maintainer
decides (explicit flag) whether to update it. The corpus manifest is
regenerated to reflect the new state.

**Acceptance Scenarios**:

1. **Given** an app that already imported features 001–010, **When** the
   maintainer re-imports a corpus that added 011–012, **Then** 001–010 are
   untouched, 011–012 are imported, and the manifest lists 012 features.
2. **Given** a target feature directory with loop progress (test lists,
   cycle logs, artifacts), **When** the import re-runs, **Then** nothing
   under that feature's `tdd/` is modified — import owns `spec.md` (with the
   change-report rule above), never loop evidence.
3. **Given** a spec whose source content differs from the already-imported
   copy, **When** the import runs, **Then** the default behavior is to keep
   the imported copy and report the divergence; updating requires an
   explicit flag.

---

### User Story 3 - Loop-ready by verification, not assumption (Priority: P2)

After import, the maintainer can ask the tool to verify loop-readiness:
every feature's spec parses (acceptance scenarios + functional requirements
present), and a dry-run of what `zfa tdd plan` would derive is reported
per feature (counts only). The manifest marks each feature `ready` /
`not-ready` with the reason.

**Acceptance Scenarios**:

1. **Given** an imported corpus, **When** the maintainer runs the
   loop-readiness check, **Then** every feature is marked `ready` or
   `not-ready` with a one-line reason, and the manifest reflects the marks.
2. **Given** a `not-ready` feature, **When** batch driving (#628) consults
   the manifest, **Then** it can skip or stop on that feature per its
   policy, using the manifest's mark rather than re-deriving it.

---

### Edge Cases

- Source corpus features with pre-existing speckit artifacts (checklists,
  `tdd/test-list.md` in foreign formats) — import copies `spec.md` only;
  foreign artifacts are reported as ignored, never converted silently
  (format conversion is #617 territory and stays out of scope).
- Name collisions between corpus features and existing target features with
  different content — reported as divergent (US2 rule), never merged.
- A corpus path that is a single feature rather than a corpus root —
  rejected with a clear message.
- Very large corpora (120 features) — import is file-copy fast; no test
  execution happens at import time.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `zfa setup <name> --specs <dir>` (and `zfa corpus import
  <dir>` on an existing app) MUST copy every source feature's `spec.md`
  into `<app>/specs/<feature>/spec.md` verbatim and create the per-feature
  `tdd/` directory, without rewriting requirement content.
- **FR-002**: The import MUST emit a corpus manifest listing every imported
  feature in a deterministic order (source lexicographic), consumable by
  batch driving (#628).
- **FR-003**: Re-running the import MUST be idempotent and non-destructive:
  existing specs untouched unless explicitly updated, `tdd/` contents
  (test lists, cycle logs, artifacts) never modified.
- **FR-004**: Divergent specs (source differs from imported copy) MUST be
  reported with both content hashes and updated only under an explicit flag.
- **FR-005**: The import MUST report, per feature: imported / skipped /
  already-present / divergent / not-loop-ready (no acceptance scenarios),
  and MUST NOT silently drop, merge, or mutate any feature.
- **FR-006**: A loop-readiness check MUST mark each manifest feature
  `ready`/`not-ready` with a reason, derived from the same parsing rules
  `zfa tdd plan` uses.
- **FR-007**: Foreign-format artifacts inside source features MUST be
  ignored (reported, not copied, not converted).

### Key Entities

- **Corpus Manifest**: the ordered feature list with readiness marks —
  the contract between import and batch driving (#628).
- **Source Corpus**: a directory of feature directories, each with at least
  `spec.md`.
- **Import Report**: the per-feature outcome list printed by the import.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A 3-fixture corpus (clean / not-loop-ready / foreign-artifact)
  imports with a correct manifest and an accurate per-feature report (100%
  of outcomes classified, 0 silent drops).
- **SC-002**: 100% of imported features are plannable by `zfa tdd plan`
  without manual edits; 100% of not-loop-ready features are reported as
  such at import time.
- **SC-003**: Re-import after corpus growth touches only new features (0
  writes to existing `tdd/` trees, checksum-verified).
- **SC-004**: The manifest is machine-readable and stable (same corpus →
  byte-identical manifest, ready marks excepted).

## Out of Scope

- Format conversion of foreign test lists (#617 owns test-list format).
- Ordering by dependency (the manifest is lexicographic; dependency
  resolution belongs to batch driving, #628).
- Executing any tests at import time.
- Extracting specs from a legacy app (the rewrite/tupec tooling owns that;
  this feature consumes an already-extracted corpus).

## Assumptions

- The source corpus shape follows the rewrite tooling's output: feature
  directories each containing `spec.md` (as verified in
  `~/Developer/zik_zak_zfa/specs`).
- Import is a file operation plus manifest; no network, no codegen.
- The epic's target remains `zfa setup zik_zak_tdd --platforms=ios,android,macos`
  followed by corpus import (#628 then drives it).
