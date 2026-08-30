---
feature: 046-tdd-verify-red
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 14
planned_at: 0118a465
updated_at: 5232a80b
suite_baseline: green
---

# Test List: `zfa tdd verify-red`

Baseline note: `dart test test/plugins/tdd/` at `0118a465` → 104 passed, 2
failed (pre-existing 044 failures: `verify_command_test.dart` NOT_ASSESSED
expectation; `gen_command_test.dart` temp-dir cwd restore). At `938a5aec`
(“spec ready”) the scoped suite is fully green — 106 passed, 0 failed
(re-verified at loop start). The loop starts on a green baseline.

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`. Each drives the real CLI entry
point (`CliRunner` → `zfa tdd verify-red`) and stays red until the story
works end to end. Scenario files follow the profile convention
`test/plugins/tdd/scenarios/sc_<NNN>_<slug>_test.dart`.

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| A1 | Honestly-red behavior run: classification `assertion`, red entry appended, exit 0 | US1.AC1 | example | DONE | sc_001_certifies_honest_red_test.dart::A1 |
| A2 | Appended red entry carries all 9 serialized fields: 8 evidence fields plus required structural marker `kind` (behavior, kind, classification, criterion, test, command, exit, at, output) | US1.AC2 | example | DONE | sc_001_certifies_honest_red_test.dart::A2 |
| A3 | A certified run modifies no file under `test/` or `lib/` (checksum-verified) | US1.AC3 | example | DONE | sc_001_certifies_honest_red_test.dart::A3 |
| A4 | Compile-broken subject → exit non-zero, `compile-error` named, log unchanged | US2.AC1 | example | DONE | sc_002_rejects_dishonest_red_test.dart::A4 |
| A5 | Missing test file/import → exit non-zero, `load-error` named, log unchanged | US2.AC2 | example | DONE | sc_002_rejects_dishonest_red_test.dart::A5 |
| A6 | Passing target test → exit non-zero, `unexpected-green` named, log unchanged | US2.AC3 | example | DONE | sc_002_rejects_dishonest_red_test.dart::A6 |
| A7 | Skipped/pending target test → exit non-zero, `skipped` named, log unchanged | US2.AC4 | example | DONE | sc_002_rejects_dishonest_red_test.dart::A7 |
| A8 | Runner cannot execute (tooling/timeout/blended run) → exit non-zero, `runner-error` named, log unchanged | US2.AC5 | example | DONE | sc_002_rejects_dishonest_red_test.dart::A8 |
| A9 | No-arg invocation with exactly one uncertified gen'd behavior verifies that behavior | US3.AC1 | example | DONE | sc_003_target_resolution_test.dart::A9 |
| A10 | No-arg invocation with multiple uncertified behaviors exits non-zero listing candidate ids | US3.AC2 | example | DONE | sc_003_target_resolution_test.dart::A10 |
| A11 | Unknown behavior id exits non-zero naming the id before any test run | US3.AC3 | example | DONE | sc_003_target_resolution_test.dart::A11 |
| A12 | Behavior id without registry artifacts exits non-zero instructing `zfa tdd gen` first | US3.AC4 | example | DONE | sc_003_target_resolution_test.dart::A12 |
| A13 | Every invocation ends with the summary line `verify-red: behavior=<id> classification=<class> certified=<bool> feature=<feature>` | US4.AC1 | example | DONE | sc_004_summary_contract_test.dart::A13/U26 |
| A14 | Exit code 0 occurs exactly on certification; every rejection is non-zero | US4.AC2 | example | DONE | sc_004_summary_contract_test.dart::A14 |

## Inner loop: unit behaviors

### `lib/src/plugins/tdd/services/red_classifier.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U1 | Non-zero exit with assertion signature (`Expected:`/`Actual:`/`TestFailure`) classifies `assertion` | FR-004 | example | DONE | red_classifier_test.dart::U1 |
| U2 | Exit 0 with no skip markers classifies `unexpected-green` | FR-004 | example | DONE | red_classifier_test.dart::U2 |
| U3 | Exit 0 where all executed tests are skipped/pending classifies `skipped` | FR-004 | example | DONE | red_classifier_test.dart::U3 |
| U4 | `Failed to load` / unresolvable import / missing file output classifies `load-error` | FR-004 | example | DONE | red_classifier_test.dart::U4 |
| U5 | CFE compilation diagnostics without load signature classify `compile-error` | FR-004 | example | DONE | red_classifier_test.dart::U5 |
| U6 | Process failed to start classifies `runner-error` | FR-004 | example | DONE | red_classifier_test.dart::U6 |
| U7 | Parsed executed-test count ≠ 1 classifies `runner-error` (blended run) | FR-005 | example | DONE | red_classifier_test.dart::U7 |
| U8 | Count ≠ 1 with a load/compile signature still classifies load/compile (signature beats count) | FR-005 | example | DONE | red_classifier_test.dart::U8 |
| U9 | Non-zero exit, one test, no assertion signature classifies `runner-error` (unexplained red is not honest red) | FR-004 | example | DONE | red_classifier_test.dart::U9 |
| U10 | Classification is deterministic when multiple signatures co-occur: fixed precedence runner-start → load → compile → skip → green → assertion → runner-error | FR-004 | example | DONE | red_classifier_test.dart::U10 |

