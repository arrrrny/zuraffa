# Traceability: 991-non-scalar-param-hand-delta-seam

Every spec acceptance criterion and functional requirement traced to the
behaviors that certify it and the tests that prove it.

| Spec item | Behavior | Test | Evidence |
| --- | --- | --- | --- |
| AC-1 (make stops hand-delta-required, exact edit) | A1 / U-1323-1 | `issue_1323_hand_delta_seam_test.dart` U-1323-1 | outcome=hand-delta-required; remedy names `_arg0()`, test path, `Object`, re-run; no green entry; subject restored |
| AC-1 precision (unrelated red stays generic) | — | `issue_1323_hand_delta_seam_test.dart` U-1323-2 | outcome=generation-error; no hand-delta diagnosis |
| AC-2 (re-certify from the updated test) | A2 / U-1323-5 | `issue_1323_hand_delta_seam_test.dart` U-1323-5, U-1323-5b | red re-cert → generation ran → green; green re-cert → skip transition, generation never spawned |
| AC-3 (`_scalarLiteral` covers Object) | A3 / U-1323-3 | `issue_1323_hand_delta_seam_test.dart` U-1323-3 | gen emits `(Object())`, no `_arg` helper |
| AC-4 (scalar literals unchanged) | A4 / U-1323-4 | `issue_1323_hand_delta_seam_test.dart` U-1323-4 | `(r'sample', 0, 0, false, 0.0)` verbatim |
| AC-5 (driver named hand step) | A5 / U-1323-6 | `issue_1323_hand_delta_driver_test.dart` U-1323-6 | `stopped_at=U1:hand`; journal `hand-step=U1:hand` + exact edit |
| FR-001 (two-signal detection) | U1-U4 | `arg_placeholder_test.dart` U1-U4b | both signals agree; single-signal → null |
| FR-002 (exact-edit remedy) | U5 | `arg_placeholder_test.dart` U5 | remedy names placeholder, path, type, re-run command |
| FR-003 (seam stays an escape hatch) | U3 | U-1323-1 (entity/`Object?`-degraded param keeps the placeholder path) + M1 kill | seam surfaced, not eliminated |
| FR-005 (re-verification never skipped) | U5 | U-1323-5/5b + make drift-check comment pin | certified-red entry never short-circuits the drift run |
| FR-006 (driver hand step + journal) | U6 | `arg_placeholder_test.dart` U7 + U-1323-6 | shared vocabulary; content-keyed journal dispatch |
| FR-007 (backward compat) | U7 | U-1323-4 + U-1323-2 + full 1308/1259/run suites | existing outcomes and literals unchanged |
