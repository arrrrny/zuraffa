# Breaking Changes

This document tracks breaking changes for v2 and how to adapt.

## v2.0.0

### CLI flags and generation patterns

- `--repos` replaced by `--repo`
  - Multi-repo workflows should use the orchestrator pattern with `--usecases`
- `--subdirectory` removed
  - Use `--domain` for custom UseCase folder placement
- Custom UseCases now require `--domain` and `--repo` (except orchestrators/background)
- UseCase files are organized by domain, not flat structure
- Repository method naming auto-matches UseCase name

### DI generation

- `--di` only registers DataSources and Repositories
- UseCases, Presenters, and Controllers are no longer auto-registered

### Parameter types

- Parameter selection is explicit via `--id-field-type` and `--query-field-type`
- Use `NoParams` for parameterless get/watch methods

## v2.8.0

### Parameter type handling

- Replaced string-based `query-field=null` handling with `--query-field-type`
- `--query-field-type` now independently controls get/watch parameter type

### Local-only data sources

- `--local` generates LocalDataSource instead of RemoteDataSource when used with `--data`
- If your workflow relied on remote generation, remove `--local`

## v2.5.x

### Domain-based custom UseCases

- Custom UseCases generate under `usecases/<domain>/` and require `--domain`
- Update manual imports to new paths

### Service-based custom UseCases

- `--service` now generates service interfaces in `domain/services/`
- Providers are generated in `data/providers/`

## v2.4.x

### GraphQL generation flags

- New `--gql` behavior adds GraphQL files under `data/data_sources/<entity>/graphql/`
- If you already had custom GraphQL files, confirm naming to avoid conflicts
