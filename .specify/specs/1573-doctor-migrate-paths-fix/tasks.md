# Tasks: 1573-doctor-migrate-paths-fix

- **Spec ID**: 1573-doctor-migrate-paths-fix
- **Created**: 2026-09-13

Dependency order: T001 (closing-loop test + positional-refusal test, RED
evidence) → T002 (fix: prescription strings + migrate-paths scope + arg
rejection + raw drift line, GREEN) → T003 (update the #1397/#874 string
assertions, still part of the prescription change) → T004 (verify +
artifacts).

## T001: Red — execute-the-prescription test + loud positional refusal
- New file `test/plugins/tdd/commands/bug_1573_doctor_migrate_prescription_test.dart`:
  - fixture: `Directory.systemTemp` project with `specs/` anchor, a bug
    feature dir `.specify/bugs/<slug>/{spec.md, tdd/test-list.md}`,
    `tdd/artifacts.json` recording a machine-absolute pair
    (`$tmp/test/tdd/<slug>/a1_test.dart` + subject), the pair seeded on
    disk at those project-relative locations (the relocated-registry
    shape, mirroring the real #1573 fixture)
  - P1 (SC-1, SC-4): `doctor .specify/bugs/<slug>` → verdict `drift`,
    prescription `migrate`, `fix == 'zfa tdd migrate-paths --feature <slug>'`;
    THEN tokenize the prescribed command from the `--> fix:` payload and
    EXECUTE it via the runner → assert `migrated=1` (migrated > 0), the
    stored registry form is portable, and a follow-up doctor run is healthy
  - P2 (SC-3): `migrate-paths <slug>` positional → usage error: exit
    `ExitProtocol.usage` (2), output names `--feature`, no migration
    happened (whole-project sweep refused)
  - P3 (SC-2): `migrate-paths --feature <slug>` reaches the bug registry
    (migrated=1) and the no-flag sweep lists the bug registry after `specs/`
  - P4 (SC-5): the doctor drift line contains the RAW recorded
    machine-absolute string, not the normalized relative form
- RED EVIDENCE: run the new file against HEAD → all four behaviors FAIL
  (P1: prescription is positional + executed command migrates 0;
  P2: exit 0 with a 92-record-style sweep shape; P3: migrated=0;
  P4: normalized value printed) → record `tdd/red-1573.log`
- Tests: `bug_1573_doctor_migrate_prescription_test.dart`

## T002: Green — the fix
- `doctor_command.dart`: the four single-feature `migrate-paths`
  prescriptions (:230, :377, :484, :612) → `'zfa tdd migrate-paths --feature …'`;
  the multi-owner branch stays `'zfa tdd migrate-paths'`; check 2e drift
  lines print the raw `record.testPath` / `record.subjectPath`
- `proof_chain_checker.dart:703` → `'zfa tdd migrate-paths --feature $feature'`
- `gen_command.dart:1039/:1108` → `'zfa tdd migrate-paths --feature …'`
- `migrate_paths_command.dart`:
  - `_run()`: `rest` non-empty → `usageException` naming the `--feature` form
  - `_scanRegistries()`: flag form routes through
    `TddFeaturePaths.resolveWithPin` (+ plain-name conventional bug-dir
    probe when the resolved dir carries no registry); sweep form adds
    `.specify/bugs/*` after `specs/*` (both sorted by basename)
- Run the T001 file → all green → record `tdd/green-1573.log`
- Tests: `bug_1573_doctor_migrate_prescription_test.dart`

## T003: Prescription-shape assertions in the related suites
- `bug_1397_path_form_mismatch_test.dart`: :221/:227/:302 →
  `contains('zfa tdd migrate-paths --feature $feature')`; header comment
  :24 `migrate-paths <feature>` → `migrate-paths --feature <feature>`
- `bug_874_doctor_cross_feature_adoption_test.dart`: :220/:270/:344 →
  same flag form; header comment :19 updated
- These files must pass UNCHANGED otherwise (the #874 multi-owner guard
  and every behavioral assertion stay as-is)
- Tests: both files, full run

## T004: Verify + artifacts
- `dart analyze` on every changed file → no new warnings
- Targeted re-runs: the three touched test files + neighbors
  (`bug_912_migrate_paths_package_uris_test.dart`,
  `gen_namespacing_827_test.dart`, `bug_969_json_verdict_envelope_test.dart`,
  `proof_chain_command_test.dart`)
- Live CLI re-check of the original repro (dry-run, real repo): doctor
  emits the flag form; `migrate-paths --feature cycle-log-phantom-sections
  --dry-run` reports the 5 bug-dir records (migrated=5) instead of 0;
  positional form exits 2
- `dart format .` → `git diff --stat` reviewed
- Write `tdd/verification.md` (FRESH from the actual run): verdict, gate
  table, red/green evidence, SC audit
- Commit, push, PR (`Closes #1573`)
