# Bug Issue: cache adapter receipt: kind string has space instead of hyphen, entitySource is null (2 failing tests)

- **Slug**: cache-adapter-receipt-kind
- **Fetched**: 2026-09-05
- **Issue**: 1130
- **URL**: https://github.com/arrrrny/zuraffa/issues/1130
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

## Mission

Two tests in `test/plugins/cache/cache_adapter_receipt_test.dart` are currently failing on master:

1. **Receipt kind string mismatch**: the test expects `'cache-adapter'` (hyphenated) but the code emits `'cache adapter'` (space-separated).
2. **Entity source binding**: the test expects a non-null `entitySource` on the receipt, but it is null.

These failures were found by the re-grade session (2026-09-05) and are blocking the full test suite from being green (1,328 passed, 2 failed).

## Orders

1. Find where the `cache-adapter` receipt kind is written and change the space to a hyphen to match the test expectation `'cache-adapter'`. Check `lib/src/plugins/cache/capabilities/create_cache_adapter_capability.dart` and `lib/src/core/project/receipt_store.dart`.
2. Find where `entitySource` is set on cache adapter receipts and ensure it is populated with the entity source file path (the same pattern `repository_plugin.dart:375-420` uses for `RepositoryContractManifest`).
3. Run `dart test test/plugins/cache/cache_adapter_receipt_test.dart` — all tests must pass.
4. Run the full cache chunk: `dart test test/plugins/cache/` — all 84+ tests must pass.

## Constraints

- Do not change any receipt semantics beyond fixing these two bugs.
- Do not change other plugins' receipt code.

## Acceptance

- `dart test test/plugins/cache/cache_adapter_receipt_test.dart` exits 0.
- Both receipts assert `'cache-adapter'` (hyphen) and non-null `entitySource`.
- No regressions in other cache tests.

## Comments

None.