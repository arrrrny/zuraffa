# Traceability: dart-core-lane-timeout-overflow

Coverage proof for `zfa tdd plan` (bug #846): every FR/AC requirement statement maps to a behavior row or an explicit manual declaration. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan required).

<!-- tdd:traceability
spec-hash: sha256:fafe107826e77462a6160de211550c62c660977089e982f523a4511ff5388fa0
statements: 8
automated: 8
manual: 0
fr-manual: 0
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| FR-001 | 19 | - **FR-001**: every fast-lane-eligible `*_test.dart` (carrying no | U1 | automated |
| FR-002 | 30 | - **FR-002**: the regression-tier files annotated `@Tags(['regression'])` | U2 | automated |
| FR-003 | 36 | - **FR-003**: a structural pin test (fast, pure — it reads sources and tags, | U3 | automated |
| FR-004 | 41 | - **FR-004**: the `dart_core` test step MUST run the residual lane with | U4 | automated |
| AC-1 | 67 | 1. **Given** the pre-fix tree (master `8480a53e`) **When** the FR-003 census | A1 | automated |
| AC-2 | 74 | 2. **Given** the tagged tree (every census offender carrying `e2e` or `slow`, | A2 | automated |
| AC-3 | 79 | 3. **Given** the tagged tree **When** | A3 | automated |
| AC-4 | 85 | 4. **Given** the edited `ci.yaml` **When** `test/tier_integrity_test.dart` | A4 | automated |

