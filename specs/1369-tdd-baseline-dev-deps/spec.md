**Template Version**: `zuraffa-1.0`

# Spec: 1369-tdd-baseline-dev-deps

GitHub issue: arrrrny/zuraffa#1369 (verify-misfire / missing-integration,
EPIC #1012 Phase A step 6 / exit criterion 3, #1008 two-cycle driver)

## Summary

The shipped `example/` baseline's dev_dependencies lacked `test` and
`coverage` (mutation_test was present). The engine lane correctly
generates a PURE-DART test importing `package:test` — engine discipline
holds — but the project baseline could not compile it, so the meta-run
died on its first engine behavior: `Couldn't resolve the package 'test'`
(compile-error), `result=stopped pending=3 red=1`. `zfa tdd init` repairs
exactly this (it added `test: ^1.0.0, coverage: ^1.15.1,
mutation_test: ^1.8.0` in the verify sandbox), proving the baseline
writer exists while the shipped tree predates it.

## Locked decisions

1. Data fix: `example/pubspec.yaml` declares the FULL TDD baseline
   (`test: ^1.0.0`, `coverage: ^1.15.1` added; `mutation_test: ^1.8.0`
   already present; `flutter_test` kept) — the constraints the init
   writer itself prescribes, so the repair path and the shipped baseline
   agree.
2. The driver pre-flight idea (auto-running the init writers before the
   first gen) and the friendlier `tdd init` repair path for a drifted
   tdd-profile.md are NOT taken here — they are behavior changes with
   their own design surface; the shipped-tree fix closes the issue's
   compile-error with the writer's own prescription.
3. A structural regression pin (YAML parse of the shipped baseline)
   guards the baseline against future dependency pruning.

## Functional requirements

- **FR-1**: `example/pubspec.yaml` declares `test`, `coverage`,
  `mutation_test`, and `flutter_test` under dev_dependencies.
- **FR-2**: the TDD deps carry the writer-canonical constraints
  (`test: ^1.0.0`, `coverage: ^1.15.1`, `mutation_test: ^1.8.0`).

## Acceptance scenarios

1. Loading the shipped pubspec shows all four dev_dependencies (B1).
2. The constraints equal the writer-canonical set (B2).

## Success criteria

- **SC-001**: The meta-run's engine lane compiles against the shipped
  tree without a manual `zfa tdd init` pass (CI's flutter-smoke-gate +
  the two-cycle driver re-prove resolution on every run).
- **SC-002**: The package_sdk suite stays green.

## Assumptions

- Flutter resolution is re-proven by `tools/flutter_smoke_gate.sh` in CI
  (per the #1189 note in the pubspec); the structural pin is the local,
  hermetic half.
