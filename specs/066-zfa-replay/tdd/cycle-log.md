# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: 066-replay-A1 (red)

- behavior: 066-replay-A1
- kind: red
- classification: loadError
- criterion: SC1
- test: test/plugins/tdd/commands/replay_command_test.dart::A1
- command: `dart test test/plugins/tdd/services/replay_history_test.dart test/plugins/tdd/services/replay_sandbox_test.dart test/plugins/tdd/services/replay_runner_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 1
- at: 2026-09-02T21:57:47.133989Z
- output:
```
00:00 +0 -4: loading test/plugins/tdd/commands/replay_command_test.dart [E]
  Failed to load "test/plugins/tdd/commands/replay_command_test.dart":
  .../replay_command_test.dart:17:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_history_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_history_test.dart":
  .../replay_history_test.dart:16:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_runner_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_runner_test.dart":
  .../replay_runner_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_runner.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_sandbox_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_sandbox_test.dart":
  .../replay_sandbox_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_sandbox.dart': No such file or directory
00:00 +0 -4: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: c94c953a5d5d4858447dc3acf7ff5660fe83cab0730349d0aae4b2a522019376

## Cycle: 066-replay-A2 (red)

- behavior: 066-replay-A2
- kind: red
- classification: loadError
- criterion: SC2
- test: test/plugins/tdd/commands/replay_command_test.dart::A2
- command: `dart test test/plugins/tdd/services/replay_history_test.dart test/plugins/tdd/services/replay_sandbox_test.dart test/plugins/tdd/services/replay_runner_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 1
- at: 2026-09-02T21:57:47.170234Z
- output:
```
00:00 +0 -4: loading test/plugins/tdd/commands/replay_command_test.dart [E]
  Failed to load "test/plugins/tdd/commands/replay_command_test.dart":
  .../replay_command_test.dart:17:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_history_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_history_test.dart":
  .../replay_history_test.dart:16:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_runner_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_runner_test.dart":
  .../replay_runner_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_runner.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_sandbox_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_sandbox_test.dart":
  .../replay_sandbox_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_sandbox.dart': No such file or directory
00:00 +0 -4: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: 2012e52900b40af954716e6738d13e4e6c6680df92a6f1bdb39e037cb076fdbb

## Cycle: 066-replay-A3 (red)

- behavior: 066-replay-A3
- kind: red
- classification: loadError
- criterion: SC3
- test: test/plugins/tdd/commands/replay_command_test.dart::A3
- command: `dart test test/plugins/tdd/services/replay_history_test.dart test/plugins/tdd/services/replay_sandbox_test.dart test/plugins/tdd/services/replay_runner_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 1
- at: 2026-09-02T21:57:47.173125Z
- output:
```
00:00 +0 -4: loading test/plugins/tdd/commands/replay_command_test.dart [E]
  Failed to load "test/plugins/tdd/commands/replay_command_test.dart":
  .../replay_command_test.dart:17:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_history_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_history_test.dart":
  .../replay_history_test.dart:16:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_runner_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_runner_test.dart":
  .../replay_runner_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_runner.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_sandbox_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_sandbox_test.dart":
  .../replay_sandbox_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_sandbox.dart': No such file or directory
00:00 +0 -4: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: e8824dd4a82921a5111235c37fe4118f6c31c2a43545a65086c9972b4e93f26a

## Cycle: 066-replay-A4 (red)

- behavior: 066-replay-A4
- kind: red
- classification: loadError
- criterion: SC4
- test: test/plugins/tdd/commands/replay_command_test.dart::A4
- command: `dart test test/plugins/tdd/services/replay_history_test.dart test/plugins/tdd/services/replay_sandbox_test.dart test/plugins/tdd/services/replay_runner_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 1
- at: 2026-09-02T21:57:47.174681Z
- output:
```
00:00 +0 -4: loading test/plugins/tdd/commands/replay_command_test.dart [E]
  Failed to load "test/plugins/tdd/commands/replay_command_test.dart":
  .../replay_command_test.dart:17:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_history_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_history_test.dart":
  .../replay_history_test.dart:16:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_runner_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_runner_test.dart":
  .../replay_runner_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_runner.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_sandbox_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_sandbox_test.dart":
  .../replay_sandbox_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_sandbox.dart': No such file or directory
00:00 +0 -4: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: b5ff85df8e10455bdf4b3a0e734b4de5af6c7193e0b903c51b29a61e8747bd5c

## Cycle: 066-replay-A5 (red)

- behavior: 066-replay-A5
- kind: red
- classification: loadError
- criterion: SC5
- test: test/plugins/tdd/commands/replay_command_test.dart::A5
- command: `dart test test/plugins/tdd/services/replay_history_test.dart test/plugins/tdd/services/replay_sandbox_test.dart test/plugins/tdd/services/replay_runner_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 1
- at: 2026-09-02T21:57:47.176446Z
- output:
```
00:00 +0 -4: loading test/plugins/tdd/commands/replay_command_test.dart [E]
  Failed to load "test/plugins/tdd/commands/replay_command_test.dart":
  .../replay_command_test.dart:17:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_history_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_history_test.dart":
  .../replay_history_test.dart:16:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_runner_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_runner_test.dart":
  .../replay_runner_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_runner.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_sandbox_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_sandbox_test.dart":
  .../replay_sandbox_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_sandbox.dart': No such file or directory
00:00 +0 -4: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: 3e3c33e4da1e324ae7b53d744111ccba2f304ef11662e481884997688ba8d23a

## Cycle: 066-replay-A6 (red)

- behavior: 066-replay-A6
- kind: red
- classification: loadError
- criterion: SC6
- test: test/plugins/tdd/commands/replay_command_test.dart::A6
- command: `dart test test/plugins/tdd/services/replay_history_test.dart test/plugins/tdd/services/replay_sandbox_test.dart test/plugins/tdd/services/replay_runner_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 1
- at: 2026-09-02T21:57:47.177879Z
- output:
```
00:00 +0 -4: loading test/plugins/tdd/commands/replay_command_test.dart [E]
  Failed to load "test/plugins/tdd/commands/replay_command_test.dart":
  .../replay_command_test.dart:17:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_history_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_history_test.dart":
  .../replay_history_test.dart:16:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_runner_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_runner_test.dart":
  .../replay_runner_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_runner.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_sandbox_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_sandbox_test.dart":
  .../replay_sandbox_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_sandbox.dart': No such file or directory
00:00 +0 -4: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: 77020ef06a4d670a2d09be113e577e89f5a949d1951cbb9b1b0e24956a07086e

## Cycle: 066-replay-A7 (red)

- behavior: 066-replay-A7
- kind: red
- classification: loadError
- criterion: SC7
- test: test/plugins/tdd/commands/replay_command_test.dart::A7
- command: `dart test test/plugins/tdd/services/replay_history_test.dart test/plugins/tdd/services/replay_sandbox_test.dart test/plugins/tdd/services/replay_runner_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 1
- at: 2026-09-02T21:57:47.182619Z
- output:
```
00:00 +0 -4: loading test/plugins/tdd/commands/replay_command_test.dart [E]
  Failed to load "test/plugins/tdd/commands/replay_command_test.dart":
  .../replay_command_test.dart:17:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_history_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_history_test.dart":
  .../replay_history_test.dart:16:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_runner_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_runner_test.dart":
  .../replay_runner_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_runner.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_sandbox_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_sandbox_test.dart":
  .../replay_sandbox_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_sandbox.dart': No such file or directory
00:00 +0 -4: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: e9a1fb7fda0fbf47cbd8a772eef911c51ab6e3bf1261fd707a60b39a03ab9565

## Cycle: 066-replay-U1 (red)

