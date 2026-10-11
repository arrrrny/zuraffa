# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the
test existed and failed before the implementation.

## Cycle: U-1542-1 (red)

- behavior: U-1542-1
- kind: red
- classification: assertionFailure
- criterion: FR-001, SC-1
- test: test/plugins/tdd/bug_1542_born_green_contract_refactor_test.dart
- command: `dart test --preset=all test/plugins/tdd/bug_1542_born_green_contract_refactor_test.dart`
- exit: 1
- at: 2026-09-13T00:00:00.000Z
- output:
```
refactor certified but evidence for "contract:A7" is incomplete in tdd/cycle-log.md (red: false, green: true)
run: feature=1542-born-green-refactor result=runner-error pending=0 red=0 green=1 done=0 stopped_at=contract:A7:refactor
Expected: not contains 'is incomplete in tdd/cycle-log.md'
  Actual: <the misfire transcript above>
```
The EXACT issue #1542 trap reproduces on pristine HEAD against a scripted
contract-lane behavior parked at `blocked` with green-only evidence: the run
dead-ends `runner-error` at `contract:A7:refactor` because the refactor
evidence check demands a red entry the BLOCKED-never-RED lane (#1007) can
never produce.

## Cycle: U-1542-2 (red)

- behavior: U-1542-2
- kind: red
- classification: assertionFailure
- criterion: FR-002, SC-2
- test: test/plugins/tdd/bug_1542_born_green_contract_refactor_test.dart
- command: `dart test --preset=all test/plugins/tdd/bug_1542_born_green_contract_refactor_test.dart`
- exit: 1
- at: 2026-09-13T00:00:00.000Z
- output:
```
refactor certified but evidence for "U1" is incomplete in tdd/cycle-log.md (red: false, green: true)
run: feature=1542-born-green-refactor result=runner-error pending=0 red=0 green=1 done=0 stopped_at=U1:refactor
```
A UNIT behavior whose last green entry carries the born-green journal marker
(#1411) dead-ends the same way — the check has no born-green exemption on
any lane.

## Cycle: U-1542-4 (red)

- behavior: U-1542-4
- kind: red
- classification: assertionFailure
- criterion: FR-002, SC-4
- test: test/plugins/tdd/bug_1542_born_green_contract_refactor_test.dart
- command: `dart test --preset=all test/plugins/tdd/bug_1542_born_green_contract_refactor_test.dart`
- exit: 2
- at: 2026-09-13T00:00:00.000Z
- output:
```
refactor certified but evidence for "contract:A7" is incomplete in tdd/cycle-log.md (red: false, green: true)
run: feature=1542-born-green-refactor result=runner-error pending=0 red=0 green=1 done=0 stopped_at=contract:A7:refactor
Expected: <0> Actual: <2>
```
The full born-green contract flow (post-advancement state + journal
certification) cannot complete the run.

## Cycle: M-1542-1 (red)

- behavior: M-1542-1
- kind: red
- classification: assertionFailure
- criterion: FR-004, FR-006, SC-3
- test: test/plugins/tdd/commands/bug_1411_born_green_hand_transition_test.dart
- command: `dart test --preset=all test/plugins/tdd/commands/bug_1411_born_green_hand_transition_test.dart --plain-name "M-1542"`
- exit: 1
- at: 2026-09-13T00:00:00.000Z
- output:
```
Expected: contains 'U1 blocked -> done'
  Actual: 'zfa tdd make: behavior U1 ... born-green hand transition (issue #1411): ... certifying green from the passing transcript.
   green evidence appended to specs/090-tdd-fixture/tdd/cycle-log.md
make: behavior=U1 outcome=born-green feature=090-tdd-fixture'
Which: does not contain 'U1 blocked -> done'
```
`make --born-green` certifies green but leaves the seeded `blocked`
run-state untouched — dead-end #2 of the #1542 compound trap (the re-run
re-enters at verify-red → make and re-stops at the flagless
not-certified-red refusal).

## Cycle: U-1542-3 (green)

- behavior: U-1542-3
- kind: green
- criterion: FR-003
- test: test/plugins/tdd/bug_1542_born_green_contract_refactor_test.dart
- exit: 0
- at: 2026-09-13T00:00:00.000Z
- output:
```
00:23 +1 -2: U-1542-3 ... the marker-less twin still misfires with the byte-identical pre-#1542 message
```
Regression twin GREEN ON PRISTINE HEAD (pre-pass): the bug #682 honesty
contract (green-only refactor misfires for non-contract, non-born-green)
holds before and must hold after the fix.

## Cycle: M-1542-2 (green)

- behavior: M-1542-2
- kind: green
- criterion: FR-004
- test: test/plugins/tdd/commands/bug_1411_born_green_hand_transition_test.dart
- exit: 0
- at: 2026-09-13T00:00:00.000Z
- output:
```
00:14 +1 -1: M-1542-2 ... born-green with NO run-state.json still certifies green and writes no state file
```
Regression twin GREEN ON PRISTINE HEAD (pre-pass).

## Cycle: M-1542-3 (green)

- behavior: M-1542-3
- kind: green
- criterion: FR-004
- test: test/plugins/tdd/commands/bug_1411_born_green_hand_transition_test.dart
- exit: 0
- at: 2026-09-13T00:00:00.000Z
- output:
```
00:22 +2 -1: M-1542-3 ... born-green leaves a pending run-state untouched
```
Regression twin GREEN ON PRISTINE HEAD (pre-pass).

## Cycle: U-1542-1 (green)

- behavior: U-1542-1
- kind: green
- criterion: FR-001, SC-1
- test: test/plugins/tdd/bug_1542_born_green_contract_refactor_test.dart
- exit: 0
- at: 2026-09-13T00:00:00.000Z
- output:
```
00:07 +1: U-1542-1 ... a contract-lane behavior with green-only evidence completes the run — red is defined out of existence for the BLOCKED-never-RED lane (#1007)
run: feature=1542-born-green-refactor result=complete pending=0 red=0 green=1 done=0
```
The run COMPLETES: refactor certifies clean, the misfire is gone, exit 0.
(The behavior ends GREEN — the pre-existing bug-#682 reconcile demotes
green-only dones; the machine contract unchanged.)

## Cycle: U-1542-2 (green)

- behavior: U-1542-2
- kind: green
- criterion: FR-002, SC-2
- test: test/plugins/tdd/bug_1542_born_green_contract_refactor_test.dart
- exit: 0
- at: 2026-09-13T00:00:00.000Z
- output:
```
00:15 +2: U-1542-2 ... a behavior whose LAST green entry carries the born-green journal marker completes refactor on green-only evidence — any lane
```
The journal probe exempts the born-green UNIT behavior: refactor re-entry
only (make never spawns), run completes.

## Cycle: U-1542-4 (green)

- behavior: U-1542-4
- kind: green
- criterion: FR-002, SC-4
- test: test/plugins/tdd/bug_1542_born_green_contract_refactor_test.dart
- exit: 0
- at: 2026-09-13T00:00:00.000Z
- output:
```
00:29 +4: U-1542-4 ... the full born-green contract flow — the post-advancement state reconciles to green and re-enters at refactor ONLY (make never re-spawns) — no manual run-state surgery
```
The full born-green contract flow completes the run.

## Cycle: M-1542-1 (green)

- behavior: M-1542-1
- kind: green
- criterion: FR-004, FR-006, SC-3
- test: test/plugins/tdd/commands/bug_1411_born_green_hand_transition_test.dart
- exit: 0
- at: 2026-09-13T00:00:00.000Z
- output:
```
00:39 +9: make block (real runner) M-1542-1 ... born-green advances run-state.json blocked → done — the wedge closes without manual state surgery
   run-state advanced: U1 blocked -> done (born-green certification, issue #1542)
```
Dead-end #2 closed: the transition advances the wedged claim on disk.

## Cycle: regression-guard suite (green)

- behavior: R-1542-1/2/3
- kind: green
- criterion: FR-003, SC-5
- test: test/plugins/tdd/run_command_test.dart
- exit: 0
- at: 2026-09-13T00:00:00.000Z
- output:
```
05:28 +50: All tests passed!   (run_command_test.dart — includes the pinned bug-682 green-only honesty misfire)
01:40 +17: All tests passed!   (1542 + 1411 suites together)
+359/+160/+240/+293: fast tier test/plugins/tdd — All tests passed!
```
Pre-existing master failures VERIFIED BY `git stash` re-run on pristine
HEAD (not caused by this change): bug_828 (doctor --feature),
bug_1345, bug_1162 green-path, bug_840.
