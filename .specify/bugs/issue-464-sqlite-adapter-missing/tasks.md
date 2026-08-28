# Tasks: issue-464 — SQLite data source generation (`zfa sqlite adapter <Entity>`)

**Input**: `.specify/bugs/issue-464-sqlite-adapter-missing/issue.md`

**Context**: zuraffa ships Hive (`zfa cache adapter`) but no SQLite path; server/Dart-VM projects must hand-write the whole `TaskSqliteDataSource`. Feature gap, severity high. Design follows the established plugin architecture (CachePlugin/MockPlugin precedent) and the mock datasource's semantics (query extension for reads, `applyTo` for updates, `copyWithField` for toggles).

## Design decisions

- Storage model: one row per entity — `id` TEXT PRIMARY KEY + `data` TEXT (JSON via the entity's generated `toJson`/`fromJson`), uniform across all field types; `schema_version` table + constant = migration scaffolding; `PRAGMA journal_mode=WAL` on open.
- Read semantics mirror the mock datasource (in-memory `query(params)` / offset+limit); id-keyed writes are real SQL (`INSERT OR REPLACE` / `UPDATE ... WHERE id` / `DELETE ... WHERE id`). SQL-level filter translation is explicitly a non-goal.
- Constructor takes a `Database` (package:sqlite3) — flexible, testable; the command reminds the user to add `sqlite3` (+ `sqlite3_flutter_libs` on Flutter).
- Command accepts both `zfa sqlite adapter <Entity>` (issue wording) and `zfa sqlite <Entity>`.

## Tasks

- [ ] T001 `lib/src/plugins/sqlite/builders/sqlite_datasource_builder.dart` — generates `<outputDir>/data/datasources/<snake>/<snake>_sqlite_datasource.dart` implementing `<Entity>DataSource` per `config.methods`: `_ensureSchema` (WAL + CREATE TABLE IF NOT EXISTS + schema_version), `get`, `getList`, `list`, `create`, `update` (SELECT→`applyTo`→UPDATE), `toggle` (SELECT→`copyWithField`→UPDATE), `delete`, `watch`/`watchList` (poll streams), `initialize`/`dispose`.
- [ ] T002 `lib/src/plugins/sqlite/capabilities/create_sqlite_adapter_capability.dart` — capability wiring (name/description/input-output schemas, execute → builder).
- [ ] T003 `lib/src/plugins/sqlite/sqlite_plugin.dart` — `SqlitePlugin` (id `sqlite`, CliAwarePlugin, generateWithContext passthrough).
- [ ] T004 `lib/src/commands/sqlite_command.dart` — `zfa sqlite [adapter] <Entity>` with `--methods`, `--db-path` (info only), `--dry-run/--force/--verbose`; prints the `sqlite3` dependency reminder.
- [ ] T005 Register `SqlitePlugin` in `lib/src/cli/plugin_loader.dart`.
- [ ] T006 Tests (fast tier): `test/plugins/sqlite/sqlite_datasource_builder_test.dart` (class + implements, schema/WAL/version statements, SQL CRUD statements, query/offset/limit semantics, methods filter, watch stream, entity import path) + `test/commands/sqlite_command_test.dart` (name/description/flags/registration).
- [ ] T007 Changeset, format with the CI (flutter) formatter, `dart analyze`, run suites.
- [ ] T008 Commit, push, PR → merge → pull master → re-verify.

## Non-goals

- SQL-level WHERE translation of the `Filter` tree (reads stay in-memory like the mock datasource).
- Auto-editing the user's pubspec (reminder printed instead).
- Flutter desktop/web wiring (`sqlite3_flutter_libs` note only).