- behavior: 066-replay-U1
- kind: red
- classification: loadError
- criterion: FR-002, FR-003
- test: test/plugins/tdd/services/replay_history_test.dart::U1
- command: `dart test test/plugins/tdd/services/replay_history_test.dart test/plugins/tdd/services/replay_sandbox_test.dart test/plugins/tdd/services/replay_runner_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 1
- at: 2026-09-02T21:57:47.183638Z
- output:
```
00:00 +0 -4: loading test/plugins/tdd/commands/replay_command_test.dart [E]
  Failed to load "test/plugins/tdd/commands/replay_command_test.dart":
  .../replay_command_test.dart:17:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_history_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_history_test.dart":
  .../replay_history_test.dart:16:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_runner_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_runner_test.dart":
  .../replay_runner_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_runner.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_sandbox_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_sandbox_test.dart":
  .../replay_sandbox_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_sandbox.dart': No such file or directory
00:00 +0 -4: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: c910ed8caa5e16000b2096b819fc2fe1d8977e292fbac9d2b3137b686f1d64c3

## Cycle: 066-replay-U2 (red)

- behavior: 066-replay-U2
- kind: red
- classification: loadError
- criterion: FR-008
- test: test/plugins/tdd/services/replay_history_test.dart::U2
- command: `dart test test/plugins/tdd/services/replay_history_test.dart test/plugins/tdd/services/replay_sandbox_test.dart test/plugins/tdd/services/replay_runner_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 1
- at: 2026-09-02T21:57:47.184782Z
- output:
```
00:00 +0 -4: loading test/plugins/tdd/commands/replay_command_test.dart [E]
  Failed to load "test/plugins/tdd/commands/replay_command_test.dart":
  .../replay_command_test.dart:17:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_history_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_history_test.dart":
  .../replay_history_test.dart:16:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_runner_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_runner_test.dart":
  .../replay_runner_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_runner.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_sandbox_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_sandbox_test.dart":
  .../replay_sandbox_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_sandbox.dart': No such file or directory
00:00 +0 -4: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: 4cb6a1e99bed872437058ddc4e8f41a18f15fa4d0ff77d3646473973b4a825ae

## Cycle: 066-replay-U3 (red)

- behavior: 066-replay-U3
- kind: red
- classification: loadError
- criterion: FR-004
- test: test/plugins/tdd/services/replay_history_test.dart::U3
- command: `dart test test/plugins/tdd/services/replay_history_test.dart test/plugins/tdd/services/replay_sandbox_test.dart test/plugins/tdd/services/replay_runner_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 1
- at: 2026-09-02T21:57:47.185735Z
- output:
```
00:00 +0 -4: loading test/plugins/tdd/commands/replay_command_test.dart [E]
  Failed to load "test/plugins/tdd/commands/replay_command_test.dart":
  .../replay_command_test.dart:17:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_history_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_history_test.dart":
  .../replay_history_test.dart:16:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_runner_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_runner_test.dart":
  .../replay_runner_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_runner.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_sandbox_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_sandbox_test.dart":
  .../replay_sandbox_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_sandbox.dart': No such file or directory
00:00 +0 -4: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: da72c61564896ca0a49a95b57d375a855602cb16f00cd5c099566cf9b3eee122

## Cycle: 066-replay-U4 (red)

- behavior: 066-replay-U4
- kind: red
- classification: loadError
- criterion: FR-005
- test: test/plugins/tdd/services/replay_history_test.dart::U4
- command: `dart test test/plugins/tdd/services/replay_history_test.dart test/plugins/tdd/services/replay_sandbox_test.dart test/plugins/tdd/services/replay_runner_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 1
- at: 2026-09-02T21:57:47.186837Z
- output:
```
00:00 +0 -4: loading test/plugins/tdd/commands/replay_command_test.dart [E]
  Failed to load "test/plugins/tdd/commands/replay_command_test.dart":
  .../replay_command_test.dart:17:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_history_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_history_test.dart":
  .../replay_history_test.dart:16:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_runner_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_runner_test.dart":
  .../replay_runner_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_runner.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_sandbox_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_sandbox_test.dart":
  .../replay_sandbox_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_sandbox.dart': No such file or directory
00:00 +0 -4: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: 53f0a5e3a8a1f1b0f43d94e22e1b889aca09a1b8e54231063261417d1c529933

## Cycle: 066-replay-U5 (red)

- behavior: 066-replay-U5
- kind: red
- classification: loadError
- criterion: FR-008, FR-010
- test: test/plugins/tdd/services/replay_history_test.dart::U5
- command: `dart test test/plugins/tdd/services/replay_history_test.dart test/plugins/tdd/services/replay_sandbox_test.dart test/plugins/tdd/services/replay_runner_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 1
- at: 2026-09-02T21:57:47.207192Z
- output:
```
00:00 +0 -4: loading test/plugins/tdd/commands/replay_command_test.dart [E]
  Failed to load "test/plugins/tdd/commands/replay_command_test.dart":
  .../replay_command_test.dart:17:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_history_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_history_test.dart":
  .../replay_history_test.dart:16:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_runner_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_runner_test.dart":
  .../replay_runner_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_runner.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_sandbox_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_sandbox_test.dart":
  .../replay_sandbox_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_sandbox.dart': No such file or directory
00:00 +0 -4: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: 7e63484d69187bcdd3028deb7ec6b4cce345f7e15b053cfc613b285967a8aaa1

## Cycle: 066-replay-U6 (red)

- behavior: 066-replay-U6
- kind: red
- classification: loadError
- criterion: FR-006, FR-007
- test: test/plugins/tdd/services/replay_sandbox_test.dart::U6
- command: `dart test test/plugins/tdd/services/replay_history_test.dart test/plugins/tdd/services/replay_sandbox_test.dart test/plugins/tdd/services/replay_runner_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 1
- at: 2026-09-02T21:57:47.209070Z
- output:
```
00:00 +0 -4: loading test/plugins/tdd/commands/replay_command_test.dart [E]
  Failed to load "test/plugins/tdd/commands/replay_command_test.dart":
  .../replay_command_test.dart:17:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_history_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_history_test.dart":
  .../replay_history_test.dart:16:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_runner_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_runner_test.dart":
  .../replay_runner_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_runner.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_sandbox_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_sandbox_test.dart":
  .../replay_sandbox_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_sandbox.dart': No such file or directory
00:00 +0 -4: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: 36d001579313cfe220d404e89e586d0cd2b9958e940c5ae14af7245013824a49

## Cycle: 066-replay-U7 (red)

- behavior: 066-replay-U7
- kind: red
- classification: loadError
- criterion: FR-008, FR-009
- test: test/plugins/tdd/services/replay_history_test.dart::U7
- command: `dart test test/plugins/tdd/services/replay_history_test.dart test/plugins/tdd/services/replay_sandbox_test.dart test/plugins/tdd/services/replay_runner_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 1
- at: 2026-09-02T21:57:47.210203Z
- output:
```
00:00 +0 -4: loading test/plugins/tdd/commands/replay_command_test.dart [E]
  Failed to load "test/plugins/tdd/commands/replay_command_test.dart":
  .../replay_command_test.dart:17:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_history_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_history_test.dart":
  .../replay_history_test.dart:16:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_runner_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_runner_test.dart":
  .../replay_runner_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_runner.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_sandbox_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_sandbox_test.dart":
  .../replay_sandbox_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_sandbox.dart': No such file or directory
00:00 +0 -4: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: 8b16bcc63fd4c729668b3edfbd960b84503b9de34d8a3a43031c141638b3da55

## Cycle: 066-replay-U8 (red)

- behavior: 066-replay-U8
- kind: red
- classification: loadError
- criterion: FR-010, FR-011
- test: test/plugins/tdd/services/replay_history_test.dart::U8
- command: `dart test test/plugins/tdd/services/replay_history_test.dart test/plugins/tdd/services/replay_sandbox_test.dart test/plugins/tdd/services/replay_runner_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 1
- at: 2026-09-02T21:57:47.211252Z
- output:
```
00:00 +0 -4: loading test/plugins/tdd/commands/replay_command_test.dart [E]
  Failed to load "test/plugins/tdd/commands/replay_command_test.dart":
  .../replay_command_test.dart:17:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_history_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_history_test.dart":
  .../replay_history_test.dart:16:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_runner_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_runner_test.dart":
  .../replay_runner_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_runner.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_sandbox_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_sandbox_test.dart":
  .../replay_sandbox_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_sandbox.dart': No such file or directory
