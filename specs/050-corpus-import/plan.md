# Implementation Plan: `zfa corpus import` (+ `zfa setup --specs`)

**Branch**: `050-corpus-import` | **Date**: 2026-08-31 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/050-corpus-import/spec.md`

## Summary

Implement corpus onboarding (issue #627): a new top-level `zfa corpus
import <source>` command plus a `--specs <dir>` shortcut on `zfa setup`,
sharing one `CorpusImporter` service. The importer copies each source
feature's `spec.md` verbatim into the app's `specs/<feature>/`, creates
per-feature `tdd/` directories (never touching existing contents), runs a
loop-readiness check via the existing `SpecParser`, and emits a deterministic
corpus manifest at `.zfa/manifests/corpus-manifest.json` for batch driving
(#628). Idempotent, non-destructive, divergence-aware (`--force` to update,
hashes reported otherwise), with a per-feature outcome report.

## Technical Context

**Language/Version**: Dart 3 (repo SDK), CLI plugin architecture.

**Primary Dependencies**: existing internals only — `SpecParser`
(`lib/src/plugins/tdd/services/spec_parser.dart`), `ProjectPaths.manifestsDirectory`,
`FileUtils.writeFile`, `package:crypto` sha256 (already used by
`TreeSnapshot`). No new pub dependencies.

**Storage**: `<app>/specs/<feature>/spec.md` (copy), `<app>/specs/<feature>/tdd/`
(create), `<app>/.zfa/manifests/corpus-manifest.json` (write).

**Testing**: fast unit tier: importer tests with a 3-feature fixture corpus
(clean / no-acceptance / foreign-artifact); command-level tests with
`Directory.systemTemp` + `--project`-style conventions (post-CWD-race
practices); a slow-tier real-corpus import is NOT needed (file ops only).

**Target Platform**: macOS/Linux CLI.

**Project Type**: CLI command + shared service.

**Performance Goals**: file-copy class; 120-feature corpus imports in
seconds (no test execution at import time).

**Constraints**: never rewrite requirement content; never modify existing
`specs/<feature>/tdd/` contents; sha256-based divergence reporting;
deterministic manifest ordering.

**Scale/Scope**: one top-level command + one shared service + one manifest
model (~400 LOC), tests included.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is still the unfilled template — no
ratified gates. AGENTS.md constraints respected; this feature only copies
requirement documents (not source), so the zfa-only generation contract is
untouched.

**Post-design re-check**: no violations; no new dependencies or layers.

## Project Structure

### Documentation (this feature)

```text
specs/050-corpus-import/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit-tasks — NOT created here)
```

### Source Code (repository root)

```text
lib/src/
├── commands/
│   ├── corpus_command.dart            # NEW — top-level `corpus`, subcommands:
│   │                                  #   import <source> (--dry-run, --force)
│   ├── setup_command.dart             # EXTEND — `--specs <dir>` → import step
│   └── cli/cli_runner.dart            # EXTEND — register CorpusCommand
├── cli/services/
│   └── corpus_importer.dart           # NEW — shared import logic + report
└── core/project/
    └── corpus_manifest.dart           # NEW — manifest + CorpusFeature model

test/
├── commands/corpus_command_test.dart  # NEW (fast)
├── cli/services/corpus_importer_test.dart # NEW (fast, 3-feature fixture)
└── core/project/corpus_manifest_test.dart # NEW (fast)
```

**Structure Decision**: mirrors existing command/service placement; the
importer is a CLI service (like `tdd_profile_writer`) because both `setup`
and `corpus import` consume it; manifest model lives in
`core/project/` next to `ProjectPaths`.

## Complexity Tracking

No constitution violations; nothing to justify.