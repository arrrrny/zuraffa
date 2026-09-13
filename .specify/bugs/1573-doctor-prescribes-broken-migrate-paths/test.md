# Bug Verification: doctor prescription + migrate-paths reachability for bug directories (#1573)

- **Slug**: 1573-doctor-prescribes-broken-migrate-paths
- **Tested**: 2026-09-13
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: ./tdd/verification.md

## Summary

The bug no longer reproduces. The doctor's prescription for every
migrate-paths branch is now the executable flag form with the canonical
feature reference, the prescribed command reaches the bug-directory
registry it was diagnosed from and heals it (`migrated=5` on the shipped
fixture, doctor returns healthy), unrecognized positional arguments are
rejected with exit 2 instead of silently sweeping the project, and the
path-form drift line shows the raw recorded value. All six new contract
behaviors ran RED pre-fix (`+0 -6`) and GREEN post-fix (`+6`), with the
affected pre-existing suites re-run green.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (pre-fix control) | `dart test test/plugins/tdd/commands/bug_1573_doctor_prescribes_broken_migrate_paths_test.dart` before the fix | fail (expected) | `+0 -6` — prescription form, reachability, pin resolution, positional rejection, sweep coverage, raw drift value all red |
| Live repro (pre-fix) | `dart run zuraffa:zfa tdd doctor .specify/bugs/cycle-log-phantom-sections` / `migrate-paths <slug>` / `migrate-paths --feature <slug>` on the unmodified tree | fail (expected) | positional prescription; `migrated=5 ... feature=all` sweep on the discarded slug; `migrated=0` on the flag form |
| New / updated tests | `dart test` on the 1573 file | pass | 6/6 post-fix |
| Prescription executes (live, dry-run) | `dart run zuraffa:zfa tdd migrate-paths --feature .specify/bugs/cycle-log-phantom-sections --dry-run` | pass | `migrated=5 refused=0 missing=0 feature=.specify/bugs/cycle-log-phantom-sections`; dry-run wrote nothing |
| Positional rejection (live) | `dart run zuraffa:zfa tdd migrate-paths cycle-log-phantom-sections --dry-run` | pass | `❌ Unexpected positional argument ...` + usage; raw exit code 2 (`ExitProtocol.usage`) |
| Doctor heal loop (live) | doctor → prescribe → migrate (dry-run for the record) → doctor | pass | prescription now names `--feature .specify/bugs/<slug>`; migrated=5 planned |
| Prescription-form regressions | `dart test` on 1397, 874, 840, 912 package-URI, 969, gen-namespacing-827, artifact-registry, `test/core/proof/` | pass | pinned `--> fix:` assertions updated to the flag form; all other assertions untouched |
| Static analysis | `dart analyze` on the three lib files + three test files | pass | No issues found |
| Format gate | `dart format --set-exit-if-changed` on changed files | pass | 0 files needed formatting (see output excerpts) |
| Full fast-tier regression | `tools/run_tests_chunked.sh` | pass | see `tdd/verification.md` front-matter for the exact chunk tally on this machine |

## Output Excerpts

```
RED (pre-fix):   00:13 +0 -6: Some tests failed.
GREEN (post-fix):00:04 +38: All tests passed.   # 6 affected suites together

LIVE doctor (post-fix):
 --> fix: zfa tdd migrate-paths --feature .specify/bugs/cycle-log-phantom-sections — rewrite the recorded forms to the portable project-relative POSIX form ...

LIVE prescription (post-fix, dry-run):
migrate-paths: migrated=5 refused=0 missing=0 feature=.specify/bugs/cycle-log-phantom-sections

LIVE positional rejection (post-fix):
❌ Unexpected positional argument "cycle-log-phantom-sections" — migrate-paths takes the feature as a flag: zfa tdd migrate-paths --feature <name>
raw exit=2
```
