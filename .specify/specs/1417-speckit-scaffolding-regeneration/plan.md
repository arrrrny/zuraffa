# Implementation Plan: speckit scaffolding regenerable into existing repos (issue #1417)

**Branch**: `fix/1417-speckit-scaffolding-regeneration`

**Root cause**: `.gitignore` in affected repos excludes `.specify/*` (only
`constitution.md` force-added), so `.specify/scripts/bash/*` existed only on
the original machine. The zfa CLI has no verb that regenerates the scaffolding
into an existing repo (`zfa setup` = new app; `zfa initialize` = pubspec
wiring + entity; `zfa generate-commands` = command .md files, not bash
helpers).

**Remediation (chosen approach)**: option (b) from the issue —
`zfa initialize --speckit` emits the current speckit helper scripts into an
existing repo, embedded in the CLI so they are versioned with it. Option (a)
(track the helpers in git) is already satisfied in the framework repo itself
(`git ls-files .specify/scripts/bash/` lists 17 files on master); the framework
gap for *downstream* repos is the missing CLI verb. Constitution I preserved:
the scripts ship as CLI-owned content, nothing is hand-scaffolded into the
fix.

## Design

- **Embed, don't copy at runtime**: the four Step-1 helper scripts
  (`common.sh`, `setup-plan.sh`, `check-prerequisites.sh`, `setup-tasks.sh`)
  are embedded as byte-identical Dart string constants in
  `lib/src/commands/speckit_scaffolding.dart` — the same pattern as
  `kZuraffaSpecTemplate` (`lib/src/cli/writers/tdd/spec_template_writer.dart`),
  which works from a pub-cache install with no repo checkout.
- **Writer**: `SpeckitScaffoldingWriter.emit()` creates
  `<root>/.specify/scripts/bash/`, writes each script, returns
  created/skipped/force-overwritten lists for the command output.
  - No `--force` → existing files skipped (SC-002, no clobber).
  - `--force` → overwritten with CLI-current content.
- **.gitignore handling**: if the target `.gitignore` matches a rule that
  would ignore `.specify/scripts` (`.specify/`, `.specify/*`,
  `.specify/scripts`, `.specify/scripts/*`), append a documented
  force-include block (last-match-wins) keyed by a marker comment so the
  append is idempotent. No matching rule → file untouched (FR-004).
- **Flag wiring**: `InitializeCommand.buildParser()` gains `--speckit`;
  when set, `execute()` runs the emission and returns before dependency
  wiring / entity scaffolding (surgical, FR-005) — it must work without a
  `pubspec.yaml`.
- **Drift guard**: `initialize_speckit_test.dart` compares each embedded
  constant against the framework repo's canonical
  `.specify/scripts/bash/<name>` file; any divergence fails the suite
  (FR-002 / SC-003), forcing re-embed when the canonical scripts evolve.

## Tasks

1. [x] Red: write `test/commands/initialize_speckit_test.dart` against the
   existing API surface (parser flag absence → RED; emission → exit≠0).
2. [x] Implement `lib/src/commands/speckit_scaffolding.dart` (constants +
   writer + gitignore logic).
3. [x] Wire `--speckit` into `InitializeCommand` (parser + execute + help).
4. [x] Drift-guard test (green phase; needs the constants to compile).
5. [x] Green: full new suite passes.
6. [x] E2E: fresh clone of `zuraffa_agent` → red (exit 127) → `--speckit` →
   `setup-plan.sh --json` exits 0 with JSON.
7. [x] No-regression: zuraffa repo itself (`--speckit` without `--force`
   leaves committed scaffolding byte-identical).
8. [x] Mutation audit on the changed files (`mutation-test-1417.xml`).
9. [x] `/speckit.tdd.verify` → `tdd/verification.md` from the real run.

## Risks / trade-offs

- Embedded constants can drift from the canonical scripts as the repo evolves
  them — mitigated by the drift-guard test (SC-003).
- `.gitignore` edits touch user content — mitigated: only appends a marked,
  idempotent block, and only when a rule would actually ignore the helpers.
