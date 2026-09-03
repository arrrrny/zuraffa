# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: 0806-replay-A1 (red)

- behavior: 0806-replay-A1
- kind: red
- classification: assertionFailure
- criterion: SC1
- test: test/plugins/tdd/services/replay_paths_test.dart::A1
- command: `dart test <0806 suite>`
- exit: 1
- at: 2026-09-03T14:58:37.448863Z
- output:
```
^^^^^^^
  test/plugins/tdd/services/replay_anchor_test.dart:219:9: Error: No named parameter with the name 'recordedRoot'.
          recordedRoot: recordedRoot,
          ^^^^^^^^^^^^
  lib/src/plugins/tdd/services/replay_sandbox.dart:25:32: Context: Found this candidate, but the arguments don't match.
    static Future<ReplaySandbox> create({
                                 ^^^^^^
00:00 +0 -2: Some tests failed.

Failing tests:
  test/plugins/tdd/services/replay_anchor_test.dart: loading test/plugins/tdd/services/replay_anchor_test.dart
  test/plugins/tdd/services/replay_paths_test.dart: loading test/plugins/tdd/services/replay_paths_test.dart
```

- schema: 1
- prev-hash: genesis
- hash: 94a5c2cea0b50d7686f1dcf063868e31dd7b33a9738ef74c4bba042bd26fd4e7

## Cycle: 0806-replay-A2 (red)