00:00 +0 -4: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: 5ceca0080d93c5abb8f187d33caeb86e6b7b1782d454e2d9675f8470de79ce4d

## Cycle: 066-replay-U9 (red)

- behavior: 066-replay-U9
- kind: red
- classification: loadError
- criterion: FR-013
- test: test/plugins/tdd/services/replay_runner_test.dart::U9
- command: `dart test test/plugins/tdd/services/replay_history_test.dart test/plugins/tdd/services/replay_sandbox_test.dart test/plugins/tdd/services/replay_runner_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 1
- at: 2026-09-02T21:57:47.212381Z
- output:
```
00:00 +0 -4: loading test/plugins/tdd/commands/replay_command_test.dart [E]
  Failed to load "test/plugins/tdd/commands/replay_command_test.dart":
  .../replay_command_test.dart:17:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_history_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_history_test.dart":
  .../replay_history_test.dart:16:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_runner_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_runner_test.dart":
  .../replay_runner_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_runner.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_sandbox_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_sandbox_test.dart":
  .../replay_sandbox_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_sandbox.dart': No such file or directory
00:00 +0 -4: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: 390134bdf32587d13a9e37456eee5b954fb226043cda6ef48df29b583207eb8e

## Cycle: 066-replay-U10 (red)

- behavior: 066-replay-U10
- kind: red
- classification: loadError
- criterion: FR-014
- test: test/plugins/tdd/services/replay_runner_test.dart::U10
- command: `dart test test/plugins/tdd/services/replay_history_test.dart test/plugins/tdd/services/replay_sandbox_test.dart test/plugins/tdd/services/replay_runner_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 1
- at: 2026-09-02T21:57:47.213887Z
- output:
```
00:00 +0 -4: loading test/plugins/tdd/commands/replay_command_test.dart [E]
  Failed to load "test/plugins/tdd/commands/replay_command_test.dart":
  .../replay_command_test.dart:17:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_history_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_history_test.dart":
  .../replay_history_test.dart:16:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_history.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_runner_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_runner_test.dart":
  .../replay_runner_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_runner.dart': No such file or directory
00:00 +0 -4: loading test/plugins/tdd/services/replay_sandbox_test.dart [E]
  Failed to load "test/plugins/tdd/services/replay_sandbox_test.dart":
  .../replay_sandbox_test.dart:14:8: Error: Error when reading
  'lib/src/plugins/tdd/services/replay_sandbox.dart': No such file or directory
00:00 +0 -4: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: 8815da25c83fcbb6d2a10a054f1e366a676e948339bbe113e0947c18ff52ec8a

## Cycle: 066-replay-A1 (green)

- behavior: 066-replay-A1
- kind: green
- criterion: SC1
- test: test/plugins/tdd/commands/replay_command_test.dart::A1
- command: `dart test test/plugins/tdd/services/replay_{history,sandbox,runner}_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 0
- at: 2026-09-02T22:13:53.183589Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/replay_history_test.dart
00:00 +0: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U1: entries group by behavior in file order
00:00 +1: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +2: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +3: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +4: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U2: a (none) generation block yields empty steps
00:00 +5: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: absent sources are skipped silently
00:00 +6: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: the recorded chain verifies
00:00 +7: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: .git, build/ and dart kernel caches are excluded
00:00 +8: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +9: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +10: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a spliced prev-hash breaks with a linkage divergence
00:00 +11: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: hash-less schema-0 entries are unverified, never failed
00:00 +12: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red test path missing from the tree diverges
00:00 +13: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry recorded with exit 0 diverges
00:00 +14: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry without a classification diverges
00:00 +15: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a valid red passes
00:00 +16: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U5: replayability derives from what was recorded
00:00 +17: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: identical trees when the recorded gen reproduces
00:00 +18: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: drift is reported path-stably with classifications
00:00 +19: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: added files are classified as drift too
00:00 +20: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: a failing gen step is a runner-error divergence
00:00 +21: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a passing recorded command is green in the sandbox cwd
00:01 +22: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a broken subject diverges with expected/actual
00:01 +23: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unspawnable recorded command is a runner error
00:01 +24: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unresolved project skips verify (FR-011)
00:01 +25: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: any divergence aggregates to divergent/1
00:01 +26: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: zero replayed behaviors aggregate to partial/2
00:01 +27: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: all-replayed-without-divergence aggregates to clean/0
00:01 +28: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: the summary line carries the contract fields
00:01 +29: test/plugins/tdd/services/replay_runner_test.dart: ReplayEvents (U10) U10: events are NDJSON and end with the exit
00:07 +30: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A1: a full recorded cycle replays clean
00:07 +31: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A2: a tampered cycle-log entry is caught, entry named
00:07 +32: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A3: artifact drift is caught with the path named
00:07 +33: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A4: a verify divergence names behavior + exits
00:07 +34: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A5: full-history aggregation, partial, and missing-log
00:07 +35: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A6: the NDJSON event log mirrors the run
00:08 +36: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A7: the dream surface delegates; unknown ids fail named
00:08 +37: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: c94c953a5d5d4858447dc3acf7ff5660fe83cab0730349d0aae4b2a522019376
- hash: 2166642d9e825b52ed9118f9eea65070ffbd837d329e00b03d5e793a574bf4d3

## Cycle: 066-replay-A2 (green)

- behavior: 066-replay-A2
- kind: green
- criterion: SC2
- test: test/plugins/tdd/commands/replay_command_test.dart::A2
- command: `dart test test/plugins/tdd/services/replay_{history,sandbox,runner}_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 0
- at: 2026-09-02T22:13:53.233110Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/replay_history_test.dart
00:00 +0: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U1: entries group by behavior in file order
00:00 +1: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +2: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +3: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +4: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U2: a (none) generation block yields empty steps
00:00 +5: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: absent sources are skipped silently
00:00 +6: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: the recorded chain verifies
00:00 +7: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: .git, build/ and dart kernel caches are excluded
00:00 +8: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +9: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +10: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a spliced prev-hash breaks with a linkage divergence
00:00 +11: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: hash-less schema-0 entries are unverified, never failed
00:00 +12: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red test path missing from the tree diverges
00:00 +13: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry recorded with exit 0 diverges
00:00 +14: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry without a classification diverges
00:00 +15: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a valid red passes
00:00 +16: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U5: replayability derives from what was recorded
00:00 +17: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: identical trees when the recorded gen reproduces
00:00 +18: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: drift is reported path-stably with classifications
00:00 +19: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: added files are classified as drift too
00:00 +20: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: a failing gen step is a runner-error divergence
00:00 +21: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a passing recorded command is green in the sandbox cwd
00:01 +22: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a broken subject diverges with expected/actual
00:01 +23: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unspawnable recorded command is a runner error
00:01 +24: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unresolved project skips verify (FR-011)
00:01 +25: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: any divergence aggregates to divergent/1
00:01 +26: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: zero replayed behaviors aggregate to partial/2
00:01 +27: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: all-replayed-without-divergence aggregates to clean/0
00:01 +28: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: the summary line carries the contract fields
00:01 +29: test/plugins/tdd/services/replay_runner_test.dart: ReplayEvents (U10) U10: events are NDJSON and end with the exit
00:07 +30: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A1: a full recorded cycle replays clean
00:07 +31: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A2: a tampered cycle-log entry is caught, entry named
00:07 +32: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A3: artifact drift is caught with the path named
00:07 +33: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A4: a verify divergence names behavior + exits
00:07 +34: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A5: full-history aggregation, partial, and missing-log
00:07 +35: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A6: the NDJSON event log mirrors the run
00:08 +36: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A7: the dream surface delegates; unknown ids fail named
00:08 +37: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 2012e52900b40af954716e6738d13e4e6c6680df92a6f1bdb39e037cb076fdbb
- hash: 1b1078ac37d2150b54e584b481a75f237c1352d67b959138d819740267eef009

## Cycle: 066-replay-A3 (green)

