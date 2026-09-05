# Bug Verification: cache adapter receipt: kind string has space instead of hyphen, entitySource is null (2 failing tests)

- **Slug**: cache-adapter-receipt-kind
- **Tested**: 2026-09-05
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

The two original failures (space-separated command string, null spec binding) no longer reproduce. All 6 targeted receipt tests and all 46 cache tests pass. No regressions found.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `dart test test/plugins/cache/cache_adapter_receipt_test.dart` | pass | 6/6 — both original failures now pass |
| New / updated tests | same as above | pass | receipt asserts `command == 'cache-adapter'` and `spec != null` |
| Regression suite | `dart test test/plugins/cache/` | pass | 46/46 — zero regressions across the full cache module |
| Lint / type-check | `dart analyze` on 3 changed files | pass | No issues found |

## Output Excerpts

```
00:00 +6: All tests passed!                    (cache_adapter_receipt_test.dart)
00:07 +46: All tests passed!                   (test/plugins/cache/)
Analyzing ... No issues found!                  (dart analyze)
```

## Residual Risks

- The fix removed a duplicate receipt path (`CapabilityInvocationWrapper.persistReceipt`
  call and `CapabilityCommand._persistCapabilityReceipt`); capabilities that rely on
  the wrapper's receipt for proof verification may need to be audited — but the
  capability's own `_emitReceipt` already writes the canonical receipt, so the
  duplicate was dead weight.

## Recommendation

Close the bug — verified end-to-end. Both acceptance criteria (hyphenated command,
non-null spec) are met, and the full cache test suite is green.
