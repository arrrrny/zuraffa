Fixes #1130 — two failing tests in `test/plugins/cache/cache_adapter_receipt_test.dart`.

## Summary

The `CapabilityInvocationWrapper.persistReceipt` wrote a duplicate receipt with `command: 'cache adapter'` (space-separated) and no `spec` binding. This receipt shadowed the capability's own correct receipt (`'cache-adapter'` hyphenated, with `spec` populated) because alphabetical filename sorting put the wrapper's receipt last in `loadAll()`.

## Changes

| File | Change |
|------|--------|
| `lib/src/core/plugin_system/capability_invocation_wrapper.dart` | Removed `persistReceipt` call from `execute()`; added `_specOf()` helper for future use |
| `lib/src/commands/capability_command.dart` | Removed duplicate `_persistCapabilityReceipt` call and dead methods; cleaned up unused imports |

## Local Verification

- `dart test test/plugins/cache/cache_adapter_receipt_test.dart` → 6/6 passed (both original failures now pass)
- `dart test test/plugins/cache/` → 46/46 passed (zero regressions)
- `dart analyze` on all changed files → no issues

Assessment: .specify/bugs/cache-adapter-receipt-kind/assessment.md

Closes #1130