- behavior: 066-replay-A3
- kind: green
- criterion: SC3
- test: test/plugins/tdd/commands/replay_command_test.dart::A3
- command: `dart test test/plugins/tdd/services/replay_{history,sandbox,runner}_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 0
- at: 2026-09-02T22:13:53.235118Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/replay_history_test.dart
00:00 +0: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U1: entries group by behavior in file order
00:00 +1: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +2: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +3: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +4: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U2: a (none) generation block yields empty steps
00:00 +5: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: absent sources are skipped silently
00:00 +6: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: the recorded chain verifies
00:00 +7: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: .git, build/ and dart kernel caches are excluded
00:00 +8: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +9: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +10: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a spliced prev-hash breaks with a linkage divergence
00:00 +11: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: hash-less schema-0 entries are unverified, never failed
00:00 +12: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red test path missing from the tree diverges
00:00 +13: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry recorded with exit 0 diverges
00:00 +14: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry without a classification diverges
00:00 +15: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a valid red passes
00:00 +16: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U5: replayability derives from what was recorded
00:00 +17: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: identical trees when the recorded gen reproduces
00:00 +18: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: drift is reported path-stably with classifications
00:00 +19: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: added files are classified as drift too
00:00 +20: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: a failing gen step is a runner-error divergence
00:00 +21: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a passing recorded command is green in the sandbox cwd
00:01 +22: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a broken subject diverges with expected/actual
00:01 +23: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unspawnable recorded command is a runner error
00:01 +24: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unresolved project skips verify (FR-011)
00:01 +25: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: any divergence aggregates to divergent/1
00:01 +26: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: zero replayed behaviors aggregate to partial/2
00:01 +27: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: all-replayed-without-divergence aggregates to clean/0
00:01 +28: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: the summary line carries the contract fields
00:01 +29: test/plugins/tdd/services/replay_runner_test.dart: ReplayEvents (U10) U10: events are NDJSON and end with the exit
00:07 +30: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A1: a full recorded cycle replays clean
00:07 +31: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A2: a tampered cycle-log entry is caught, entry named
00:07 +32: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A3: artifact drift is caught with the path named
00:07 +33: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A4: a verify divergence names behavior + exits
00:07 +34: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A5: full-history aggregation, partial, and missing-log
00:07 +35: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A6: the NDJSON event log mirrors the run
00:08 +36: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A7: the dream surface delegates; unknown ids fail named
00:08 +37: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: e8824dd4a82921a5111235c37fe4118f6c31c2a43545a65086c9972b4e93f26a
- hash: 17d9323ef8fcb197eb27f0e89cb5bca7fc404b3ccebd58369c85ba6736765e24

## Cycle: 066-replay-A4 (green)

- behavior: 066-replay-A4
- kind: green
- criterion: SC4
- test: test/plugins/tdd/commands/replay_command_test.dart::A4
- command: `dart test test/plugins/tdd/services/replay_{history,sandbox,runner}_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 0
- at: 2026-09-02T22:13:53.236768Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/replay_history_test.dart
00:00 +0: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U1: entries group by behavior in file order
00:00 +1: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +2: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +3: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +4: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U2: a (none) generation block yields empty steps
00:00 +5: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: absent sources are skipped silently
00:00 +6: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: the recorded chain verifies
00:00 +7: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: .git, build/ and dart kernel caches are excluded
00:00 +8: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +9: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +10: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a spliced prev-hash breaks with a linkage divergence
00:00 +11: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: hash-less schema-0 entries are unverified, never failed
00:00 +12: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red test path missing from the tree diverges
00:00 +13: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry recorded with exit 0 diverges
00:00 +14: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry without a classification diverges
00:00 +15: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a valid red passes
00:00 +16: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U5: replayability derives from what was recorded
00:00 +17: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: identical trees when the recorded gen reproduces
00:00 +18: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: drift is reported path-stably with classifications
00:00 +19: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: added files are classified as drift too
00:00 +20: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: a failing gen step is a runner-error divergence
00:00 +21: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a passing recorded command is green in the sandbox cwd
00:01 +22: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a broken subject diverges with expected/actual
00:01 +23: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unspawnable recorded command is a runner error
00:01 +24: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unresolved project skips verify (FR-011)
00:01 +25: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: any divergence aggregates to divergent/1
00:01 +26: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: zero replayed behaviors aggregate to partial/2
00:01 +27: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: all-replayed-without-divergence aggregates to clean/0
00:01 +28: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: the summary line carries the contract fields
00:01 +29: test/plugins/tdd/services/replay_runner_test.dart: ReplayEvents (U10) U10: events are NDJSON and end with the exit
00:07 +30: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A1: a full recorded cycle replays clean
00:07 +31: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A2: a tampered cycle-log entry is caught, entry named
00:07 +32: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A3: artifact drift is caught with the path named
00:07 +33: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A4: a verify divergence names behavior + exits
00:07 +34: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A5: full-history aggregation, partial, and missing-log
00:07 +35: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A6: the NDJSON event log mirrors the run
00:08 +36: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A7: the dream surface delegates; unknown ids fail named
00:08 +37: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: b5ff85df8e10455bdf4b3a0e734b4de5af6c7193e0b903c51b29a61e8747bd5c
- hash: b2795bb9e2072443e4541d501c31ec63bbacd2473cb32f46c6db71209f5fcf7e

## Cycle: 066-replay-A5 (green)

- behavior: 066-replay-A5
- kind: green
- criterion: SC5
- test: test/plugins/tdd/commands/replay_command_test.dart::A5
- command: `dart test test/plugins/tdd/services/replay_{history,sandbox,runner}_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 0
- at: 2026-09-02T22:13:53.238507Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/replay_history_test.dart
00:00 +0: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U1: entries group by behavior in file order
00:00 +1: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +2: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +3: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +4: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U2: a (none) generation block yields empty steps
00:00 +5: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: absent sources are skipped silently
00:00 +6: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: the recorded chain verifies
00:00 +7: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: .git, build/ and dart kernel caches are excluded
00:00 +8: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +9: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +10: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a spliced prev-hash breaks with a linkage divergence
00:00 +11: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: hash-less schema-0 entries are unverified, never failed
00:00 +12: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red test path missing from the tree diverges
00:00 +13: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry recorded with exit 0 diverges
00:00 +14: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry without a classification diverges
00:00 +15: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a valid red passes
00:00 +16: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U5: replayability derives from what was recorded
00:00 +17: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: identical trees when the recorded gen reproduces
00:00 +18: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: drift is reported path-stably with classifications
00:00 +19: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: added files are classified as drift too
00:00 +20: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: a failing gen step is a runner-error divergence
00:00 +21: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a passing recorded command is green in the sandbox cwd
00:01 +22: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a broken subject diverges with expected/actual
00:01 +23: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unspawnable recorded command is a runner error
00:01 +24: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unresolved project skips verify (FR-011)
00:01 +25: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: any divergence aggregates to divergent/1
00:01 +26: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: zero replayed behaviors aggregate to partial/2
00:01 +27: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: all-replayed-without-divergence aggregates to clean/0
00:01 +28: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: the summary line carries the contract fields
00:01 +29: test/plugins/tdd/services/replay_runner_test.dart: ReplayEvents (U10) U10: events are NDJSON and end with the exit
00:07 +30: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A1: a full recorded cycle replays clean
00:07 +31: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A2: a tampered cycle-log entry is caught, entry named
00:07 +32: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A3: artifact drift is caught with the path named
00:07 +33: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A4: a verify divergence names behavior + exits
00:07 +34: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A5: full-history aggregation, partial, and missing-log
00:07 +35: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A6: the NDJSON event log mirrors the run
00:08 +36: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A7: the dream surface delegates; unknown ids fail named
00:08 +37: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 3e3c33e4da1e324ae7b53d744111ccba2f304ef11662e481884997688ba8d23a
- hash: cc40f1ce2180fe1d8d1f34487852448ea6d559096a2478a382c9b518bfd2641a

## Cycle: 066-replay-A6 (green)

- behavior: 066-replay-A6
- kind: green
- criterion: SC6
- test: test/plugins/tdd/commands/replay_command_test.dart::A6
- command: `dart test test/plugins/tdd/services/replay_{history,sandbox,runner}_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 0
- at: 2026-09-02T22:13:53.240555Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/replay_history_test.dart
00:00 +0: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U1: entries group by behavior in file order
00:00 +1: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +2: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +3: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +4: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U2: a (none) generation block yields empty steps
00:00 +5: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: absent sources are skipped silently
00:00 +6: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: the recorded chain verifies
00:00 +7: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: .git, build/ and dart kernel caches are excluded
00:00 +8: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +9: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +10: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a spliced prev-hash breaks with a linkage divergence
00:00 +11: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: hash-less schema-0 entries are unverified, never failed
00:00 +12: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red test path missing from the tree diverges
00:00 +13: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry recorded with exit 0 diverges
00:00 +14: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry without a classification diverges
00:00 +15: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a valid red passes
00:00 +16: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U5: replayability derives from what was recorded
00:00 +17: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: identical trees when the recorded gen reproduces
00:00 +18: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: drift is reported path-stably with classifications
00:00 +19: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: added files are classified as drift too
00:00 +20: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: a failing gen step is a runner-error divergence
00:00 +21: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a passing recorded command is green in the sandbox cwd
00:01 +22: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a broken subject diverges with expected/actual
00:01 +23: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unspawnable recorded command is a runner error
00:01 +24: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unresolved project skips verify (FR-011)
00:01 +25: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: any divergence aggregates to divergent/1
00:01 +26: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: zero replayed behaviors aggregate to partial/2
00:01 +27: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: all-replayed-without-divergence aggregates to clean/0
00:01 +28: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: the summary line carries the contract fields
00:01 +29: test/plugins/tdd/services/replay_runner_test.dart: ReplayEvents (U10) U10: events are NDJSON and end with the exit
00:07 +30: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A1: a full recorded cycle replays clean
00:07 +31: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A2: a tampered cycle-log entry is caught, entry named
00:07 +32: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A3: artifact drift is caught with the path named
00:07 +33: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A4: a verify divergence names behavior + exits
00:07 +34: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A5: full-history aggregation, partial, and missing-log
00:07 +35: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A6: the NDJSON event log mirrors the run
00:08 +36: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A7: the dream surface delegates; unknown ids fail named
00:08 +37: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 77020ef06a4d670a2d09be113e577e89f5a949d1951cbb9b1b0e24956a07086e
- hash: a1f02dd2f16662276964beb3d2f1a687040015d120699d5608410f1b27edc288

