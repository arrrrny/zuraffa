# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: U1-U3 (red)

- behavior: U1-U3
- kind: red
- classification: assertionFailure
- criterion: SC-5
- test: test/plugins/tdd/services/realize_state_test.dart
- command: `dart test test/plugins/tdd/services/realize_state_test.dart`
- exit: 1
- at: 2026-09-03T08:22:59.465190Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/realize_state_test.dart
00:00 +0: U1: absent state file means era MOCKED (mock-first default)
00:00 +0 -1: U1: absent state file means era MOCKED (mock-first default) [E]
  UnimplementedError
  package:zuraffa/src/plugins/tdd/services/realize_state.dart 78:9  RealizeStateStore.loadOrDefault
  test/plugins/tdd/services/realize_state_test.dart 35:33           main.<fn>
  
00:00 +0 -1: U2: transitionToReal persists era REAL with gate evidence
00:00 +0 -2: U2: transitionToReal persists era REAL with gate evidence [E]
  UnimplementedError
  package:zuraffa/src/plugins/tdd/services/realize_state.dart 78:9  RealizeStateStore.loadOrDefault
  test/plugins/tdd/services/realize_state_test.dart 50:29           main.<fn>
  
00:00 +0 -2: U3: re-realizing the same adapter is idempotent
00:00 +0 -3: U3: re-realizing the same adapter is idempotent [E]
  UnimplementedError
  package:zuraffa/src/plugins/tdd/services/realize_state.dart 78:9  RealizeStateStore.loadOrDefault
  test/plugins/tdd/services/realize_state_test.dart 92:29           main.<fn>
  
00:00 +0 -3: Some tests failed.

Failing tests:
  test/plugins/tdd/services/realize_state_test.dart: U1: absent state file means era MOCKED (mock-first default)
  test/plugins/tdd/services/realize_state_test.dart: U2: transitionToReal persists era REAL with gate evidence
  test/plugins/tdd/services/realize_state_test.dart: U3: re-realizing the same adapter is idempotent

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```
- schema: 1
- prev-hash: genesis
- hash: e424d3e09eeca6773587118948da25cced253bcaaf8447c66d15b4c86c937163

## Cycle: U4-U7 (red)

- behavior: U4-U7
- kind: red
- classification: assertionFailure
- criterion: SC-1
- test: test/plugins/tdd/services/di_rebind_test.dart
- command: `dart test test/plugins/tdd/services/di_rebind_test.dart`
- exit: 1
- at: 2026-09-03T08:23:04.878576Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/di_rebind_test.dart
00:00 +0: U4: scan finds the mock binding sites for the entity
00:00 +0 -1: U4: scan finds the mock binding sites for the entity [E]
  UnimplementedError
  package:zuraffa/src/plugins/tdd/services/di_rebind.dart 66:7  DiRebinder.scan
  test/plugins/tdd/services/di_rebind_test.dart 96:36           main.<fn>
  
00:00 +0 -1: U5: rebind swaps symbols, fixes imports, keeps domain untouched
00:00 +0 -2: U5: rebind swaps symbols, fixes imports, keeps domain untouched [E]
  UnimplementedError
  package:zuraffa/src/plugins/tdd/services/di_rebind.dart 79:9  DiRebinder.rebind
  test/plugins/tdd/services/di_rebind_test.dart 125:37          main.<fn>
  
00:00 +0 -2: U6: rebind refuses when the adapter class does not exist in lib/
00:00 +0 -3: U6: rebind refuses when the adapter class does not exist in lib/ [E]
  Expected: throws <Instance of 'DiRebindException'> with `message`: (contains 'UserFirestore' and contains 'never generates')
    Actual: <Closure: () => Future<DiRebindResult>>
     Which: threw UnimplementedError:<UnimplementedError>
            stack package:zuraffa/src/plugins/tdd/services/di_rebind.dart 79:9  DiRebinder.rebind
                  test/plugins/tdd/services/di_rebind_test.dart 175:24          main.<fn>.<fn>
                  package:matcher                                               expect
                  test/plugins/tdd/services/di_rebind_test.dart 174:5           main.<fn>
                  
            which is not an instance of 'DiRebindException'
  
  package:matcher                                      expect
  test/plugins/tdd/services/di_rebind_test.dart 174:5  main.<fn>
  
00:00 +0 -3: U7: rebind refuses when there is no mock binding to swap
00:00 +0 -4: U7: rebind refuses when there is no mock binding to swap [E]
  Expected: throws <Instance of 'DiRebindException'> with `message`: contains 'no mock binding'
    Actual: <Closure: () => Future<DiRebindResult>>
     Which: threw UnimplementedError:<UnimplementedError>
            stack package:zuraffa/src/plugins/tdd/services/di_rebind.dart 79:9  DiRebinder.rebind
                  test/plugins/tdd/services/di_rebind_test.dart 193:24          main.<fn>.<fn>
                  package:matcher                                               expect
                  test/plugins/tdd/services/di_rebind_test.dart 192:5           main.<fn>
                  
            which is not an instance of 'DiRebindException'
  
  package:matcher                                      expect
  test/plugins/tdd/services/di_rebind_test.dart 192:5  main.<fn>
  
00:00 +0 -4: Some tests failed.

Failing tests:
  test/plugins/tdd/services/di_rebind_test.dart: U4: scan finds the mock binding sites for the entity
  test/plugins/tdd/services/di_rebind_test.dart: U5: rebind swaps symbols, fixes imports, keeps domain untouched
  test/plugins/tdd/services/di_rebind_test.dart: U6: rebind refuses when the adapter class does not exist in lib/
  test/plugins/tdd/services/di_rebind_test.dart: U7: rebind refuses when there is no mock binding to swap

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```
- schema: 1
- prev-hash: genesis
- hash: 1ab5516df18d3845509516b24e8a24568261fa5623b95929dc4c594240164b16

## Cycle: A1,A2,A6 (red)

