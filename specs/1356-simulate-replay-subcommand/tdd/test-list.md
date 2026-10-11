# TDD Test List — Spec 1356 simulate replay subcommand

Red pre-fix: `replay` is not registered → every invocation exits 2 with
the usage screen (the issue signature); `--help` does not list replay.

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | init + run then bare `zfa simulate replay test_world` (pin) → exit 0, `simulate-replay: scenario=test_world`, `deterministic=true` | FR-1 / AS-1 | test/simulation/worlds/simulate_worlds_command_test.dart |
| B2 | replay with no recorded run receipt → exit 1 naming the missing receipt + run-first fix | FR-2 / AS-2 | test/simulation/worlds/simulate_worlds_command_test.dart |
| B3 | replay after mutating the world manifest → exit 1 naming `mutated since the recorded run` + both hashes | FR-2 / AS-3 | test/simulation/worlds/simulate_worlds_command_test.dart |
| B4 | tampered recorded digest → exit 1 with `DIGEST MISMATCH` + both digests | FR-3 / AS-4 | test/simulation/worlds/simulate_worlds_command_test.dart |
| B5 | `zfa simulate --help` lists `replay`; legacy flag surface stays green (same suite's bug-#856 test) | FR-4 / AS-5 | test/simulation/worlds/simulate_worlds_command_test.dart |

## Red protocol

```
dart test test/simulation/worlds/simulate_worlds_command_test.dart
```
Expected RED (pre-fix): B1–B5 all red — `replay` unregistered (exit 2
usage screen, no 'replay' in help). No guard is green pre-fix.