## Cycle: 066-replay-A7 (green)

- behavior: 066-replay-A7
- kind: green
- criterion: SC7
- test: test/plugins/tdd/commands/replay_command_test.dart::A7
- command: `dart test test/plugins/tdd/services/replay_{history,sandbox,runner}_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 0
- at: 2026-09-02T22:13:53.242959Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/replay_history_test.dart
00:00 +0: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U1: entries group by behavior in file order
00:00 +1: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +2: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +3: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +4: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U2: a (none) generation block yields empty steps
00:00 +5: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: absent sources are skipped silently
00:00 +6: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: the recorded chain verifies
00:00 +7: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: .git, build/ and dart kernel caches are excluded
00:00 +8: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +9: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +10: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a spliced prev-hash breaks with a linkage divergence
00:00 +11: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: hash-less schema-0 entries are unverified, never failed
00:00 +12: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red test path missing from the tree diverges
00:00 +13: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry recorded with exit 0 diverges
00:00 +14: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry without a classification diverges
00:00 +15: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a valid red passes
00:00 +16: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U5: replayability derives from what was recorded
00:00 +17: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: identical trees when the recorded gen reproduces
00:00 +18: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: drift is reported path-stably with classifications
00:00 +19: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: added files are classified as drift too
00:00 +20: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: a failing gen step is a runner-error divergence
00:00 +21: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a passing recorded command is green in the sandbox cwd
00:01 +22: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a broken subject diverges with expected/actual
00:01 +23: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unspawnable recorded command is a runner error
00:01 +24: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unresolved project skips verify (FR-011)
00:01 +25: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: any divergence aggregates to divergent/1
00:01 +26: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: zero replayed behaviors aggregate to partial/2
00:01 +27: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: all-replayed-without-divergence aggregates to clean/0
00:01 +28: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: the summary line carries the contract fields
00:01 +29: test/plugins/tdd/services/replay_runner_test.dart: ReplayEvents (U10) U10: events are NDJSON and end with the exit
00:07 +30: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A1: a full recorded cycle replays clean
00:07 +31: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A2: a tampered cycle-log entry is caught, entry named
00:07 +32: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A3: artifact drift is caught with the path named
00:07 +33: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A4: a verify divergence names behavior + exits
00:07 +34: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A5: full-history aggregation, partial, and missing-log
00:07 +35: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A6: the NDJSON event log mirrors the run
00:08 +36: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A7: the dream surface delegates; unknown ids fail named
00:08 +37: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: e9a1fb7fda0fbf47cbd8a772eef911c51ab6e3bf1261fd707a60b39a03ab9565
- hash: c520b3a6659031b8797d39a06a7dfacde89d233ae212b0f40a0120e6b4d344d3

## Cycle: 066-replay-U1 (green)

- behavior: 066-replay-U1
- kind: green
- criterion: FR-002, FR-003
- test: test/plugins/tdd/services/replay_history_test.dart::U1
- command: `dart test test/plugins/tdd/services/replay_{history,sandbox,runner}_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 0
- at: 2026-09-02T22:13:53.244717Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/replay_history_test.dart
00:00 +0: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U1: entries group by behavior in file order
00:00 +1: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +2: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +3: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +4: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U2: a (none) generation block yields empty steps
00:00 +5: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: absent sources are skipped silently
00:00 +6: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: the recorded chain verifies
00:00 +7: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: .git, build/ and dart kernel caches are excluded
00:00 +8: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +9: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +10: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a spliced prev-hash breaks with a linkage divergence
00:00 +11: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: hash-less schema-0 entries are unverified, never failed
00:00 +12: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red test path missing from the tree diverges
00:00 +13: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry recorded with exit 0 diverges
00:00 +14: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry without a classification diverges
00:00 +15: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a valid red passes
00:00 +16: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U5: replayability derives from what was recorded
00:00 +17: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: identical trees when the recorded gen reproduces
00:00 +18: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: drift is reported path-stably with classifications
00:00 +19: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: added files are classified as drift too
00:00 +20: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: a failing gen step is a runner-error divergence
00:00 +21: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a passing recorded command is green in the sandbox cwd
00:01 +22: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a broken subject diverges with expected/actual
00:01 +23: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unspawnable recorded command is a runner error
00:01 +24: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unresolved project skips verify (FR-011)
00:01 +25: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: any divergence aggregates to divergent/1
00:01 +26: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: zero replayed behaviors aggregate to partial/2
00:01 +27: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: all-replayed-without-divergence aggregates to clean/0
00:01 +28: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: the summary line carries the contract fields
00:01 +29: test/plugins/tdd/services/replay_runner_test.dart: ReplayEvents (U10) U10: events are NDJSON and end with the exit
00:07 +30: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A1: a full recorded cycle replays clean
00:07 +31: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A2: a tampered cycle-log entry is caught, entry named
00:07 +32: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A3: artifact drift is caught with the path named
00:07 +33: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A4: a verify divergence names behavior + exits
00:07 +34: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A5: full-history aggregation, partial, and missing-log
00:07 +35: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A6: the NDJSON event log mirrors the run
00:08 +36: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A7: the dream surface delegates; unknown ids fail named
00:08 +37: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: c910ed8caa5e16000b2096b819fc2fe1d8977e292fbac9d2b3137b686f1d64c3
- hash: 6aadcb9f6bd5ff6549411171487f15abff13c8e125bb6ae6371f17f19a962b69

## Cycle: 066-replay-U2 (green)

