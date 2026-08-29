---
feature: 041-tdd-setup-plugin
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 29
planned_at: adda6b4c
updated_at: adda6b4c
suite_baseline: green
---

# Test List: TDD-ready `zfa setup` baseline + `zfa tdd` plugin

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`. Each stays red until the feature works end to end through the real entry point — the `zfa` CLI for Part 2 subcommands, the generated `flutter` project for Part 1.

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| A1  | After `zfa setup myapp`, the project contains `test/bootstrap_smoke_test.dart`, `dart_test.yaml`, `.specify/memory/tdd-profile.md`, and `pubspec.yaml` with testing `dev_dependencies` | US1.AC1, FR-1..4 | example | PENDING | `test/plugins/tdd/tdd_command_smoke_test.dart::emits baseline` |
| A2  | After `zfa setup myapp`, `flutter test` exits 0 with ≥1 test | US1.AC2, FR-6 | example | PENDING | `test/plugins/tdd/scenarios/sc_001_setup_emits_tdd_baseline_test.dart::flutter test exits 0 ≥1 test` |
| A3  | `flutter test test/bootstrap_smoke_test.dart` runs exactly that file | US1.AC3, FR-7 | example | PENDING | (same as A2) |
| A4  | `.specify/memory/tdd-profile.md` has the five resolvable keys | US1.AC4, FR-4 | example | PENDING | `test/cli/writers/tdd/tdd_profile_writer_test.dart::resolves all five keys` |
| A5  | `zfa setup myapp --tdd-example` emits an assertion-failing example test | US1.AC5, FR-5 | example | PENDING | `test/cli/writers/tdd/tdd_example_writer_test.dart::failure is assertion` |
| A6  | `zfa tdd init` on a missing-baseline project creates all four artifacts | US2.AC1, FR-8 | example | PENDING | `test/plugins/tdd/tdd_command_smoke_test.dart::init creates missing` |
| A7  | `zfa tdd init` on an already-satisfied project is a no-op | US2.AC2, FR-9 | example | PENDING | `test/plugins/tdd/tdd_command_smoke_test.dart::init idempotent` |
| A8  | `zfa tdd init` on a partial baseline fills gaps only | US2.AC3, FR-8 | example | PENDING | `test/cli/writers/tdd/smoke_test_writer_test.dart::preserves existing` |
| A9  | `zfa tdd plan <feature>` emits one acceptance + one unit per criterion | US3.AC1, FR-10 | example | PENDING | `test/plugins/tdd/services/spec_parser_test.dart::extracts behaviors` |
| A10 | Re-running `zfa tdd plan` preserves ids for unchanged behaviors | US3.AC2, FR-11 | example | PENDING | `test/plugins/tdd/commands/plan_command_test.dart::preserves ids` (deferred) |
| A11 | `zfa tdd plan` on spec with no acceptance scenarios exits non-zero | US3.AC3, FR-12 | example | PENDING | `test/plugins/tdd/services/spec_parser_test.dart::no scenarios exits non-zero` |
| A12 | `zfa tdd gen B-003` writes test + compiling stub | US4.AC1, FR-13 | example | PENDING | (deferred to Phase 6) |
| A13 | Generated test fails with assertion failure | US4.AC2, FR-13 | example | PENDING | (deferred to Phase 6) |
| A14 | `zfa tdd gen <unknown-id>` exits non-zero | US4.AC3, FR-14 | example | PENDING | (deferred to Phase 6) |
| A15 | `zfa tdd verify-red` on honest red writes red entry, exit 0 | US5.AC1, FR-15..17 | example | PENDING | (deferred to Phase 7) |
| A16 | `zfa tdd verify-red` on compile error exits non-zero, no entry | US5.AC2, FR-17 | example | PENDING | (deferred to Phase 7) |
| A17 | `zfa tdd verify-red` on unexpected green exits non-zero, no entry | US5.AC3, FR-17 | example | PENDING | (deferred to Phase 7) |
| A18 | `zfa tdd make B-003` generates impl, test passes, green entry | US6.AC1, FR-18..19 | example | PENDING | (deferred to Phase 8) |
| A19 | `zfa tdd make` cannot generate — exits non-zero, no test mod | US6.AC2, FR-25 | example | PENDING | (deferred to Phase 8) |
| A20 | `zfa tdd make` detects sibling regression | US6.AC3, FR-20 | example | PENDING | (deferred to Phase 8) |
| A21 | `zfa tdd refactor` on green suite, no test modification | US7.AC1, FR-22 | example | PENDING | (deferred to Phase 9) |
| A22 | `zfa tdd refactor` on red suite refuses to start | US7.AC2, FR-21 | example | PENDING | (deferred to Phase 9) |
| A23 | `zfa tdd refactor` regressed exits non-zero, no green entry | US7.AC3, FR-22 | example | PENDING | (deferred to Phase 9) |
| A24 | `zfa tdd run <feature>` advances all behaviors through DONE | US8.AC1, FR-23 | example | PENDING | (deferred to Phase 10) |
| A25 | Interrupted `zfa tdd run` resumes from last incomplete behavior | US8.AC2, FR-24 | example | PENDING | (deferred to Phase 10) |
| A26 | `zfa tdd run` misfire stops the run, no fake pass | US8.AC3, FR-25 | example | PENDING | (deferred to Phase 10) |
| A27 | `zfa tdd verify` writes 3-section verification.md with mutation tool | US9.AC1, FR-26..28 | example | PENDING | (deferred to Phase 11) |
| A28 | `zfa tdd verify` falls back to spot-check when no mutation tool | US9.AC2, FR-27 | example | PENDING | (deferred to Phase 11) |
| A29 | `zfa tdd verify` on non-green exits non-zero before coverage | US9.AC3, FR-29 | example | PENDING | (deferred to Phase 11) |

## Inner loop: unit behaviors

### `lib/src/plugins/tdd/models/behavior.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U1  | Equality by id alone | FR-10 | example | PENDING | `test/plugins/tdd/models/behavior_test.dart::equality by id` |
| U2  | Default state is `pending` | FR-23 | example | PENDING | `test/plugins/tdd/models/behavior_test.dart::default state` |

