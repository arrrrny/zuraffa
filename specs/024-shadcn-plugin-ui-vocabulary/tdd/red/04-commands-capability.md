# Red Evidence — CLI commands + MCP capability

**Test file**: `test/plugins/shadcn/ui_command_test.dart`
**Behaviors**: B19 — zfa ui schema; B20 — zfa ui validate; B21 — zfa ui
preview (gates + harness); B22 — zfa make --ui; B23 — capability (FR-006)
**Spec**: FR-002, FR-004, FR-006, FR-008, US-1..4, Edge Cases

## First-run output (before implementation)

```
$ dart test test/plugins/shadcn/ui_command_test.dart
  test/plugins/shadcn/ui_command_test.dart:223:32: Error: Member not found:
  'MakeCommand.forTesting'.
  test/plugins/shadcn/ui_command_test.dart:247:22: Error:
  'UiVocabularyExportCapability' isn't a type.
00:00 +0 -1: Some tests failed.
```

**Status**: RED ✓ — no `zfa ui` command family, no `--ui` make flag, no
export capability on the shadcn plugin.