- behavior: A1,A2,A6
- kind: red
- classification: assertionFailure
- criterion: SC-4
- test: test/plugins/tdd/commands/realize_command_test.dart
- command: `dart test test/plugins/tdd/commands/realize_command_test.dart`
- exit: 1
- at: 2026-09-03T08:23:05.375328Z
- output:
```
00:00 +0: loading test/plugins/tdd/commands/realize_command_test.dart
00:00 +0: A1: full green path rebinds DI, transitions era, persists state
00:00 +0 -1: A1: full green path rebinds DI, transitions era, persists state [E]
  UnimplementedError
  package:zuraffa/src/plugins/tdd/commands/realize_command.dart 64:31  RealizeCommand.run
  package:args/command_runner.dart 212:27                              CommandRunner.runCommand
  package:args/command_runner.dart 122:25                              CommandRunner.run.<fn>
  dart:async                                                           new Future.sync
  package:args/command_runner.dart 122:14                              CommandRunner.run
  test/plugins/tdd/commands/realize_command_test.dart 120:20           main.runRealize.<fn>
  dart:async                                                           runZoned
  test/plugins/tdd/commands/realize_command_test.dart 119:11           main.runRealize
  test/plugins/tdd/commands/realize_command_test.dart 130:23           main.<fn>
  
00:00 +0 -1: A2: --adapter is required — a swap without a real adapter is refused
00:00 +0 -2: A2: --adapter is required — a swap without a real adapter is refused [E]
  UnimplementedError
  package:zuraffa/src/plugins/tdd/commands/realize_command.dart 64:31  RealizeCommand.run
  package:args/command_runner.dart 212:27                              CommandRunner.runCommand
  package:args/command_runner.dart 122:25                              CommandRunner.run.<fn>
  dart:async                                                           new Future.sync
  package:args/command_runner.dart 122:14                              CommandRunner.run
  test/plugins/tdd/commands/realize_command_test.dart 120:20           main.runRealize.<fn>
  dart:async                                                           runZoned
  test/plugins/tdd/commands/realize_command_test.dart 119:11           main.runRealize
  test/plugins/tdd/commands/realize_command_test.dart 162:23           main.<fn>
  
00:00 +0 -2: A6: a behavior id target resolves through the registry
00:00 +0 -3: A6: a behavior id target resolves through the registry [E]
  UnimplementedError
  package:zuraffa/src/plugins/tdd/commands/realize_command.dart 64:31  RealizeCommand.run
  package:args/command_runner.dart 212:27                              CommandRunner.runCommand
  package:args/command_runner.dart 122:25                              CommandRunner.run.<fn>
  dart:async                                                           new Future.sync
  package:args/command_runner.dart 122:14                              CommandRunner.run
  test/plugins/tdd/commands/realize_command_test.dart 120:20           main.runRealize.<fn>
  dart:async                                                           runZoned
  test/plugins/tdd/commands/realize_command_test.dart 119:11           main.runRealize
  test/plugins/tdd/commands/realize_command_test.dart 177:23           main.<fn>
  
00:00 +0 -3: Some tests failed.

Failing tests:
  test/plugins/tdd/commands/realize_command_test.dart: A1: full green path rebinds DI, transitions era, persists state
  test/plugins/tdd/commands/realize_command_test.dart: A2: --adapter is required — a swap without a real adapter is refused
  test/plugins/tdd/commands/realize_command_test.dart: A6: a behavior id target resolves through the registry

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```
- schema: 1
- prev-hash: genesis
- hash: 28756beb9f722ce9481b3414987c40097b468e675d0e7a1929c6b3f6f1c0ed85

## Cycle: U1-U3 (green)

- behavior: U1-U3
- kind: green
- classification: -
- criterion: SC-5
- test: test/plugins/tdd/services/realize_state_test.dart
- command: `dart test test/plugins/tdd/services/realize_state_test.dart`
- exit: 0
- at: 2026-09-03T08:27:44.881617Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/realize_state_test.dart
00:00 +0: test/plugins/tdd/services/realize_state_test.dart: U1: absent state file means era MOCKED (mock-first default)
00:00 +1: test/plugins/tdd/services/di_rebind_test.dart: U4: scan finds the mock binding sites for the entity
00:00 +2: test/plugins/tdd/services/di_rebind_test.dart: U4: scan finds the mock binding sites for the entity
00:00 +3: test/plugins/tdd/services/di_rebind_test.dart: U4: scan finds the mock binding sites for the entity
00:00 +4: test/plugins/tdd/services/di_rebind_test.dart: U5: rebind swaps symbols, fixes imports, keeps domain untouched
00:00 +5: test/plugins/tdd/services/di_rebind_test.dart: U6: rebind refuses when the adapter class does not exist in lib/
00:00 +6: test/plugins/tdd/services/di_rebind_test.dart: U7: rebind refuses when there is no mock binding to swap
00:00 +7: test/plugins/tdd/commands/realize_command_test.dart: A1: full green path rebinds DI, transitions era, persists state
00:00 +8: test/plugins/tdd/commands/realize_command_test.dart: A2: --adapter is required — a swap without a real adapter is refused
00:00 +9: test/plugins/tdd/commands/realize_command_test.dart: A6: a behavior id target resolves through the registry
00:00 +10: All tests passed!
```
- schema: 1
- prev-hash: e424d3e09eeca6773587118948da25cced253bcaaf8447c66d15b4c86c937163
- hash: 8c58a0069d02d1fbc6a430f972bb5e255ca5874b29f719f91cb5894fc6f3af7e

## Cycle: U4-U7 (green)

- behavior: U4-U7
- kind: green
- classification: -
- criterion: SC-1
- test: test/plugins/tdd/services/di_rebind_test.dart
- command: `dart test test/plugins/tdd/services/di_rebind_test.dart`
- exit: 0
- at: 2026-09-03T08:27:45.456315Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/realize_state_test.dart
00:00 +0: test/plugins/tdd/services/realize_state_test.dart: U1: absent state file means era MOCKED (mock-first default)
00:00 +1: test/plugins/tdd/services/di_rebind_test.dart: U4: scan finds the mock binding sites for the entity
00:00 +2: test/plugins/tdd/services/di_rebind_test.dart: U4: scan finds the mock binding sites for the entity
00:00 +3: test/plugins/tdd/services/di_rebind_test.dart: U4: scan finds the mock binding sites for the entity
00:00 +4: test/plugins/tdd/services/di_rebind_test.dart: U5: rebind swaps symbols, fixes imports, keeps domain untouched
00:00 +5: test/plugins/tdd/services/di_rebind_test.dart: U6: rebind refuses when the adapter class does not exist in lib/
00:00 +6: test/plugins/tdd/services/di_rebind_test.dart: U7: rebind refuses when there is no mock binding to swap
00:00 +7: test/plugins/tdd/commands/realize_command_test.dart: A1: full green path rebinds DI, transitions era, persists state
00:00 +8: test/plugins/tdd/commands/realize_command_test.dart: A2: --adapter is required — a swap without a real adapter is refused
00:00 +9: test/plugins/tdd/commands/realize_command_test.dart: A6: a behavior id target resolves through the registry
00:00 +10: All tests passed!
```
- schema: 1
- prev-hash: 1ab5516df18d3845509516b24e8a24568261fa5623b95929dc4c594240164b16
- hash: d37b6214fee9740c91e06570d49f679411b9c85ad97386d795be728964163367