### `lib/src/plugins/tdd/models/tdd_profile.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U3  | Flutter profile has all five keys | FR-4, FR-30 | example | PENDING | `tdd_profile_test.dart::has all five keys` |
| U4  | `resolveSingle` substitutes both placeholders | FR-30 | example | PENDING | `tdd_profile_test.dart::resolveSingle` |
| U5  | `resolveFile`, `resolveSuite`, `resolveCoverage` substitute placeholders | FR-30 | example | PENDING | `tdd_profile_test.dart::other resolutions` |

### `lib/src/plugins/tdd/models/cycle_entry.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U6  | Red entry renders all required fields | FR-16, FR-19 | example | PENDING | `cycle_entry_test.dart::renders red entry` |
| U7  | `FailureClass` distinguishes the four classes | FR-15 | example | PENDING | `cycle_entry_test.dart::distinguishes classes` |

### `lib/src/plugins/tdd/models/run_state.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U8  | `advance` returns an immutable copy | FR-24 | example | PENDING | `run_state_test.dart::advance immutable` |
| U9  | `toJson`/`fromJson` round-trips with in-flight markers | FR-24 | example | PENDING | `run_state_test.dart::round-trip` |

### `lib/src/cli/writers/tdd/tdd_profile_writer.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U10 | Writes the five-key map | FR-4 | example | PENDING | `tdd_profile_writer_test.dart::writes five-key map` |
| U11 | Idempotent — second run is a no-op | FR-9 | example | PENDING | `tdd_profile_writer_test.dart::idempotent` |

### `lib/src/cli/writers/tdd/dart_test_yaml_writer.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U12 | Writes parseable `dart_test.yaml` | FR-3 | example | PENDING | `dart_test_yaml_writer_test.dart::writes parseable yaml` |
| U13 | Idempotent | FR-9 | example | PENDING | `dart_test_yaml_writer_test.dart::idempotent` |

