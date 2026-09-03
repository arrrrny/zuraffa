# Cycle Log — 893-simulation-di-binding

Append only. Newest last. Each entry is a schema-1 hash-chained record:
`hash = sha256(prev-hash + behavior + kind + command + exit + output)`,
matching the format the run driver and doctor parse (spec 049, bug #828).
Red entries are recorded before the implementation commit that turns them
green; the red command and output are copied verbatim from the run.

## 2026-09-03T09:02:54Z: 893-simulation-flavor (red)
- behavior: 893-simulation-flavor
- kind: red
- at: 2026-09-03T09:02:54Z
- exit: 1
- criterion: FR-001: a single build-time flag activates simulation mode; the test detects the SIMULATION define and routes to the simulation binding (T001 red: flavor module not implemented yet)
- command: `dart test test/simulation/simulation_flavor_test.dart`
- schema: 1
- prev-hash: genesis
- hash: a56e3f546553afeaa6dbb84b19d9ace568d58cc9b67786d867d849933ebedbf3
- output: ```
00:00 +0: loading test/simulation/simulation_flavor_test.dart
00:00 +0 -1: loading test/simulation/simulation_flavor_test.dart [E]
  Failed to load "test/simulation/simulation_flavor_test.dart":
  test/simulation/simulation_flavor_test.dart:14:8: Error: Error when reading 'lib/src/simulation/simulation_flavor.dart': No such file or directory
  import 'package:zuraffa/src/simulation/simulation_flavor.dart';
         ^
  test/simulation/simulation_flavor_test.dart:21:14: Error: Undefined name 'kSimulationMode'.
        expect(kSimulationMode, isFalse);
               ^^^^^^^^^^^^^^^
  test/simulation/simulation_flavor_test.dart:22:14: Error: Undefined name 'SimulationFlavor'.
        expect(SimulationFlavor.describe(), 'real');
               ^^^^^^^^^^^^^^^^
  test/simulation/simulation_flavor_test.dart:50:15: Error: Undefined name 'SimulationFlavor'.
          () => SimulationFlavor.checkFlagConflicts(
                ^^^^^^^^^^^^^^^^
  test/simulation/simulation_flavor_test.dart:54:21: Error: 'SimulationFlagConflict' isn't a type.
          throwsA(isA<SimulationFlagConflict>()),
                      ^^^^^^^^^^^^^^^^^^^^^^
  test/simulation/simulation_flavor_test.dart:60:15: Error: Undefined name 'SimulationFlavor'.
          () => SimulationFlavor.checkFlagConflicts(
                ^^^^^^^^^^^^^^^^
  test/simulation/simulation_flavor_test.dart:70:15: Error: Undefined name 'SimulationFlavor'.
          () => SimulationFlavor.checkFlagConflicts(
                ^^^^^^^^^^^^^^^^
  test/simulation/simulation_flavor_test.dart:80:9: Error: Undefined name 'SimulationFlavor'.
          SimulationFlavor.checkFlagConflicts(
          ^^^^^^^^^^^^^^^^
  test/simulation/simulation_flavor_test.dart:85:12: Error: 'SimulationFlagConflict' isn't a type.
        } on SimulationFlagConflict catch (e) {
             ^^^^^^^^^^^^^^^^^^^^^^
00:00 +0 -1: Some tests failed.

Failing tests:
  test/simulation/simulation_flavor_test.dart: loading test/simulation/simulation_flavor_test.dart
```

## 2026-09-03T09:02:54Z: 893-simulation-flavor (green)
- behavior: 893-simulation-flavor
- kind: green
- at: 2026-09-03T09:02:54Z
- exit: 0
- criterion: FR-001/FR-012: kSimulationMode const + SimulationFlagConflict gate, proven through the real toolchain via dart run -DSIMULATION=true
- command: `dart test test/simulation/simulation_flavor_test.dart`
- schema: 1
- prev-hash: a56e3f546553afeaa6dbb84b19d9ace568d58cc9b67786d867d849933ebedbf3
- hash: 4a2c3057891f8965b9ce94d6630981edb07499ca173a7dfb20a1771e532cd512
- output: ```
00:00 +0: loading test/simulation/simulation_flavor_test.dart
00:00 +0: kSimulationMode defaults to false without the SIMULATION define
00:00 +1: kSimulationMode U1: SIMULATION define routes kSimulationMode to true
00:00 +2: kSimulationMode default toolchain run keeps kSimulationMode false
00:00 +3: kSimulationMode probe reports the real flavor name without the define
00:00 +4: A5: SimulationFlavor.checkFlagConflicts throws SimulationFlagConflict when both defines are set
00:00 +5: A5: SimulationFlavor.checkFlagConflicts allows the simulation flavor alone
00:00 +6: A5: SimulationFlavor.checkFlagConflicts allows the real backend alone (default toolchain)
00:00 +7: A5: SimulationFlavor.checkFlagConflicts conflict error names both flags and the resolution rule
00:00 +8: All tests passed!
```