## Cycle: A1,A2,A6 (green)

- behavior: A1,A2,A6
- kind: green
- classification: -
- criterion: SC-4
- test: test/plugins/tdd/commands/realize_command_test.dart
- command: `dart test test/plugins/tdd/commands/realize_command_test.dart`
- exit: 0
- at: 2026-09-03T08:27:45.992052Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/realize_state_test.dart
00:00 +0: test/plugins/tdd/services/realize_state_test.dart: U1: absent state file means era MOCKED (mock-first default)
00:00 +1: test/plugins/tdd/services/di_rebind_test.dart: U4: scan finds the mock binding sites for the entity
00:00 +2: test/plugins/tdd/services/di_rebind_test.dart: U4: scan finds the mock binding sites for the entity
00:00 +3: test/plugins/tdd/services/di_rebind_test.dart: U4: scan finds the mock binding sites for the entity
00:00 +4: test/plugins/tdd/services/di_rebind_test.dart: U5: rebind swaps symbols, fixes imports, keeps domain untouched
00:00 +5: test/plugins/tdd/services/di_rebind_test.dart: U6: rebind refuses when the adapter class does not exist in lib/
00:00 +6: test/plugins/tdd/services/di_rebind_test.dart: U7: rebind refuses when there is no mock binding to swap
00:00 +7: test/plugins/tdd/commands/realize_command_test.dart: A1: full green path rebinds DI, transitions era, persists state
00:00 +8: test/plugins/tdd/commands/realize_command_test.dart: A2: --adapter is required — a swap without a real adapter is refused
00:00 +9: test/plugins/tdd/commands/realize_command_test.dart: A6: a behavior id target resolves through the registry
00:00 +10: All tests passed!
```
- schema: 1
- prev-hash: 28756beb9f722ce9481b3414987c40097b468e675d0e7a1929c6b3f6f1c0ed85
- hash: a2120d9ce9ff8a1bff4734c33fecca587f78fdfe7b431ec2afb0bbb40e83032f

## Cycle: U8-U10 (red)

- behavior: U8-U10
- kind: red
- classification: assertionFailure
- criterion: SC-1
- test: test/plugins/tdd/services/contract_gate_test.dart
- command: `dart test test/plugins/tdd/services/contract_gate_test.dart`
- exit: 1
- at: 2026-09-03T08:29:17.715591Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/contract_gate_test.dart
00:00 +0: U8: green when the suite is green against both bindings
00:00 +0 -1: U8: green when the suite is green against both bindings [E]
  UnimplementedError
  package:zuraffa/src/plugins/tdd/services/contract_gate.dart 56:9  ContractGate.evaluate
  test/plugins/tdd/services/contract_gate_test.dart 18:25           main.<fn>
  
00:00 +0 -1: U9: real-broke-contract when baseline green and real red
00:00 +0 -2: U9: real-broke-contract when baseline green and real red [E]
  UnimplementedError
  package:zuraffa/src/plugins/tdd/services/contract_gate.dart 56:9  ContractGate.evaluate
  test/plugins/tdd/services/contract_gate_test.dart 29:25           main.<fn>
  
00:00 +0 -2: U10: mock-broke-contract when the baseline run is already red
00:00 +0 -3: U10: mock-broke-contract when the baseline run is already red [E]
  UnimplementedError
  package:zuraffa/src/plugins/tdd/services/contract_gate.dart 56:9  ContractGate.evaluate
  test/plugins/tdd/services/contract_gate_test.dart 49:25           main.<fn>
  
00:00 +0 -3: Some tests failed.

Failing tests:
  test/plugins/tdd/services/contract_gate_test.dart: U10: mock-broke-contract when the baseline run is already red
  test/plugins/tdd/services/contract_gate_test.dart: U8: green when the suite is green against both bindings
  test/plugins/tdd/services/contract_gate_test.dart: U9: real-broke-contract when baseline green and real red

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```
- schema: 1
- prev-hash: genesis
- hash: 4a47d62cf29c92e9a33b68ff2febda98532340c2cd49160f3d46e5b7e99f9cb7

## Cycle: A3,A3b (red)

