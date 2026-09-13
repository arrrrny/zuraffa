# Test: Bug #1495 — registry-owns-missing-file recovery

- **Suite**: `test/plugins/tdd/bug_1495_registry_owns_missing_file_test.dart`
  (CLI-surface, TddFixture + `CliRunner(exitOnCompletion: false)` — the
  bug_840 recovery-suite pattern) plus 4 registry unit tests in
  `test/plugins/tdd/services/artifact_registry_test.dart`.
- **Runner**: `dart test <file> --preset=all` (the `slow` tag tiers are
  excluded from the default fast preset; these suites are slow-tagged
  because they drive the real CLI against temp fixtures).

## Test list

See `tdd/test-list.md` (A-1495-a1…a3 acceptance, b1…b3 unit,
c1…c4 doctor integration, d1…d4 registry primitive, r1 regression).

## RED (pre-fix) — evidence: `red-evidence.txt`

Command:
`dart test test/plugins/tdd/bug_1495_registry_owns_missing_file_test.dart --preset=all`

Result: `00:08 +2 -9` — 9 failures, exactly the new behaviors:

| # | Test | RED observation |
|---|------|-----------------|
| 1 | owned-and-missing refusal names the repair command | output contains the circular "Run `zfa tdd gen <behavior-id>` after resolving the conflict." |
| 2 | exists-unowned refusal names `--adopt` | same circular text, no `--adopt` |
| 3 | `gen --repair` drops the stale record and regenerates | usage error: `Could not find an option named "--repair"` (exit 2) |
| 4 | `gen --repair` keeps a verified surviving half | (flag absent) |
| 5 | `gen --repair` on exists-unowned refuses naming `--adopt` | (flag absent) |
| 6 | `doctor --repair` GCs gone-file records, keeps healthy | usage error: `Could not find an option named "--repair"` (exit 2) |
| 7 | `doctor --repair` refuses a HALF-missing record | (flag absent) |
| 8 | doctor (no flag) fix line names the surgical repair | fix line says only `zfa tdd reset <feature>` |
| 9 | `doctor --repair` healthy no-op | (flag absent) |

The 2 passes are by design pre-fix: the flag-absence documentation test
(skipped at GREEN — superseded by the success tests, evidence lives in
`red-evidence.txt`) and the `--adopt` regression guard (must pass both
before AND after).

## GREEN (post-fix)

Same command: `00:11 +39 ~1` across the three suites run together
(10 bug-1495 + 29 artifact_registry incl. the 4 new dropRecords tests +
13 bug_1397 path-form tests… combined run, 1 intentional RED-only skip).
Individually:

- `bug_1495_registry_owns_missing_file_test.dart`: **+10 ~1 — All tests passed**
- `artifact_registry_test.dart`: **All tests passed** (25 + 4 new)
- `bug_1397_path_form_mismatch_test.dart`: **All tests passed**

Sample refusal (the remedy is no longer circular):

```
zfa tdd gen: ownership conflict — OwnershipConflict: the registry records
test file "…/b_001_test.dart", but it is missing from disk.
Owned-and-missing has nothing to clobber. Run
`zfa tdd gen <behavior-id> --repair` to drop the stale record and
regenerate, or `zfa tdd doctor <feature> --repair` to garbage-collect
every gone-file record. --> fix: zfa tdd gen B-001 --repair --feature 090-bug-1495
```

## Regression protocol (no new failures)

Baseline captured by `git stash`-ing this branch's changes and running the
same suites on the pristine tree:

| Suite | Pristine baseline | With fix | New failures |
|-------|-------------------|----------|--------------|
| `bug_840_recovery_commands_test.dart` | +4 -5 | +4 -5 | **0** |
| `bug_874_doctor_cross_feature_adoption_test.dart` | +7 -4 | +7 -4 | **0** |
| `bug_1397_path_form_mismatch_test.dart` | all pass | all pass | **0** |
| `artifact_registry_test.dart` | all pass | all pass | **0** |

The pre-existing 840/874 failures reproduce identically before and after
(environment-dependent fixtures on this host); they are unrelated to the
ownership-conflict paths this fix touches.

One #840 test was UPDATED deliberately (`doctor prescribes reset when the
registry records files missing from disk`): its record is fully gone, so
the prescription is now the surgical `zfa tdd doctor <feature> --repair`
— exactly the remedy issue #1495 demands (its `reset` alternative remains
prescribed for half-missing records, covered by A-1495-c2).

## Mutation spot-checks (manual, per behavior)

- Repair does NOT drop the record when the plain refusal fires (A-1495-a1
  asserts the record survives a flagless gen).
- Repair refuses (exit 1) and leaves the dropped-record state resolvable
  when a surviving half fails the generated-shape check.
- `dropRecords` is a no-op for unknown ids and never writes when nothing
  was dropped (no spurious registry rewrite).
- `doctor --repair` on a half-missing record drops NOTHING.
