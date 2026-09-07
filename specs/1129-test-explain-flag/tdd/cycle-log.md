# TDD Cycle Log: 1129-test-explain-flag

## Cycle 1 — the `--explain` flag (all behaviors)

**RED** (before any implementation):
- CLI probe: `zfa test create --name FetchUser --explain` → `❌ Could not find an option named "--explain".`
- Suite: `dart test test/plugins/test/test_explain_test.dart` → load error (`No named parameter with the name 'projectRoot'` on `TestCommand`).

**GREEN** (implementation: `test_explain.dart`, `test_create_command.dart`, `test_command.dart` wiring, capability schema):
- `dart test test/plugins/test/test_explain_test.dart` → `+14: All tests passed!`

**REFACTOR**:
- Test-side corrections (implementation semantics kept — they are the honest ones):
  - A8 re-pinned: an ALL-skipped run wrote nothing, so the honest block tier is `unverified`; the "pre-existing never lowers the floor" property moved to a mixed-run builder test (U6).
  - U12 fixed to parent the command tree under a `CommandRunner` before reading `usage` (package:args walks `parent.invocation`).
- File-formatting pass via `dart format .`; unrelated pre-existing unformatted files (specs/1142 evidence) reverted.

## Cycle 2 — verification

- Targeted suite: `dart test test/plugins/test/` → `+61: All tests passed!`
- `dart analyze` (5 changed/new files) → No issues found!
- Format gate: `dart format --output=none --set-exit-if-changed <5 files>` → 0 changed.
- Manifest treaty: `zfa manifest --verify test` → 1 route certified, 0 drift findings (exit 0).
- Real-CLI sandbox demo (real `dart analyze`): acceptance invocations 1 and 2 verified; `--json` alone unchanged.