- behavior: 0806-replay-A2
- kind: red
- classification: assertionFailure
- criterion: SC2
- test: test/plugins/ttd/scenarios/sc_023_replay_path_stable_test.dart::A2
- command: `dart test test/plugins/ttd/scenarios/sc_023_replay_path_stable_test.dart --preset=integration`
- exit: 1
- at: 2026-09-03T14:58:50.106436Z
- output:
```
00:00 +0 -2: SC-023: a leaked registry anchor is a named runner-error (the fake zfa refuses)
00:00 +1 -2: Some tests failed.

Failing tests:
  test/plugins/tdd/scenarios/sc_023_replay_path_stable_test.dart: SC-023: a recorded-elsewhere full history replays clean
  test/plugins/tdd/scenarios/sc_023_replay_path_stable_test.dart: SC-023: an injected mutation into a re-anchored step is caught, path named

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: f6000e870b4aa327664d756410e4827df26b553a80eb45e353a817378f66d8e4

## Cycle: 0806-replay-U1 (red)

- behavior: 0806-replay-U1
- kind: red
- classification: assertionFailure
- criterion: FR-001
- test: test/plugins/tdd/services/replay_paths_test.dart::U1
- command: `dart test test/plugins/tdd/services/replay_paths_test.dart`
- exit: 1
- at: 2026-09-03T14:58:50.743541Z
- output:
```
^^^^^
  test/plugins/tdd/services/replay_paths_test.dart:206:24: Error: Undefined name 'ReplayPaths'.
        final resolved = ReplayPaths.resolveTestPath(
                         ^^^^^^^^^^^
  test/plugins/tdd/services/replay_paths_test.dart:216:9: Error: Undefined name 'ReplayPaths'.
          ReplayPaths.resolveTestPath(
          ^^^^^^^^^^^
  test/plugins/tdd/services/replay_paths_test.dart:224:9: Error: Undefined name 'ReplayPaths'.
          ReplayPaths.resolveTestPath(
          ^^^^^^^^^^^
00:00 +0 -1: Some tests failed.

Failing tests:
  test/plugins/tdd/services/replay_paths_test.dart: loading test/plugins/tdd/services/replay_paths_test.dart
```

- schema: 1
- prev-hash: genesis
- hash: 5d37fb8d072cb377854b920a4e2f418438f9d175d83ff00b0a5b1f4f972bd091

## Cycle: 0806-replay-U2 (red)

- behavior: 0806-replay-U2
- kind: red
- classification: assertionFailure
- criterion: FR-002
- test: test/plugins/tdd/services/replay_anchor_test.dart::U2
- command: `dart test test/plugins/tdd/services/replay_anchor_test.dart`
- exit: 1
- at: 2026-09-03T14:58:51.408298Z
- output:
```
Failed to load "test/plugins/tdd/services/replay_anchor_test.dart":
  test/plugins/tdd/services/replay_anchor_test.dart:90:9: Error: No named parameter with the name 'recordedRoot'.
  test/plugins/tdd/services/replay_anchor_test.dart:122:9: Error: No named parameter with the name 'recordedRoot'.
  test/plugins/tdd/services/replay_anchor_test.dart:172:9: Error: No named parameter with the name 'recordedRoot'.
  test/plugins/tdd/services/replay_anchor_test.dart:188:40: Error: 'default' can't be used as an identifier because it's a keyword.
```

- schema: 1
- prev-hash: genesis
- hash: d639bce7ae5ab5d887c2d05a69fc57e2eace3e51f521a6eab643d547705b8716

## Cycle: 0806-replay-U3 (red)

- behavior: 0806-replay-U3
- kind: red
- classification: assertionFailure
- criterion: FR-004
- test: test/plugins/tdd/services/replay_paths_test.dart::U3
- command: `dart test test/plugins/tdd/services/replay_paths_test.dart`
- exit: 1
- at: 2026-09-03T14:58:51.999318Z
- output:
```
^^^^^
  test/plugins/tdd/services/replay_paths_test.dart:206:24: Error: Undefined name 'ReplayPaths'.
        final resolved = ReplayPaths.resolveTestPath(
                         ^^^^^^^^^^^
  test/plugins/tdd/services/replay_paths_test.dart:216:9: Error: Undefined name 'ReplayPaths'.
          ReplayPaths.resolveTestPath(
          ^^^^^^^^^^^
  test/plugins/tdd/services/replay_paths_test.dart:224:9: Error: Undefined name 'ReplayPaths'.
          ReplayPaths.resolveTestPath(
          ^^^^^^^^^^^
00:00 +0 -1: Some tests failed.

Failing tests:
  test/plugins/tdd/services/replay_paths_test.dart: loading test/plugins/tdd/services/replay_paths_test.dart
```

- schema: 1
- prev-hash: genesis
- hash: b606ba964cf59523befeddaf06fcc59fd4d971504fef4b424b670eaab3abcd13

## Cycle: 0806-replay-U4 (red)

- behavior: 0806-replay-U4
- kind: red
- classification: assertionFailure
- criterion: FR-003
- test: test/plugins/tdd/services/replay_paths_test.dart::U4
- command: `dart test test/plugins/tdd/services/replay_paths_test.dart`
- exit: 1
- at: 2026-09-03T14:58:52.549155Z
- output:
```
^^^^^
  test/plugins/tdd/services/replay_paths_test.dart:206:24: Error: Undefined name 'ReplayPaths'.
        final resolved = ReplayPaths.resolveTestPath(
                         ^^^^^^^^^^^
  test/plugins/tdd/services/replay_paths_test.dart:216:9: Error: Undefined name 'ReplayPaths'.
          ReplayPaths.resolveTestPath(
          ^^^^^^^^^^^
  test/plugins/tdd/services/replay_paths_test.dart:224:9: Error: Undefined name 'ReplayPaths'.
          ReplayPaths.resolveTestPath(
          ^^^^^^^^^^^
00:00 +0 -1: Some tests failed.

Failing tests:
  test/plugins/tdd/services/replay_paths_test.dart: loading test/plugins/tdd/services/replay_paths_test.dart
```

- schema: 1
- prev-hash: genesis
- hash: 8eac8b6a36a79c4b19e68e8065e2af4dd1e29649ef743655b31fcfd8d028160c

## Cycle: 0806-replay-U5 (red)

- behavior: 0806-replay-U5
- kind: red
- classification: assertionFailure
- criterion: FR-005
- test: test/plugins/tdd/services/replay_anchor_test.dart::U5
- command: `dart test test/plugins/tdd/services/replay_anchor_test.dart`
- exit: 1
- at: 2026-09-03T14:58:53.107267Z
- output:
```
Failed to load "test/plugins/tdd/services/replay_anchor_test.dart":
  test/plugins/tdd/services/replay_anchor_test.dart:90:9: Error: No named parameter with the name 'recordedRoot'.
  test/plugins/tdd/services/replay_anchor_test.dart:122:9: Error: No named parameter with the name 'recordedRoot'.
  test/plugins/tdd/services/replay_anchor_test.dart:172:9: Error: No named parameter with the name 'recordedRoot'.
  test/plugins/tdd/services/replay_anchor_test.dart:188:40: Error: 'default' can't be used as an identifier because it's a keyword.
```

- schema: 1
- prev-hash: genesis
- hash: d5bf6778729ce1d8071dcf2422cb8145d19e426b982f63a8cffc066bdb49abcf

## Cycle: 0806-replay-U6 (red)

- behavior: 0806-replay-U6
- kind: red
- classification: assertionFailure
- criterion: FR-006
- test: test/commands/entity_convergent_test.dart::U6
- command: `dart test test/commands/entity_convergent_test.dart`
- exit: 1
- at: 2026-09-03T14:58:53.653444Z
- output:
```
the convergent skip is reported, not silent
  
  package:matcher                                 expect
  test/commands/entity_convergent_test.dart 87:7  main.<fn>
  
00:00 +0 -1: U6: a fresh create still writes the entity (the loop contract)
00:00 +1 -1: (tearDownAll)
00:00 +1 -1: Some tests failed.

Failing tests:
  test/commands/entity_convergent_test.dart: U6: an existing entity file is skipped (exit 0, bytes untouched)

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 90c4eef51373caa93a37992903453993d61fe0552ddf3b71678685a14954938e

## Cycle: 0806-replay-U7 (red)

- behavior: 0806-replay-U7
- kind: red
- classification: assertionFailure
- criterion: FR-006
- test: test/plugins/tdd/commands/func_convergent_test.dart::U7
- command: `dart test test/plugins/tdd/commands/func_convergent_test.dart`
- exit: 1
- at: 2026-09-03T14:58:54.207190Z
- output:
```
func: behavior=B-001 outcome=runner-error feature=090-tdd-fixture
  
  
  package:matcher                                           expect
  test/plugins/tdd/commands/func_convergent_test.dart 64:7  main.<fn>
  
00:00 +0 -1: U7: a genuine unrecognized throw still refuses with exit 1 (never guess at a shape func did not generate)
00:00 +1 -1: Some tests failed.

Failing tests:
  test/plugins/tdd/commands/func_convergent_test.dart: U7: an implemented subject whose doc comment mentions UnimplementedError is already-implemented, exit 0

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 2aebac67736bb902711c5ad1fd9ee4c261f16a17d720c7910f421da4d9728f8e

## Cycle: 0806-replay-A1 (green)

- behavior: 0806-replay-A1
- kind: green
- criterion: SC1
- test: test/plugins/tdd/scenarios/sc_023_replay_path_stable_test.dart::A1
- command: `dart test test/plugins/tdd/scenarios/sc_023_replay_path_stable_test.dart --preset=integration`
- exit: 0
- at: 2026-09-03T15:42:50.835922Z
- output:
```
00:00 +1: SC-023: an injected mutation into a re-anchored step is caught, path named
00:00 +2: SC-023: a leaked registry anchor is a named runner-error (the fake zfa refuses)
00:00 +3: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 94a5c2cea0b50d7686f1dcf063868e31dd7b33a9738ef74c4bba042bd26fd4e7
- hash: 778f901e74e1d4393e89f66183fc483fc8afe1f5acc11e9f3eaf525eb9a39d62

## Cycle: 0806-replay-A2 (green)

- behavior: 0806-replay-A2
- kind: green
- criterion: SC2
- test: test/plugins/tdd/scenarios/sc_023_replay_path_stable_test.dart::A2
- command: `dart test test/plugins/tdd/scenarios/sc_023_replay_path_stable_test.dart --preset=integration`
- exit: 0
- at: 2026-09-03T15:42:51.427592Z
- output:
```
00:00 +1: SC-023: an injected mutation into a re-anchored step is caught, path named
00:00 +2: SC-023: a leaked registry anchor is a named runner-error (the fake zfa refuses)
00:00 +3: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: f6000e870b4aa327664d756410e4827df26b553a80eb45e353a817378f66d8e4
- hash: 79451cac3a0aa132ce366716c853ef38bcb6c165eb05292191d27528a3e4d559

## Cycle: 0806-replay-U1 (green)

- behavior: 0806-replay-U1
- kind: green
- criterion: FR-001
- test: test/plugins/tdd/services/replay_paths_test.dart::U1
- command: `dart test test/plugins/tdd/services/replay_paths_test.dart`
- exit: 0
- at: 2026-09-03T15:42:52.053394Z
- output:
```
00:00 +17: U2 (path half): resolveTestPath relative and anchor-less paths pass through
00:00 +18: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 5d37fb8d072cb377854b920a4e2f418438f9d175d83ff00b0a5b1f4f972bd091
- hash: 377d2390121334723bfcb078a50637ef4be3c879f8216d669b4d596e460d64c1

## Cycle: 0806-replay-U2 (green)

- behavior: 0806-replay-U2
- kind: green
- criterion: FR-002
- test: test/plugins/tdd/services/replay_anchor_test.dart::U2
- command: `dart test test/plugins/tdd/services/replay_anchor_test.dart`
- exit: 0
- at: 2026-09-03T15:42:52.627972Z
- output:
```
00:00 +5: U5: ReplaySandbox re-anchors the copied registry an anchor-less registry copies verbatim
00:00 +6: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: d639bce7ae5ab5d887c2d05a69fc57e2eace3e51f521a6eab643d547705b8716
- hash: abadb0589dc0577a8c073804e47967b9cdf0ee4aa7d09730cc8ed0ec602bb1ed

## Cycle: 0806-replay-U3 (green)

- behavior: 0806-replay-U3
- kind: green
- criterion: FR-004
- test: test/plugins/tdd/services/replay_paths_test.dart::U3
- command: `dart test test/plugins/tdd/services/replay_paths_test.dart`
- exit: 0
- at: 2026-09-03T15:42:53.243439Z
- output:
```
00:00 +17: U2 (path half): resolveTestPath relative and anchor-less paths pass through
00:00 +18: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: b606ba964cf59523befeddaf06fcc59fd4d971504fef4b424b670eaab3abcd13
- hash: 5f6e97a4dc7400d0bb11d7626c8dda9736b800bd5a4ee46d41346f1584b25d0e

## Cycle: 0806-replay-U4 (green)

- behavior: 0806-replay-U4
- kind: green
- criterion: FR-003
- test: test/plugins/tdd/services/replay_paths_test.dart::U4
- command: `dart test test/plugins/tdd/services/replay_paths_test.dart`
- exit: 0
- at: 2026-09-03T15:42:53.843818Z
- output:
```
00:00 +17: U2 (path half): resolveTestPath relative and anchor-less paths pass through
00:00 +18: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 8eac8b6a36a79c4b19e68e8065e2af4dd1e29649ef743655b31fcfd8d028160c
- hash: 5ce6eb3d8d30d7acf1b1e0a7d95837e9cccd5b70cd7fe7c64b7c9d34f94135cd

## Cycle: 0806-replay-U5 (green)

- behavior: 0806-replay-U5
- kind: green
- criterion: FR-005
- test: test/plugins/tdd/services/replay_anchor_test.dart::U5
- command: `dart test test/plugins/tdd/services/replay_anchor_test.dart`
- exit: 0
- at: 2026-09-03T15:42:54.495707Z
- output:
```
00:00 +5: U5: ReplaySandbox re-anchors the copied registry an anchor-less registry copies verbatim
00:00 +6: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: d5bf6778729ce1d8071dcf2422cb8145d19e426b982f63a8cffc066bdb49abcf
- hash: 94c8bde40c2d62e37473c3a16860021e54f692a6df16379cb7231541828090bd

## Cycle: 0806-replay-U6 (green)

- behavior: 0806-replay-U6
- kind: green
- criterion: FR-006
- test: test/commands/entity_convergent_test.dart::U6
- command: `dart test test/commands/entity_convergent_test.dart`
- exit: 0
- at: 2026-09-03T15:42:55.116342Z
- output:
```
00:00 +2: (tearDownAll)
00:00 +2: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 90c4eef51373caa93a37992903453993d61fe0552ddf3b71678685a14954938e
- hash: 991b37dfea43062d25dbc400e683b24497e672cb2d68f275a33cc60bf546592a

## Cycle: 0806-replay-U7 (green)

- behavior: 0806-replay-U7
- kind: green
- criterion: FR-006
- test: test/plugins/tdd/commands/func_convergent_test.dart::U7
- command: `dart test test/plugins/tdd/commands/func_convergent_test.dart`
- exit: 0
- at: 2026-09-03T15:42:55.700758Z
- output:
```
00:00 +1: U7: a genuine unrecognized throw still refuses with exit 1 (never guess at a shape func did not generate)
00:00 +2: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 2aebac67736bb902711c5ad1fd9ee4c261f16a17d720c7910f421da4d9728f8e
- hash: f9003c38f23bf7967a6242a74d6c873b803bd0ba0324a7af080f5e0132ab262a

## Cycle: 0806-replay-refactor (refactor)

- behavior: 0806-replay-refactor
- kind: refactor
- criterion: FR-007
- test: test/
- command: `dart format lib/src/plugins/ttd/services/ lib/src/plugins/tdd/commands/func_command.dart lib/src/commands/entity_command.dart test/plugins/ttd/ test/commands/entity_convergent_test.dart`
- exit: 0
- at: 2026-09-03T17:13:57.006376Z
- output:
```
refactor pass: removed the dead bare-zfa substitution in runGen (subsumed by ReplayPaths.reAnchorEntrypoint); test assertions tightened to the documented contract; dart format over the touched files; gates re-run green
```

- schema: 1
- prev-hash: genesis
- hash: 1e9fc103582400b7e85a63ab58671a4dcbd7140ee5b679290986932e16c5d4dd

