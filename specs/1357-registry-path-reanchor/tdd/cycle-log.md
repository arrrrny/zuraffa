# TDD Cycle Log — Spec 1357

## RED (2026-09-09)
- `dart test test/plugins/tdd/bug_1357_registry_path_reanchor_test.dart`
- `+3 -2`: B1 (sandbox-absolute paths loaded verbatim) and B5 (derive
  yields non-existent paths) RED; B2/B3/B4 guards green by design.
- Committed as certified red before the implementation.

## GREEN (2026-09-09)
- `ArtifactRegistry._loadRecords` re-anchors `test_path`/`subject_path`
  and the `runnable_test_name` path prefix via the pure
  `reanchorRecordPath` (absolute + missing + last `/test/`|`/lib/`
  suffix exists under the project root → repo-relative; everything
  else verbatim). `+5 All tests passed!` on the bug file.
- Regression pin: `dart test test/plugins/tdd/` → `+1789 ~1 -2`. The 2
  failures (`view_command_test` U-V3, `wire_command_test` U-W3) are
  PRE-EXISTING on master (reproduced identically with the change
  stashed; environment-specific runner-error spawns, untouched lanes).
- analyze clean, format clean.
