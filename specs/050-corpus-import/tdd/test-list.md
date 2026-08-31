---
feature: 050-corpus-import
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 8
planned_at: 2a6246f3
updated_at: 2a6246f3
suite_baseline: green
---

# Test List: `zfa corpus import`

Baseline: `dart test test/commands test/core/project` at `2a6246f3` → 53
passed, 0 failed (fast tier; `test/cli/services/` is created by this
feature). All tests for this feature are fast-tier file operations — no
subprocess/slow suites.

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`, through the real CLI entry point
(`zfa corpus import`) in command-level tests (fast tier).

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| A1 | N-feature corpus imports: every `spec.md` present, per-feature `tdd/` dir exists, manifest lists all N deterministically | US1.AC1 | example | DONE | `test/commands/corpus_command_test.dart::A1` |
| A2 | Every imported feature plans via `zfa tdd plan` semantics with zero manual edits | US1.AC2 | example | DONE | `test/commands/corpus_command_test.dart::A2` |
| A3 | A no-scenario feature is imported AND reported `not-ready` (never dropped, never mutated) | US1.AC3 | example | DONE | `test/commands/corpus_command_test.dart::A3` |
| A4 | Re-import after corpus growth touches only new features (old untouched, manifest reflects the new total) | US2.AC1 | example | DONE | `test/commands/corpus_command_test.dart::A4` |
| A5 | Re-import leaves existing `tdd/` trees (test lists, cycle logs, artifacts) byte-identical | US2.AC2 | example | DONE | `test/commands/corpus_command_test.dart::A5` |
| A6 | Divergent spec is kept by default with both hashes reported; `--force` updates it | US2.AC3 | example | DONE | `test/commands/corpus_command_test.dart::A6` |
| A7 | Manifest marks every feature `ready`/`not-ready` with a one-line reason | US3.AC1 | example | DONE | `test/commands/corpus_command_test.dart::A7` |
| A8 | A consumer (batch driving, #628) can rely on the manifest mark without re-deriving it | US3.AC2 | example | DONE | `test/commands/corpus_command_test.dart::A8` |

## Inner loop: unit behaviors

### `lib/src/core/project/corpus_manifest.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U1 | Round-trips through `toJson`/`fromJson` (features, sourceCorpus, importedAt) | FR-002 | example | DONE | `test/core/project/corpus_manifest_test.dart::U1` |
| U2 | Features serialize in deterministic lexicographic order | FR-002 | example | DONE | `test/core/project/corpus_manifest_test.dart::U2` |
| U3 | write→read is stable except `importedAt` across identical re-imports | SC-004 | example | DONE | `test/core/project/corpus_manifest_test.dart::U3` |
| U4 | A missing manifest reads as null (not an error) | FR-002 | example | DONE | `test/core/project/corpus_manifest_test.dart::U4` |

### `lib/src/cli/services/corpus_importer.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U5 | A corpus root is accepted; a single-feature path is rejected with a clear message | FR-001 | example | DONE | `test/cli/services/corpus_importer_test.dart::U5` |
| U6 | An absent target spec is copied byte-for-byte (`imported`) | FR-001 | example | DONE | `test/cli/services/corpus_importer_test.dart::U6` |
| U7 | An identical existing spec is skipped | FR-003 | example | DONE | `test/cli/services/corpus_importer_test.dart::U7` |
| U8 | A different existing spec is kept with both hashes reported (`divergent`) | FR-004 | example | DONE | `test/cli/services/corpus_importer_test.dart::U8` |
| U9 | `--force` replaces a divergent spec (`imported`) | FR-004 | example | DONE | `test/cli/services/corpus_importer_test.dart::U9` |
| U10 | `tdd/` is created when absent | FR-001 | example | DONE | `test/cli/services/corpus_importer_test.dart::U10` |
| U11 | Existing `tdd/` contents are never modified (checksum-verified) | FR-003 | example | DONE | `test/cli/services/corpus_importer_test.dart::U11` |
| U12 | The readiness mark equals the `SpecParser` verdict (`ready`) and carries the parser's reason (`not-ready`) | FR-006 | example | DONE | `test/cli/services/corpus_importer_test.dart::U12` |
| U13 | Foreign artifacts are ignored and reported, never copied or converted | FR-007 | example | DONE | `test/cli/services/corpus_importer_test.dart::U13` |
| U14 | `--dry-run` writes nothing, manifest included | FR-003 | example | DONE | `test/cli/services/corpus_importer_test.dart::U14` |
| U15 | The per-feature report and summary line match the contract; exit 0 on a completed copy | FR-005 | example | DONE | `test/cli/services/corpus_importer_test.dart::U15` |

### `lib/src/commands/corpus_command.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U16 | `import` requires `source`, accepts `--dry-run` and `--force` | FR-001 | example | DONE | `test/commands/corpus_command_test.dart::U16` |
| U17 | An invalid source fails with a message, not a crash | FR-001 | example | DONE | `test/commands/corpus_command_test.dart::U17` |
| U18 | `corpus` is registered in the CLI runner (help lists it) | FR-001 | example | DONE | `test/commands/corpus_command_test.dart::U18` |

### `lib/src/commands/setup_command.dart` (extension)

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U19 | `--specs <dir>` triggers the import step after the TDD baseline | FR-001 | example | PENDING | |
| U20 | `setup` without `--specs` behaves exactly as before | FR-001 | example | PENDING | |

## Invariants and edge cases still to place

None — spec edge cases mapped: name collisions → U8 (divergent, never
merged); single-feature source → U5; very large corpora → fast-tier file
ops (no test-execution at import time, test/execution timing not a
concern here).

## Out of scope

- Test-list format conversion (#617 owns it) — foreign formats reported,
  never converted (U13).
- Dependency-ordered corpus ordering (#628's batch driver owns that).
- Execution of any tests at import time.
- Extracting specs from a legacy app (rewrite/tupec tooling owns that).

## Verification commands

Copied from `.specify/memory/tdd-profile.md` at planning time (feature scope
adapted to this feature's test tree):

- Single test: `dart test test/<path>.dart -P "<name>"`
- Full suite (feature scope): `dart test test/cli/services/ test/commands/ test/core/project/`
- Full suite (repo): `dart test` — slow; not for loop use
- Static analysis (feature scope): `dart analyze lib/src/cli/services/ lib/src/commands/corpus_command.dart lib/src/core/project/corpus_manifest.dart test/cli/services/ test/commands/corpus_command_test.dart test/core/project/corpus_manifest_test.dart`
- Coverage: `dart test --coverage=<dir>` then `dart run coverage:format_coverage`
- Mutation: none wired; `/speckit.tdd.verify` falls back to deliberate-mutant
  sampling