### `lib/src/cli/writers/tdd/smoke_test_writer.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U14 | Writes `bootstrap_smoke_test.dart` referencing the package | FR-1 | example | PENDING | `smoke_test_writer_test.dart::writes smoke test` |
| U15 | Idempotent; refuses to overwrite user-edited smoke test | FR-9 | example | PENDING | `smoke_test_writer_test.dart::preserves existing` |

### `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U16 | Adds all six missing dev_dependencies | FR-2 | example | PENDING | `pubspec_dev_dependencies_patcher_test.dart::adds all six missing` |
| U17 | No duplicates | FR-9 | example | PENDING | `pubspec_dev_dependencies_patcher_test.dart::does not duplicate` |
| U18 | Misfire-stop on parse failure | FR-31 | example | PENDING | `pubspec_dev_dependencies_patcher_test.dart::misfire-stop` |

### `lib/src/cli/writers/tdd/tdd_example_writer.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U19 | Emits assertion-failing example test | FR-5 | example | PENDING | `tdd_example_writer_test.dart::references AppContainer.greeting` |

### `lib/src/commands/setup_command.dart` (extended)

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U20 | `SetupCommand.run` calls the four writers after the scaffold | FR-1..4 | example | PENDING | (verified via `tdd_command_smoke_test.dart` end-to-end) |
| U21 | `SetupCommand.run` honors `--dry-run` | FR-1 | example | PENDING | (deferred) |
| U22 | `SetupCommand.run` with `--tdd-example` calls `TddExampleWriter` | FR-5 | example | PENDING | (deferred) |

### `lib/src/plugins/tdd/commands/init_command.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U23 | `zfa tdd init` invokes the four writers in order | FR-8 | example | PENDING | `tdd_command_smoke_test.dart::init creates missing` |
| U24 | `zfa tdd init` misfire-stop on writer failure | FR-31 | example | PENDING | (deferred) |

### `lib/src/plugins/tdd/services/spec_parser.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U25 | Extracts one acceptance behavior per Given/When/Then + one unit per FR | FR-10 | example | PENDING | `spec_parser_test.dart::extracts behaviors` |
| U26 | Exits non-zero on no acceptance scenarios | FR-12 | example | PENDING | `spec_parser_test.dart::no scenarios` |

### `lib/src/plugins/tdd/commands/plan_command.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U27 | Writes `tdd/test-list.md` with the parsed behaviors | FR-10 | example | PENDING | (verified via `tdd_command_smoke_test.dart::plan on missing spec`) |
| U28 | Preserves existing ids for unchanged behaviors on re-plan | FR-11 | example | PENDING | (deferred) |

### `lib/src/plugins/tdd/commands/{gen,verify_red,make,refactor,run,verify}_command.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U29–U58 | Each unimplemented subcommand exits non-zero with an honest "not yet implemented" message | FR-031 | example | PENDING | (deferred to Phases 6–11) |

### `lib/src/plugins/tdd/services/cycle_log.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U38 | `CycleLog.append` creates the file if missing | FR-16 | example | PENDING | `cycle_log_test.dart::creates file` |
| U39 | `CycleLog.append` is strictly append-only | FR-19, I-3 | example | PENDING | `cycle_log_test.dart::append-only` |

## Out of scope

- Generation of an entire Flutter project test directory tree beyond `bootstrap_smoke_test.dart` and `tdd_example_test.dart`.
- Mutation tool installation.
- CI integration (GitHub Actions workflow that runs `zfa tdd run` on every PR).
- IDE integrations.
- Refactor hooks beyond `zfa make --refactor`/`zfa build --refactor`.
- Test-list format conversion.

## Verification commands

Copied verbatim from `.specify/memory/tdd-profile.md`:

- Single test: `dart test test/<path>.dart -P "<name>"`
- Full suite (feature scope): `dart test test/plugins/tdd/`
- Full suite (repo): `dart test`
- Static analysis (feature scope): `dart analyze lib/src/plugins/tdd/ lib/src/cli/writers/tdd/ test/plugins/tdd/`
- Static analysis (full repo): `dart analyze`
- Coverage: `dart test --coverage=<dir>` then `dart run coverage:format_coverage`.
- Mutation: none wired in CI; falls back to deliberate-mutant sampling per the rubric.
