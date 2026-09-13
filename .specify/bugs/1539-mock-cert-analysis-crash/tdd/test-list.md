# TDD test list — #1539 mock-cert analysis crash (infra, not drift)

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| U-1539-1 | test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart | unit | a crash retried clean passes with NO fix line and exactly 2 analyze calls (initial + one retry) | FR-1, FR-2, FR-4 / AC-1 | GREEN (RED pre-fix: `analyzeUnverified` undefined) |
| U-1539-2 | test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart | unit | a twice-crashing analyze leaves the clean certification standing — `analyzeUnverified` carries the crash text, the crash never rides a `--> fix:` line | FR-1, FR-3 / AC-2 | GREEN (RED pre-fix) |
| U-1539-3 | test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart | unit | a twice-crashing analyze does NOT mask real structural drift — gate fails, fix line names the missing member, and the drift is never retried (exactly 1 analyze call) | FR-4 / AC-3 | GREEN (RED pre-fix) |
| U-1539-4 | test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart | unit | a real analyzer error (no crash signature) is never retried (1 call) and still fails the gate | FR-2, FR-4 / AC-4 | GREEN (RED pre-fix) |
| U-1539-4b | test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart | unit | a crash retried into a real `error -` diagnostic still fails the gate with fix lines (2 calls, no `analyzeUnverified`) | FR-2, FR-4 / AC-4 | GREEN (#1616 review finding 5) |
| U-1539-4c | test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart | unit | unrecognized non-zero output is NOT a crash — no retry, gate fails on the raw tail (fail-safe direction pinned) | FR-1, FR-4 / AC-4 | GREEN (#1616 review finding 3) |
| U-1539-4d | test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart | unit | a re-cased / reworded analysis-server shutdown is still classified as infra and retried | FR-1 / AC-1 | GREEN (#1616 review finding 3) |
| U-1539-5 | test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart | cli | `mock create --certify` exits 0 with the loud UNVERIFIED disclosure naming `zfa mock verify` when the analyze crashes on both passes | FR-3 / AC-2 | GREEN (RED pre-fix: exit 1) |
| U-1539-6 | test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart | cli | `mock verify` shares the classification — exit 0 + disclosure, no crash-tail analyze_error finding | FR-5 / AC-5 | GREEN (RED pre-fix: exit 1) |
| U-1539-7 | test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart | cli | `mock create --certify --json` carries `details.analyzeUnverified` in its single stdout envelope, so the machine contract cannot report a silent pass | FR-3 / AC-2 | GREEN (#1616 review finding 1) |
| U-1539-8 | test/plugins/mock/bug_1539_analyzer_crash_not_drift_test.dart | unit | the ONE shared disclosure formatter reports the receipt write that actually happened — `receipt persisted` / `receipt NOT written`, and no receipt claim from the read-only `mock verify` | FR-3 / AC-2 | GREEN (#1616 review findings 4 + 6) |

Regression neighbors (must stay green — the safe-failure contract):

- `test/plugins/mock/mock_certify_gate_test.dart` — the #970 gate contract (A6 drift refuses, A7 conforming passes, U6 analyzer errors surface as fix lines).
- `test/plugins/mock/mock_verify_test.dart` — spec 1121 verify machinery.
- `test/plugins/mock/mock_certification_receipt_test.dart`, `test/plugins/mock/mock_command_exit_test.dart` — receipt + exit protocol.
