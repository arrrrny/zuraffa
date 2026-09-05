# Cycle Log: 1007-contract-tests-first-class

## Cycle: contract:A1 (red)

- behavior: contract:A1
- kind: red
- classification: assertionFailure
- criterion: SpecParser.parseContractBehaviors
- test: test/plugins/tdd/commands/plan_contract_kind_1007_test.dart
- command: `dart test test/plugins/tdd/commands/plan_contract_kind_1007_test.dart`
- exit: 1
- at: 2026-09-05T05:00:00.000Z

RED: plan emitted no contract:<id> rows (BehaviorKind.contract did not
exist — the test suite failed to load with "Member not found: 'contract'",
then failed behaviorally 4/5 after the minimal enum stub: no
`| contract:A1 |` in the engine plan, no contract kind resolution, no
re-plan preservation; the one passing test was the additive baseline
"a spec without Layer Contracts plans contract-free").

## Cycle: contract:A1 (green)

- behavior: contract:A1
- kind: green
- criterion: SpecParser.parseContractBehaviors
- test: test/plugins/tdd/commands/plan_contract_kind_1007_test.dart
- command: `dart test test/plugins/tdd/commands/plan_contract_kind_1007_test.dart`
- exit: 0
- at: 2026-09-05T05:40:00.000Z

GREEN: plan derives contract rows from the spec's Layer Contracts
(`contract:A<n>` entity / `contract:C<n>` controller / `contract:U<n>`
usecase), renders `## Contract loop:` in both the legacy single-file plan
and 04-ENGINE.md, preserves prior rows across re-planning, and
TestListReader resolves the kind. 5/5 passing.

## Cycle: contract:A2 (red)

- behavior: contract:A2
- kind: red
- classification: assertionFailure
- criterion: ContractTestWriter.render
- test: test/plugins/tdd/commands/gen_contract_kind_1007_test.dart
- command: `dart test test/plugins/tdd/commands/gen_contract_kind_1007_test.dart`
- exit: 1
- at: 2026-09-05T05:05:00.000Z

RED: `zfa tdd gen contract:A1` was "unknown behavior id" — no contract
kind in any gen surface (3/3 failing).

## Cycle: contract:A2 (green)

- behavior: contract:A2
- kind: green
- criterion: ContractTestWriter.render
- test: test/plugins/tdd/commands/gen_contract_kind_1007_test.dart
- command: `dart test test/plugins/tdd/commands/gen_contract_kind_1007_test.dart`
- exit: 0
- at: 2026-09-05T05:45:00.000Z

GREEN: gen dispatches the contract pair (ContractTestWriter +
ContractSubjectWriter), sanitizes the `:` id to a portable file segment
(`contract_a1`), registers the pair, and the generated test enumerates
the subject's declared case table (the `dart analyze` clean proof ran in
the third test). 3/3 passing.

## Cycle: contract:U1 (red)

- behavior: contract:U1
- kind: red
- classification: assertionFailure
- criterion: ContractBlockedReceipt.write
- test: test/plugins/tdd/commands/verify_red_contract_blocked_1007_test.dart
- command: `dart test test/plugins/tdd/commands/verify_red_contract_blocked_1007_test.dart`
- exit: 1
- at: 2026-09-05T05:10:00.000Z

RED: a deliberately unimplemented method certified an ordinary assertion
RED (classification=assertion, certified=true) — no blocked verdict, no
receipt; the run stop reported result=stopped. The two passing tests were
the additive baselines (non-contract red still certifies; StepRunner
passes the classification token through).

## Cycle: contract:U1 (green)

- behavior: contract:U1
- kind: green
- criterion: ContractBlockedReceipt.write
- test: test/plugins/tdd/commands/verify_red_contract_blocked_1007_test.dart
- command: `dart test test/plugins/tdd/commands/verify_red_contract_blocked_1007_test.dart`
- exit: 0
- at: 2026-09-05T05:50:00.000Z

GREEN: verify-red's contract lane reports classification=blocked (exit 1,
no red evidence) and persists the contract-blocked.contract_A1.json
receipt; StepRunner surfaces outcome=blocked; the run stops with
result=blocked at contract:A1:verify-red, never reaching make. 4/4
passing.

## Cycle: U6 (red)

- behavior: U6
- kind: red
- classification: assertionFailure
- criterion: FR-006
- test: test/plugins/tdd/corpus_economics/contract_severity_1007_test.dart
- command: `dart test test/plugins/tdd/corpus_economics/contract_severity_1007_test.dart`
- exit: 1
- at: 2026-09-05T05:12:00.000Z

RED: GapSeverity did not exist (compile failure — the model layer was
missing entirely); after the minimal compile surface the model-level
assertions passed (the model is the trivial part) with the behavioral
stamping/printing untested.

## Cycle: U6 (green)

- behavior: U6
- kind: green
- criterion: FR-006
- test: test/plugins/tdd/corpus_economics/contract_severity_1007_test.dart
- command: `dart test test/plugins/tdd/corpus_economics/contract_severity_1007_test.dart`
- exit: 0
- at: 2026-09-05T05:55:00.000Z

GREEN: the ledger stamps severity=contract through GapSeverity.forStop,
legacy entries parse severity-free, previously-appended entries stay
byte-identical (U13), totals rank contract gaps first and count them, and
the corpus run/status surfaces label the severity. 5/5 passing. (The
corpus run stamping is exercised through the same GapSeverity.forStop the
run command calls — the pure classification rule is shared.)
