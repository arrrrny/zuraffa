Fixes #1130 — two failing tests in `test/plugins/cache/cache_adapter_receipt_test.dart`.

## Summary

The cache adapter capability was writing its own receipt via `_emitReceipt`,
and `CapabilityCommand._persistCapabilityReceipt` was writing a second one.
The two raced: alphabetical filename sort put the wrapper's space-separated
receipt last in `loadAll()`, shadowing the capability's correct
hyphenated receipt.

The fix consolidates receipt writing into a single path:
`CapabilityCommand._persistCapabilityReceipt` is the single source of truth
for standalone capability receipts. The cache adapter capability no longer
writes its own receipt — it exposes the spec/registrar hash/build status
via `args['_spec']`, `args['_registrarHash']`, etc., and the wrapper
assembles them into a `proof.v1` receipt with the correct hyphenated
command (`'cache-adapter'`) and spec binding.

## Changes

| File | Change |
|------|--------|
| `lib/src/commands/capability_command.dart` | `_persistCapabilityReceipt` now uses hyphenated command (`'$pluginName-$verb'`) and reads spec from `args['_spec']`; merges `args['_discoveredEntities']` / `args['_registrarHash']` / `args['_buildStatus']` into the receipt input as canonical keys |
| `lib/src/plugins/cache/capabilities/create_cache_adapter_capability.dart` | Removed duplicate `_emitReceipt`; replaced with `_buildReceiptSpec` (just computes the spec binding); exposes registrar hash, build status, and discovered entities via `args` for the wrapper to assemble |
| `lib/src/core/plugin_system/capability_invocation_wrapper.dart` | Added `_specOf` helper used by capabilities that bypass `CapabilityCommand` (e.g. `zfa shadcn`) |

## Local Verification

- `dart test test/plugins/cache/cache_adapter_receipt_test.dart` → 6/6 passed
- `dart test test/plugins/cache/` → 46/46 passed (zero regressions)
- `dart analyze` on all changed files → no issues

Assessment: .specify/bugs/cache-adapter-receipt-kind/assessment.md

Closes #1130