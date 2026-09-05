# Test List: 1007-contract-tests-first-class

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the plan emits contract:A1 (entity method contract) in the engine plan | AC-1 | DONE |
| A2 | gen contract:A1 produces a contract test that enumerates method cases | AC-2 | DONE |
| A3 | a deliberately unimplemented method causes a BLOCKED (not RED) verdict | AC-3 | DONE |
| A4 | the corpus-economics gate treats contract-test failures as highest-severity gaps | AC-4 | DONE |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | BehaviorKind.contract exists and TestListReader resolves `## Contract loop:` rows as contract kind | FR-001 | DONE |
| U2 | plan derives contract:<L><n> rows per declared entity method / controller method / usecase, preserved across re-plan, engine-side in lane splits | FR-002 | DONE |
| U3 | gen writes the contract pair (case-enumerating test + case-table subject) with a portable id segment, registry + receipts | FR-003 | DONE |
| U4 | verify-red on a failing contract case reports blocked, exits non-zero, writes no red evidence, persists contract-blocked.<id>.json | FR-004 | DONE |
| U5 | run turns a blocked verify-red into result=blocked stopped before GREEN; StepRunner surfaces the token | FR-005 | DONE |
| U6 | the gap ledger stamps severity=contract, totals rank contract gaps first, corpus status prints severity | FR-006 | DONE |

## Contract loop: contract behaviors

Contract behaviors (issue #1007): one row per declared entity method,
controller method, and usecase. The gen pair is a contract test scaffold
that enumerates the method cases and asserts the implementation satisfies
them — a failing case is BLOCKED, never RED, and blocks the cycle from
proceeding to GREEN.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| contract:A1 | SpecParser.parseContractBehaviors must satisfy the declared contract `parseContractBehaviors(spec) -> List<Behavior>` | SpecParser.parseContractBehaviors | DONE |
| contract:A2 | ContractTestWriter.render must satisfy the declared contract `render(behavior, subjectPath) -> String` | ContractTestWriter.render | DONE |
| contract:U1 | ContractBlockedReceipt.write must satisfy the declared contract `write(behavior, feature, ...) -> File` | ContractBlockedReceipt.write | DONE |
