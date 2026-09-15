# Traceability: 1652-defer-phase1-refactor-to-batch

Coverage proof for `zfa tdd plan` (bug #846): every FR/AC requirement statement maps to a behavior row or an explicit manual declaration. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan required).

<!-- tdd:traceability
spec-hash: sha256:179c42d4c6b6d6d6e15b2ec9eaf14278cd96154bd5f904c7ab70c3416e475b04
statements: 10
automated: 5
manual: 5
fr-manual: 5
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| AC-1 | 66 | 1. **Given** a forward run where a behavior's make certifies it green | A1 | automated |
| AC-2 | 75 | 2. **Given** the same run reaching the phase-2b batch pass with N green | A2 | automated |
| AC-3 | 82 | 3. **Given** a resumed run where a behavior re-enters phase 1 directly | A3 | automated |
| AC-4 | 90 | 4. **Given** a hand-stepped behavior (#1568: make stopped | A4 | automated |
| AC-5 | 99 | 5. **Given** a forward run where a LATER behavior's make fails (honest | A5 | automated |
| FR-001 | 108 | - **FR-001**: The run driver's step loop MUST defer a phase-1 refactor | — | manual (defaulted: no `traces:` binding) |
| FR-002 | 114 | - **FR-002**: The deferral MUST use the existing deferral machinery — | — | manual (defaulted: no `traces:` binding) |
| FR-003 | 120 | - **FR-003**: A phase-1 refactor reached WITHOUT a same-drive make (the | — | manual (defaulted: no `traces:` binding) |
| FR-004 | 127 | - **FR-004**: The deferral predicate evaluation MUST remain | — | manual (defaulted: no `traces:` binding) |
| FR-005 | 133 | - **FR-005**: No state machine transitions change: `refactor` success | — | manual (defaulted: no `traces:` binding) |

## manual:

FRs declared manual (feature 1484) — tracked here with their full text, never unit behaviour rows. The acceptance-side `(manual:)` concept from bug #846, extended to FRs via the `**Type**: manual` marker.

| requirement | line | statement | tag |
| --- | --- | --- | --- |
| FR-001 | 108 | - **FR-001**: The run driver's step loop MUST defer a phase-1 refactor | manual (defaulted: no `traces:` binding) |
| FR-002 | 114 | - **FR-002**: The deferral MUST use the existing deferral machinery — | manual (defaulted: no `traces:` binding) |
| FR-003 | 120 | - **FR-003**: A phase-1 refactor reached WITHOUT a same-drive make (the | manual (defaulted: no `traces:` binding) |
| FR-004 | 127 | - **FR-004**: The deferral predicate evaluation MUST remain | manual (defaulted: no `traces:` binding) |
| FR-005 | 133 | - **FR-005**: No state machine transitions change: `refactor` success | manual (defaulted: no `traces:` binding) |

