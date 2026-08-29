---
feature: 044-test-tdd-generation
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 24
planned_at: 044-init
updated_at: 044-init
suite_baseline: green
---

# Test List: 044 — Behavior-aware test generation and trustworthy mutation evidence

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`. Each stays red until the feature
works end to end through the real entry point (`zfa tdd gen` / `zfa tdd verify`).

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| A1  | `zfa tdd gen B-003` writes exactly one test + one subject and exits 0 with the six required result fields | US1.AC1, FR-001, FR-005 | acceptance | PENDING | `test/plugins/tdd/commands/gen_command_test.dart::happy path writes one test one subject structured result` |
| A2  | The generated test, on first execution, fails with an assertion failure (not compile/load/skip/pending) | US1.AC2, FR-010 | acceptance | PENDING | `test/plugins/tdd/commands/gen_command_test.dart::honest red assertion failure on first run` |
| A3  | `zfa tdd gen <unknown-id>` exits non-zero before writing any file | US1.AC3, FR-002 | acceptance | PENDING | `test/plugins/tdd/commands/gen_command_test.dart::unknown id exits non-zero pre-write` |
| A4  | `zfa tdd gen <behavior-id>` with missing required fields exits non-zero pre-write | US1.AC4, FR-002 | acceptance | PENDING | `test/plugins/tdd/commands/gen_command_test.dart::missing required field exits non-zero pre-write` |
| A5  | `zfa tdd gen` on an acceptance-classified behavior works without pre-existing entity/use case/repository | US1.AC5, FR-003, FR-004 | acceptance | PENDING | `test/plugins/tdd/commands/gen_command_test.dart::acceptance classification no pre-existing domain` |
| A6  | Repeating `gen B-003` creates zero duplicate artifacts; result reports `Ownership.reused` | US2.AC1, FR-006 | acceptance | PENDING | `test/plugins/tdd/commands/gen_command_test.dart::idempotent repeat reuses ownership` |
| A7  | Ownership conflict: file exists with no registry entry → exit non-zero, file byte-for-byte unchanged | US2.AC2, FR-008 | acceptance | PENDING | `test/plugins/tdd/commands/gen_command_test.dart::ownership conflict preserves user content` |
| A8  | `zfa tdd gen B-003 --dry-run` writes nothing, prints planned paths, ownership `planned` | US2.AC3, FR-009 | acceptance | PENDING | `test/plugins/tdd/commands/gen_command_test.dart::dry run plans without writing` |
| A9  | `zfa tdd verify --feature 044` derives scope from registered behavior artifacts | US3.AC1, FR-012 | acceptance | PENDING | `test/plugins/tdd/commands/verify_command_test.dart::scope derived from artifacts` |
| A10 | `zfa tdd verify` runs green-suite preflight FIRST; red preflight → `PREFLIGHT_RED`, no mutation | US3.AC2, FR-013 | acceptance | PENDING | `test/plugins/tdd/commands/verify_command_test.dart::preflight red stops before mutation` |
| A11 | `zfa tdd verify` on unavailable mutation tool → `NOT_ASSESSED`, exit non-zero | US3.AC3, FR-015 | acceptance | PENDING | `test/plugins/tdd/commands/verify_command_test.dart::tool unavailable not assessed` |
| A12 | `zfa tdd verify` with >=1 survived mutant → `FAIL_SURVIVED`, affected behaviors listed, exit non-zero | US3.AC4, FR-017 | acceptance | PENDING | `test/plugins/tdd/commands/verify_command_test.dart::survived mutant fails gate` |
| A13 | After any audit, all temporarily mutated subjects restored (sha256 verified) | US3.AC5, FR-021 | acceptance | PENDING | `test/plugins/tdd/commands/verify_command_test.dart::source restoration verified` |

## Inner loop: unit behaviors

### `lib/src/plugins/tdd/models/ownership.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U1  | `Ownership.created` is the default for new artifacts | FR-005 | unit | PENDING | `test/plugins/tdd/models/ownership_test.dart::created is default` |
| U2  | `Ownership.reused` is returned for matching idempotent repeat | FR-006 | unit | PENDING | `test/plugins/tdd/models/ownership_test.dart::reused on repeat` |
| U3  | `Ownership.planned` is returned for `--dry-run` | FR-009 | unit | PENDING | `test/plugins/tdd/models/ownership_test.dart::planned on dry run` |

### `lib/src/plugins/tdd/models/artifact_record.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U4  | Record carries behavior id + test path + subject path + runnable test name + ownership + created_at | FR-005, FR-007 | unit | PENDING | `test/plugins/tdd/models/artifact_record_test.dart::fields exposed` |
| U5  | Record JSON round-trips losslessly | FR-007 | unit | PENDING | `test/plugins/tdd/models/artifact_record_test.dart::json round trip` |

### `lib/src/plugins/tdd/models/mutation_outcome.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U6  | `MutationOutcome` has four values: killed, survived, timedOut, notAssessed | FR-014, FR-016 | unit | PENDING | `test/plugins/tdd/models/mutation_outcome_test.dart::four values` |
| U7  | `MutationGateDecision` has five values: pass, failSurvived, failTimeout, preflightRed, notAssessed | FR-017, FR-019 | unit | PENDING | `test/plugins/tdd/models/mutation_outcome_test.dart::five gate decisions` |
| U8  | Gate decision picks `failSurvived` over `failTimeout` when both present | FR-017 | unit | PENDING | `test/plugins/tdd/models/mutation_outcome_test.dart::survived takes precedence` |

