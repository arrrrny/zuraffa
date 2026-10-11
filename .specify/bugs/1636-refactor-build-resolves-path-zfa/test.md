# Bug Verification: the refactor build pass resolves the PATH-installed zfa instead of the driving binary

- **Slug**: 1636-refactor-build-resolves-path-zfa
- **Tested**: 2026-09-15T15:25:00+00:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: ../tdd/verification.md

## Summary

The bug reproduced at the tier level pre-fix (the resolver returned the
PATH install for a compiled driving binary — B1/B2 red), and the fix held
post-fix (the running binary wins — B1/B2 green) with zero regressions
across 1145 tests in the affected suites and zero analyzer findings on the
changed files.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (pre-fix) | `dart test test/plugins/tdd/services/bug_1636_running_binary_tier_test.dart` | pass (red) | `+3 -2` — B1/B2 resolved the PATH fixture, the issue's exact bug; verbatim in ./red-evidence.md |
| Reproduction (post-fix) | same command | pass | `+5: All tests passed!` — the running binary wins for the cache-exe driver |
| New / updated tests | `dart test test/plugins/tdd/services/` | pass | `01:42 +1104: All tests passed!` — includes the #690 group re-labels, #1371, #689/#717 build-pass suites |
| Version-pin contract (#1472) | `dart test test/plugins/tdd/bug_1472_refactor_gate_acceptance_test.dart test/plugins/tdd/bug_1472_refactor_gate_errors_only_test.dart` | pass | `+18` — pin unchanged: equal versions keep, provably-different swap, unresolvable fail open |
| Runner-adjacent regressions | `dart test test/utils/dart_toolchain_resolver_test.dart test/plugins/tdd/bug_1329_step_failure_diagnostics_test.dart test/plugins/tdd/bug_1159_baseline_timeout_test.dart` | pass | `+18` |
| No-JIT sweep | `dart test test/core/no_jit_zfa_spawn_scan_test.dart` | pass | `+5` — the promoted tier returns a compiled binary, never a VM spawn |
| Lint / type-check | `dart analyze <changed files>` then `dart format <changed files>` | pass | No issues found!; format reported `0 changed` |
| Whole-repo baseline | `dart analyze` | pass (pre-existing) | 106 issues, 0 errors / 0 warnings — info-level baseline drift, not this change |

## Output Excerpts

```
00:00 +3 -2: Some tests failed.                      ← RED, pre-fix
  B1 Expected: '/tmp/zfa1636_cacheNSSXIE/zfa_exe'
     Actual:   '/tmp/zfa1636_pathLAZCWU/zfa'
00:00 +5: All tests passed!                          ← GREEN, post-fix
01:42 +1104: All tests passed!                       ← services scope
00:00 +18: All tests passed!                         ← #1472 gate suites
```

## Residual Risks

- The compiled-driver fix is proven at the `StepRunner.resolveEntrypoint`
  tier level plus the delegation doc trail, not by spawning a real
  compiled binary through a full refactor run (the repo's fast-tier
  convention; a real end-to-end would pay a full AOT compile per CI run).
- `PipelineRunner._resolveEntrypoint` (the #665 chain used by
  `tdd make`/`gen` spawns) retains the PATH-before-running-binary order;
  out of scope per the issue's hard constraint (fix the named
  entrypoint resolution only, one PR per bug). Logged in fix.md
  Follow-ups.
- The one-attempt whole-scope run (`test/plugins/tdd/ --exclude-tags
  "flutter || e2e"`) was abandoned after its kernel cache filled the
  filesystem (tool-ceiling kill at 10 minutes); the affected suites were
  re-run chunked, green. Unrelated heavyweight suites were not run in
  this session.

## Recommendation

Close the bug — the fix is verified at every level this session could
honestly reach: red→green on the repro, 1145 green regression tests, the
pin contract intact, analyzer-clean changed files. Merge via the PR that
closes #1636; consider filing the PipelineRunner ordering as a follow-up
issue.
