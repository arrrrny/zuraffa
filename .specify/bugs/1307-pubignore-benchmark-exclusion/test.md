# Bug Verification: Published package 6.2.0/6.2.1 broken — anchor .pubignore benchmark/ to root; add publish-time export guard

- **Slug**: 1307-pubignore-benchmark-exclusion
- **Tested**: 2026-09-08T13:12:00Z
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: ./tdd/verification.md (PASS)

## Summary

The bug no longer reproduces: after anchoring the `.pubignore` patterns, the
exported `lib/src/core/benchmark/` sources are present in the would-publish
set, `dart pub publish --dry-run` shows them in the tarball tree, and the
new publish-time export guard proves it continuously (RED pre-fix → GREEN
post-fix → mutant killed). No regressions surfaced in the scoped checks.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `dart test test/pubignore_export_guard_test.dart` (rebuilds publish set from `.pubignore`) | pass | 3/3 — the automated equivalent of the day-zero scaffold compile check for the published file set |
| Reproduction (pre-fix control) | same command against unmodified `.pubignore` | fail (expected) | exactly the 8 exported benchmark targets missing — RED proof |
| New / updated tests | `dart test test/pubignore_export_guard_test.dart` | pass | 3/3 behaviors, ~1s, scoped per cloud-agent rules |
| Publish gate | `dart pub publish --dry-run` | pass | tarball tree contains `lib/src/core/benchmark/` + `lib/src/plugins/benchmark/`; 4 warnings + 1 hint all pre-existing layout advisories, unrelated to 1307 |
| Mutation sample | reintroduce unanchored `benchmark/` → run → restore | pass | mutant killed (suite RED), restoration verified byte-identical diff |
| Static analysis | `dart analyze test/pubignore_export_guard_test.dart` | pass | No issues found |
| Format gate | `dart format` (file-scoped check) | pass | 0 changed for the new test; repo-wide run touched only pre-existing drift files (left untouched, see fix.md follow-ups) |
| Regression suite (full) | — | skipped | cloud-agent constraint: full suite compiles a ~6.5 GB kernel cache (dart_test.yaml itself warns against it here); no `lib/` source changed (tracked diff = `.pubignore` only), so no lib test surface is affected |
| Scope audit | `git diff --stat` | pass | tracked diff = `.pubignore` (13+/8-); sole new file = guard test + bug records |

## Output Excerpts

```
RED (pre-fix):  00:00 +0 -3: Some tests failed.
                'lib/zuraffa.dart: export 'src/core/benchmark/benchmark_contract.dart'
                 -> lib/src/core/benchmark/benchmark_contract.dart (on disk: yes)'
GREEN (post-fix): 00:00 +3: All tests passed!
MUTANT: killed (RED under unanchored benchmark/, GREEN after restore)
```

## Residual Risks

- The guard mirrors pub's gitignore semantics for the constructs this
  `.pubignore` uses (name/anchored/`*`/`**`/`!`); exotic constructs (e.g.
  character classes) would fall to `dart pub publish --dry-run`, which
  remains the authoritative gate and was exercised here.
- pub.dev still serves the broken 6.2.0/6.2.1 tarballs until a maintainer
  republishes 6.2.2 after merge (out of scope per the bug record).
- Full suite not run (cloud-agent disk constraint, documented above).

## Recommendation

Close the bug once the PR merges and 6.2.2 is republished — the fix is
verified end-to-end against the would-publish set and corroborated by
`dart pub publish --dry-run`.
