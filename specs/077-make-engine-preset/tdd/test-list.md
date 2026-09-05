# Test List: 077-make-engine-preset

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | all layers of the engine slice for each requested method are generated and the command exits successfully. | AC-1 | PENDING |
| A2 | the engine tree's tests pass alongside the rest of the suite. | AC-2 | PENDING |
| A3 | a machine-readable engine receipt exists listing every generated method with certification status and the source files involved. | AC-3 | PENDING |
| A4 | it completes without an "already registered" failure. | AC-1 | PENDING |
| A5 | no exception is thrown (registration is unregister-first). | AC-2 | PENDING |
| A6 | the reset clears registrations cleanly and setup succeeds. | AC-3 | PENDING |
| A7 | it exits 0. | AC-1 | PENDING |
| A8 | it exits non-zero and names the offending file. | AC-2 | PENDING |
| A9 | it exits non-zero and names the uncertified method. | AC-3 | PENDING |
| A10 | it exits non-zero and surfaces the analysis findings. | AC-4 | PENDING |
| A11 | each suite contains at least two behavioral tests and all pass. | AC-1 | PENDING |
| A12 | at least one test fails, naming the broken artifact. | AC-2 | PENDING |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | The system MUST provide a single command that generates the full engine slice (use case, service, repository, datasource, mock, DI registration, test scaffold) for a named entity in one invocation. | FR-001 | PENDING |
| U2 | The command MUST accept a comma-separated method list (get, getList, create, update, delete) and generate only the requested methods. | FR-002 | PENDING |
| U3 | The command MUST accept flags to enable cache support and sync support in the generated slice, and to force datasource generation. | FR-003 | PENDING |
| U4 | All code in the generated engine tree MUST be free of UI-framework imports; the engine generation MUST enforce this boundary as a built-in check, not an ad-hoc external test. | FR-004 | PENDING |
| U5 | Generated dependency registration code MUST be idempotent: it MUST unregister an existing registration before registering, so repeated setup does not throw. | FR-005 | PENDING |
| U6 | Generated DI code MUST include a reset function alongside the setup function so tests can clear and re-establish registrations. | FR-006 | PENDING |
| U7 | The system MUST write a machine-readable engine receipt after generation, containing the entity name, every generated method with its certification status and mock class, and the list of generated source files. | FR-007 | PENDING |
| U8 | Every generated method's mock MUST be certified before the receipt records it as certified; any uncertified method is visible in the receipt. | FR-008 | PENDING |
| U9 | The system MUST provide a check command that validates an entity's engine slice by (a) running static analysis on the engine tree, (b) verifying the engine receipt exists and contains no uncertified method, and (c) verifying zero UI-framework imports in the engine tree; it exits non-zero if any condition fails. | FR-009 | PENDING |
| U10 | The check command MUST report actionable failures (which file violated the import boundary, which method is uncertified, which analysis findings exist). | FR-010 | PENDING |
| U11 | Each of the five generated artifact types (use case, service, repository, datasource, mock provider) MUST have a dedicated behavioral test suite with at least two tests: one structural and one compile-level. | FR-011 | PENDING |
| U12 | The command chain MUST be re-runnable: running generation again for the same entity either updates or safely replaces prior output without corrupting the project. | FR-012 | PENDING |