- behavior: 066-replay-U2
- kind: green
- criterion: FR-008
- test: test/plugins/tdd/services/replay_history_test.dart::U2
- command: `dart test test/plugins/tdd/services/replay_{history,sandbox,runner}_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 0
- at: 2026-09-02T22:13:53.246417Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/replay_history_test.dart
00:00 +0: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U1: entries group by behavior in file order
00:00 +1: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +2: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +3: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +4: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U2: a (none) generation block yields empty steps
00:00 +5: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: absent sources are skipped silently
00:00 +6: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: the recorded chain verifies
00:00 +7: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: .git, build/ and dart kernel caches are excluded
00:00 +8: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +9: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +10: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a spliced prev-hash breaks with a linkage divergence
00:00 +11: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: hash-less schema-0 entries are unverified, never failed
00:00 +12: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red test path missing from the tree diverges
00:00 +13: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry recorded with exit 0 diverges
00:00 +14: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry without a classification diverges
00:00 +15: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a valid red passes
00:00 +16: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U5: replayability derives from what was recorded
00:00 +17: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: identical trees when the recorded gen reproduces
00:00 +18: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: drift is reported path-stably with classifications
00:00 +19: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: added files are classified as drift too
00:00 +20: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: a failing gen step is a runner-error divergence
00:00 +21: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a passing recorded command is green in the sandbox cwd
00:01 +22: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a broken subject diverges with expected/actual
00:01 +23: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unspawnable recorded command is a runner error
00:01 +24: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unresolved project skips verify (FR-011)
00:01 +25: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: any divergence aggregates to divergent/1
00:01 +26: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: zero replayed behaviors aggregate to partial/2
00:01 +27: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: all-replayed-without-divergence aggregates to clean/0
00:01 +28: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: the summary line carries the contract fields
00:01 +29: test/plugins/tdd/services/replay_runner_test.dart: ReplayEvents (U10) U10: events are NDJSON and end with the exit
00:07 +30: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A1: a full recorded cycle replays clean
00:07 +31: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A2: a tampered cycle-log entry is caught, entry named
00:07 +32: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A3: artifact drift is caught with the path named
00:07 +33: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A4: a verify divergence names behavior + exits
00:07 +34: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A5: full-history aggregation, partial, and missing-log
00:07 +35: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A6: the NDJSON event log mirrors the run
00:08 +36: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A7: the dream surface delegates; unknown ids fail named
00:08 +37: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 4cb6a1e99bed872437058ddc4e8f41a18f15fa4d0ff77d3646473973b4a825ae
- hash: 609dea7542a5927c4c7dd8d852a191ac878d42a0848d9c3d4d4a370161463bc2

## Cycle: 066-replay-U3 (green)

- behavior: 066-replay-U3
- kind: green
- criterion: FR-004
- test: test/plugins/tdd/services/replay_history_test.dart::U3
- command: `dart test test/plugins/tdd/services/replay_{history,sandbox,runner}_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 0
- at: 2026-09-02T22:13:53.248281Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/replay_history_test.dart
00:00 +0: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U1: entries group by behavior in file order
00:00 +1: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +2: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +3: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +4: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U2: a (none) generation block yields empty steps
00:00 +5: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: absent sources are skipped silently
00:00 +6: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: the recorded chain verifies
00:00 +7: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: .git, build/ and dart kernel caches are excluded
00:00 +8: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +9: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +10: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a spliced prev-hash breaks with a linkage divergence
00:00 +11: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: hash-less schema-0 entries are unverified, never failed
00:00 +12: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red test path missing from the tree diverges
00:00 +13: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry recorded with exit 0 diverges
00:00 +14: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry without a classification diverges
00:00 +15: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a valid red passes
00:00 +16: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U5: replayability derives from what was recorded
00:00 +17: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: identical trees when the recorded gen reproduces
00:00 +18: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: drift is reported path-stably with classifications
00:00 +19: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: added files are classified as drift too
00:00 +20: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: a failing gen step is a runner-error divergence
00:00 +21: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a passing recorded command is green in the sandbox cwd
00:01 +22: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a broken subject diverges with expected/actual
00:01 +23: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unspawnable recorded command is a runner error
00:01 +24: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unresolved project skips verify (FR-011)
00:01 +25: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: any divergence aggregates to divergent/1
00:01 +26: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: zero replayed behaviors aggregate to partial/2
00:01 +27: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: all-replayed-without-divergence aggregates to clean/0
00:01 +28: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: the summary line carries the contract fields
00:01 +29: test/plugins/tdd/services/replay_runner_test.dart: ReplayEvents (U10) U10: events are NDJSON and end with the exit
00:07 +30: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A1: a full recorded cycle replays clean
00:07 +31: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A2: a tampered cycle-log entry is caught, entry named
00:07 +32: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A3: artifact drift is caught with the path named
00:07 +33: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A4: a verify divergence names behavior + exits
00:07 +34: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A5: full-history aggregation, partial, and missing-log
00:07 +35: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A6: the NDJSON event log mirrors the run
00:08 +36: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A7: the dream surface delegates; unknown ids fail named
00:08 +37: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: da72c61564896ca0a49a95b57d375a855602cb16f00cd5c099566cf9b3eee122
- hash: 4493178f20c0fe0cbece5707f082f8f9fa9b6a67afa497c1d98e1c31902b9c94

## Cycle: 066-replay-U4 (green)

- behavior: 066-replay-U4
- kind: green
- criterion: FR-005
- test: test/plugins/tdd/services/replay_history_test.dart::U4
- command: `dart test test/plugins/tdd/services/replay_{history,sandbox,runner}_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 0
- at: 2026-09-02T22:13:53.251194Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/replay_history_test.dart
00:00 +0: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U1: entries group by behavior in file order
00:00 +1: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +2: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +3: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +4: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U2: a (none) generation block yields empty steps
00:00 +5: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: absent sources are skipped silently
00:00 +6: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: the recorded chain verifies
00:00 +7: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: .git, build/ and dart kernel caches are excluded
00:00 +8: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +9: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +10: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a spliced prev-hash breaks with a linkage divergence
00:00 +11: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: hash-less schema-0 entries are unverified, never failed
00:00 +12: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red test path missing from the tree diverges
00:00 +13: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry recorded with exit 0 diverges
00:00 +14: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry without a classification diverges
00:00 +15: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a valid red passes
00:00 +16: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U5: replayability derives from what was recorded
00:00 +17: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: identical trees when the recorded gen reproduces
00:00 +18: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: drift is reported path-stably with classifications
00:00 +19: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: added files are classified as drift too
00:00 +20: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: a failing gen step is a runner-error divergence
00:00 +21: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a passing recorded command is green in the sandbox cwd
00:01 +22: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a broken subject diverges with expected/actual
00:01 +23: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unspawnable recorded command is a runner error
00:01 +24: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unresolved project skips verify (FR-011)
00:01 +25: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: any divergence aggregates to divergent/1
00:01 +26: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: zero replayed behaviors aggregate to partial/2
00:01 +27: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: all-replayed-without-divergence aggregates to clean/0
00:01 +28: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: the summary line carries the contract fields
00:01 +29: test/plugins/tdd/services/replay_runner_test.dart: ReplayEvents (U10) U10: events are NDJSON and end with the exit
00:07 +30: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A1: a full recorded cycle replays clean
00:07 +31: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A2: a tampered cycle-log entry is caught, entry named
00:07 +32: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A3: artifact drift is caught with the path named
00:07 +33: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A4: a verify divergence names behavior + exits
00:07 +34: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A5: full-history aggregation, partial, and missing-log
00:07 +35: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A6: the NDJSON event log mirrors the run
00:08 +36: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A7: the dream surface delegates; unknown ids fail named
00:08 +37: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 53f0a5e3a8a1f1b0f43d94e22e1b889aca09a1b8e54231063261417d1c529933
- hash: b43536a18c46d2cc337695bd349c1154a45f61017ad8930aa14301bd2da3f2be

## Cycle: 066-replay-U5 (green)

- behavior: 066-replay-U5
- kind: green
- criterion: FR-008, FR-010
- test: test/plugins/tdd/services/replay_history_test.dart::U5
- command: `dart test test/plugins/tdd/services/replay_{history,sandbox,runner}_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 0
- at: 2026-09-02T22:13:53.253301Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/replay_history_test.dart
00:00 +0: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U1: entries group by behavior in file order
00:00 +1: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +2: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +3: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +4: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U2: a (none) generation block yields empty steps
00:00 +5: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: absent sources are skipped silently
00:00 +6: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: the recorded chain verifies
00:00 +7: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: .git, build/ and dart kernel caches are excluded
00:00 +8: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +9: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +10: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a spliced prev-hash breaks with a linkage divergence
00:00 +11: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: hash-less schema-0 entries are unverified, never failed
00:00 +12: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red test path missing from the tree diverges
00:00 +13: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry recorded with exit 0 diverges
00:00 +14: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry without a classification diverges
00:00 +15: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a valid red passes
00:00 +16: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U5: replayability derives from what was recorded
00:00 +17: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: identical trees when the recorded gen reproduces
00:00 +18: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: drift is reported path-stably with classifications
00:00 +19: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: added files are classified as drift too
00:00 +20: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: a failing gen step is a runner-error divergence
00:00 +21: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a passing recorded command is green in the sandbox cwd
00:01 +22: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a broken subject diverges with expected/actual
00:01 +23: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unspawnable recorded command is a runner error
00:01 +24: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unresolved project skips verify (FR-011)
00:01 +25: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: any divergence aggregates to divergent/1
00:01 +26: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: zero replayed behaviors aggregate to partial/2
00:01 +27: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: all-replayed-without-divergence aggregates to clean/0
00:01 +28: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: the summary line carries the contract fields
00:01 +29: test/plugins/tdd/services/replay_runner_test.dart: ReplayEvents (U10) U10: events are NDJSON and end with the exit
00:07 +30: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A1: a full recorded cycle replays clean
00:07 +31: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A2: a tampered cycle-log entry is caught, entry named
00:07 +32: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A3: artifact drift is caught with the path named
00:07 +33: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A4: a verify divergence names behavior + exits
00:07 +34: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A5: full-history aggregation, partial, and missing-log
00:07 +35: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A6: the NDJSON event log mirrors the run
00:08 +36: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A7: the dream surface delegates; unknown ids fail named
00:08 +37: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 7e63484d69187bcdd3028deb7ec6b4cce345f7e15b053cfc613b285967a8aaa1
- hash: 8855fc1d21fc9c03e5e1feab5ea4b69d906e47d9986289297e4bb84bb7ee8b81

