# Bug Verification: tdd engine lane certifies vacuous greens — unit subjects ship as `return 0;` dummies with result=complete

- **Slug**: 1651-vacuous-green-unit-dummies
- **Tested**: 2026-09-15
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: ./tdd/verification.md (verdict **PASS**)

## Summary

The bug's exact repro (gen → verify-red → func → make on a scalar-declared
contract) now refuses with `outcome=vacuous-green` instead of certifying a
dummy-body green; legacy marker-less type-only tests are refused by the
detector backstop; the vacuous-family suites stay green. No regressions
found; the only repair beyond the fix is a pre-existing slow-tier helper
breakage in bug_1259 documented in fix.md (Deviations).

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `dart test test/plugins/tdd/commands/bug_1651_make_dummy_green_refusal_test.dart` | pass | the issue's exact flow; make exits 1, `outcome=vacuous-green`, no green evidence appended |
| New tests | `dart test test/plugins/tdd/bug_1651_type_only_vacuous_green_test.dart` | pass | 9/9 (detector vacuity + guard rails + writer marker) |
| RED evidence (pre-fix) | same two files against the unfixed tree | fail (by design) | `+5 -4` and the marker-absent gen output — `red-evidence.md` |
| Vacuous-family regression (fast) | 1483 shape, 1308, 1626, 1512, arg_placeholder, behavior_test_writer, 1320, 1388, 1323 seam | pass | `+46: All tests passed!` |
| Vacuous-family regression (slow/e2e) | 1259, 1538, 1310, 1411 (`--preset=all`, scoped to files) | pass | `+33: All tests passed!` |
| Untagged driver suites | 1483 driver, 1308 driver, 1626 driver, 1323 driver, 1652 | pass | all passed |
| Mutation probes | strip removed; comment constant swapped | killed, killed | `tdd/verification.md` §4 |
| Lint / type-check | `dart analyze` on all touched lib + test files | pass | No issues found |
| Full default suite | `dart test test` | skipped | surgical contract / AGENTS.md disk guidance — CI fast lane covers it |

## Output Excerpts

```
00:00 +9: All tests passed!                                  (fast pins)
01:26 +1: All tests passed!                                  (e2e repro)
00:11 +46: All tests passed!                                 (fast family)
02:38 +33: All tests passed!                                 (slow/e2e family)
-- red, pre-fix:
   Which: does not contain 'zfa:tdd: vacuous-guard'
   ...expect(result, isA<int>());   ← gen's verbatim emission
```

## Residual Risks

- Issue ask 1 (mechanically deriving scenario-value unit assertions) is a
  follow-up feature — until it lands, the unit lane stops at the designed
  hand step for scalar contracts (the author writes the value assertion
  from the spec's scenario), rather than auto-generating it.
- Other slow-tier suites may carry the same #1574 CWD-relative-record
  drift found in bug_1259 (pre-existing, not touched here).

## Recommendation

Close the bug — verified end-to-end (red→green with evidence, family
stable, targeted mutants killed, TDD audit PASS).
