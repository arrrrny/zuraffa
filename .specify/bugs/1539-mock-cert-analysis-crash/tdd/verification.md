# TDD verification — #1539 mock-cert analysis crash

**Date**: 2026-09-13
**Verdict**: GREEN — all 6 bug tests + all regression neighbors pass.

## Red evidence (pre-fix)

- `dart test test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart`
  → compile-red: `The getter 'analyzeUnverified' isn't defined for the
  type 'CertifyReport'` (the new gate contract does not exist on master).
- Dogfood (the issue): exit 1 + crash tail riding the fix line + the
  `(conforms)` receipt persisted in the same output.

## Green run (post-fix)

```
dart test test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart
→ 00:02 +6: All tests passed!
```

Mutation checks (each mutant killed by the named test):

| id | mutant | kills it |
| -- | ------ | -------- |
| M1 | remove the retry (`_isAnalyzerCrash` gate branch dropped) | U-1539-1 (calls==2 fails: 1) and U-1539-2 (calls==2) |
| M2 | drop `fixes.isEmpty` from the infra-classification guard (crash tolerates drift too) | U-1539-3 (passed must be false) |
| M3 | return `analyzeUnverified: null` on the infra path (silent pass) | U-1539-2 / U-1539-5 (disclosure asserted) |
| M4 | classify any non-zero crash-shaped output as infra WITHOUT the crash signature (signature check dropped) | U-1539-4 (real error must fail + not retry) |

## Regression run

```
dart test test/plugins/mock/mock_certify_gate_test.dart \
  test/plugins/mock/mock_verify_test.dart \
  test/plugins/mock/mock_certification_receipt_test.dart \
  test/plugins/mock/mock_command_exit_test.dart
→ 00:14 +20: All tests passed!
```

The #970 safe-failure contract (A6 drift refuses, U6 real analyzer
errors fail with fix lines) is intact.

## Notes

- FR-2's "exactly once" is pinned by call counting (U-1539-1/2/4).
- The disclosure names `zfa mock verify` as the re-proof path so the
  degraded verdict is actionable (asserted in U-1539-5).
