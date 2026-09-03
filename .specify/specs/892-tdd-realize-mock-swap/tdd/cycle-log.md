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

