# TDD verification — #1539 mock-cert analysis crash

**Date**: 2026-09-13
**Verdict**: GREEN — all 11 bug tests + all regression neighbors pass.

## Red evidence (pre-fix)

- `dart test test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart`
  → compile-red: `The getter 'analyzeUnverified' isn't defined for the
  type 'CertifyReport'` (the new gate contract does not exist on master).
- Dogfood (the issue): exit 1 + crash tail riding the fix line + the
  `(conforms)` receipt persisted in the same output.

## Green run (post-fix)

```
dart test test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart
→ 00:05 +11: All tests passed!
```

Mutation checks (each mutant killed by the named test):

| id | mutant | kills it |
| -- | ------ | -------- |
| M1 | remove the retry (`_isAnalyzerCrash` gate branch dropped) | U-1539-1 (calls==2 fails: 1) and U-1539-2 (calls==2) |
| M2 | drop `fixes.isEmpty` from the infra-classification guard (crash tolerates drift too) | U-1539-3 (passed must be false) |
| M3 | return `analyzeUnverified: null` on the infra path (silent pass) | U-1539-2 / U-1539-5 (disclosure asserted) |
| M4 | classify any non-zero crash-shaped output as infra WITHOUT the crash signature (signature check dropped) | U-1539-4 (real error must fail + not retry) |
| M5 | widen `_isAnalyzerCrash` to every non-zero exit (drop the `analysis server` + `crash`/`shut down` match) | U-1539-4c (unrecognized output must fail, never pass on the structural proof) |
| M6 | drop `fixes.isEmpty` from the RETRY gate (retry even when drift already fails the gate) | U-1539-3 (calls==1) |

## Review-fix round — PR #1616 (2026-09-13)

Six findings from the automated review of the PR itself; all six were
still valid against head `29f2266e` (none stale). Fixes:

| # | finding | fix |
| -- | ------- | --- |
| 1 | `mock create --certify --json` reported a clean pass with no `analyzeUnverified` | `_buildEnvelope` takes `analyzeUnverified` and emits it in `details` (null-aware element, so the plain-generation key set is unchanged); pinned by U-1539-7 |
| 2 | the retry fired even when structural drift already failed the gate | retry gated on `fixes.isEmpty` (`mock_certification.dart`); pinned by U-1539-3 |
| 3 | `_isAnalyzerCrash` pinned to two verbatim SDK strings | case-insensitive match on the stable part (`analysis server` + `crash`/`shut down`), unrecognized output still fails safe; pinned by U-1539-4c/4d |
| 4 | "receipt persisted" claimed even when the best-effort receipt write failed | the clause now reports the write that happened (`receipt persisted` / `receipt NOT written`); pinned by U-1539-8 |
| 5 | the crash → real-`error -` retry interaction was untested | U-1539-4b (2 calls, gate fails with fix lines, `analyzeUnverified` null) |
| 6 | the disclosure text was duplicated across the two commands and had already drifted | one shared `analyzeUnverifiedNotice()` in `mock_certification.dart`, used by both; pinned by U-1539-8 |

Evidence after the round:

```
dart analyze lib/src/commands/mock_command.dart \
  lib/src/commands/mock_verify_command.dart \
  lib/src/plugins/mock/services/mock_certification.dart \
  test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart
→ No issues found!

dart test test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart \
  test/plugins/mock/mock_certify_gate_test.dart \
  test/plugins/mock/mock_json_output_test.dart \
  test/plugins/mock/mock_verify_test.dart
→ 00:32 +29: All tests passed!

dart format lib test → 0 changed (pub get --no-example first, per AGENTS.md)
```

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