- behavior: A3,A3b
- kind: red
- classification: assertionFailure
- criterion: SC-1
- test: test/plugins/tdd/commands/realize_command_test.dart
- command: `dart test test/plugins/tdd/commands/realize_command_test.dart`
- exit: 1
- at: 2026-09-03T08:29:18.223136Z
- output:
```
00:00 +0: loading test/plugins/tdd/commands/realize_command_test.dart
00:00 +0: A1: full green path rebinds DI, transitions era, persists state
00:00 +1: A2: --adapter is required — a swap without a real adapter is refused
00:00 +2: A6: a behavior id target resolves through the registry
00:00 +3: A3: a red real-binding run blocks the swap, rolls the rebind back, and the verdict names the side
00:00 +3 -1: A3: a red real-binding run blocks the swap, rolls the rebind back, and the verdict names the side [E]
  Expected: <1>
    Actual: <0>
  out: zfa tdd realize: entity User -> adapter UserRealAdapter
     feature: 090-tdd-fixture
     era: MOCKED
     rebound: lib/src/di/datasources/user_mock_datasource_di.dart (2 site(s))
     rebound: lib/src/di/repositories/user_repository_di.dart (1 site(s))
     interface preserved: 1 domain file(s) byte-identical
     contract gate green: suite stays green on the real binding
     state: MOCKED -> REAL (/tmp/tdd_fixture_IWDLCU/specs/090-tdd-fixture/tdd/realize-state.json)
  realize: entity=User adapter=UserRealAdapter feature=090-tdd-fixture contract=green era=MOCKED->REAL result=realized
  
  package:matcher                                            expect
  test/plugins/tdd/commands/realize_command_test.dart 209:5  main.<fn>
  
00:00 +3 -1: A3b: a red baseline (mock era already broken) blocks before any rebind and blames the mock side
00:00 +3 -2: A3b: a red baseline (mock era already broken) blocks before any rebind and blames the mock side [E]
  Expected: contains 'contract=mock-broke-contract'
    Actual: 'zfa tdd realize: entity User -> adapter UserRealAdapter\n'
              '   feature: 090-tdd-fixture\n'
              '   era: MOCKED\n'
              '   rebound: lib/src/di/datasources/user_mock_datasource_di.dart (2 site(s))\n'
              '   rebound: lib/src/di/repositories/user_repository_di.dart (1 site(s))\n'
              '   interface preserved: 1 domain file(s) byte-identical\n'
              '   contract gate RED: the mock-era suite failed against the real binding.\n'
              '   suite output (tail):\n'
              'call 1 exit 1\n'
              'realize: entity=User adapter=UserRealAdapter feature=090-tdd-fixture contract=red era=MOCKED result=blocked'
     Which: does not contain 'contract=mock-broke-contract'
  
  package:matcher                                            expect
  test/plugins/tdd/commands/realize_command_test.dart 238:5  main.<fn>
  
00:00 +3 -2: Some tests failed.

Failing tests:
  test/plugins/tdd/commands/realize_command_test.dart: A3: a red real-binding run blocks the swap, rolls the rebind back, and the verdict names the side
  test/plugins/tdd/commands/realize_command_test.dart: A3b: a red baseline (mock era already broken) blocks before any rebind and blames the mock side

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```
- schema: 1
- prev-hash: genesis
- hash: 88aafeb75e9618cb3458a62657e0ee0c4f0203e9c99b34628d4d49ffdb2e28b5

## Cycle: U8-U10 (green)

- behavior: U8-U10
- kind: green
- classification: -
- criterion: SC-1
- test: test/plugins/tdd/services/contract_gate_test.dart
- command: `dart test test/plugins/tdd/services/contract_gate_test.dart`
- exit: 0
- at: 2026-09-03T08:30:20.583393Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/contract_gate_test.dart
00:00 +0: test/plugins/tdd/services/contract_gate_test.dart: U8: green when the suite is green against both bindings
00:00 +1: test/plugins/tdd/services/contract_gate_test.dart: U9: real-broke-contract when baseline green and real red
00:00 +2: test/plugins/tdd/services/contract_gate_test.dart: U10: mock-broke-contract when the baseline run is already red
00:00 +3: test/plugins/tdd/commands/realize_command_test.dart: A1: full green path rebinds DI, transitions era, persists state
00:00 +4: test/plugins/tdd/commands/realize_command_test.dart: A2: --adapter is required — a swap without a real adapter is refused
00:00 +5: test/plugins/tdd/commands/realize_command_test.dart: A6: a behavior id target resolves through the registry
00:00 +6: test/plugins/tdd/commands/realize_command_test.dart: A3: a red real-binding run blocks the swap, rolls the rebind back, and the verdict names the side
00:00 +7: test/plugins/tdd/commands/realize_command_test.dart: A3b: a red baseline (mock era already broken) blocks before any rebind and blames the mock side
00:00 +8: All tests passed!
```
- schema: 1
- prev-hash: 4a47d62cf29c92e9a33b68ff2febda98532340c2cd49160f3d46e5b7e99f9cb7
- hash: 0ac3bf6a3f29d9db2a8884573a463a2ffa25aa899786e17d332529c83ef19ebd

## Cycle: A3,A3b (green)

- behavior: A3,A3b
- kind: green
- classification: -
- criterion: SC-1
- test: test/plugins/tdd/commands/realize_command_test.dart
- command: `dart test test/plugins/tdd/commands/realize_command_test.dart`
- exit: 0
- at: 2026-09-03T08:30:21.136886Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/contract_gate_test.dart
00:00 +0: test/plugins/tdd/services/contract_gate_test.dart: U8: green when the suite is green against both bindings
00:00 +1: test/plugins/tdd/services/contract_gate_test.dart: U9: real-broke-contract when baseline green and real red
00:00 +2: test/plugins/tdd/services/contract_gate_test.dart: U10: mock-broke-contract when the baseline run is already red
00:00 +3: test/plugins/tdd/commands/realize_command_test.dart: A1: full green path rebinds DI, transitions era, persists state
00:00 +4: test/plugins/tdd/commands/realize_command_test.dart: A2: --adapter is required — a swap without a real adapter is refused
00:00 +5: test/plugins/tdd/commands/realize_command_test.dart: A6: a behavior id target resolves through the registry
00:00 +6: test/plugins/tdd/commands/realize_command_test.dart: A3: a red real-binding run blocks the swap, rolls the rebind back, and the verdict names the side
00:00 +7: test/plugins/tdd/commands/realize_command_test.dart: A3b: a red baseline (mock era already broken) blocks before any rebind and blames the mock side
00:00 +8: All tests passed!
```
- schema: 1
- prev-hash: 88aafeb75e9618cb3458a62657e0ee0c4f0203e9c99b34628d4d49ffdb2e28b5
- hash: 8694b60dd7b2b12e17c1d3fb3a6a5854094ec049c98f99ce5875a7e5fff229fa