### `lib/src/plugins/tdd/services/runner.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U11 | Substitutes `{file}` and `{name}` from the profile `single` template into the executed command | FR-003 | example | DONE | runner_test.dart::U11 |
| U12 | Returns exit code and combined stdout+stderr of the run | FR-003 | example | DONE | runner_test.dart::U12 |
| U13 | Records `startedProcess=false` when the executable cannot launch | FR-004 | example | DONE | runner_test.dart::U13 |
| U14 | Executes in the provided working directory | FR-003 | example | DONE | runner_test.dart::U14 |

### `lib/src/plugins/tdd/models/cycle_entry.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U15 | `toMarkdown()` emits all 9 serialized fields in fixed order: 8 evidence fields plus required structural marker `kind` (behavior, kind, classification, criterion, test, command, exit, at, output) | FR-006 | example | DONE | models/cycle_entry_test.dart::U15 |
| U16 | `FailureClass` includes `skipped` and `runnerError` and serializes them round-trip | FR-004, FR-006 | example | DONE | models/cycle_entry_test.dart::U16 |

### `lib/src/plugins/tdd/commands/verify_red_command.dart` — resolution

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U17 | Explicit known behavior id resolves its registry record | FR-001, FR-002 | example | DONE | verify_red_command_test.dart::U17 |
| U18 | Unknown id errors naming the id before any runner invocation | FR-002 | example | DONE | verify_red_command_test.dart::U18 |
| U19 | Zero-arg with exactly one uncertified record selects it | FR-002 | example | DONE | verify_red_command_test.dart::U19 |
| U20 | Zero-arg with multiple uncertified records errors listing the candidates | FR-002 | example | DONE | verify_red_command_test.dart::U20 |
| U21 | Zero-arg with zero candidates errors stating none exist | FR-002 | example | DONE | verify_red_command_test.dart::U21 |
| U22 | Known behavior id without a registry record instructs `zfa tdd gen <id>` first | FR-002 | example | DONE | verify_red_command_test.dart::U22 |

### `lib/src/plugins/tdd/commands/verify_red_command.dart` — command behavior

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U23 | Certified run appends exactly one red entry with all 8 evidence fields | FR-006 | example | DONE | verify_red_command_test.dart::U23 |
| U24 | Rejected run leaves `cycle-log.md` byte-identical | FR-007 | example | DONE | verify_red_command_test.dart::U24 |
| U25 | No invocation writes, creates, or deletes under `test/` or `lib/` | FR-008 | example | DONE | verify_red_command_test.dart::U25 |
| U26 | Summary line is the final stdout line in the contract format on every code path | FR-009 | example | DONE | verify_red_command_test.dart::U26 |
| U27 | Missing/unreadable `tdd-profile.md` stops with a misfire error before any run | FR-003, FR-010 | example | DONE | verify_red_command_test.dart::U27 |

## Invariants and edge cases still to place

None — all spec edge cases mapped: deleted-after-gen test file → A5/U4;
blended runs → U7/A8; repeated certification (append-only history) → covered
by U23's append semantics.

## Out of scope

- `zfa tdd make`, `refactor`, `run` — separate precondition specs of epic 045.
- Re-classifying historical cycle-log entries — spec Out of Scope.
- Changing `gen` artifact shapes — epic FR-012 gap protocol.
- Repo-wide suite health — profile says run the scoped subset for feature
  work; the 2 pre-existing failures are recorded in the baseline note.

## Verification commands

Copied from `.specify/memory/tdd-profile.md` at planning time (feature scope
adapted to this feature's test tree):

- Single test: `dart test <file> --plain-name "<name>"`
  (corrected at loop start: the profile’s recorded `-P` flag means `--preset`
  to `dart test` and made every single-test run fail with “Undefined preset”;
  `--plain-name` is the plain-text filter the profile describes)
- Full suite (feature scope): `dart test test/plugins/tdd/`
- Full suite (repo): `dart test` — slow; not for loop use
- Static analysis (feature scope): `dart analyze lib/src/plugins/tdd/ test/plugins/tdd/`
- Coverage: `dart test --coverage=<dir>` then `dart run coverage:format_coverage`
- Mutation: none wired; `/speckit.tdd.verify` falls back to deliberate-mutant
  sampling
