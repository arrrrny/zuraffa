# Bug Issue: zfa service method: silent on success (no stdout output)

- **Slug**: issue-414-zfa-service-method-silent-on-success-no-stdout-output
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 414
- **URL**: https://github.com/arrrrny/zuraffa/issues/414
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

**Bug**: `zfa service method` produces no console output on success (silent), unlike other zfa commands that show `✅ Success! Created/Modified: ...`.

**Reproduction**:
1. `zfa service method --target MyService --name doThing --returns void --params String --type sync`
2. No output at all — must read file to confirm.

**Expected**: Consistent UX — show `✅ Success! Created/Modified: ...` like `provider create`, `usecase create`, etc.

**Files**: `lib/src/plugins/method_append/capabilities/method_capability.dart` or the service method append code path.


## Comments

None.