## Cycle: U11-U13 (red)

- behavior: U11-U13
- kind: red
- classification: assertionFailure
- criterion: SC-2
- test: test/plugins/tdd/services/differential_gate_test.dart
- command: `dart test test/plugins/tdd/services/differential_gate_test.dart`
- exit: 1
- at: 2026-09-03T08:33:48.266515Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/differential_gate_test.dart
00:00 +0: U11: per-field drift report from committed fixtures
00:00 +0 -1: U11: per-field drift report from committed fixtures [E]
  UnimplementedError
  package:zuraffa/src/plugins/tdd/services/differential_gate.dart 102:7  DifferentialGate.run
  test/plugins/tdd/services/differential_gate_test.dart 74:33            main.<fn>
  
00:00 +0 -1: U12: threshold from .zfa.json — 0.5 tolerates the 0.2 drift
00:00 +0 -2: U12: threshold from .zfa.json — 0.5 tolerates the 0.2 drift [E]
  UnimplementedError
  package:zuraffa/src/plugins/tdd/services/differential_gate.dart 102:7  DifferentialGate.run
  test/plugins/tdd/services/differential_gate_test.dart 108:33           main.<fn>
  
00:00 +0 -2: U12b: default threshold 0.0 is strict — any drift fails
00:00 +0 -3: U12b: default threshold 0.0 is strict — any drift fails [E]
  UnimplementedError
  package:zuraffa/src/plugins/tdd/services/differential_gate.dart 102:7  DifferentialGate.run
  test/plugins/tdd/services/differential_gate_test.dart 119:33           main.<fn>
  
00:00 +0 -3: U13: a missing fixtures directory is skipped, never silently passed
00:00 +0 -4: U13: a missing fixtures directory is skipped, never silently passed [E]
  UnimplementedError
  package:zuraffa/src/plugins/tdd/services/differential_gate.dart 102:7  DifferentialGate.run
  test/plugins/tdd/services/differential_gate_test.dart 127:33           main.<fn>
  
00:00 +0 -4: Some tests failed.

Failing tests:
  test/plugins/tdd/services/differential_gate_test.dart: U11: per-field drift report from committed fixtures
  test/plugins/tdd/services/differential_gate_test.dart: U12: threshold from .zfa.json — 0.5 tolerates the 0.2 drift
  test/plugins/tdd/services/differential_gate_test.dart: U12b: default threshold 0.0 is strict — any drift fails
  test/plugins/tdd/services/differential_gate_test.dart: U13: a missing fixtures directory is skipped, never silently passed

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```
- schema: 1
- prev-hash: genesis
- hash: 5daba8d63284c58004741bec6c65cc1b4afd713ac0ea0b9d2845975db63e013f

## Cycle: A4a,A4b (red)

- behavior: A4a,A4b
- kind: red
- classification: assertionFailure
- criterion: SC-2
- test: test/plugins/tdd/commands/realize_command_test.dart
- command: `dart test test/plugins/tdd/commands/realize_command_test.dart`
- exit: 1
- at: 2026-09-03T08:33:48.776762Z
- output:
```
00:00 +0: loading test/plugins/tdd/commands/realize_command_test.dart
00:00 +0: A1: full green path rebinds DI, transitions era, persists state
00:00 +1: A2: --adapter is required — a swap without a real adapter is refused
00:00 +2: A6: a behavior id target resolves through the registry
00:00 +3: A3: a red real-binding run blocks the swap, rolls the rebind back, and the verdict names the side
00:00 +4: A3b: a red baseline (mock era already broken) blocks before any rebind and blames the mock side
00:00 +5: A4a: drift within the .zfa.json threshold passes with a drift report
00:00 +5 -1: A4a: drift within the .zfa.json threshold passes with a drift report [E]
  Expected: contains 'differential=pass'
    Actual: 'zfa tdd realize: entity User -> adapter UserRealAdapter\n'
              '   feature: 090-tdd-fixture\n'
              '   era: MOCKED\n'
              '   rebound: lib/src/di/datasources/user_mock_datasource_di.dart (2 site(s))\n'
              '   rebound: lib/src/di/repositories/user_repository_di.dart (1 site(s))\n'
              '   interface preserved: 1 domain file(s) byte-identical\n'
              '   contract gate green: the mock-era suite stays green against the real binding — the contract holds on both sides.\n'
              '   state: MOCKED -> REAL (/tmp/tdd_fixture_GPPRZM/specs/090-tdd-fixture/tdd/realize-state.json)\n'
              'realize: entity=User adapter=UserRealAdapter feature=090-tdd-fixture contract=green era=MOCKED->REAL result=realized'
     Which: does not contain 'differential=pass'
  
  package:matcher                                            expect
  test/plugins/tdd/commands/realize_command_test.dart 282:5  main.<fn>
  
00:00 +5 -1: A4b: drift beyond the .zfa.json threshold blocks the transition and rolls the rebind back
00:00 +5 -2: A4b: drift beyond the .zfa.json threshold blocks the transition and rolls the rebind back [E]
  Expected: <1>
    Actual: <0>
  out: zfa tdd realize: entity User -> adapter UserRealAdapter
     feature: 090-tdd-fixture
     era: MOCKED
     rebound: lib/src/di/datasources/user_mock_datasource_di.dart (2 site(s))
     rebound: lib/src/di/repositories/user_repository_di.dart (1 site(s))
     interface preserved: 1 domain file(s) byte-identical
     contract gate green: the mock-era suite stays green against the real binding — the contract holds on both sides.
     state: MOCKED -> REAL (/tmp/tdd_fixture_HYPKBN/specs/090-tdd-fixture/tdd/realize-state.json)
  realize: entity=User adapter=UserRealAdapter feature=090-tdd-fixture contract=green era=MOCKED->REAL result=realized
  
  package:matcher                                            expect
  test/plugins/tdd/commands/realize_command_test.dart 313:5  main.<fn>
  
00:00 +5 -2: Some tests failed.

