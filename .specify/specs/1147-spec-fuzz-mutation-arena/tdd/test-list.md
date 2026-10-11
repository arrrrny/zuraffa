# TDD test list — 1147-spec-fuzz-mutation-arena (issue #1147, extends #967)

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| A-1147-b1 | test/commands/spec_fuzz_command_1147_run_semantics_test.dart | acceptance | weak spec: mutants survive, exit 1, `certified=false`, the machine line carries `survived>0` (issue constraint 5, non-zero when survived > 0) | US1-AC-2 | RED → GREEN |
| A-1147-b2 | test/commands/spec_fuzz_command_1147_run_semantics_test.dart | acceptance | strong spec: every mutant killed, exit 0, `certified=true`, `survived=0`, `killed>0` (issue constraint 5, exit 0 when all killed) | US1-AC-1 | RED → GREEN |
| A-1147-b3 | test/commands/spec_fuzz_command_1147_run_semantics_test.dart | acceptance | report rows carry the documented fields `{mutation_id, spec_line, operator, verdict, evidence}` under `schema: spec-fuzz.v1`; ids are `SM-###`, spec lines positive, evidence non-empty (issue constraint 4) | US1-AC-1 | RED → GREEN |
| A-1147-b4 | test/commands/spec_fuzz_command_1147_run_semantics_test.dart | acceptance | the five declared operators (weaken, drop, swap-literal, widen, drop-must-not) all appear against the all-element fixture (issue constraint 1, the operator table) | US2-AC-1 | RED → GREEN |
| A-1147-b5 | test/commands/spec_fuzz_command_1147_run_semantics_test.dart | acceptance | `--operators weaken,drop` judges only the selected operators; the report's operator list is the sorted filter; the unfiltered candidate count is strictly larger (issue constraint 1, filter replayability) | US2-AC-3 | RED → GREEN |
| A-1147-b6 | test/commands/spec_fuzz_command_1147_run_semantics_test.dart | acceptance | `--budget 2` caps the judged mutants at exactly 2 against a larger candidate count and records `budget=2` (issue constraint 6) | US3-AC-1 | RED → GREEN |
| A-1147-b7 | test/commands/spec_fuzz_command_1147_run_semantics_test.dart | acceptance | same seed + budget → byte-identical `spec-fuzz.json` across rounds (issue constraint 1, replay) | US2-AC-2 | RED → GREEN |
| A-1147-b8 | test/commands/spec_fuzz_command_1147_run_semantics_test.dart | acceptance | a red preflight is refused (usage exit 2, `preflightRed` gate named, "never grade a red loop"), no report written for the unrun round | US1-AC-4 | RED → GREEN |

Guard pins (pre-existing, unchanged and green against the seam):

| id | suite | description |
| -- | ----- | ----------- |
| 0967 registration/usage/drift | test/commands/spec_fuzz_command_test.dart | 12 CLI-surface pins (flags, usage errors, drift exit 3, corpus misfire) — untouched |
| 0967 auditor | test/plugins/tdd/services/spec_fuzz_auditor_test.dart | 13 pins: weak/strong fixtures, honest refusals, budget+seed, report shape, restoration — untouched |
| 0967 mutator | test/plugins/tdd/services/spec_mutator_test.dart | 25 pins: per-operator candidate generation, line surgery, budget+seed selection, P1 gate chain — untouched |

## Red evidence (pre-fix, this session)

`dart test test/commands/spec_fuzz_command_1147_run_semantics_test.dart`
→ `00:00 +0 -1: Some tests failed.` — the file fails to LOAD:

```
Error: No named parameter with the name 'runPreflight'.
            runPreflight: preflight ?? _greenPreflight,
            ^^^^^^^^^^^^
lib/src/commands/spec_command.dart:16:3: Context: Found this candidate, but the arguments don't match.
  SpecCommand() {
  ^
```

The compile-error red is the honest first red for a NEW seam: it proves
the command layer had NO injectable preflight/spawn path — the fast tier
could not drive the REAL command's run semantics at all (every existing
CLI-level test stopped at usage/drift refusals; exit 0/1 semantics lived
only in the slow demo). With the API's logic in place pre-fix, A-1147-b1
would have returned the real-process result instead of the injected fake.

## Green evidence (post-fix, this session)

- `dart test test/commands/spec_fuzz_command_1147_run_semantics_test.dart`
  → `00:00 +8: All tests passed!`
- Siblings (no modifications):
  `dart test test/commands/spec_fuzz_command_test.dart
  test/plugins/tdd/services/spec_fuzz_auditor_test.dart
  test/plugins/tdd/services/spec_mutator_test.dart`
  → `00:01 +50: All tests passed!`
- Combined lane re-run after `dart format .`:
  → `00:11 +58: All tests passed!`
