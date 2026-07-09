# Key Insights

<!-- Updated: 2026-07-09 -->

## VM Service Extensions: `isolateId` Is Mandatory for RPC Calls

- **VM Service extensions MUST be called via WebSocket JSON-RPC with `isolateId` in params — HTTP GET silently returns "Method not found" for custom extensions in Flutter 3.44+.**
  - Context: Extensions registered via `developer.registerExtension('ext.zuraffa.ping', ...)` appear in the isolate's `extensionRPCs` list but `curl http://host/ext.zuraffa.ping` returns "Method not found". The same extension called via WebSocket with `{'method':'ext.zuraffa.ping','params':{'isolateId':'isolates/...'}}` works immediately.
  - Impact: All `call_ext.dart`, `test_vm_extension.dart`, and `call_api.sh` scripts must use WebSocket + `isolateId`, never HTTP GET. The `dart:developer.registerExtension` API documentation implies HTTP GET should work but Flutter's service protocol routing intercepts it.

- **`isolateId` must match the main user isolate — not vm-service, not engine isolates.**
  - Context: `curl http://host/getVM` returns all isolates. Extension calls must target the user isolate (e.g., `isolates/123456789` where `name:'main'` and `isSystemIsolate:false`). Calling with wrong isolate ID silently routes to the wrong handler.
  - Impact: Scripts must dynamically resolve `isolateId` from `getVM` — never hardcode it across app restarts.

## ZuraffaApiBridge: UseCases MUST Be Registered in DI

- **The bridge calls `GetIt.I<GetTodoListUseCase>()` — if the UseCase isn't registered in the DI container, the extension returns a "not registered" error, not a "method not found" error.**
  - Context: The bridge `registerTodoApiBridge()` registered the extension handler but the example app's DI only registered Concert UseCases. The handler executed, resolved the UseCase from GetIt, and `GetIt.I<T>()` threw. This produced a `status: "error"` response, not a 404.
  - Impact: Every UseCase exposed via the bridge must have a corresponding DI registration. The `zfa api` command should auto-generate DI registrations alongside the bridge file, or at minimum document the dependency clearly.

## Zorphy `fromJson`: Non-Nullable Primitive Fields Require Defaults in Bridge Handlers

- **`Entity.fromJson(MissingField)` crashes with `'type Null is not a subtype of type num'` when non-nullable primitives (`int`, `double`, `bool`) are absent from the input JSON.**
  - Context: `Todo.fromJson({'title':'Test'})` fails because `id: int` is non-nullable and the generated `fromJson` does `json['id'] as int`. Nullable fields (`String?`) work fine as-is.
  - Impact: Generated bridge handlers for `create*` endpoints must pre-populate non-nullable primitive fields with defaults (`id:0`, `createdAt:DateTime.now().toIso8601String()`) before calling `fromJson`. The `zfa api` command should detect non-nullable fields in the entity and generate the default-fill logic.

## DTD `hot_restart` Does NOT Re-Register VM Service Extensions

- **`hot_restart` via DTD resets app state but does NOT re-run `main()` — VM Service extensions registered in `main()` remain from the previous cold start.**
  - Context: After hot restart, extensions registered in `main()` still work but don't reflect code changes. A cold start (`flutter run` from scratch) is required to load new `registerExtension` calls.
  - Impact: When testing VM Service extensions, always do a cold restart after adding or changing `developer.registerExtension` calls.

## `Hive.openBox()` Must Be Called Before Repository Operations

- **Repository operations fail with `HiveError: Box not found. Did you forget to call Hive.openBox()?` if `initAllCaches()` doesn't complete successfully before the repository is used.**
  - Context: The example app's `main.dart` has a `catchError` path that starts the app even when `setupDependencies()` fails. On macOS, Hive initialization may fail silently, causing the app to boot without Hive boxes open. UseCase operations via the bridge then fail at the repository layer.
  - Impact: The `catchError` in main.dart should at minimum log the error and NOT start the app. Alternatively, the bridge handler should return `ServiceExtensionError.result` with a descriptive message when the UseCase throws a `HiveError`.
