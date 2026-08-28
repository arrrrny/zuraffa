# Bug Issue: zfa lacks built-in SQLite data source generation (only Hive)

- **Slug**: issue-464-sqlite-adapter-missing
- **Fetched**: 2026-08-23T11:49:39.475676+00:00
- **Issue**: 464
- **URL**: https://github.com/arrrrny/zuraffa/issues/464
- **State**: open
- **Severity**: high
- **Author**: arrrrny
- **Labels**: bug, enhancement

## Body

## Symptom

The zuraffa framework includes built-in support for Hive (via `hive_ce` and `hive_ce_generator`) for local storage and caching, with a `zfa cache adapter <EntityName>` command that generates Hive TypeAdapters and registers them. However, there is **no equivalent for SQLite** — no `zfa sqlite adapter` command, no SQLite data source template in the mock plugin, and no built-in pattern for generating a `DataSource` implementation backed by `package:sqlite3`. Projects requiring a production SQLite store (like forklift Phase 7) must hand-write the entire `TaskSqliteDataSource` implementing the generated `TaskDataSource` interface, including schema creation, WAL mode, migrations, and CRUD operations.

## Reproduction

1. Run `zfa init --dart --deps-only` in a pure-Dart package
2. Create an entity: `zfa entity create -n Task --auto-id --field spec:String --field status:String`
3. Generate CRUD with mock: `zfa make Task --preset=crud --mock --di --use-mock --methods=get,getList,create,update,delete`
3. Run `zfa build`
4. Observe that `zfa cache adapter Task` generates Hive adapters, but there is no `zfa sqlite adapter Task` or similar command
5. Check `zfa help` — no SQLite-related subcommands exist
6. Hand-write `TaskSqliteDataSource` implementing `TaskDataSource` with `sqlite3` package

## Suspected Code Paths

- `/workspace/zuraffa/lib/src/plugins/cache/` — Hive cache adapter plugin (generates TypeAdapters, registrars)
- `/workspace/zuraffa/lib/src/plugins/mock/builders/mock_datasource_builder.dart` — mock data source template (read-only fixture)
- `/workspace/zuraffa/lib/src/commands/cache_command.dart` — `zfa cache adapter` command
- `/workspace/zuraffa/lib/src/commands/entity_command.dart` — entity commands (no sqlite subcommand)

## Root Cause Hypothesis

**Confidence: high**. Zuraffa's architecture prioritizes Hive for local-first/offline storage (Flutter/web friendly). SQLite is a server/Dart-VM-only concern and was not included in the v5/v6 plugin set. The `cache` plugin handles Hive; there is no `sqlite` plugin. This is a **feature gap**, not a bug per se, but it forces every server-side project to hand-write the same boilerplate SQLite data source.

## Severity

high

## Assessment

Assessment: .specify/bugs/zfa-sqlite-support/assessment.md


## Comments

None.
