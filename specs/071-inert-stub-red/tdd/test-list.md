# Test List: 071-inert-stub-red

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the run reports red with the verdict identifying a specific authored interface assertion as the failing evidence. | AC-1 | PENDING |
| A2 | all authored assertions pass (green) with zero edits to the assertions. | AC-2 | PENDING |
| A3 | that assertion fails because the stand-in does not display the label. | AC-3 | PENDING |
| A4 | the verdict is not-red (the vacuous assertions pass, so nothing certifies red). | AC-1 | PENDING |
| A5 | the verdict is not-red and the workflow refuses to proceed until real assertions are authored. | AC-2 | PENDING |
| A6 | the verdict is red and the workflow proceeds to implementation. | AC-3 | PENDING |
| A7 | the classification names the specific failing assertion and states it is the red evidence. | AC-1 | PENDING |
| A8 | the classification distinguishes this from assertion-level red. | AC-2 | PENDING |
| A9 | the existing error-capture guard reports the failure as it did before this feature existed. | AC-1 | PENDING |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | The red harness for widget-lane behavior tests MUST use an inert-but-valid stand-in as the red surface — a renderable widget that satisfies the interface type but displays none of the authored expectations — instead of aborting at the unimplemented error. | FR-001 | PENDING |
| U2 | Red certification MUST execute all authored view assertions at red time; the run MUST NOT stop at the first guard assertion when the stand-in renders successfully. | FR-002 | PENDING |
| U3 | The red verdict classification MUST identify the specific authored assertion whose failure certifies red. | FR-003 | PENDING |
| U4 | A test whose view assertions all pass against the inert stand-in (vacuous or scaffold-placeholder assertions) MUST be classified not-red, and the generation workflow MUST refuse to proceed to implementation for it. | FR-004 | PENDING |
| U5 | The existing unimplemented-error capture path MUST remain active as a secondary guard for cases where the subject still throws. | FR-005 | PENDING |
| U6 | When the real implementation is supplied, the previously red test MUST pass with zero modifications to the authored assertions. | FR-006 | PENDING |
| U7 | A red verdict MUST distinguish assertion-level red (an authored assertion failed against the stand-in) from guard-level red (only the secondary guard fired) and from harness failure. | FR-007 | PENDING |
| U8 | The placeholder marker left by test scaffolding MUST continue to force a not-red verdict until removed and replaced by real assertions. | FR-008 | PENDING |

