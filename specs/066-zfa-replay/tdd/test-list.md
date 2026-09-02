---
feature: 066-zfa-replay
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 7
planned_at: 066-zfa-replay
updated_at: 066-zfa-replay
suite_baseline: green
---

# Test List: `zfa replay` — deterministically re-execute a feature's recorded TDD history

Baseline: `dart test test/plugins/tdd/` at branch point `bd535c07` → fast tier
green (chunked runner). All fixture histories are seeded through the REAL
`CycleLog.append` writer so the machine format (schema-1 chain lines) is
byte-exact by construction; fixture gen steps target the scripted fake zfa
binary and fixture green commands target shell scripts (the sc_013–sc_017
driver-test pattern — no `dart test` inside fixtures, kernel-cache safe).

## Outer loop: acceptance behaviors

The 7 A-rows trace all 7 success criteria in `spec.md`; the `traces` column
names the SC each row covers. A-rows drive the real CLI entry point
in-process (`CliRunner.runCapturing`, the sc_001–sc_012 pattern).

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| A1  | A feature with two behaviors carrying full schema-1 recorded cycles replays clean end-to-end: exit 0, `result=clean replayed=2 skipped=0 diverged=0` as the final stdout line, gen stages identical, verify stages green, and the real project's trees byte-identical before/after (read-only contract) | SC1 | example | DONE | `test/plugins/tdd/commands/replay_command_test.dart::A1: a full recorded cycle replays clean` |
| A2  | Flipping a certified fact inside a hashed green entry (`- exit:` 0→1) breaks replay: exit 1, `result=divergent`, divergence names the behavior and the `green` entry as the broken chain link | SC2 | example | DONE | `test/plugins/tdd/commands/replay_command_test.dart::A2: a tampered cycle-log entry is caught with the entry named` |
| A3  | Hand-editing a generated test file in the real project so the re-rendered sandbox content differs flips the gen stage: `gen -> drift` naming the project-relative path, exit 1 | SC3 | example | DONE | `test/plugins/tdd/commands/replay_command_test.dart::A3: artifact drift is caught with the path named` |
| A4  | Breaking the subject the recorded green command's script checks flips the verify stage: `verify -> diverged (exit expected 0, actual 1)`, exit 1, behavior named | SC4 | example | DONE | `test/plugins/tdd/commands/replay_command_test.dart::A4: a verify divergence names behavior + expected/actual exits` |
| A5  | A three-behavior feature (two replayable, one only-red) replays `replayed=2 skipped=1 diverged=0` exit 0; a narrative-only log yields `result=partial` exit 2; a missing cycle-log exits 1 | SC5 | example | DONE | `test/plugins/tdd/commands/replay_command_test.dart::A5: full-history aggregation, partial, and missing-log` |
| A6  | `--events <path>` on a clean run writes parseable NDJSON starting `replay.start` and ending `replay.end` with `exit: 0`; on a divergent run the divergence-carrying `step.end` is present and `replay.end.exit == 1`; without `--events` no file is created | SC6 | example | DONE | `test/plugins/tdd/commands/replay_command_test.dart::A6: the NDJSON event log mirrors the run` |
| A7  | `zfa replay <feature>` and `zfa replay <path>/tdd/cycle-log.md` produce the same summary/exit as `zfa tdd replay <feature>`; an unknown `--behavior` id stops exit 1 naming the id and the recorded behaviors | SC7 | example | DONE | `test/plugins/tdd/commands/replay_command_test.dart::A7: the dream surface delegates and unknown ids fail named` |

## Inner loop: unit behaviors

### `lib/src/plugins/tdd/services/replay_history.dart` (grouping + gen steps)

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U1  | Entries group by behavior id in file order (interleaved behaviors stay grouped; red/green/refactor attached to their behavior); zero parseable sections → empty list | FR-002, FR-003 | example | DONE | `test/plugins/tdd/services/replay_history_test.dart::U1: entries group by behavior in file order` |
| U2  | Generation-step extraction: a green section's `- generation:` block parses into ordered steps (command/exit/purpose); `  (none)` → empty; red/refactor sections contribute none | FR-008 | example | DONE | `test/plugins/tdd/services/replay_history_test.dart::U2: generation steps parse from the green block` |

### `lib/src/plugins/tdd/services/replay_history.dart` (integrity + replayability)

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U3  | Chain integrity: a valid per-behavior chain verifies; a tampered certified fact breaks with the behavior + entry kind named; a spliced prev-hash breaks with a linkage divergence; hash-less schema-0 entries are skipped as unverified, never failed; an integrity divergence stops that behavior's gen/verify stages (tampered commands never execute) | FR-004 | example | DONE | `test/plugins/tdd/services/replay_history_test.dart::U3: the recorded chain verifies or breaks named` |
| U4  | Red structural checks: missing recorded test path → `red-missing-test-artifact`; recorded exit 0 → `red-exit-zero`; missing classification → `red-no-classification`; a valid red passes | FR-005 | example | DONE | `test/plugins/tdd/services/replay_history_test.dart::U4: red evidence is structurally validated` |
| U5  | Replayability derivation: only-red → gen/verify skippable; green without a generation block → gen skipped; green without a recorded command → verify skipped; both present → fully replayable | FR-008, FR-010 | example | DONE | `test/plugins/tdd/services/replay_history_test.dart::U5: replayability derives from what was recorded` |

### `lib/src/plugins/tdd/services/replay_sandbox.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U6  | Seeding copies pubspec.yaml/pubspec.lock/analysis_options.yaml/.zfa.json/lib//test//specs/<feature>//.specify//.dart_tool/package_config.json; excludes .git, build/, .dart_tool/test/**; absent sources skipped silently; cleanup deletes unless kept; copies are byte-identical | FR-006, FR-007 | example | DONE | `test/plugins/tdd/services/replay_sandbox_test.dart::U6: the sandbox seeds, excludes, and cleans` |

### `lib/src/plugins/tdd/services/replay_runner.dart` (stages)

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U7  | Gen replay: recorded steps run (cwd = sandbox, `--zfa-bin` substituted); identical trees → `identical` (0 paths); drift → sorted project-relative A/M/D paths with the sandbox root absent from every path | FR-008, FR-009 | example | DONE | `test/plugins/tdd/services/replay_runner_test.dart::U7: gen replay compares trees path-stably` |
| U8  | Verify replay: recorded command runs in the sandbox cwd; equal exit → `green`; mismatch → `verify-exit-mismatch` with expected/actual; unspawnable → `runner-error`; absent command or unresolved project → skipped with reason | FR-010, FR-011 | example | DONE | `test/plugins/tdd/services/replay_runner_test.dart::U8: verify replay asserts the recorded exit` |
| U9  | Report shaping: result rules (any divergence → `divergent`/1; zero replayed → `partial`/2; else `clean`/0) and replayed/skipped/diverged counts per FR-013 | FR-013 | example | DONE | `test/plugins/tdd/services/replay_runner_test.dart::U9: the report aggregates to result + exit` |
| U10 | NDJSON events: one JSON object per line in stable shape; `replay.start` → per-stage `step.start`/`step.end` → terminal `replay.end` whose `exit` equals the final exit; written on every outcome | FR-014 | example | DONE | `test/plugins/tdd/services/replay_runner_test.dart::U10: events are NDJSON and end with the exit` |
