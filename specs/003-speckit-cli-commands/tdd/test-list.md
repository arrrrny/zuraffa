# TDD Test List: 003-speckit-cli-commands

**Feature**: Implement all ZFA CLI Commands in Zuraffa Speckit Extension  
**Spec**: `/specs/003-speckit-cli-commands/spec.md`  
**Plan**: `/specs/003-speckit-cli-commands/plan.md`  
**Baseline Commit**: `614e648`  
**Generated**: 2026-08-26  

---

## Acceptance Behaviors (Outer Loop)

Derived from `spec.md` User Stories and Success Criteria.

| ID | Behavior | Type | Source | Status | Test Name / Path |
|---|---|---|---|---|---|
| **A1** | AI agent can scaffold complete Todo app using only extension commands (no manual file writing) | acceptance | US1, SC-002 | PENDING | `integration/todo_app_e2e_test.dart` |
| **A2** | Generated Todo app passes `flutter analyze` with zero errors | acceptance | SC-003 | PENDING | `integration/todo_app_e2e_test.dart` |
| **A3** | Generated Todo app runs without runtime errors | acceptance | US1, SC-004 | PENDING | `integration/todo_app_e2e_test.dart` |
| **A4** | All plugin commands from `zfa manifest` are available as extension .md files | acceptance | SC-001 | PENDING | `regression/manifest_coverage_test.dart` |
| **A5** | Regenerating from manifest produces identical command files (reproducible) | acceptance | SC-005 | PENDING | `regression/manifest_regeneration_test.dart` |
| **A6** | Extension detects missing zfa and reports clearly | acceptance | Edge Case 1 | PENDING | `integration/zfa_missing_detection_test.dart` |
| **A7** | Extension handles invalid parameters by surfacing CLI errors | acceptance | Edge Case 3 | PENDING | `integration/invalid_params_handling_test.dart` |

---

## Unit Behaviors (Inner Loop)

Derived from `spec.md` Functional Requirements and `plan.md` tasks.

| ID | Behavior | Type | Source | Status | Test Name / Path |
|---|---|---|---|---|---|
| **U1** | `generate-commands` script regenerates all .md files from `zfa manifest` output | unit | FR-001, FR-003, FR-008 | DONE | `test/commands/generate_command_test.dart` |
| **U2** | Each generated command .md file has correct YAML frontmatter (name, description, category) | unit | FR-001, FR-004 | PENDING | `test/commands/generate_command_test.dart` |
| **U3** | Each generated command .md includes all flags from manifest inputSchema | unit | FR-002 | PENDING | `test/commands/generate_command_test.dart` |
| **U4** | Commands are organized into correct category subdirectories | unit | FR-004 | DONE | `test/commands/generate_command_test.dart` |
| **U5** | Extension.yml provides section includes all 26+ commands with correct aliases | unit | FR-001 | DONE | `test/commands/generate_command_test.dart` |
| **U6** | Category index files exist for each category directory | unit | US2, T037 | DONE | *(existing directory structure)* |
| **U7** | Category navigation index.md exists and lists all commands by category | unit | US2, T039 | DONE | *(existing commands/index.md)* |
| **U8** | Auto-discovery configuration in extension.yml enables regeneration | unit | FR-003, T045 | DONE | *(extension.yml auto-discovery)* |
| **U9** | Regeneration script updates extension from ZFA CLI without manual edits | unit | FR-003, T044 | PENDING | `test/commands/generate_command_test.dart` |
| **U10** | Extension supports `--format=json` and `--dry-run` for generation commands | unit | FR-005 | DONE | `test/commands/make_command_test.dart` |
| **U11** | Extension help text matches CLI `--help` output for each command | unit | FR-002, T048 | PENDING | `test/commands/help_text_test.dart` |

---

## Coverage Notes

- **A1-A3**: Full E2E integration test - scaffold Todo app via extension commands only
- **A4**: Verifies 53 commands from manifest all have .md files
- **A5**: Verifies idempotent regeneration
- **A6-A7**: Error handling edge cases
- **U1, U4, U5, U6, U7, U8, U10**: Already implemented based on existing extension structure and tests
- **U2, U3, U9, U11**: Need new test coverage

---

## Existing Test Mapping

| Test File | Covers Behaviors |
|---|---|
| `test/commands/generate_command_test.dart` | U1, U4, U5 (migration guidance) |
| `test/commands/make_command_test.dart` | U10 (--format=json, --plan, --from-json, --from-stdin) |
| `test/commands/feature_command_test.dart` | Feature scaffold plan normalization |
| `test/integration/full_entity_workflow_test.dart` | A1-A3 pattern (full workflow) |
| `test/regression/regression_test_utils.dart` | Helpers for A1-A3 implementation |

---

## Test Commands (from TDD Profile)

- **Single test**: `dart test {file} -n "{name}"`
- **File**: `dart test {file}`
- **Fast suite**: `dart test test` (excludes slow)
- **Integration tier**: `dart test --preset=integration`
- **Full suite**: `dart test --preset=all`

---

## Next Steps

1. Run baseline tests to confirm current state
2. Implement PENDING behaviors (A1-A7, U2, U3, U9, U11)
3. Record each cycle in `cycle-log.md`
4. Verify with `verification.md`