# TDD Test List — #1496 config-init-defaults-all-false

- **Feature dir**: `.specify/bugs/1496-config-init-defaults-all-false`
- **Suite**: `test/commands/bug_1496_config_init_defaults_test.dart`
- **Derived from**: `assessment.md` (remediation plan) + `issue.md`
  (expected items 1-4)

## Behaviors (red → green, one row per pinned behavior)

| ID | Behavior | Test | Level | RED (master b621f38b) | GREEN (fix branch) |
| -- | -------- | ---- | ----- | --------------------- | ------------------ |
| B1 | `config init` writes the 12 stack plugins `true`, opt-ins `false` | `B1 — ZfaConfig.init writes the stack true and opt-ins false` | unit (temp dir) | FAIL (all false) | PASS |
| B2 | The in-memory default enables the stack; bare plan resolves the stack | `B2 — the in-memory default enables the stack for the resolver` | unit + real registry | FAIL (empty pluginIds) | PASS |
| B3 | Custom configs: explicit `false` still wins | `B3 — explicit false in a custom config still wins` | unit (temp dir) | FAIL (mock/route flips impossible to pin against an all-false base) | PASS |
| B4 | `config init --minimal` writes the all-off map | `B4 — config init --minimal keeps the all-off behaviour` | integration (CliRunner) | FAIL (unknown flag, no file) | PASS |
| B5 | Bare `zfa make <Entity>` in an init-ed project generates the stack | `B5 — bare zfa make in an init-ed project generates the stack` | integration (real generation) | FAIL ("No active plugins to run.", zero files) | PASS |
| B6 | Empty-plan message names the remedy | `B6 — the empty-plan message names the remedy` | integration (CliRunner) | FAIL (dead-end line) | PASS |

## Guardrails (must NOT change)

| Guard | Evidence |
| ----- | -------- |
| Registry untouched | 0 diff lines under plugin registry sources |
| Plan resolver logic untouched | `plan_resolver.dart` 0 diff; `plan_resolver_test.dart` green unmodified |
| State machine untouched | no state-machine files in the diff |
| Existing custom configs unaffected | B3 + `test/core/plugin_system/plugin_manager_test.dart` + `test/regression/compare_outputs_test.dart` green |
