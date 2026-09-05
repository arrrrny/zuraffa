# Assessment: 991-tdd-run-phase0-no-analyze

- **Assessed**: 2026-09-05 (fix session)
- **Base commit**: `77e69f2` (fix/991-tdd-run-phase0-no-analyze at branch-off)

## Root cause

`RunCommand._runEntityPhaseZero`
(`lib/src/plugins/tdd/commands/run_command.dart`, phase-0 orchestration added
for bug #829) spawns the once-per-run generation build as a bare invocation:

```dart
build = await spawn(const ['build']);
```

`zfa build` declares an `--analyze` flag that defaults ON
(`lib/src/commands/build_command.dart`: "Run `dart analyze` after build and
fail on errors (default: on; use --no-analyze to skip)"). When the target
repo carries pre-existing analyzer findings, the gate makes `zfa build` exit
non-zero, and the driver's honest-stop contract (`failedSpawn` →
`result: 'runner-error'`, `stoppedAt: 'phase-0:build'`) stops the run before
any behavior is driven. The build_runner step itself succeeds — the failure
comes from the analyze gate, not from generation.

The analyze gate is legitimate where it is also enforced by the TDD loop:
the verify/refactor steps keep their own analysis. The phase-0 build is a
different kind of gate — it proves the generated tree compiles after the
phase-0 entity spawns; it must not inherit the repo-wide lint verdict.

## Why the fix belongs in the driver

The driver owns the spawn argv. Forwarding `--no-analyze` on the phase-0
build (and only there) removes the false failure mode without touching:

- `zfa build`'s default `--analyze` (every non-TDD caller unchanged);
- the make/gen pipeline build steps (`generation_planner.dart`,
  `composition_planner.dart`) and their #942 analyzer-error tolerance gate;
- the refactor passes' build commands (`refactor_passes.dart`) — analyze
  stays in verify/refactor per the hard constraint.

## Failure-mode classification

- Severity: medium — every run on a repo with pre-existing analyze findings
  dies at phase 0, but the stop is honest (no green-wash) and resumable.
- Blast radius of the fix: one spawn argv constant + documentation; no
  state, no schemas, no step semantics.