Failing tests:
  test/plugins/tdd/commands/realize_command_test.dart: A4a: drift within the .zfa.json threshold passes with a drift report
  test/plugins/tdd/commands/realize_command_test.dart: A4b: drift beyond the .zfa.json threshold blocks the transition and rolls the rebind back

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```
- schema: 1
- prev-hash: genesis
- hash: 31a1455f63e8154744ca5be892836b1336b0a7e80b38441ff57470e7bd6989dd

## Cycle: U11-U13 (green)

- behavior: U11-U13
- kind: green
- classification: -
- criterion: SC-2
- test: test/plugins/tdd/services/differential_gate_test.dart
- command: `dart test test/plugins/tdd/services/differential_gate_test.dart`
- exit: 0
- at: 2026-09-03T08:36:47.831254Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/differential_gate_test.dart
00:00 +0: test/plugins/tdd/services/differential_gate_test.dart: U11: per-field drift report from committed fixtures
00:00 +1: test/plugins/tdd/services/differential_gate_test.dart: U12: threshold from .zfa.json — 0.5 tolerates the 0.2 drift
00:00 +2: test/plugins/tdd/services/differential_gate_test.dart: U12b: default threshold 0.0 is strict — any drift fails
00:00 +3: test/plugins/tdd/services/differential_gate_test.dart: U13: a missing fixtures directory is skipped, never silently passed
00:00 +4: test/plugins/tdd/commands/realize_command_test.dart: A1: full green path rebinds DI, transitions era, persists state
00:00 +5: test/plugins/tdd/commands/realize_command_test.dart: A2: --adapter is required — a swap without a real adapter is refused
00:00 +6: test/plugins/tdd/commands/realize_command_test.dart: A6: a behavior id target resolves through the registry
00:00 +7: test/plugins/tdd/commands/realize_command_test.dart: A3: a red real-binding run blocks the swap, rolls the rebind back, and the verdict names the side
00:00 +8: test/plugins/tdd/commands/realize_command_test.dart: A3b: a red baseline (mock era already broken) blocks before any rebind and blames the mock side
00:00 +9: test/plugins/tdd/commands/realize_command_test.dart: A4a: drift within the .zfa.json threshold passes with a drift report
00:00 +10: test/plugins/tdd/commands/realize_command_test.dart: A4b: drift beyond the .zfa.json threshold blocks the transition and rolls the rebind back
00:00 +11: All tests passed!
```
- schema: 1
- prev-hash: 5daba8d63284c58004741bec6c65cc1b4afd713ac0ea0b9d2845975db63e013f
- hash: d78cec9da309d7e778504a84739f9354df251a13b7d7c3d756825ea6e9f137a3

## Cycle: A4a,A4b (green)

- behavior: A4a,A4b
- kind: green
- classification: -
- criterion: SC-2
- test: test/plugins/tdd/commands/realize_command_test.dart
- command: `dart test test/plugins/tdd/commands/realize_command_test.dart`
- exit: 0
- at: 2026-09-03T08:36:48.524612Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/differential_gate_test.dart
00:00 +0: test/plugins/tdd/services/differential_gate_test.dart: U11: per-field drift report from committed fixtures
00:00 +1: test/plugins/tdd/services/differential_gate_test.dart: U12: threshold from .zfa.json — 0.5 tolerates the 0.2 drift
00:00 +2: test/plugins/tdd/services/differential_gate_test.dart: U12b: default threshold 0.0 is strict — any drift fails
00:00 +3: test/plugins/tdd/services/differential_gate_test.dart: U13: a missing fixtures directory is skipped, never silently passed
00:00 +4: test/plugins/tdd/commands/realize_command_test.dart: A1: full green path rebinds DI, transitions era, persists state
00:00 +5: test/plugins/tdd/commands/realize_command_test.dart: A2: --adapter is required — a swap without a real adapter is refused
00:00 +6: test/plugins/tdd/commands/realize_command_test.dart: A6: a behavior id target resolves through the registry
00:00 +7: test/plugins/tdd/commands/realize_command_test.dart: A3: a red real-binding run blocks the swap, rolls the rebind back, and the verdict names the side
00:00 +8: test/plugins/tdd/commands/realize_command_test.dart: A3b: a red baseline (mock era already broken) blocks before any rebind and blames the mock side
00:00 +9: test/plugins/tdd/commands/realize_command_test.dart: A4a: drift within the .zfa.json threshold passes with a drift report
00:00 +10: test/plugins/tdd/commands/realize_command_test.dart: A4b: drift beyond the .zfa.json threshold blocks the transition and rolls the rebind back
00:00 +11: All tests passed!
```
- schema: 1
- prev-hash: 31a1455f63e8154744ca5be892836b1336b0a7e80b38441ff57470e7bd6989dd
- hash: e19ad8e73efd154b25090d6d6fbb0d8437322430c7f8d4f68de1222026a247aa

## Cycle: U14-U16 (red)

- behavior: U14-U16
- kind: red
- classification: assertionFailure
- criterion: SC-3
- test: test/plugins/tdd/services/nuance_receipts_test.dart
- command: `dart test test/plugins/tdd/services/nuance_receipts_test.dart`
- exit: 1
- at: 2026-09-03T08:39:10.565006Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/nuance_receipts_test.dart
00:00 +0: U14: record() writes (file, reason, diff-hash) into the ledger
00:00 +0 -1: U14: record() writes (file, reason, diff-hash) into the ledger [E]
  UnimplementedError
  package:zuraffa/src/plugins/tdd/services/nuance_receipts.dart 97:9  NuanceReceipts.record
  test/plugins/tdd/services/nuance_receipts_test.dart 53:36           main.<fn>
  
00:00 +0 -1: U15: record() refuses an empty reason — reason is enforced
00:00 +0 -2: U15: record() refuses an empty reason — reason is enforced [E]
  Expected: throws <Instance of 'NuanceReceiptException'> with `message`: contains 'reason'
    Actual: <Closure: () => Future<LedgerEntry>>
     Which: threw UnimplementedError:<UnimplementedError>
            stack package:zuraffa/src/plugins/tdd/services/nuance_receipts.dart 97:9  NuanceReceipts.record
                  test/plugins/tdd/services/nuance_receipts_test.dart 85:24           main.<fn>.<fn>
                  package:matcher                                                     expect
                  test/plugins/tdd/services/nuance_receipts_test.dart 84:5            main.<fn>
                  
            which is not an instance of 'NuanceReceiptException'
  
  package:matcher                                           expect
  test/plugins/tdd/services/nuance_receipts_test.dart 84:5  main.<fn>
  
00:00 +0 -2: U16: detect() finds drifted and unreceipted hand-deltas
00:00 +0 -3: U16: detect() finds drifted and unreceipted hand-deltas [E]
  UnimplementedError
  package:zuraffa/src/plugins/tdd/services/nuance_receipts.dart 106:9  NuanceReceipts.detect
  test/plugins/tdd/services/nuance_receipts_test.dart 131:29           main.<fn>
  
00:00 +0 -3: Some tests failed.

Failing tests:
  test/plugins/tdd/services/nuance_receipts_test.dart: U14: record() writes (file, reason, diff-hash) into the ledger
  test/plugins/tdd/services/nuance_receipts_test.dart: U15: record() refuses an empty reason — reason is enforced
  test/plugins/tdd/services/nuance_receipts_test.dart: U16: detect() finds drifted and unreceipted hand-deltas

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```
- schema: 1
- prev-hash: genesis
- hash: caaefb8710422020778f6a628ef481690e068aea0d8239d3ac813bdba32bbd28

