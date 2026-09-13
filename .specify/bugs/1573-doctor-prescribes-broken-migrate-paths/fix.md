# Bug Fix: 1573-doctor-prescribes-broken-migrate-paths

- **Fixed**: 2026-09-13
- **Branch**: fix/1573-doctor-prescribes-broken-migrate-paths
- **Issue**: #1573
- **Related**: #1397, #874, #1471

## Change list

1. `lib/src/plugins/tdd/commands/doctor_command.dart` — every
   `migrate-paths` prescription now names the flag form:
   - foreign-owned migrate (bug #874): `zfa tdd migrate-paths --feature
     <owner>` (owners are specs/ basenames by construction);
   - relocated registry (2c), recorded path-form drift (2e) and
     import-resolution drift (2b): `zfa tdd migrate-paths --feature
     ${resolved.ref}` — the CANONICAL reference (issue #1471), so a bug
     feature the doctor resolved by path prescribes
     `--feature .specify/bugs/<slug>`, exactly the convention the adopt
     prescription already follows. Detection logic, verdict shapes and
     drift classification untouched.
   - the 2e path-form drift line prints the RAW recorded value
     (`record.testPath` / `record.subjectPath` verbatim) instead of the
     `_displayPath(cwd, p.normalize(...))` re-rendering that masked the
     machine-absolute form the drift is about.
2. `lib/src/core/proof/proof_chain_checker.dart` — the test-integrity
   import-drift prescription (line ~703) becomes
   `zfa tdd migrate-paths --feature $feature` (the feature is a specs/
   basename there by construction of `_featureDirs`).
3. `lib/src/plugins/tdd/commands/migrate_paths_command.dart`:
   - `_run()` rejects every unrecognized positional argument LOUDLY via
     `usageException` (`Unexpected positional argument "<arg>" —
     migrate-paths takes the feature as a flag: zfa tdd migrate-paths
     --feature <name>`), which exits `ExitProtocol.usage` (2). The silent
     discard-then-sweep behavior is dead.
   - `_scanRegistries` routes `--feature` through
     `TddFeaturePaths.resolveWithPin` (issue #1471) — plain names keep the
     legacy `specs/<name>` resolution (pin redirect honored), and
     `.specify/bugs/<slug>` path references resolve directly. A plain slug
     that names no `specs/` feature but matches `.specify/bugs/<slug>`
     falls back to the bug directory (legacy specs/ keeps priority; no
     traversal — the probe is plain-segment only).
   - the no-flag sweep enumerates BOTH `specs/*/tdd/artifacts.json` and
     `.specify/bugs/*/tdd/artifacts.json`, deterministically sorted per
     root; the "no feature registry found" message names both roots.
4. `test/plugins/tdd/commands/bug_1573_doctor_prescribes_broken_migrate_paths_test.dart`
   (NEW) — six hermetic behaviors (see `tdd/test-list.md`), RED pre-fix
   (`+0 -6`), GREEN post-fix. The contract test EXECUTES the prescribed
   command and asserts `migrated=1` + doctor-healthy (B2), and proves the
   positional rejection leaves a bystander form-drift registry
   byte-identical (B4).
5. `test/plugins/tdd/commands/bug_1397_path_form_mismatch_test.dart`,
   `test/plugins/tdd/bug_874_doctor_cross_feature_adoption_test.dart` —
   the pinned prescription assertions updated to the `--feature` form
   (they pinned the broken string shape, which is exactly how the drift
   passed CI; all other assertions untouched).

## Hard constraints honored

- Path-form normalization (`artifact_registry.dart`, #1397): untouched.
- Doctor detection logic / drift classification / verdict shape: untouched
  (only the fix-string payloads and the 2e drift-line interpolation
  changed).
- The TDD state machine (run/gen/verify-red/make/refactor): untouched.
- `migrate-paths` pair-atomic/ownership/fail-honest semantics: untouched —
  the fix only widens WHERE registries are looked up and HOW arguments are
  validated.
