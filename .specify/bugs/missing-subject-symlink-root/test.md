# Bug Verification: a MISSING subject file is not "outside the project root" on symlinked roots

- **Slug**: missing-subject-symlink-root
- **Tested**: 2026-09-13
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: ./tdd/verification.md (verdict: PASS)

## Summary

The issue's exact reproduction now passes: with the fix applied, a missing
subject file on a symlinked project root takes the missing-subject refusal
branch (exit 1) instead of "points outside the project root". Both the
original macOS red (U-V3) and the new cross-platform regression pin (U-V11)
are green; the genuine outside-root refusal (U-V12) is unchanged, and both
directions are mutation-killed. No regressions surfaced in the sibling view
surface (29/29).

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `dart test test/plugins/tdd/commands/view_command_test.dart -n 'U-V3'` (issue's exact repro) | pass | `00:04 +1: All tests passed!` — was red pre-fix with the issue's symptom |
| New / updated tests | `dart test test/plugins/tdd/commands/view_command_test.dart` | pass | `00:51 +12: All tests passed!` (U-V1..U-V12 incl. U-V11/U-V12) |
| RED evidence (pre-fix) | `dart test test/plugins/tdd/commands/view_command_test.dart -n "U-V1[12]"` (pre-fix tree) | pass (represents RED) | `+1 -1`: U-V11 failed with `points outside the project root`; U-V12 guard green — recorded in `tdd/cycle-log.md` |
| Mutation sample (M1) | identity canonicalization (`canonicalSubject = subjectPath;`) + `-n "U-V1[12]"` | killed | U-V11 fails (`does not contain 'missing subject file'`); reverted |
| Mutation sample (M3) | outside-root guard disabled (`if (false && …)`) + `-n "U-V1[12]"` | killed | U-V12 fails (`does not contain 'points outside the project root'`); reverted |
| Regression suite | `dart test` over `bug_1141_view_audit`, `bug_965_view_i18n_generation`, `bug_1141_login_ui_regeneration`, `spec_1142_adaptive_layout` | pass | `00:38 +29: All tests passed!` |
| Lint / type-check | `dart analyze lib/src/plugins/tdd/commands/view_command.dart test/plugins/tdd/commands/view_command_test.dart` | pass | `No issues found!` |
| Format | `dart format` on both changed files | pass | `Formatted 2 files (0 changed)` |

## Output Excerpts

Pre-fix (the bug), U-V11:

```
Expected: contains 'missing subject file'
  Actual: '...zfa tdd view: the registry record for behavior "A-001" points
   outside the project root at "lib/a_001_subject.dart"...'
   Which: does not contain 'missing subject file'
```

Post-fix (the issue's exact repro):

```
00:00 +0: U-V3: a missing subject file is a hard runner-error
00:04 +1: All tests passed!
```

Full file post-fix:

```
00:49 +12: All tests passed!
```

## Residual Risks

- The symlink regression pin (U-V11) uses a relative recorded subject path
  (the portable #1397 registry form). An *absolute* recorded subject that
  crosses the symlink boundary is not pinned — the sibling `wire` surface has
  the same property; behavior there is now canonicalized identically.
- No mutation tool is wired in this repo (`tdd-profile.md` Phase 4 fallback):
  the mutation evidence is two deliberate hand-applied mutants, both killed,
  not a full mutation score.

## Recommendation

Close the bug — verified end-to-end on the pre-fix-engineered regression
(U-V11, cross-platform deterministic), the original macOS red (U-V3), and
mutation kills in both directions (U-V11/U-V12). Open the PR linking
`Closes #1603`.
