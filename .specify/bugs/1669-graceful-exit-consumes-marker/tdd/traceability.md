# Traceability: 1669-graceful-exit-consumes-marker

Coverage proof for `zfa tdd plan` (bug #846): every FR/AC requirement statement maps to a behavior row or an explicit manual declaration. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan required).

<!-- tdd:traceability
spec-hash: sha256:c33cfd9af20759c7ee346a5325365e90dbf2600a75cdcf2af13c9dd557996f47
statements: 9
automated: 5
manual: 4
fr-manual: 4
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| FR-001 | 22 | - **FR-001**: The system MUST keep `specs/<feature>/tdd/make-interrupt.json` on disk and print an `issue #1669` retention note when a graceful make exit does not adopt the subject, THIS make inherited a previous make's interrupt marker at begin time, the on-disk subject's sha256 differs from the certified hash in the evidence registry, and the on-disk subject is not a born-green placeholder. | — | manual (defaulted: no `traces:` binding) |
| FR-002 | 37 | - **FR-002**: The system MUST consume the marker on every graceful exit that does not meet the FR-001 compound, exactly as before the fix. | — | manual (defaulted: no `traces:` binding) |
| FR-003 | 50 | - **FR-003**: The system MUST leave the resume un-wedged when the marker is retained: the next make finds the crash record, adopts the passing subject through the #1398 adoption arm (outcome=adopted-interrupted, exit 0), appends green evidence binding the current subject hash, and consumes the marker. The wedge state (mutation + no marker) MUST be unreachable via graceful exits. | — | manual (defaulted: no `traces:` binding) |
| FR-004 | 52 | - **FR-004**: The fix MUST NOT change the make-skip logic, the fingerprint comparison, or the #1036 recovery path: the drift signal is computed at clear time inside the summary funnel from the CURRENT disk state (sync read: subject bytes + cycle-log entries), leaving `_subjectDriftRefusal` and the adoption arms unchanged. | — | manual (defaulted: no `traces:` binding) |
| AC-1 | 56 | 1. **Given** a behavior whose certified green evidence binds the stub's hash | A1 | automated |
| AC-2 | 64 | 2. **Given** the same shape but the on-disk subject still matches the | A2 | automated |
| AC-3 | 69 | 3. **Given** the identical drift to scenario 1 but NO marker on disk before | A3 | automated |
| AC-4 | 75 | 4. **Given** the wedge state of scenario 1 (mutated subject, marker retained | A4 | automated |
| AC-5 | 81 | 5. **Given** a crashed make whose marker was inherited but whose on-disk | A5 | automated |

## manual:

FRs declared manual (feature 1484) — tracked here with their full text, never unit behaviour rows. The acceptance-side `(manual:)` concept from bug #846, extended to FRs via the `**Type**: manual` marker.

| requirement | line | statement | tag |
| --- | --- | --- | --- |
| FR-001 | 22 | - **FR-001**: The system MUST keep `specs/<feature>/tdd/make-interrupt.json` on disk and print an `issue #1669` retention note when a graceful make exit does not adopt the subject, THIS make inherited a previous make's interrupt marker at begin time, the on-disk subject's sha256 differs from the certified hash in the evidence registry, and the on-disk subject is not a born-green placeholder. | manual (defaulted: no `traces:` binding) |
| FR-002 | 37 | - **FR-002**: The system MUST consume the marker on every graceful exit that does not meet the FR-001 compound, exactly as before the fix. | manual (defaulted: no `traces:` binding) |
| FR-003 | 50 | - **FR-003**: The system MUST leave the resume un-wedged when the marker is retained: the next make finds the crash record, adopts the passing subject through the #1398 adoption arm (outcome=adopted-interrupted, exit 0), appends green evidence binding the current subject hash, and consumes the marker. The wedge state (mutation + no marker) MUST be unreachable via graceful exits. | manual (defaulted: no `traces:` binding) |
| FR-004 | 52 | - **FR-004**: The fix MUST NOT change the make-skip logic, the fingerprint comparison, or the #1036 recovery path: the drift signal is computed at clear time inside the summary funnel from the CURRENT disk state (sync read: subject bytes + cycle-log entries), leaving `_subjectDriftRefusal` and the adoption arms unchanged. | manual (defaulted: no `traces:` binding) |

