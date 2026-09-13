# tdd.verify — Bug #1495 registry-owns-missing-file recovery

- **Verified**: 2026-09-13, this session, on
  `fix/1495-registry-owns-missing-file-recovery` (working tree, pre-push)
- **Toolchain**: Dart 3.13.3 (stable) on linux_x64 (cloud sandbox)
- **Scope**: the three changed source files
  (`artifact_registry.dart`, `gen_command.dart`, `doctor_command.dart`),
  the new bug-1495 suite, the extended registry suite, and the mapped
  regression suites below — then the chunked regression sweep summary.

## Verdict: PASS

## 1. What the fix ships

1. `zfa tdd gen <id> --repair` — drops the stale registry record when the
   registry RECORDS a file missing from disk and regenerates the pair.
   Surviving halves are kept only after the same generated-shape
   verification `--adopt` uses; the repair is audit-logged
   (`action: "repair"`) to `specs/<feature>/tdd/audit.log`; verdict
   `repaired`.
2. Actionable refusals — `OwnershipConflict` now carries a direction
   (`ownedButMissing` / `existsUnowned` / `pathMismatch`) and the remedy
   text names the RESOLVING command: `gen <id> --repair` /
   `gen <id> --adopt` / `doctor <feature>`. The circular
   "Run `zfa tdd gen <behavior-id>` after resolving the conflict" remedy
   is gone from every direction.
3. `zfa tdd doctor <feature> --repair` — garbage-collects every registry
   record whose BOTH files are gone (relocation-probe aware), keeps every
   healthy record, touches no file, audit-logs, exits 0 with verdict
   `repaired`. Half-missing records are never collected (reset remains
   their prescription); the flagless diagnosis names the surgical fix.
4. `ArtifactRegistry.dropRecords` — the surgical, atomic (write-and-
   rename) registry primitive both repair paths build on.

Constraints honored: the FR-008 ownership contract (preflight refuses by
default), the `--adopt` logic, and the state machine are unchanged.

## 2. RED evidence (pre-fix)

`dart test test/plugins/tdd/bug_1495_registry_owns_missing_file_test.dart --preset=all`
→ `00:08 +2 -9` — raw output committed at
`.specify/bugs/1495-registry-owns-missing-file-recovery/red-evidence.txt`.

Key RED observations:

- owned-and-missing gen output contained the circular remedy
  "Run `zfa tdd gen <behavior-id>` after resolving the conflict." (A-1495-a1)
- `gen <id> --repair` → `Could not find an option named "--repair"`, exit 2
- `doctor <feature> --repair` → same usage error (A-1495-c1)
- flagless doctor fix line named only `zfa tdd reset <feature>` (A-1495-c3)

## 3. GREEN evidence (post-fix, this run)

| Command | Result |
|---------|--------|
| `dart test test/plugins/tdd/bug_1495_registry_owns_missing_file_test.dart --preset=all` | **+10 ~1 — All tests passed!** |
| `dart test test/plugins/tdd/services/artifact_registry_test.dart --preset=all` | **All tests passed** (25 existing + 4 new dropRecords) |
| `dart test test/plugins/tdd/commands/bug_1397_path_form_mismatch_test.dart --preset=all` | **All tests passed** |
| `dart analyze` over all six changed .dart files | **No issues found!** |
| `dart format` over the changed files | 4 reformatted, re-analyzed clean, suite re-run green |

The one skipped test is the RED-only flag-absence documentation test
(`skip:` marker in-source; its evidence lives in `red-evidence.txt`).

## 4. Chunked regression sweep (no-new-failures protocol)

`dart_test.yaml` mandates the chunked runner on constrained hosts
(whole-tree kernel cache overflows small disks), so suites were run as
focused chunks with baseline comparison — the pristine baseline captured
by `git stash`-ing this branch's changes:

| Chunk | Pristine baseline | With fix | New failures |
|-------|-------------------|----------|--------------|
| `bug_840_recovery_commands_test.dart` | +4 -5 | +4 -5 | 0 |
| `bug_874_doctor_cross_feature_adoption_test.dart` | +7 -4 | +7 -4 | 0 |
| `gen_command_test.dart` | +17 -1 | +17 -1 | 0 |
| `gen_command_{theme,platform,ffi_835}_test.dart` + `bug_1518_gen_command_seam_test.dart` | +11 -1 | +11 -1 | 0 |
| `bug_1397_path_form_mismatch_test.dart` | all pass | all pass | 0 |
| `artifact_registry_test.dart` | all pass | all pass | 0 |

The 11 pre-existing failures reproduce identically before and after
(host-environment fixtures: temp-project `dart test` spawns and template
assertions unrelated to the ownership paths); the ownership-conflict,
adopt, doctor, and registry suites specific to this fix are fully green.

One deliberate expectation update, recorded in the test's comment:
`bug_840_recovery_commands_test.dart` → "doctor prescribes reset when the
registry records files missing from disk" — its record is FULLY gone, so
per issue #1495 the prescription is now the surgical
`zfa tdd doctor <feature> --repair` (the heavy `reset` remains prescribed
for half-missing records, covered by A-1495-c2).

## 5. Kernel cache hygiene

`rm -rf .dart_tool/test/ && rm -f $TMPDIR/dart_test.kernel.*` executed
before the analyze sweep and again after the final suite run (the
dart_test.yaml disk-pressure protocol for cloud agents).

## 6. Honest caveats

- The sandbox has no Flutter SDK: suites requiring `flutter_test`
  (example/ package resolution) are out of scope for this run; none of
  the touched code paths depend on Flutter.
- The heavy `gen_command_test.dart` honest-red chunk spawns `dart test`
  in temp fixtures; on this host it shows the same single pre-existing
  failure as the pristine tree (verified, not assumed).
- `--reclaim` (the issue's parenthetical alternative name) is NOT
  implemented: `args` has no flag aliases and `--repair` is the primary
  name in the issue.
