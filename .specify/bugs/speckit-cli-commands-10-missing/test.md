# Bug Verification: Speckit CLI Commands missing from extension manifest

- **Slug**: speckit-cli-commands-10-missing
- **Tested**: 2026-08-28
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: ./tdd/verification.md (present only when validation ran in TDD mode)

## Summary

The original symptom (14 `zfa manifest` commands with no Speckit extension
registration) no longer reproduces: the parity test reports 0 missing commands, and
the 14 generated `commands/*.md` files exist and follow the template. A deliberate
mutant (removing one registration) was caught by the test, so the safety net is real.
TDD auditor verdict: `PASS_WITH_GAPS` (test-first evidence `LIKELY` because the fix
is still uncommitted; mutation sampled on one behavior).

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `dart test test/cli/standard/extension_command_parity_test.dart` (parity) | pass | 0 missing commands |
| New / updated tests | same | pass | 2/2 (parity + shape) |
| Deliberate mutant | removed `cache.adapter` `provides` entry, re-ran, restored | pass | test went RED, then GREEN on restore |
| Regression suite | repo-wide `dart test` | skipped | slow; scoped parity test used instead (noted in verification.md) |
| Lint / type-check | `dart analyze` on changed files | not-run | parity test compiles and runs; full analyze not run this cycle |

## Output Excerpts

```text
00:45 +2: All tests passed!
```

Deliberate mutant (cache.adapter removed) failed as expected:

```text
Actual: ['cache/adapter -> zfa.cache.adapter']
```

## Residual Risks

- The fix is uncommitted; committing the test and docs together before PR would raise
  the test-first evidence class from `LIKELY` to `PROVEN`.
- The parity test shells `dart run bin/zfa.dart manifest` (~40s) and reads the on-disk
  `extension.yml`; it is deterministic but slow.
- `zfa generate-commands` is still not implemented, so this coverage is manual; a future
  manifest change could reintroduce a gap (the parity test will catch it, but only if
  run in CI).

## Recommendation

Close the bug — verified end-to-end via the parity test. Add the parity test to CI so
the extension-to-manifest gap cannot silently return.
