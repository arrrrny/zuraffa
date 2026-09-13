# TDD test list — #1539 mock-cert analysis crash (infra, not drift)

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| U-1539-1 | test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart | unit | a crash retried clean passes with NO fix line and exactly 2 analyze calls (initial + one retry) | FR-1, FR-2, FR-4 / AC-1 | GREEN (RED pre-fix: `analyzeUnverified` undefined) |
| U-1539-2 | test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart | unit | a twice-crashing analyze leaves the clean certification standing — `analyzeUnverified` carries the crash text, the crash never rides a `--> fix:` line | FR-1, FR-3 / AC-2 | GREEN (RED pre-fix) |
| U-1539-3 | test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart | unit | a twice-crashing analyze does NOT mask real structural drift — gate fails, fix line names the missing member | FR-4 / AC-3 | GREEN (RED pre-fix) |
| U-1539-4 | test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart | unit | a real analyzer error (no crash signature) is never retried (1 call) and still fails the gate | FR-2, FR-4 / AC-4 | GREEN (RED pre-fix) |
| U-1539-5 | test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart | cli | `mock create --certify` exits 0 with the loud UNVERIFIED disclosure naming `zfa mock verify` when the analyze crashes on both passes | FR-3 / AC-2 | GREEN (RED pre-fix: exit 1) |
| U-1539-6 | test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart | cli | `mock verify` shares the classification — exit 0 + disclosure, no crash-tail analyze_error finding | FR-5 / AC-5 | GREEN (RED pre-fix: exit 1) |

Regression neighbors (must stay green — the safe-failure contract):

- `test/plugins/mock/mock_certify_gate_test.dart` — the #970 gate contract (A6 drift refuses, A7 conforming passes, U6 analyzer errors surface as fix lines).
- `test/plugins/mock/mock_verify_test.dart` — spec 1121 verify machinery.
- `test/plugins/mock/mock_certification_receipt_test.dart`, `test/plugins/mock/mock_command_exit_test.dart` — receipt + exit protocol.
