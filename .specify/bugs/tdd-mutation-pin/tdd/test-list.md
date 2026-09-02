# Test List — Bug #755: tdd-mutation-pin

> The bug fix is scoped to a single source file
> (`lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart`) and a
> single test file (`test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart`).
> There is no `spec.md` for this bug; the issue body
> (`.specify/bugs/tdd-mutation-pin/issue.md`) and the assessment
> (`.specify/bugs/tdd-mutation-pin/assessment.md`) stand in as the
> requirements. The behaviors below are the contract derived from those
> two artifacts.

## Behaviors

| ID    | Behavior                                                                                | Traces                                                                                                                                    | State |
| ----- | --------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ----- |
| B-01  | `flutterDevDependencies` pins `mutation_test` at `^1.8.0` (matches MutationVerifier)   | `pubspec_dev_dependencies_patcher_test.dart :: bug #755 :: flutterDevDependencies pins mutation_test at ^1.8.0`                           | DONE  |
| B-02  | `dartDevDependencies` pins `mutation_test` at `^1.8.0` (matches MutationVerifier)      | `pubspec_dev_dependencies_patcher_test.dart :: bug #755 :: dartDevDependencies pins mutation_test at ^1.8.0`                              | DONE  |
| B-03  | `flutterDevDependencies` pins `coverage` at `^1.15.1` (current latest per pub.dev)     | `pubspec_dev_dependencies_patcher_test.dart :: bug #755 :: flutterDevDependencies pins coverage at ^1.15.1`                               | DONE  |
| B-04  | `dartDevDependencies` pins `coverage` at `^1.15.1`                                     | `pubspec_dev_dependencies_patcher_test.dart :: bug #755 :: dartDevDependencies pins coverage at ^1.15.1`                                  | DONE  |
| B-05  | `flutterDevDependencies` does NOT include `mocktail` (unused by generated templates)   | `pubspec_dev_dependencies_patcher_test.dart :: bug #755 :: flutterDevDependencies does NOT include mocktail`                              | DONE  |
| B-06  | `dartDevDependencies` does NOT include `mocktail`                                      | `pubspec_dev_dependencies_patcher_test.dart :: bug #755 :: dartDevDependencies does NOT include mocktail`                                 | DONE  |
| B-07  | `ensure(...)` in Flutter mode writes `mutation_test: ^1.8.0` and `coverage: ^1.15.1` into a generated `pubspec.yaml` and writes NO `mocktail` entry | `pubspec_dev_dependencies_patcher_test.dart :: bug #755 :: flutter-mode ensure writes mutation_test: ^1.8.0 into pubspec.yaml`            | DONE  |
| B-08  | `ensure(...)` in Dart mode writes `mutation_test: ^1.8.0` and `coverage: ^1.15.1` into a generated `pubspec.yaml` and writes NO `mocktail` entry     | `pubspec_dev_dependencies_patcher_test.dart :: bug #755 :: dart-mode ensure writes mutation_test: ^1.8.0 into pubspec.yaml`               | DONE  |

## Cycle log

See `tdd/cycle-log.md` for the recorded red and green evidence per cycle.
