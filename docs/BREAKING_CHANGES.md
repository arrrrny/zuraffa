# Breaking Changes in Zuraffa v2

This document summarizes breaking changes introduced in the v2 series. Use it alongside the migration guide.

## UseCase API

- UseCase call sites now return Result<T, AppFailure> instead of raw values.
- CancelToken is supported across UseCase types for cooperative cancellation.
- Update and delete operations use parameter wrappers:
  - UpdateParams<ID, Data>
  - DeleteParams<ID>
  - ListQueryParams<T>

## Entity Generation

- Entity generation is standardized around Zorphy.
- Entities are expected under:
  - lib/src/domain/entities/{entity_snake}/{entity_snake}.dart
- Patch types are preferred for updates when Zorphy is enabled.

## Code Generation Architecture

- Generation is plugin-based to isolate concerns and enable easier extension.
- code_builder is the default generation mechanism for consistency and safe refactors.
- Append mode uses AST parsing rather than string concatenation.

## Transactions and Dry Runs

- Generation operations can run inside a transaction for dry runs and conflict checks.
- File writes are coordinated through the transaction system.

## CLI and Output Paths

- CLI defaults to output in lib/src unless overridden with --output.
- Subdirectory generation now respects the current working directory when using relative output paths.

## Action Required

- Regenerate code with v2 CLI using --force.
- Update all UseCase call sites to handle Result.
- Ensure entities and imports follow the new folder conventions.

## Related

- [MIGRATION_GUIDE.md](file:///Users/arrrrny/Developer/zuraffa/docs/MIGRATION_GUIDE.md)
