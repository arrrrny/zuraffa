# Bug Verification: zfa tdd plan consumes the zuraffa-1.0 template's declared structures

- **Slug**: tdd-120-template-structures
- **Tested**: 2026-09-03
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: ./tdd/verification.md (PASS_WITH_GAPS)

## Summary

The bug's symptom — table-authored zuraffa-1.0 specs driving `zfa tdd plan`
with no phase-0 entities, no declared dependencies/layer contracts in the
artifact, no version pin, and no undeclared-dependency lint — no longer
reproduces. All 14 behaviors close, the full scoped suite is green (731
passed, 1 skipped), the analyzer is clean, and 4 deliberate mutants were
caught. Plan-side scope is complete; make-side consumption remains #909's
territory (recorded out of scope).

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `dart test test/plugins/tdd/bug_919_template_structures_test.dart` (14 behaviors, CLI-level) | pass | The exact issue scenarios: table entities → artifact → phase-0 seam; version gate exit 3; deps/contracts in artifact; lint exit 2 |
| New / updated tests | `dart test test/plugins/tdd/services/bug_919_reader_test.dart` | pass | Reader round-trip; pre-919 artifacts → empty lists |
| Reader regression | `dart test test/plugins/tdd/services/test_list_reader_test.dart` | pass | Existing reader suite unchanged/green |
| Fixture regression | `dart test test/plugins/tdd/bug_846_coverage_gate_test.dart test/plugins/tdd/bug_830_widget_subject_kind_test.dart test/plugins/tdd/commands/plan_gen_contract_test.dart test/plugins/tdd/commands/plan_persistence_marking_833_test.dart` | pass | 38 tests green after marker/Hive fixture updates |
| Regression suite | `dart test test/plugins/tdd/` | pass | 731 passed, 1 skipped, 0 failed (3m31s) |
| Lint / type-check | `dart analyze` on all 6 touched files | pass | No issues |
| Test strength | 4 deliberate mutants (A1, A3, A6, A12) | pass | All caught; restored + suite re-verified green |

## Output Excerpts

- `dart test test/plugins/tdd/` -> `03:31 +731 ~1: All tests passed!`
- `dart analyze ...` -> `No issues found!`
- Audit verdict line: `tdd/verification.md` -> `PASS_WITH_GAPS` (9 PROVEN, 5 control/characterization, 0 HIGH smells, 12/12 criteria covered)

## Residual Risks

- Issue acceptance criteria 2/3's make-side half ("make's mock path consumes
  the dependencies table", "generated repository matches layer-contract
  signatures") is NOT verified here — #909 is still OPEN; the declarations
  land in the plan artifact and read back, which is the agreed plan-side scope.
- The bug's acceptance says `zfa tdd plan` "announces phase-0 entity ...
  created" — creation actually runs in `zfa tdd run` phase-0 (existing,
  tested); plan extracts into the artifact the run consumes. Verified at the
  artifact/reader seam (A3), not by spawning a full run subprocess.
- `verify_red_subdirectory_test.dart` (bug #679) passed on the final run but
  has a known-fragile 75s child-timeout under machine load (environmental,
  reproduced on a clean tree mid-session).
- One MED finding deferred: A14's CLI test is eager (two artifact sections in
  one test) — remediation task T021.
- Strict version gate is a behavior change for legacy specs: they must carry
  the marker to plan. Test fixtures were updated; other repos using zfa
  (`~/zik_zak_test`, specs in this repo) need the marker on their next plan.

## Recommendation

Close the bug (plan-side) — verified end-to-end through the real CLI entry
point with recorded red-green evidence and mutant validation. The deferred
make-side work is #909, not a defect of this fix. Proceed to `/skill:speckit-bug-pr`.