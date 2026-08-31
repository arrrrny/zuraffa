# Bug Verification: Misfire: zfa cannot rewrite the zikzak_inappwebview WebView plugin

- **Slug**: zfa-cannot-rewrite-inappwebview
- **Tested**: 2026-08-31
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified (documentation/expectations fix; no code change)
- **TDD verification**: ./tdd/verification.md (from the real run in this session)

## Summary

The reported symptom is expected `zfa` behavior (the plugin is not a Zuraffa
app), so the fix targets the expectations gap the misfire exposed: the
user-facing docs never stated `zfa`'s scope. Post-fix, `CLI_GUIDE.md` and
`README.md` carry an explicit scope statement, and the new doc-contract
regression test pins every clause of it (red before the doc change, green
after). A deliberate mutant (removing the scope sentence from the guide)
flips the test red, so the safety net is real.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (RED) | `dart test --preset=regression test/regression/issue_477_zfa_scope_docs_test.dart` before doc change | fail 5/5 | matcher misses on every scope clause — the right reason |
| Post-fix (GREEN) | same command after doc change | pass 5/5 | `00:00 +5: All tests passed!` |
| Neighbor doc contract | `dart test --preset=regression test/regression/docs_command_consistency_test.dart` | pass 8/8 | doc edits regress nothing |
| Deliberate mutant | removed the scope sentence from `CLI_GUIDE.md`, re-ran, restored | pass | test went RED, then GREEN on restore |
| Static analysis | `dart analyze` | pass | No issues found! |
| Formatter | `dart format .` then re-run | pass | 0 remaining diffs |
| Fast suite (chunked) | per-chunk commands of `tools/run_tests_chunked.sh`, resumable | pass | 59/59 executed chunks green; 5 all-slow folders exit 79 "No tests ran" — pre-existing at baseline, unrelated |

## Output Excerpts

```text
00:00 +5: All tests passed!          (issue_477_zfa_scope_docs_test.dart)
00:00 +8: All tests passed!          (docs_command_consistency_test.dart)
```

Deliberate mutant (scope sentence removed from CLI_GUIDE.md) failed as
expected:

```text
Expected: contains 'does not rewrite existing non-Zuraffa'
  Which: does not contain 'does not rewrite existing non-Zuraffa'
```

## Residual Risks

- The 5 "No tests ran" chunk quirks (`test/benchmark`,
  `test/core/dependencies`, `test/integration`, `test/plugins/tdd/scenarios`,
  `test/property`) pre-date this change and also occur on a stashed clean
  tree; fixing the chunked runner's tag handling is out of scope for this
  one-bug PR.
- The scope contract is pinned by string containment; a future rewording of
  the docs must keep the five pinned phrases or update the test — by design,
  that is the guard.

## Recommendation

Close #477 as a documented expectation: `zfa` operates on Zuraffa apps by
design; a command that rewrites non-Zuraffa Flutter packages, if wanted, is
a separate feature request.
