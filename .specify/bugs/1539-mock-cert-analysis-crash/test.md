# Test: #1539 mock-cert analysis crash

- **Slug**: 1539-mock-cert-analysis-crash
- **Result**: verified
- **Date**: 2026-09-13

## Reproduction of the reported failure

The dogfood shape (crash output + persisted `(conforms)` receipt + exit
1) is pinned at gate level: pre-fix, a twice-crashing analyze produced
`passed: false` with the crash text riding a `--> fix:` line. The new
U-1539-2 flips that contract: `passed: true`, no fix line,
`analyzeUnverified` carrying the crash text.

## Runs

| Suite | Command | Result |
| ----- | ------- | ------ |
| New bug suite (RED pre-fix) | `dart test test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart` | 6/6 pass (post-fix); compile-red pre-fix |
| #970 gate contract | `dart test test/plugins/mock/mock_certify_gate_test.dart` | pass |
| spec 1121 verify | `dart test test/plugins/mock/mock_verify_test.dart` | pass |
| Receipt + exit protocol | `dart test test/plugins/mock/mock_certification_receipt_test.dart test/plugins/mock/mock_command_exit_test.dart` | pass |
| Static analysis of touched files | `dart analyze <touched>` | No issues |

Mutation kills are recorded in `tdd/verification.md` (M1–M4).

## Exit-code story after the fix

- structural drift → exit 1 (unchanged, crash or not)
- real `error -` diagnostics → exit 1 (unchanged, never retried)
- crash → clean retry → exit 0 (normal pass)
- crash twice, structurally clean → exit 0 + loud UNVERIFIED
  disclosure naming `zfa mock verify` (the #1539 fix)