## Cycle: A5 (red)

- behavior: A5
- kind: red
- classification: assertionFailure
- criterion: SC-3
- test: test/plugins/tdd/commands/realize_command_test.dart
- command: `dart test test/plugins/tdd/commands/realize_command_test.dart`
- exit: 1
- at: 2026-09-03T08:39:11.080355Z
- output:
```
00:00 +0: loading test/plugins/tdd/commands/realize_command_test.dart
00:00 +0: A1: full green path rebinds DI, transitions era, persists state
00:00 +1: A2: --adapter is required — a swap without a real adapter is refused
00:00 +2: A6: a behavior id target resolves through the registry
00:00 +3: A3: a red real-binding run blocks the swap, rolls the rebind back, and the verdict names the side
00:00 +4: A3b: a red baseline (mock era already broken) blocks before any rebind and blames the mock side
00:00 +5: A4a: drift within the .zfa.json threshold passes with a drift report
00:00 +6: A4b: drift beyond the .zfa.json threshold blocks the transition and rolls the rebind back
00:00 +7: A5: ungated hand-deltas block the swap; gated deltas are recorded and the swap proceeds
00:00 +7 -1: A5: ungated hand-deltas block the swap; gated deltas are recorded and the swap proceeds [E]
  Expected: <1>
    Actual: <0>
  out: zfa tdd realize: entity User -> adapter UserRealAdapter
     feature: 090-tdd-fixture
     era: MOCKED
     rebound: lib/src/di/datasources/user_mock_datasource_di.dart (2 site(s))
     rebound: lib/src/di/repositories/user_repository_di.dart (1 site(s))
     interface preserved: 1 domain file(s) byte-identical
     contract gate green: the mock-era suite stays green against the real binding — the contract holds on both sides.
     differential gate skipped: no committed fixtures under specs/090-tdd-fixture/tdd/fixtures — the gate is marked skipped, never silently passed
     state: MOCKED -> REAL (/tmp/tdd_fixture_TDPZGZ/specs/090-tdd-fixture/tdd/realize-state.json)
  realize: entity=User adapter=UserRealAdapter feature=090-tdd-fixture contract=green differential=skipped drift=0.0 threshold=0.0 era=MOCKED->REAL result=realized
  
  package:matcher                                            expect
  test/plugins/tdd/commands/realize_command_test.dart 368:5  main.<fn>
  
00:00 +7 -1: Some tests failed.

Failing tests:
  test/plugins/tdd/commands/realize_command_test.dart: A5: ungated hand-deltas block the swap; gated deltas are recorded and the swap proceeds

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```
- schema: 1
- prev-hash: genesis
- hash: 0b0b5e30341453268307fe459fe69c3015c9dfc293606bb6368ab7c9f6bd1c05

## Cycle: U14-U16 (green)

