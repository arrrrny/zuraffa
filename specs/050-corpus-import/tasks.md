# Tasks: `zfa corpus import`

**Input**: Design documents from `/specs/050-corpus-import/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/corpus-import.md

**Tests**: MANDATORY (tdd.plan) — spec SC-001..SC-004 demand automated
proof. Every behavior in `tdd/test-list.md` has a test task below, and each
test must be observed failing before its implementation task starts. All
tests are fast tier (file operations only — no subprocess suites needed).

**Organization**: Tasks grouped by user story from spec.md. Behavior markers
(`[A1]`, `[U3]`) trace tasks to `tdd/test-list.md`; `/speckit.tdd.run` ticks
tasks by these markers.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Fixture corpus helper

- [ ] T001 Create a fixture-corpus helper that builds the 3-feature matrix (clean spec with Given/When/Then + FR / prose-only spec / spec + foreign `checklists/` + `tdd/test-list.md`) under `Directory.systemTemp`, in `test/cli/services/helpers/fixture_corpus.dart`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Manifest model and importer service — everything the commands use

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T002 [P] [U1] [U2] [U3] [U4] Implement `CorpusFeature` and `CorpusManifest` (features in deterministic lexicographic order, `sourceCorpus`, `importedAt`, `toJson`/`fromJson`/`read`/`write` via `ProjectPaths.manifestsDirectory` at `.zfa/manifests/corpus-manifest.json`) in `lib/src/core/project/corpus_manifest.dart`
- [ ] T003 [U5] [U6] [U7] [U8] [U9] [U10] [U11] [U12] [U13] [U14] [U15] Implement `CorpusImporter.import(...)`: source validation (corpus root vs single-feature rejection), per-feature scan, `spec.md` sha256-aware copy (identical → skipped; different → divergent unless `--force`; absent → imported), `tdd/` directory creation (never touching existing contents), readiness via `SpecParser` (reuse exactly), per-feature report + summary line per contracts/corpus-import.md, in `lib/src/cli/services/corpus_importer.dart`

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - One-command corpus onboarding (Priority: P1) 🎯 MVP

**Goal**: `zfa corpus import <source>` copies all feature specs verbatim,
creates `tdd/` dirs, emits the manifest, and reports every outcome.

**Independent Test**: 3-feature fixture import → correct outcomes per
feature, manifest in lexicographic order, summary line exact
(quickstart.md scenario 2); every `ready` feature plannable (scenario 3).

### Tests for User Story 1 ⚠️ (write first, watch fail)

- [ ] T004 [P] [US1] [U1] [U2] [U3] [U4] Manifest tests (fast): round-trip, deterministic order, byte-identical re-write except `importedAt`, missing manifest → null, in `test/core/project/corpus_manifest_test.dart`
- [ ] T005 [P] [US1] [U6] [U7] [U8] [U10] [U12] [U13] Importer matrix tests (fast): fixture corpus → outcomes `imported`/`not-ready (no acceptance scenarios)`/`imported foreign-artifacts-ignored`, `tdd/` dirs created, manifest ready marks match the SpecParser verdict, spec content byte-identical, in `test/cli/services/corpus_importer_test.dart`
- [ ] T006 [P] [US1] [A2] Plannability proof (fast): for the fixture's ready feature, `zfa tdd plan`-equivalent parsing succeeds with zero edits; for the not-ready one it refuses with the manifest's reason, in `test/cli/services/corpus_importer_test.dart`
- [ ] T007 [P] [US1] [U16] [U18] Command tests (fast): `corpus import` arg surface (mandatory `source`, `--dry-run`, `--force`), registration in the runner, invalid source rejection, in `test/commands/corpus_command_test.dart`

### Implementation for User Story 1

- [ ] T008 [US1] [U16] [U17] Implement `corpus_command.dart`: top-level `corpus` with `import <source>` subcommand wired to `CorpusImporter`, printing the report + summary line per contract and setting `exitCode` 0 on completed import (not-ready is reported, not fatal), in `lib/src/commands/corpus_command.dart`
- [ ] T009 [US1] [U18] Register `CorpusCommand` in the CLI runner's command list, in `lib/src/cli/cli_runner.dart` (+ help-text mention)
- [ ] T019 [US1] [A1] [A2] [A3] Acceptance test driving the real CLI end-to-end for the import, plannability, and not-ready report (stays red until US1 completes), in `test/commands/corpus_command_test.dart`

**Checkpoint**: US1 fully functional and independently testable; A1–A3 green

---

## Phase 4: User Story 2 - Idempotent, non-destructive import (Priority: P1)

**Goal**: Re-import skips identical specs, never touches `tdd/` contents,
reports divergent specs with hashes, updates only under `--force`.

**Independent Test**: Re-import after corpus growth (+2 features) → old
features untouched, new imported, manifest updated; edit a source spec →
divergent report with both hashes, target unchanged; `--force` → updated;
`--dry-run` writes nothing; checksums throughout (quickstart.md scenario 4).

### Tests for User Story 2 ⚠️ (write first, watch fail)

- [ ] T010 [P] [US2] [U7] [U11] Idempotency tests (fast): re-import → all skipped, target trees checksum-unchanged (spec + existing `tdd/` contents), manifest stable except `importedAt`, in `test/cli/services/corpus_importer_test.dart`
- [ ] T011 [P] [US2] [U8] [U9] [U14] Divergence tests (fast): changed source → `divergent` with both hashes and target kept; `--force` → `imported`; dry-run reports without writing, in `test/cli/services/corpus_importer_test.dart`
- [ ] T020 [P] [US2] [A4] [A5] [A6] Acceptance test driving the real CLI for growth re-import, `tdd/`-immutability, and divergence/`--force` (stays red until US2 completes), in `test/commands/corpus_command_test.dart`

### Implementation for User Story 2

- [ ] T012 [US2] [U8] [U9] [U14] Wire `--force` and `--dry-run` through the importer's copy decision and manifest write (dry-run writes nothing, manifest included), in `lib/src/cli/services/corpus_importer.dart` and `lib/src/commands/corpus_command.dart`

**Checkpoint**: US1 AND US2 both work independently; A4–A6 green

---

## Phase 5: User Story 3 - Loop-ready by verification (Priority: P2)

**Goal**: Readiness marks come from the same `SpecParser` `zfa tdd plan` uses,
so marks and plan behavior can never disagree; manifest carries
`ready`/`not-ready` + reason.

**Independent Test**: Fixture with a borderline spec (scenarios present,
FRs missing, or vice versa) → the mark matches what `zfa tdd plan` does
with the same file.

### Tests for User Story 3 ⚠️ (write first, watch fail)

- [ ] T013 [P] [US3] [U12] Readiness-parity tests (fast): for 4 fixture shapes (full / no scenarios / no FRs / malformed), assert importer mark == plan parser verdict, in `test/cli/services/corpus_importer_test.dart`
- [ ] T021 [P] [US3] [A7] [A8] Acceptance test: manifest marks survive CLI import and are directly consumable (ready/not-ready + reason present per feature), in `test/commands/corpus_command_test.dart`

### Implementation for User Story 3

- [ ] T014 [US3] [U12] Ensure readiness uses the exact `SpecParser` entry point plan uses (no second parser, no regex sniffing), capturing its error as the manifest reason, in `lib/src/cli/services/corpus_importer.dart`

**Checkpoint**: All user stories independently functional; A7–A8 green

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T015 [U19] [U20] `zfa setup --specs <dir>`: add the option to `setup_command.dart`, invoke `CorpusImporter` after the TDD baseline step (step numbering 7/7 → 8/8 when present); setup without `--specs` unchanged, in `lib/src/commands/setup_command.dart`
- [ ] T016 Run `dart analyze` on all touched files and fix findings
- [ ] T017 Run `dart test test/cli/services/ test/commands/ test/core/project/` and confirm green
- [ ] T018 Execute quickstart.md scenarios 1–5 verbatim and record results in `specs/050-corpus-import/tdd/` evidence

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none — start immediately
- **Foundational (Phase 2)**: T002 then T003; BLOCKS all user stories
- **US1 (Phase 3)**: depends on Phase 2 + T001
- **US2 (Phase 4)**: depends on T003; independent of US1's command work
- **US3 (Phase 5)**: depends on T003; independent of US1/US2
- **Polish (Phase 6)**: depends on US1 (setup wiring sits in setup_command)

### Parallel Opportunities

- T004–T007 in parallel after Phase 2 (different test files)
- T010, T011, T013 in parallel; T015 independent of US2/US3; T019/T020/T021 in parallel with their story's unit tests

## Parallel Example: User Story 1

```bash
# Launch all US1 tests together:
Task: "Manifest tests in test/core/project/corpus_manifest_test.dart"
Task: "Importer matrix tests in test/cli/services/corpus_importer_test.dart"
Task: "Plannability proof in test/cli/services/corpus_importer_test.dart"
Task: "Command tests in test/commands/corpus_command_test.dart"
Task: "Acceptance test in test/commands/corpus_command_test.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 + Phase 2 → foundation ready
2. Phase 3 (US1) → one-command import working → **STOP and VALIDATE**
3. Phases 4–5 harden idempotency and readiness parity; Phase 6 wires setup

### Incremental Delivery

The command family `corpus` lands with `import` only; #628's
`run`/`status`/`audit` slot in as sibling subcommands later.

## Notes

- All tests are fast tier — no subprocess/slow suites; keep it that way
  (import is pure file I/O).
- `SpecParser` reuse is load-bearing (US3): a second parser is the exact
  dialect-drift class #617 fixed. Guard it with the parity test.
- Foreign artifacts: report `foreign-artifacts-ignored`, never copy, never
  convert, never delete (spec FR-007).
- Not-ready features are imported and reported — import itself always exits
  0 for a completed copy operation.
- Acceptance tasks T019–T021 appended by `/speckit.tdd.plan` (ids continue
  the sequence; no existing task renumbered).