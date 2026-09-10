# Chore PR: Improve readability of zfa tdd help text

- **Slug**: zfa-tdd-help-readability
- **Opened**: 2026-09-10
- **PR**: 1453
- **URL**: https://github.com/arrrrny/zuraffa/pull/1453
- **Branch**: chore/zfa-tdd-help-readability
- **Issue**: 1452

Added `usageLineLength: 100` to the `_CrashSafeCommandRunner` constructor call, enabling line wrapping for all CLI help text. This ensures command descriptions are wrapped at a consistent column width, preserving column alignment and improving readability.