### `lib/src/plugins/tdd/services/behavior_test_writer.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U9  | Writer emits a Dart test file that imports the subject | FR-001, FR-010 | unit | PENDING | `test/plugins/tdd/services/behavior_test_writer_test.dart::imports subject` |
| U10 | The test asserts the behavior's `description`, not a placeholder | FR-010 | unit | PENDING | `test/plugins/tdd/services/behavior_test_writer_test.dart::asserts description not placeholder` |
| U11 | The test group name carries the behavior id + source criterion | FR-018 | unit | PENDING | `test/plugins/tdd/services/behavior_test_writer_test.dart::group name traces` |
| U12 | First execution of the generated test fails with an assertion failure class | FR-010 | unit | PENDING | `test/plugins/tdd/services/behavior_test_writer_test.dart::honest red on first run` |

### `lib/src/plugins/tdd/services/subject_writer.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U13 | Subject writer emits a compilable Dart file for `unit` classification | FR-001, FR-011 | unit | PENDING | `test/plugins/tdd/services/subject_writer_test.dart::unit subject compiles` |
| U14 | Subject writer emits a compilable Dart file for `acceptance` classification | FR-003, FR-004 | unit | PENDING | `test/plugins/tdd/services/subject_writer_test.dart::acceptance subject compiles` |
| U15 | Subject passes `dart analyze` with zero errors | FR-011 | unit | PENDING | `test/plugins/tdd/services/subject_writer_test.dart::analyze clean` |

### `lib/src/plugins/tdd/services/artifact_registry.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U16 | Registry appends a record on first `gen` for a behavior | FR-007 | unit | PENDING | `test/plugins/tdd/services/artifact_registry_test.dart::appends on first gen` |
| U17 | Registry returns `reused` on matching idempotent repeat (no new write) | FR-006 | unit | PENDING | `test/plugins/tdd/services/artifact_registry_test.dart::idempotent repeat reuses` |
| U18 | Registry refuses to overwrite a file that exists on disk but has no recorded ownership | FR-008 | unit | PENDING | `test/plugins/tdd/services/artifact_registry_test.dart::ownership conflict stops` |
| U19 | `--dry-run` writes no file and no registry entry | FR-009 | unit | PENDING | `test/plugins/tdd/services/artifact_registry_test.dart::dry run no write` |
| U20 | Registry reads back records for `verify`'s scope derivation | FR-012 | unit | PENDING | `test/plugins/tdd/services/artifact_registry_test.dart::read back for verify` |

### `lib/src/plugins/tdd/services/mutation_scope.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U21 | Scope derives the union of test+subject paths from `artifacts.json` | FR-012 | unit | PENDING | `test/plugins/tdd/services/mutation_scope_test.dart::derives from artifacts` |
| U22 | No registered artifacts → `NOT_ASSESSED — no behavior artifacts registered` | FR-012 | unit | PENDING | `test/plugins/tdd/services/mutation_scope_test.dart::no artifacts not assessed` |

### `lib/src/plugins/tdd/services/source_restorer.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U23 | Captures sha256 of every in-scope subject pre-audit | FR-021 | unit | PENDING | `test/plugins/tdd/services/source_restorer_test.dart::captures pre-audit sha256` |
| U24 | Restores every subject post-audit and verifies sha256 match | FR-021 | unit | PENDING | `test/plugins/tdd/services/source_restorer_test.dart::restores and verifies` |
| U25 | Restoration runs even on simulated interrupt (try/finally) | FR-021 | unit | PENDING | `test/plugins/tdd/services/source_restorer_test.dart::restores on interrupt` |

### `lib/src/plugins/tdd/services/mutation_auditor.dart`

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U26 | Auditor runs green-suite preflight FIRST | FR-013 | unit | PENDING | `test/plugins/tdd/services/mutation_auditor_test.dart::preflight first` |
| U27 | Red preflight → `PREFLIGHT_RED`, no mutation performed | FR-013 | unit | PENDING | `test/plugins/tdd/services/mutation_auditor_test.dart::preflight red stops` |
| U28 | Killed/survived/timed-out recorded as three separate buckets | FR-014 | unit | PENDING | `test/plugins/tdd/services/mutation_auditor_test.dart::three separate buckets` |
| U29 | Tool unavailable → `NOT_ASSESSED — mutation tool unavailable` | FR-015 | unit | PENDING | `test/plugins/tdd/services/mutation_auditor_test.dart::tool unavailable not assessed` |
| U30 | Empty/incomplete/unparseable report → `NOT_ASSESSED — <reason>` | FR-016 | unit | PENDING | `test/plugins/tdd/services/mutation_auditor_test.dart::unparseable not assessed` |
| U31 | Strict policy: ANY survived or timed-out → FAIL gate | FR-017 | unit | PENDING | `test/plugins/tdd/services/mutation_auditor_test.dart::strict policy fail gate` |
| U32 | Report traces outcome to behavior id + source criterion | FR-018 | unit | PENDING | `test/plugins/tdd/services/mutation_auditor_test.dart::traces to behavior id` |
| U33 | Source restoration verified post-audit by sha256 | FR-021 | unit | PENDING | `test/plugins/tdd/services/mutation_auditor_test.dart::restoration verified` |
| U34 | Never edits a test to fake a pass (auditor is read-only on test files) | FR-022 | unit | PENDING | `test/plugins/tdd/services/mutation_auditor_test.dart::never edits tests` |
