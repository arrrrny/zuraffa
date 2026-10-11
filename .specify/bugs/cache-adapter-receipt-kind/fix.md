# Bug Fix: cache adapter receipt: kind string has space instead of hyphen, entitySource is null (2 failing tests)

- **Slug**: cache-adapter-receipt-kind
- **Fixed**: 2026-09-05
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

The `CapabilityInvocationWrapper.persistReceipt` wrote a duplicate receipt with
`command: '$pluginId ${capability.name}'` (space-separated, e.g. `'cache adapter'`)
and no `spec` binding. This receipt shadowed the capability's own correct receipt
(`'cache-adapter'` hyphenated, with `spec` populated) because alphabetical filename
sorting put the wrapper's receipt last in `loadAll()`. The fix removes the
wrapper's duplicate receipt — the capability's `_emitReceipt` is already the single
source of truth for standalone cache-adapter receipts.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/core/plugin_system/capability_invocation_wrapper.dart` | modified | Removed `persistReceipt` call from `execute()`; added `_specOf()` helper for future use |
| `lib/src/commands/capability_command.dart` | modified | Removed duplicate `_persistCapabilityReceipt` call and dead methods; cleaned up unused imports |

## Diff Highlights

**capability_invocation_wrapper.dart** — `execute()` no longer persists a receipt:

```dart
Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    final result = await capability.execute(args);
    // Issue #1130: the capability's own _emitReceipt (inside execute above)
    // already writes the canonical proof.v1 receipt with the hyphenated
    // command string and spec binding. This wrapper no longer writes a
    // second receipt — the duplicate shadowed the capability's receipt
    // (alphabetical filename sort put the wrapper's space-separated
    // command name last, which loadAll().last returned).
    return result;
  }
```

**capability_command.dart** — removed dead `_persistCapabilityReceipt` and unused imports (`crypto`, `path`, `receipt_store`, `version`).

## Tests Added or Updated

No new tests — the existing tests already assert the correct behavior and now pass:

- `cache_adapter_receipt_test.dart::a cache-adapter receipt lands in .zfa/receipts/ with the full payload` — passes (`command == 'cache-adapter'`)
- `cache_adapter_receipt_test.dart::the receipt binds the entity source as its spec` — passes (`spec` is non-null)
- `cache_adapter_receipt_test.dart::a second adapter run supersedes the first receipt (latest wins)` — passes (2 receipts total, not 4)

## Local Verification

- `dart test test/plugins/cache/cache_adapter_receipt_test.dart` → 6/6 passed
- `dart test test/plugins/cache/` → 46/46 passed (zero regressions)
- `dart analyze` on all 3 changed files → no issues

## Deviations from Assessment

The assessment flagged `entitySource` as the null field; the actual test checks
`receipt.spec` (a `GenerationReceiptSpec` with `.path` and `.sha256`). The fix
addresses the correct field.

The assessment pointed to `create_cache_adapter_capability.dart` and `receipt_store.dart`
as the code locations. The root cause was actually in `capability_invocation_wrapper.dart`
(duplicate receipt with wrong format) and `capability_command.dart` (second duplicate).
The capability's own code was already correct.

## Follow-ups

- `CapabilityInvocationWrapper.persistReceipt` and `_specOf` are now unused but
  retained for potential future use if the wrapper needs to support capabilities
  that do NOT write their own receipt.
- Consider whether `CapabilityCommand` should support both receipt paths (wrapper
  and capability-internal) or standardize on one.
