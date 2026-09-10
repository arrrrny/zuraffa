# Chore PR: Improve readability of zfa tdd help text

- **Slug**: zfa-tdd-help-readability
- **Opened**: 2026-09-10
- **PR**: 1460
- **URL**: https://github.com/arrrrny/zuraffa/pull/1460
- **Branch**: chore/zfa-tdd-help-readability
- **Issue**: 1452

Added `usageLineLength: 120` to the `_CrashSafeCommandRunner` constructor call, enabling line wrapping for the runner-level help and `TddCommand`'s usage output. This ensures command descriptions are wrapped at a consistent column width, preserving column alignment and improving readability. Branch-command subcommand help (e.g. `zfa spec`, `zfa feature`) is not covered by this change.
