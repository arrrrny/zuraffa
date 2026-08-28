# Bug Issue: zfa provider: service methods use NoParams but provider generates zero-arg signatures → invalid_override

- **Slug**: issue-409-zfa-provider-service-methods-use-noparams-but-provider-gener
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 409
- **URL**: https://github.com/arrrrny/zuraffa/issues/409
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

**Bug**: Service methods default to `NoParams` parameter, but provider implementations generate zero-arg signatures → `invalid_override` analyzer error.

**Reproduction**:
1. `zfa service method --target MyService --name list --params NoParams`
2. `zfa provider create MyService --data --force`
3. `dart analyze` → `'MyProvider.list' ('List<Item> Function()') isn't a valid override of 'MyService.list' ('List<Item> Function(NoParams)')`

**Expected**: Provider methods should match service signatures exactly (include `NoParams params` parameter).

**Root cause**: `lib/src/plugins/provider/builders/provider_builder.dart` lines 147-150 — when extracting existing service methods, the params handling for `NoParams` produces empty parameter list instead of `NoParams params`.


## Comments

None.