- behavior: U14-U16
- kind: green
- classification: -
- criterion: SC-3
- test: test/plugins/tdd/services/nuance_receipts_test.dart
- command: `dart test test/plugins/tdd/services/nuance_receipts_test.dart`
- exit: 0
- at: 2026-09-03T08:43:29.421542Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/realize_state_test.dart
00:00 +0: test/plugins/tdd/services/realize_state_test.dart: U1: absent state file means era MOCKED (mock-first default)
00:00 +1: test/plugins/tdd/services/realize_state_test.dart: U2: transitionToReal persists era REAL with gate evidence
00:00 +2: test/plugins/tdd/services/realize_state_test.dart: U3: re-realizing the same adapter is idempotent
00:00 +3: test/plugins/tdd/services/di_rebind_test.dart: U4: scan finds the mock binding sites for the entity
00:00 +4: test/plugins/tdd/services/di_rebind_test.dart: U5: rebind swaps symbols, fixes imports, keeps domain untouched
00:00 +5: test/plugins/tdd/services/di_rebind_test.dart: U6: rebind refuses when the adapter class does not exist in lib/
00:00 +6: test/plugins/tdd/services/di_rebind_test.dart: U7: rebind refuses when there is no mock binding to swap
00:00 +7: test/plugins/tdd/services/contract_gate_test.dart: U8: green when the suite is green against both bindings
00:00 +8: test/plugins/tdd/services/contract_gate_test.dart: U9: real-broke-contract when baseline green and real red
00:00 +9: test/plugins/tdd/services/contract_gate_test.dart: U10: mock-broke-contract when the baseline run is already red
00:00 +10: test/plugins/tdd/services/nuance_receipts_test.dart: U14: record() writes (file, reason, diff-hash) into the ledger
00:00 +11: test/plugins/tdd/services/differential_gate_test.dart: U11: per-field drift report from committed fixtures
00:00 +12: test/plugins/tdd/services/differential_gate_test.dart: U11: per-field drift report from committed fixtures
00:00 +13: test/plugins/tdd/services/nuance_receipts_test.dart: U16: detect() finds drifted and unreceipted hand-deltas
00:00 +14: test/plugins/tdd/services/nuance_receipts_test.dart: U16: detect() finds drifted and unreceipted hand-deltas
00:00 +15: test/plugins/tdd/services/nuance_receipts_test.dart: U16: detect() finds drifted and unreceipted hand-deltas
00:00 +16: test/plugins/tdd/services/nuance_receipts_test.dart: U16: detect() finds drifted and unreceipted hand-deltas
00:00 +17: test/plugins/tdd/commands/realize_command_test.dart: A1: full green path rebinds DI, transitions era, persists state
00:01 +18: test/plugins/tdd/commands/realize_command_test.dart: A2: --adapter is required — a swap without a real adapter is refused
00:01 +19: test/plugins/tdd/commands/realize_command_test.dart: A6: a behavior id target resolves through the registry
00:01 +20: test/plugins/tdd/commands/realize_command_test.dart: A3: a red real-binding run blocks the swap, rolls the rebind back, and the verdict names the side
00:01 +21: test/plugins/tdd/commands/realize_command_test.dart: A3b: a red baseline (mock era already broken) blocks before any rebind and blames the mock side
00:01 +22: test/plugins/tdd/commands/realize_command_test.dart: A4a: drift within the .zfa.json threshold passes with a drift report
00:01 +23: test/plugins/tdd/commands/realize_command_test.dart: A4b: drift beyond the .zfa.json threshold blocks the transition and rolls the rebind back
00:01 +24: test/plugins/tdd/commands/realize_command_test.dart: A5: ungated hand-deltas block the swap; gated deltas are recorded and the swap proceeds
00:01 +25: All tests passed!
```
- schema: 1
- prev-hash: caaefb8710422020778f6a628ef481690e068aea0d8239d3ac813bdba32bbd28
- hash: ab811583236f84f7049ae55c60cdbbd5f04c5fe307832455c75c52f5f42bc814

## Cycle: A5 (green)

- behavior: A5
- kind: green
- classification: -
- criterion: SC-3
- test: test/plugins/tdd/commands/realize_command_test.dart
- command: `dart test test/plugins/tdd/commands/realize_command_test.dart`
- exit: 0
- at: 2026-09-03T08:43:29.939689Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/realize_state_test.dart
00:00 +0: test/plugins/tdd/services/realize_state_test.dart: U1: absent state file means era MOCKED (mock-first default)
00:00 +1: test/plugins/tdd/services/realize_state_test.dart: U2: transitionToReal persists era REAL with gate evidence
00:00 +2: test/plugins/tdd/services/realize_state_test.dart: U3: re-realizing the same adapter is idempotent
00:00 +3: test/plugins/tdd/services/di_rebind_test.dart: U4: scan finds the mock binding sites for the entity
00:00 +4: test/plugins/tdd/services/di_rebind_test.dart: U5: rebind swaps symbols, fixes imports, keeps domain untouched
00:00 +5: test/plugins/tdd/services/di_rebind_test.dart: U6: rebind refuses when the adapter class does not exist in lib/
00:00 +6: test/plugins/tdd/services/di_rebind_test.dart: U7: rebind refuses when there is no mock binding to swap
00:00 +7: test/plugins/tdd/services/contract_gate_test.dart: U8: green when the suite is green against both bindings
00:00 +8: test/plugins/tdd/services/contract_gate_test.dart: U9: real-broke-contract when baseline green and real red
00:00 +9: test/plugins/tdd/services/contract_gate_test.dart: U10: mock-broke-contract when the baseline run is already red
00:00 +10: test/plugins/tdd/services/nuance_receipts_test.dart: U14: record() writes (file, reason, diff-hash) into the ledger
00:00 +11: test/plugins/tdd/services/differential_gate_test.dart: U11: per-field drift report from committed fixtures
00:00 +12: test/plugins/tdd/services/differential_gate_test.dart: U11: per-field drift report from committed fixtures
00:00 +13: test/plugins/tdd/services/nuance_receipts_test.dart: U16: detect() finds drifted and unreceipted hand-deltas
00:00 +14: test/plugins/tdd/services/nuance_receipts_test.dart: U16: detect() finds drifted and unreceipted hand-deltas
00:00 +15: test/plugins/tdd/services/nuance_receipts_test.dart: U16: detect() finds drifted and unreceipted hand-deltas
00:00 +16: test/plugins/tdd/services/nuance_receipts_test.dart: U16: detect() finds drifted and unreceipted hand-deltas
00:00 +17: test/plugins/tdd/commands/realize_command_test.dart: A1: full green path rebinds DI, transitions era, persists state
00:01 +18: test/plugins/tdd/commands/realize_command_test.dart: A2: --adapter is required — a swap without a real adapter is refused
00:01 +19: test/plugins/tdd/commands/realize_command_test.dart: A6: a behavior id target resolves through the registry
00:01 +20: test/plugins/tdd/commands/realize_command_test.dart: A3: a red real-binding run blocks the swap, rolls the rebind back, and the verdict names the side
00:01 +21: test/plugins/tdd/commands/realize_command_test.dart: A3b: a red baseline (mock era already broken) blocks before any rebind and blames the mock side
00:01 +22: test/plugins/tdd/commands/realize_command_test.dart: A4a: drift within the .zfa.json threshold passes with a drift report
00:01 +23: test/plugins/tdd/commands/realize_command_test.dart: A4b: drift beyond the .zfa.json threshold blocks the transition and rolls the rebind back
00:01 +24: test/plugins/tdd/commands/realize_command_test.dart: A5: ungated hand-deltas block the swap; gated deltas are recorded and the swap proceeds
00:01 +25: All tests passed!
```
- schema: 1
- prev-hash: 0b0b5e30341453268307fe459fe69c3015c9dfc293606bb6368ab7c9f6bd1c05
- hash: 2656c362b254e63c9fa01e35dfc9e6b435b136b93d3567d2cffc97877b9566de

