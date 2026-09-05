# RED Evidence — Issue #1031 (service-mode simulation binding shape)

Date: 2026-09-04
Branch: fix/1031-service-mode-simulation-binding-shape
Repro: GitHub issue #1031 verbatim flow in scratch project
(`/home/z/my-project/red-repro/scratch`, zuraffa path dep):

```
zfa service create Auth --params AuthRequest --returns User
zfa usecase create Login --domain auth --service AuthService --params AuthRequest --returns User
zfa mock create --name Auth --service Auth --params AuthRequest --returns User --domain auth
dart analyze
```

## Observed emission (mock create, service mode)

```
✅ Success! Created/Modified:
  ✨ lib/src/data/mock/user_mock_data.dart
  ✨ lib/src/data/providers/auth/auth_mock_provider.dart
  ✨ lib/src/di/simulation/auth_simulation_datasource_di.dart   <-- WRONG SHAPE
  ✨ lib/src/di/simulation/index.dart
```

Emitted binding content (datasource shape, hardcoded):

```dart
import '../../data/datasources/auth/auth_datasource.dart';
import '../../data/datasources/auth/auth_mock_datasource.dart';

void registerAuthSimulationDataSource(GetIt getIt) {
  if (!kSimulationMode) return;
  getIt.registerLazySingleton<AuthDataSource>(() => AuthMockDataSource());
}
```

Neither `AuthDataSource` nor `AuthMockDataSource` was generated in service
mode — the mock lane generated `AuthMockProvider` (service shape) instead.

## dart analyze (RED)

```
error - lib/src/di/simulation/auth_simulation_datasource_di.dart:9:8 - Target of URI doesn't exist: '../../data/datasources/auth/auth_datasource.dart' - uri_does_not_exist
error - lib/src/di/simulation/auth_simulation_datasource_di.dart:10:8 - Target of URI doesn't exist: '../../data/datasources/auth/auth_mock_datasource.dart' - uri_does_not_exist
error - lib/src/di/simulation/auth_simulation_datasource_di.dart:14:31 - The name 'AuthDataSource' isn't a type, so it can't be used as a type argument. - non_type_as_type_argument
error - lib/src/di/simulation/auth_simulation_datasource_di.dart:14:53 - The function 'AuthMockDataSource' isn't defined. - undefined_function
```

(Note: the scratch project also reports unrelated uri errors for missing
entity types — the issue's sandbox likewise does not create entity files.
The bug-specific RED failures are the four binding errors above. After the
fix, the same repro emits `auth_simulation_service_di.dart` with zero
errors under `di/simulation/`.)

## Unit-level RED

`dart test test/plugins/di/simulation_binding_test.dart` (pre-fix, with the
new #1031 group added test-first): exit 1 — `+8 -2: Some tests failed.`
(B1 and B2 red; all 8 pre-existing tests green.)

## Expected (per issue #1031)

```dart
void registerAuthSimulationService(GetIt getIt) {
  if (!kSimulationMode) return;
  getIt.registerLazySingleton<AuthService>(() => AuthMockProvider());
}
```
