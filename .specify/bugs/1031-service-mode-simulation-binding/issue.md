# Bug Issue: service-mode mock create emits datasource-shaped simulation binding referencing nonexistent classes

- **Slug**: 1031-service-mode-simulation-binding
- **Fetched**: 2026-09-04
- **Issue**: 1031
- **URL**: https://github.com/arrrrny/zuraffa/issues/1031
- **State**: open
- **Severity**: medium
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

Context: found while building the ZikZak login engine slice (engine/skin split, #1008).

### Repro

    zfa service create Auth --params AuthRequest --returns User
    zfa usecase create Login --domain auth --service AuthService --params AuthRequest --returns User
    zfa mock create --name Auth --service Auth --params AuthRequest --returns User --domain auth
    dart analyze

The service-mode `zfa mock create` emits `lib/src/di/simulation/auth_simulation_datasource_di.dart`:

    import '../../data/datasources/auth/auth_datasource.dart';
    import '../../data/datasources/auth/auth_mock_datasource.dart';
    void registerAuthSimulationDataSource(GetIt getIt) { ... AuthDataSource -> AuthMockDataSource ... }

but in service mode NO AuthDataSource/AuthMockDataSource pair exists — the imports do not
resolve (uri_does_not_exist) and the emitted binding binds interfaces that were never generated.

### Expected

In service mode, the simulation binding should follow the service shape it actually generated:

    void registerAuthSimulationService(GetIt getIt) {
      if (!kSimulationMode) return;
      getIt.registerLazySingleton<AuthService>(() => AuthMockProvider());
    }

— i.e. `<Name>Service` -> `<Name>MockProvider`, mirroring how the datasource lane binds
`<Entity>DataSource` -> `<Entity>MockDataSource` (SimulationBindingBuilder).

### Root cause

SimulationBindingBuilder.buildBindingFile is hardcoded to the datasource shape
(`<Entity>DataSource`/`<Entity>MockDataSource`), and the mock plugin's call site does not
branch on `config.hasService`.

### Context

Worked around in the sandbox by deleting the emitted datasource-shaped binding file and
relying on `zfa di create --use-mock` (which correctly binds `AuthService -> AuthMockProvider`
in the plain layer — see `_generateServiceDI`'s `useMockInDi` branch). Filing because the
datasource-shaped debris will hit every service-mode engine slice.
