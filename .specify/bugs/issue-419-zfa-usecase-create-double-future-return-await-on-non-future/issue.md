# Bug Issue: zfa usecase create: double Future return + await on non-Future for sync type

- **Slug**: issue-419-zfa-usecase-create-double-future-return-await-on-non-future
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 419
- **URL**: https://github.com/arrrrny/zuraffa/issues/419
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

**Bug**: Generated usecases have double-Future returns and await-on-non-Future:

1. **Double Future**: `zfa usecase create --service EngineLoopService --params MissionConfig --returns "Future<void>" --type future` produces `Future<Future<void>> execute(...)` because `_returnType('usecase', 'Future<void>')` wraps the already-Future return.

2. **Await on non-Future**: For `--type sync`, the generated execute method uses `await _service.method(params)` but service returns non-Future (e.g., `void`, `bool`, `String`) → `info: Uses 'await' on an instance of 'bool', which is not a subtype of 'Future'`.

**Reproduction**:
1. `zfa usecase create --name TestSync --service MyService --params String --returns bool --type sync`
2. Generated: `Future<bool> execute(String params) async { return await _myService.testSync(params); }` — await on bool.

**Expected**: 
- For `--type sync`: return `bool`, no `async`/`await`
- For `--type future`: `--returns` should be inner type (e.g., `void`), not `Future<void>`

**Files**: `lib/src/plugins/usecase/builders/usecase_builder.dart` or similar.


## Comments

None.