## Cycle: 066-replay-U6 (green)

- behavior: 066-replay-U6
- kind: green
- criterion: FR-006, FR-007
- test: test/plugins/tdd/services/replay_sandbox_test.dart::U6
- command: `dart test test/plugins/tdd/services/replay_{history,sandbox,runner}_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 0
- at: 2026-09-02T22:13:53.255920Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/replay_history_test.dart
00:00 +0: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U1: entries group by behavior in file order
00:00 +1: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +2: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +3: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +4: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U2: a (none) generation block yields empty steps
00:00 +5: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: absent sources are skipped silently
00:00 +6: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: the recorded chain verifies
00:00 +7: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: .git, build/ and dart kernel caches are excluded
00:00 +8: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +9: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +10: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a spliced prev-hash breaks with a linkage divergence
00:00 +11: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: hash-less schema-0 entries are unverified, never failed
00:00 +12: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red test path missing from the tree diverges
00:00 +13: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry recorded with exit 0 diverges
00:00 +14: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry without a classification diverges
00:00 +15: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a valid red passes
00:00 +16: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U5: replayability derives from what was recorded
00:00 +17: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: identical trees when the recorded gen reproduces
00:00 +18: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: drift is reported path-stably with classifications
00:00 +19: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: added files are classified as drift too
00:00 +20: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: a failing gen step is a runner-error divergence
00:00 +21: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a passing recorded command is green in the sandbox cwd
00:01 +22: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a broken subject diverges with expected/actual
00:01 +23: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unspawnable recorded command is a runner error
00:01 +24: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unresolved project skips verify (FR-011)
00:01 +25: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: any divergence aggregates to divergent/1
00:01 +26: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: zero replayed behaviors aggregate to partial/2
00:01 +27: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: all-replayed-without-divergence aggregates to clean/0
00:01 +28: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: the summary line carries the contract fields
00:01 +29: test/plugins/tdd/services/replay_runner_test.dart: ReplayEvents (U10) U10: events are NDJSON and end with the exit
00:07 +30: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A1: a full recorded cycle replays clean
00:07 +31: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A2: a tampered cycle-log entry is caught, entry named
00:07 +32: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A3: artifact drift is caught with the path named
00:07 +33: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A4: a verify divergence names behavior + exits
00:07 +34: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A5: full-history aggregation, partial, and missing-log
00:07 +35: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A6: the NDJSON event log mirrors the run
00:08 +36: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A7: the dream surface delegates; unknown ids fail named
00:08 +37: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 36d001579313cfe220d404e89e586d0cd2b9958e940c5ae14af7245013824a49
- hash: ebfbf144756e9269403d3be40ecdde1547ae985670b72bbd8149f5f91acf0a32

## Cycle: 066-replay-U7 (green)

- behavior: 066-replay-U7
- kind: green
- criterion: FR-008, FR-009
- test: test/plugins/tdd/services/replay_history_test.dart::U7
- command: `dart test test/plugins/tdd/services/replay_{history,sandbox,runner}_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 0
- at: 2026-09-02T22:13:53.257957Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/replay_history_test.dart
00:00 +0: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U1: entries group by behavior in file order
00:00 +1: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +2: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +3: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +4: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U2: a (none) generation block yields empty steps
00:00 +5: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: absent sources are skipped silently
00:00 +6: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: the recorded chain verifies
00:00 +7: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: .git, build/ and dart kernel caches are excluded
00:00 +8: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +9: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +10: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a spliced prev-hash breaks with a linkage divergence
00:00 +11: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: hash-less schema-0 entries are unverified, never failed
00:00 +12: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red test path missing from the tree diverges
00:00 +13: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry recorded with exit 0 diverges
00:00 +14: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry without a classification diverges
00:00 +15: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a valid red passes
00:00 +16: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U5: replayability derives from what was recorded
00:00 +17: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: identical trees when the recorded gen reproduces
00:00 +18: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: drift is reported path-stably with classifications
00:00 +19: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: added files are classified as drift too
00:00 +20: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: a failing gen step is a runner-error divergence
00:00 +21: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a passing recorded command is green in the sandbox cwd
00:01 +22: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a broken subject diverges with expected/actual
00:01 +23: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unspawnable recorded command is a runner error
00:01 +24: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unresolved project skips verify (FR-011)
00:01 +25: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: any divergence aggregates to divergent/1
00:01 +26: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: zero replayed behaviors aggregate to partial/2
00:01 +27: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: all-replayed-without-divergence aggregates to clean/0
00:01 +28: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: the summary line carries the contract fields
00:01 +29: test/plugins/tdd/services/replay_runner_test.dart: ReplayEvents (U10) U10: events are NDJSON and end with the exit
00:07 +30: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A1: a full recorded cycle replays clean
00:07 +31: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A2: a tampered cycle-log entry is caught, entry named
00:07 +32: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A3: artifact drift is caught with the path named
00:07 +33: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A4: a verify divergence names behavior + exits
00:07 +34: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A5: full-history aggregation, partial, and missing-log
00:07 +35: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A6: the NDJSON event log mirrors the run
00:08 +36: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A7: the dream surface delegates; unknown ids fail named
00:08 +37: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 8b16bcc63fd4c729668b3edfbd960b84503b9de34d8a3a43031c141638b3da55
- hash: c4664bda52ef0da1c7ce55c0f713416ef317161d629cfac00df74e8ae3d3dde1

## Cycle: 066-replay-U8 (green)

