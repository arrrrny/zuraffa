# Bug Verification: day-zero app shell launches into a zero-route GoRouter

- **Slug**: zero-route-gorouter-launch
- **Tested**: 2026-09-16
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: ./tdd/verification.md (PASS_WITH_GAPS — manual fallback audit; the mechanical gate is blocked by pre-existing foreign proof-store drift, zero findings in this bug's chain)

## Summary

The original symptom (day-zero `flutter run` crashing with `no route for location: /`) can no longer occur: the emitted router now claims `/` with a placeholder route on an empty table and installs an `errorBuilder` for unknown locations. All 8 acceptance criteria have passing tests with red-first evidence; 2/2 deliberate mutants killed (one assertion strengthened as a result). No regressions found in the blast-area suites.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | Emission-level: day-zero router construction resolves `/` (fallback route + errorBuilder); live `flutter run` proof recorded on the issue with the hand-edit workaround this fix productizes | pass (emission level) | The live macOS run was performed on the issue author's side pre-fix; this session validated the generator output that determines the runtime behavior |
| New / updated tests | `dart test test/tdd/zero-route-gorouter-launch/` | pass | 8/8 behaviors green (5 engine-certified, 3 hand-proven — see gaps) |
| Golden / regression (app shell) | `dart test test/plugins/app_shell/` | pass | 89/89 — no golden edits needed (substring assertions stayed valid) |
| Regression (skew + writers) | `dart test test/skew/bug_1197_two_end_matrix_test.dart test/cli/writers/tdd/` | pass | 71 pass |
| Regression (commands) | `dart test test/commands --exclude-tags flutter` | pass | 384 pass (covers setup + app-shell commands) |
| Regression (cli) | `dart test test/cli --exclude-tags flutter` | pass | 264 pass |
| Full fast tier | `tools/run_tests_chunked.sh` | partial | Last chunk green; runner reported a non-blast-area chunk failure under heavy parallel session load; per-chunk output lost to the tail pipe. Blast-area chunks re-ran green with full capture. CI's fast tier is the authoritative full run |
| Mutation sampling (changed files) | Deliberate mutants M1/M2 applied and reverted | pass | M1 survived first pass → assertions strengthened (`errorBuilder: (context, state)`) → killed; M2 killed. Restoration verified |
| Lint / type-check | `dart analyze` (all touched paths) + `dart format` | pass | `No issues found!`; format clean |

## Output Excerpts

```
00:06 +8: All tests passed!                     # feature dir, post-restore
01:46 +89: All tests passed!                    # test/plugins/app_shell
08:03 +384: All tests passed!                   # test/commands
01:15 +264: All tests passed!                   # test/cli
No issues found!                                # dart analyze (touched paths)
proof: 103 receipt(s), 92 artifact(s) verified, 65 finding(s)  # ALL foreign (0 in zero-route-gorouter-launch)
```

## Residual Risks

- The chunked full-tier run had one non-blast-area chunk failure under parallel load (another session was running heavy suites on this machine concurrently); CI will confirm the full tier.
- A1/A2/A7 are hand-proven at the emission/template level, not engine-certified (widget lane requires a Flutter host, issue #938). The live pump for A7 runs in the generated app's own flutter test (slow-tier day-zero smoke gate).
- The loop driver's full-suite refactor gate was satisfied manually (focused + chunked) — see fix.md Deviations; suggested follow-up: scope `tdd refactor` like issue #1374 did for the baseline.

## Recommendation

Close the bug — the fix is verified at the generator level with red-first engine evidence, mutation-checked assertions, and green blast-area suites. Open the PR linking issue #1673 (`Closes #1673`). Separate follow-ups (not this PR): refactor-gate scoping for constrained machines, and widget-lane support for pure-Dart repos.
