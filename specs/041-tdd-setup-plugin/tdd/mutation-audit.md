# Mutation Test Combined Report — feature 041

**Tool**: `dart run mutation_test` (mutation_test package)
**Date**: 2026-08-29T09:38:54Z
**Scope**: 22 TDD source files (writers + plugin + services + models + commands)
**Per-file test command**: each source file mutated against its targeted test file
**Total mutants**: 570
**Killed**: 212
**Survived (undetected)**: 358
**Timeout**: 0
**Not covered by tests**: 0
**Overall mutation score**: 37.19%
**Total elapsed**: 142.9s

## Per-file breakdown

| Source file | Mutants | Killed | Survived | Timeout | NotCov | Score | Quality | Elapsed (s) |
|-------------|---------|--------|----------|---------|--------|-------|---------|-------------|
| `lib/src/cli/writers/tdd/dart_test_yaml_writer.dart` | 7 | 3 | 4 | 0 | 0 | 42.9% | D | 0.0 |
| `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart` | 59 | 38 | 21 | 0 | 0 | 64.4% | C | 0.0 |
| `lib/src/cli/writers/tdd/smoke_test_writer.dart` | 7 | 6 | 1 | 0 | 0 | 85.7% | B | 0.0 |
| `lib/src/cli/writers/tdd/tdd_example_writer.dart` | 7 | 4 | 3 | 0 | 0 | 57.1% | D | 0.0 |
| `lib/src/cli/writers/tdd/tdd_profile_writer.dart` | 34 | 8 | 26 | 0 | 0 | 23.5% | E | 29.9 |
| `lib/src/plugins/tdd/models/behavior.dart` | 9 | 9 | 0 | 0 | 0 | 100.0% | A | 0.0 |
| `lib/src/plugins/tdd/models/tdd_profile.dart` | 21 | 7 | 14 | 0 | 0 | 33.3% | E | 0.0 |
| `lib/src/plugins/tdd/models/cycle_entry.dart` | 19 | 13 | 6 | 0 | 0 | 68.4% | C | 0.0 |
| `lib/src/plugins/tdd/models/run_state.dart` | 7 | 6 | 1 | 0 | 0 | 85.7% | B | 0.0 |
| `lib/src/plugins/tdd/services/cycle_log.dart` | 6 | 6 | 0 | 0 | 0 | 100.0% | A | 0.0 |
| `lib/src/plugins/tdd/services/mutation_verifier.dart` | 77 | 23 | 54 | 0 | 0 | 29.9% | E | 0.0 |
| `lib/src/plugins/tdd/services/spec_parser.dart` | 56 | 52 | 4 | 0 | 0 | 92.9% | B | 0.0 |
| `lib/src/plugins/tdd/commands/init_command.dart` | 54 | 7 | 47 | 0 | 0 | 13.0% | F | 113.0 |
| `lib/src/plugins/tdd/commands/plan_command.dart` | 64 | 0 | 64 | 0 | 0 | 0.0% | F | 0.0 |
| `lib/src/plugins/tdd/commands/verify_command.dart` | 66 | 14 | 52 | 0 | 0 | 21.2% | E | 0.0 |
| `lib/src/plugins/tdd/commands/gen_command.dart` | 17 | 1 | 16 | 0 | 0 | 5.9% | F | 0.0 |
| `lib/src/plugins/tdd/commands/make_command.dart` | 13 | 3 | 10 | 0 | 0 | 23.1% | E | 0.0 |
| `lib/src/plugins/tdd/commands/refactor_command.dart` | 10 | 3 | 7 | 0 | 0 | 30.0% | E | 0.0 |
| `lib/src/plugins/tdd/commands/run_command.dart` | 11 | 3 | 8 | 0 | 0 | 27.3% | E | 0.0 |
| `lib/src/plugins/tdd/commands/verify_red_command.dart` | 13 | 3 | 10 | 0 | 0 | 23.1% | E | 0.0 |
| `lib/src/plugins/tdd/tdd_plugin.dart` | 0 | 0 | 0 | 0 | 0 | 100.0% | A | 0.0 |
| `lib/src/commands/tdd_command.dart` | 13 | 3 | 10 | 0 | 0 | 23.1% | E | 0.0 |

## Survived mutants — by file

- `lib/src/cli/writers/tdd/dart_test_yaml_writer.dart`: 4 mutant(s) survived. Score: 42.9% (3/7). Quality: D.
- `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart`: 21 mutant(s) survived. Score: 64.4% (38/59). Quality: C.
- `lib/src/cli/writers/tdd/smoke_test_writer.dart`: 1 mutant(s) survived. Score: 85.7% (6/7). Quality: B.
- `lib/src/cli/writers/tdd/tdd_example_writer.dart`: 3 mutant(s) survived. Score: 57.1% (4/7). Quality: D.
- `lib/src/cli/writers/tdd/tdd_profile_writer.dart`: 26 mutant(s) survived. Score: 23.5% (8/34). Quality: E.
- `lib/src/plugins/tdd/models/tdd_profile.dart`: 14 mutant(s) survived. Score: 33.3% (7/21). Quality: E.
- `lib/src/plugins/tdd/models/cycle_entry.dart`: 6 mutant(s) survived. Score: 68.4% (13/19). Quality: C.
- `lib/src/plugins/tdd/models/run_state.dart`: 1 mutant(s) survived. Score: 85.7% (6/7). Quality: B.
- `lib/src/plugins/tdd/services/mutation_verifier.dart`: 54 mutant(s) survived. Score: 29.9% (23/77). Quality: E.
- `lib/src/plugins/tdd/services/spec_parser.dart`: 4 mutant(s) survived. Score: 92.9% (52/56). Quality: B.
- `lib/src/plugins/tdd/commands/init_command.dart`: 47 mutant(s) survived. Score: 13.0% (7/54). Quality: F.
- `lib/src/plugins/tdd/commands/plan_command.dart`: 64 mutant(s) survived. Score: 0.0% (0/64). Quality: F.
- `lib/src/plugins/tdd/commands/verify_command.dart`: 52 mutant(s) survived. Score: 21.2% (14/66). Quality: E.
- `lib/src/plugins/tdd/commands/gen_command.dart`: 16 mutant(s) survived. Score: 5.9% (1/17). Quality: F.
- `lib/src/plugins/tdd/commands/make_command.dart`: 10 mutant(s) survived. Score: 23.1% (3/13). Quality: E.
- `lib/src/plugins/tdd/commands/refactor_command.dart`: 7 mutant(s) survived. Score: 30.0% (3/10). Quality: E.
- `lib/src/plugins/tdd/commands/run_command.dart`: 8 mutant(s) survived. Score: 27.3% (3/11). Quality: E.
- `lib/src/plugins/tdd/commands/verify_red_command.dart`: 10 mutant(s) survived. Score: 23.1% (3/13). Quality: E.
- `lib/src/commands/tdd_command.dart`: 10 mutant(s) survived. Score: 23.1% (3/13). Quality: E.

## Errors

(none)