- behavior: 066-replay-U8
- kind: green
- criterion: FR-010, FR-011
- test: test/plugins/tdd/services/replay_history_test.dart::U8
- command: `dart test test/plugins/tdd/services/replay_{history,sandbox,runner}_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 0
- at: 2026-09-02T22:13:53.260624Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/replay_history_test.dart
00:00 +0: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U1: entries group by behavior in file order
00:00 +1: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +2: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +3: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +4: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U2: a (none) generation block yields empty steps
00:00 +5: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: absent sources are skipped silently
00:00 +6: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: the recorded chain verifies
00:00 +7: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: .git, build/ and dart kernel caches are excluded
00:00 +8: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +9: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +10: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a spliced prev-hash breaks with a linkage divergence
00:00 +11: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: hash-less schema-0 entries are unverified, never failed
00:00 +12: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red test path missing from the tree diverges
00:00 +13: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry recorded with exit 0 diverges
00:00 +14: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry without a classification diverges
00:00 +15: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a valid red passes
00:00 +16: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U5: replayability derives from what was recorded
00:00 +17: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: identical trees when the recorded gen reproduces
00:00 +18: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: drift is reported path-stably with classifications
00:00 +19: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: added files are classified as drift too
00:00 +20: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: a failing gen step is a runner-error divergence
00:00 +21: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a passing recorded command is green in the sandbox cwd
00:01 +22: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a broken subject diverges with expected/actual
00:01 +23: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unspawnable recorded command is a runner error
00:01 +24: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unresolved project skips verify (FR-011)
00:01 +25: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: any divergence aggregates to divergent/1
00:01 +26: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: zero replayed behaviors aggregate to partial/2
00:01 +27: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: all-replayed-without-divergence aggregates to clean/0
00:01 +28: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: the summary line carries the contract fields
00:01 +29: test/plugins/tdd/services/replay_runner_test.dart: ReplayEvents (U10) U10: events are NDJSON and end with the exit
00:07 +30: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A1: a full recorded cycle replays clean
00:07 +31: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A2: a tampered cycle-log entry is caught, entry named
00:07 +32: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A3: artifact drift is caught with the path named
00:07 +33: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A4: a verify divergence names behavior + exits
00:07 +34: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A5: full-history aggregation, partial, and missing-log
00:07 +35: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A6: the NDJSON event log mirrors the run
00:08 +36: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A7: the dream surface delegates; unknown ids fail named
00:08 +37: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 5ceca0080d93c5abb8f187d33caeb86e6b7b1782d454e2d9675f8470de79ce4d
- hash: b863dd89a8c3daa0eddc8271059b2942485153e63dc3faab47593096371e1116

## Cycle: 066-replay-U9 (green)

- behavior: 066-replay-U9
- kind: green
- criterion: FR-013
- test: test/plugins/tdd/services/replay_runner_test.dart::U9
- command: `dart test test/plugins/tdd/services/replay_{history,sandbox,runner}_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 0
- at: 2026-09-02T22:13:53.262795Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/replay_history_test.dart
00:00 +0: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U1: entries group by behavior in file order
00:00 +1: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +2: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +3: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +4: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U2: a (none) generation block yields empty steps
00:00 +5: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: absent sources are skipped silently
00:00 +6: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: the recorded chain verifies
00:00 +7: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: .git, build/ and dart kernel caches are excluded
00:00 +8: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +9: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +10: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a spliced prev-hash breaks with a linkage divergence
00:00 +11: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: hash-less schema-0 entries are unverified, never failed
00:00 +12: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red test path missing from the tree diverges
00:00 +13: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry recorded with exit 0 diverges
00:00 +14: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry without a classification diverges
00:00 +15: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a valid red passes
00:00 +16: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U5: replayability derives from what was recorded
00:00 +17: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: identical trees when the recorded gen reproduces
00:00 +18: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: drift is reported path-stably with classifications
00:00 +19: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: added files are classified as drift too
00:00 +20: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: a failing gen step is a runner-error divergence
00:00 +21: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a passing recorded command is green in the sandbox cwd
00:01 +22: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a broken subject diverges with expected/actual
00:01 +23: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unspawnable recorded command is a runner error
00:01 +24: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unresolved project skips verify (FR-011)
00:01 +25: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: any divergence aggregates to divergent/1
00:01 +26: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: zero replayed behaviors aggregate to partial/2
00:01 +27: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: all-replayed-without-divergence aggregates to clean/0
00:01 +28: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: the summary line carries the contract fields
00:01 +29: test/plugins/tdd/services/replay_runner_test.dart: ReplayEvents (U10) U10: events are NDJSON and end with the exit
00:07 +30: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A1: a full recorded cycle replays clean
00:07 +31: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A2: a tampered cycle-log entry is caught, entry named
00:07 +32: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A3: artifact drift is caught with the path named
00:07 +33: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A4: a verify divergence names behavior + exits
00:07 +34: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A5: full-history aggregation, partial, and missing-log
00:07 +35: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A6: the NDJSON event log mirrors the run
00:08 +36: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A7: the dream surface delegates; unknown ids fail named
00:08 +37: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 390134bdf32587d13a9e37456eee5b954fb226043cda6ef48df29b583207eb8e
- hash: 5417e10b3eec18b54238270057ee234fdf32aa2fda3397391e95ed89da274214

## Cycle: 066-replay-U10 (green)

- behavior: 066-replay-U10
- kind: green
- criterion: FR-014
- test: test/plugins/tdd/services/replay_runner_test.dart::U10
- command: `dart test test/plugins/tdd/services/replay_{history,sandbox,runner}_test.dart test/plugins/tdd/commands/replay_command_test.dart`
- exit: 0
- at: 2026-09-02T22:13:53.265621Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/replay_history_test.dart
00:00 +0: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U1: entries group by behavior in file order
00:00 +1: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +2: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +3: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: seeds the project contracts byte-identically
00:00 +4: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U2: a (none) generation block yields empty steps
00:00 +5: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: absent sources are skipped silently
00:00 +6: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: the recorded chain verifies
00:00 +7: test/plugins/tdd/services/replay_sandbox_test.dart: ReplaySandbox U6: .git, build/ and dart kernel caches are excluded
00:00 +8: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +9: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a tampered certified fact breaks, named
00:00 +10: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: a spliced prev-hash breaks with a linkage divergence
00:00 +11: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U3: hash-less schema-0 entries are unverified, never failed
00:00 +12: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red test path missing from the tree diverges
00:00 +13: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry recorded with exit 0 diverges
00:00 +14: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a red entry without a classification diverges
00:00 +15: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U4: a valid red passes
00:00 +16: test/plugins/tdd/services/replay_history_test.dart: ReplayHistory U5: replayability derives from what was recorded
00:00 +17: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: identical trees when the recorded gen reproduces
00:00 +18: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: drift is reported path-stably with classifications
00:00 +19: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: added files are classified as drift too
00:00 +20: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner gen stage (U7) U7: a failing gen step is a runner-error divergence
00:00 +21: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a passing recorded command is green in the sandbox cwd
00:01 +22: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: a broken subject diverges with expected/actual
00:01 +23: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unspawnable recorded command is a runner error
00:01 +24: test/plugins/tdd/services/replay_runner_test.dart: ReplayRunner verify stage (U8) U8: an unresolved project skips verify (FR-011)
00:01 +25: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: any divergence aggregates to divergent/1
00:01 +26: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: zero replayed behaviors aggregate to partial/2
00:01 +27: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: all-replayed-without-divergence aggregates to clean/0
00:01 +28: test/plugins/tdd/services/replay_runner_test.dart: ReplayReport (U9) U9: the summary line carries the contract fields
00:01 +29: test/plugins/tdd/services/replay_runner_test.dart: ReplayEvents (U10) U10: events are NDJSON and end with the exit
00:07 +30: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A1: a full recorded cycle replays clean
00:07 +31: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A2: a tampered cycle-log entry is caught, entry named
00:07 +32: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A3: artifact drift is caught with the path named
00:07 +33: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A4: a verify divergence names behavior + exits
00:07 +34: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A5: full-history aggregation, partial, and missing-log
00:07 +35: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A6: the NDJSON event log mirrors the run
00:08 +36: test/plugins/tdd/commands/replay_command_test.dart: zfa tdd replay A7: the dream surface delegates; unknown ids fail named
00:08 +37: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 8815da25c83fcbb6d2a10a054f1e366a676e948339bbe113e0947c18ff52ec8a
- hash: b0237d4c7a92903109edae1d95c83db5edd1f7179abdb2c9d4c7ebe2e313fe73

