# Bug Verification: issue_891 regression test must assert the post-#1206 zero-overrides contract

- **Slug**: pr-1210-ci-red
- **Tested**: 2026-09-06
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: ./tdd/verification.md (gate verdict: PASS)

## Summary

The original symptom (issue_891 tests red on the post-#1206 tree) no longer
reproduces — the rewritten file passes 3/3, and deliberate mutants confirm the
new guards actually bite. Unrelated local flakes in `issue_1059_..._test.dart`
were bisect-proven pre-existing on pristine HEAD, not caused by the fix.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `dart test test/regression/issue_891_example_meta_resolution_test.dart` | pass | `+3: All tests passed!` — pre-fix RED was 3 failures matching master CI run 34027280435 |
| New / updated tests | same command, twice (incl. after `dart format`) | pass | stable green across format |
| Mutant sampling | re-add override; remove smoke gate | pass | both killed (A2, A3 red), restores verified green |
| Regression suite | `dart test test/regression/` | pass (with known env flakes) | `+12 -6`; all 6 in `issue_1059_entity_cli_bare_exit_code_test.dart`, subprocess timeouts |
| Flake attribution | stash fix → run 1059 on pristine HEAD `350e2d8e` | pass (pre-existing) | same failure signature without the fix; CI passes these tests on the same commit |
| Lint / type-check | `dart analyze <file>` + `dart format` | pass | No issues found; formatted |

## Output Excerpts

```
RED  (pre-fix):  00:00 +0 -3: Some tests failed.   # 3× issue_891, matches CI
GREEN(post-fix): 00:00 +3: All tests passed!
Mutant A2:       00:00 +0 -1: ...ZERO dependency_overrides... [E]   → killed
Mutant A3:       00:00 +0 -1: ...delegated to tools/flutter_smoke_gate.sh [E] → killed
Suite:           08:05 +12 -6: Some tests failed.  # all 6 = issue_1059 timeouts (pre-existing)
```

## Residual Risks

- The 6 `issue_1059` timeouts are local-environment (cold zfa subprocess start
  >75s under load). They fail identically on pristine HEAD and pass in CI on
  the same commit; no action in this fix. If they recur on loaded machines, a
  warmer-up or a CI-parity timeout is a separate chore.
- `zfa tdd plan/run/verify` cannot address `.specify/bugs/` feature dirs
  (hardwired to `specs/`); this cycle ran the LLM-guided fallback end-to-end.
  Worth a zfa extension gap issue.

## Recommendation

Close the bug — verified end-to-end on the fix branch. Ship via
`/skill:speckit-bug-pr slug=pr-1210-ci-red`; PR #1210 still needs its own
receipt-fixture fix + rebase (out of this issue's scope by design).
