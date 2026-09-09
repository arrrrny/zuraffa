# TDD Test List — gen-path-form-mismatch (#1397)

Bug: https://github.com/arrrrny/zuraffa/issues/1397 — `zfa tdd gen` refuses to
re-generate a behavior with an ownership conflict when the registry records
the same artifact paths in mixed forms (machine-absolute for some rows,
project-relative for others), while `zfa tdd doctor` reports the mixed-form
registry healthy and offers no remedy.

Target under test: the TDD plugin's registry/ownership gate, doctor drift
checks, and migrate-paths migration surface
(`lib/src/plugins/tdd/services/artifact_registry.dart`,
`lib/src/plugins/tdd/commands/doctor_command.dart`,
`lib/src/plugins/tdd/commands/migrate_paths_command.dart`,
`lib/src/plugins/tdd/commands/reset_command.dart`).

| ID | Behavior | Tier | Kind |
|----|----------|------|------|
| A1 | preflight reuses a prior project-relative record when the caller offers the machine-absolute form of the same files (and the inverse mix) — the ownership gate resolves both sides against the project root, never compares string forms | fast | unit (registry) |
| A2 | the registry persists records in the portable project-relative POSIX form: no machine-specific absolute path survives a write, and the runnable name's path segment is rebuilt with the persisted form while the id/description segments stay verbatim | fast | unit (registry) |
| A3 | normalization never merges distinct ownership boundaries: records resolving to different files still conflict | fast | unit (registry) |
| A4 | a repeat gen of a behavior recorded in the portable relative form succeeds (`reused/reused`) instead of refusing an ownership conflict | slow | unit (CLI surface) |
| A5 | doctor flags machine-absolute recorded paths as drift (verdict `drift`, prescription `migrate`, fix `zfa tdd migrate-paths <feature>`), and the prescribed migration repairs the drift (doctor returns healthy) | slow | unit (CLI surface) |
| A6 | migrate-paths rewrites the recorded FORM (absolute → project-relative POSIX) of already-namespaced records without moving any file; dry-run writes nothing; a recorded artifact missing from disk is reported and left unchanged; re-runs rewrite nothing | slow | unit (CLI surface) |

Acceptance criteria (from the issue's reproduction): after the fix, re-gen of
the mixed-form fixture's relative-recorded behavior reuses instead of
refusing; doctor reports the path-form drift with a working prescription; the
committed `example/specs/004-login-ui/tdd/artifacts.json` fixture carries only
portable project-relative paths.
