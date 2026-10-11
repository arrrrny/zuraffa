# Feature Specification: speckit scaffolding regenerable into existing repos (issue #1417)

**Feature Branch**: `1417-speckit-scaffolding-regeneration`

**Created**: 2026-09-18

**Status**: Implemented (one PR per spec)

**Input**: GitHub issue #1417 — "speckit scaffolding (`.specify/scripts/bash/*`) not regenerable by zfa CLI into an existing repo — speckit-plan misfires on fresh clones"

## Problem

On a fresh clone of an affected repo (any spec ≥ 002), running the speckit-plan
skill fails at Step 1:

```
bash .specify/scripts/bash/setup-plan.sh: No such file or directory   (exit 127)
```

The repo's `.gitignore` excludes `.specify/*` (only
`.specify/memory/constitution.md` is force-added), so the scaffolding was never
committed and lives only on the original machine.

**Why this is a framework gap**: the zfa CLI has no command that regenerates the
speckit scaffolding into an **existing** repo — `zfa setup` creates a *new* app,
`zfa initialize` only wires pubspec deps, and `zfa generate-commands`
regenerates speckit *command files*, not the `.specify/scripts/bash/*` helper
scripts referenced by the speckit-* skills. Constitution I (CLI-built only)
means we do not hand-scaffold the scripts as a "fix"; the framework owns this.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `zfa initialize --speckit` MUST emit the current speckit helper
  scripts (`common.sh`, `setup-plan.sh`, `check-prerequisites.sh`,
  `setup-tasks.sh`) into an existing repo's `.specify/scripts/bash/` so the
  speckit-* skills' Step 1 works on a fresh clone.
- **FR-002**: The emitted scripts MUST be embedded in the CLI package (Dart
  string constants) so they are versioned with the CLI and cannot drift from
  the skills the CLI ships; a drift-guard test MUST fail the suite when the
  embedded copies diverge from the framework repo's canonical
  `.specify/scripts/bash/` files.
- **FR-003**: Re-running `--speckit` on a repo that already carries committed
  scaffolding MUST NOT clobber it (existing files are skipped and reported)
  unless `--force` is passed; `--force` overwrites with the CLI-current
  content.
- **FR-004**: When the target `.gitignore` contains a rule that would ignore
  the emitted helpers (e.g. `.specify/*`), the command MUST append an
  idempotent force-include block so the emitted scripts are trackable, and
  MUST leave a `.gitignore` without such rules untouched.
- **FR-005**: `--speckit` MUST be surgical: it does not wire pubspec
  dependencies, does not scaffold an entity, and MUST work in a repo without a
  `pubspec.yaml` (e.g. a non-Dart project that still uses speckit).
- **FR-006**: `--dry-run` MUST preview the emission without writing anything.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Fresh clone of an affected repo (the issue's `zuraffa_agent`
  repro) → `zfa initialize --speckit --root .` →
  `bash .specify/scripts/bash/setup-plan.sh --json` exits 0 with the expected
  JSON (the exit-127 misfire is gone).
- **SC-002**: An existing repo with committed scaffolding is byte-unchanged
  after a `--speckit` run without `--force` (no regression).
- **SC-003**: The drift guard (FR-002) fails the suite when an embedded copy
  diverges from the canonical script, so skills and scripts cannot drift.
