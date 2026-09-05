# Bug Fix PR: cache adapter receipt: kind string has space instead of hyphen, entitySource is null (2 failing tests)

- **Slug**: cache-adapter-receipt-kind
- **Opened**: 2026-09-05
- **PR**: 1151
- **URL**: https://github.com/arrrrny/zuraffa/pull/1151
- **Branch**: fix/cache-adapter-receipt-kind
- **Issue**: 1130

Removes duplicate receipt that shadowed the correct cache-adapter receipt; both failing tests now pass with zero regressions.