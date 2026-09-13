---
feature: 1573-doctor-migrate-paths-fix
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 5
planned_at: 9254ec1
updated_at: 9254ec1
suite_baseline: green
---

# Test List: Doctor prescription ↔ migrate-paths reachability (bug #1573)

The behavior under test is the CLI-observable contract between `zfa tdd
doctor`'s prescription and `zfa tdd migrate-paths`' reachability — the
loop is outside-in: every behavior drives the real commands through
`CliRunner.runCapturing` against a `Directory.systemTemp` fixture,
asserting stdout, the exit code, the JSON verdict envelope, and — the
point of the fix — the EXECUTED outcome of the prescribed command.

## Outer loop: CLI behaviors

### The prescription closes the loop (doctor → migrate-paths → healthy)

| id | behavior                                                                                     | traces | kind    | state | test                                                                                                   |
| --- | ------------------------------------------------------------------------------------------- | ------ | -------- | ---- | ------------------------------------------------------------------------------------------------------- |
| P1  | Doctor on a bug-directory registry with machine-absolute records emits `fix: zfa tdd migrate-paths --feature <slug>` (fix line + JSON verdict); EXECUTING the prescribed command migrates the bug registry (migrated=1), rewrites the recorded forms to portable project-relative, and a follow-up doctor run is healthy | SC-1, SC-2, SC-4 | example | PENDING | `test/plugins/tdd/commands/bug_1573_doctor_migrate_prescription_test.dart::the prescribed migrate-paths command executes and repairs the diagnosed bug registry` |
| P2  | `zfa tdd migrate-paths <slug>` (positional) is rejected loudly: usage exit 2, message names `--feature`, nothing migrated | SC-3 | example | PENDING | `...bug_1573_doctor_migrate_prescription_test.dart::a positional feature argument is rejected loudly instead of silently sweeping every registry` |
| P3  | `migrate-paths --feature <bug-slug>` reaches `.specify/bugs/<slug>/tdd/artifacts.json` without a pin file; the no-flag sweep covers bug registries after `specs/` | SC-2 | example | PENDING | `...bug_1573_doctor_migrate_prescription_test.dart::the flag form reaches the bug registry and the whole-project sweep covers bug directories` |
| P4  | The doctor path-form drift line prints the RAW recorded machine-absolute value, not the normalized relative display form | SC-5 | example | PENDING | `...bug_1573_doctor_migrate_prescription_test.dart::the path-form drift line prints the raw recorded value` |

### Sibling prescription sites (string shape, flag form)

| id | behavior                                                                                     | traces | kind             | state | test                                             |
| --- | ------------------------------------------------------------------------------------------- | ------ | ---------------- | ---- | ------------------------------------------------- |
| S1  | The #1397 and #874 suites assert the `--feature` flag form (single-owner migrate prescriptions) | SC-1 | characterization | PENDING | `test/plugins/tdd/commands/bug_1397_path_form_mismatch_test.dart` + `test/plugins/tdd/bug_874_doctor_cross_feature_adoption_test.dart` (updated assertions) |

## Invariants and edge cases still to place

- The multi-owner doctor branch keeps the flag-less whole-project form
  (pinned by the UNCHANGED `bug_874` assertions :294-296).
- Migration mechanics (pair-atomicity, ownership refusals, fail-honest
  missing, cycle-log rewrites) are pinned by the existing #912/#827/#1397
  suites and are out of scope here.
- `gen_command.dart`/`proof_chain_checker.dart` prescription strings are
  covered by the S1 shape update; their behavioral verdicts are pinned by
  the existing #874/#1148 suites.
