# Bug Verification: fix(zfa make): no first-field id fallback + emit enum imports for signature types (supersedes #307; coordinates with #320 autoId)

- **Slug**: issue-321-fix-zfa-make-no-first-field-id-fallback-emit-enum-imports-fo
- **Tested**: 2026-08-22T00:00:00+00:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

The #321 source fix already ships in `origin/master` (merged as #324): the
resolver no longer silently picks the first field as the id, and the presenter's
import resolution now includes the id/query field types so a legitimate enum id
emits its barrel import. This PR adds a fast, plugin-level regression test that
drives the presenter plugin directly and asserts the generated import set reacts to
the id-field type (enum → barrel import emitted; primitive → no enum import). The
test needs no flutter SDK or `zfa make` subprocess, so it runs in the unit tier.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| New regression test | `dart test test/plugins/presenter/presenter_enum_id_import_test.dart` | pass | 2/2 tests — enum id imports barrel; primitive id does not. |
| Lint / type-check | `dart analyze lib` | pass | No `error` lines (no lib changes in this PR). |
| Existing regression | `dart test test/regression/issue_321_no_first_field_id_fallback_enum_import_test.dart` (pre-existing) | pass | Guards resolver + loud-error + full integration on master. |

## Output Excerpts

```
00:00 +2: All tests passed!
```

Generated presenter snippet (enum id) asserted to import:
```
import '../../../domain/entities/enums/index.dart';
...
Future<Result<MessageLog, AppFailure>> updateMessageLog(
  MessageType messageTypeId, MessageLogPatch data, ...) {
  return _updateMessageLog.call(
    UpdateParams<MessageType, MessageLogPatch>(id: messageTypeId, data: data), ...);
}
```

## Residual Risks

- The test inspects generated text only; it does not compile the output. The
  end-to-end compile-guard remains in `test/regression/issue_321_...` and the
  `zuraffa_flutter` package.

## Recommendation

Close the bug — the fix is merged in master and now locked by both the existing
slow regression test and this fast unit test.
