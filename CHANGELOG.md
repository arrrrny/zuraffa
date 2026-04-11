## [4.0.0] - 2026-04-11

### Breaking Change
- `CleanViewState` now requires three type parameters: `CleanViewState<Page, Controller, State>`. 
- Existing views must be updated to include the state type (or `void` if no state is used).
- Updated `zfa` CLI to generate views with the mandatory third type parameter.

## [3.22.0] - 2026-04-08

### Feat
- Replaced custom AWS Signature V4 implementation in `MinioClient` with the official `minio: ^3.5.8` package, improving compatibility and reliability
- Expanded `MinioClient` with full API: `fPutObject`, `fGetObject`, `copyObject`, `statObject`, `listObjects`, `deleteObjects`, `removeBucket`, `getBucketRegion`, `presignedPutObject`
- Added `ObjectStat` and `ObjectInfo` data classes for structured object metadata
- Integrated `minio/io.dart` extensions for file-based uploads and downloads

### Fix
- Replaced `print()` calls in `OtelLogExporter` with `Logger` to allow silencing in tests and avoid recursive OTel logging
- Fixed `artifact_publisher_integration_test.dart` to skip cleanly when MinIO env vars are not set
- Created `dart_test.yaml` for Dart test configuration with integration test exclusion
- Disabled automatic bucket creation in `MinIOArtifactHook` and `MinIOUploadHook` (changed `ensureBucketExists` default from `true` to `false`)

### Chore
- Removed temp test files with hardcoded credentials from the repository

## [3.21.1] - 2026-04-06

### Fix
- Hardened AST deduplication logic in `ExtensionMethodAppendStrategy` and `FieldAppendStrategy` to match primarily on identifiers, preventing duplicate member errors when signatures differ
- Improved AST modification robustness by ensuring replacement logic is prioritized over appending for matching names

## [3.21.0] - 2026-04-06

### Feat
- Implemented `toggle` method generation across all layers (Domain, Data, Presentation) to streamline boolean field updates in Clean Architecture
- Added `ToggleParams` to core parameters for type-safe field toggling

### Change
- Major refactoring: Replaced Dart augmentations (`.augment.dart` files) with direct AST-based source modification for all append operations
- Implemented "Bulletproof AST" system using structural equality checks (name, signature, return type) instead of fragile string matching
- Upgraded `AstModifier` to automatically format all generated code via `DartFormatter`
- Enhanced `InjectBuilder` to use recursive AST visitors for robust DI registration and constructor merging

### Fix
- Resolved "already declared" compilation errors when appending duplicate methods or constructors
- Fixed `StatePlugin` to correctly include stateful flags like `isToggling` when generating VPC sets

## [3.20.2] - 2026-04-05

### Fix
- Fixed invalid Dart syntax in generated cache files by explicitly using `///` for documentation comments
- Fixed `zfa make` command crashing when parsing `integer` or `number` CLI flags (e.g., `--ttl`)
- Fixed test plugin generating ghost tests when the target UseCase file does not exist
- Prevented duplicate route entries in `index.dart` by safely deduplicating canonical paths before writing imports/exports
- Migrated all build and release scripts to `dart build cli` to support Native Assets (fixing the "dart compile does not support build hooks" error)
- Resolved multiple "already declared" compilation errors in the CLI builders caused by code duplication

### Change
- Re-exported `go_router`, `get_it`, and `hive_ce_flutter` from `zuraffa.dart` to minimize required direct dependencies in projects
- Upgraded `zorphy` and `zorphy_annotation` dependencies to `^1.6.6`

## [3.20.1] - 2026-04-02

### Fix
- Added transitive import resolution for extends/implements clauses in entity generation
- Clear list state to empty before loading in generated controllers

## [3.20.0] - 2026-04-01

### Feat
- Implemented Open Telemetry integration with persistent failure report queue for better observability
- Added Dart 3.0 Records support for VPC pattern with watchRecord methods
- Added register capability to DI plugin for dynamic dependency registration
- Added `--use-service` flag to zfa feature and zfa make commands for service-based generation
- Enabled adding view/presenter to existing usecases with correct state management via zfa make

### Change
- Refactored CLI to unify orchestration and implement active discovery pattern in all generator plugins
- Upgraded analyzer dependency from version 11 to 12 for better code analysis
- Standardized presenter pattern to directly inject data and set from view/controller
- Renamed debugmode for consistency
- Extended mock command with additional bug fixes
- Updated website documentation

### Fix
- Fixed usecase registration via zfa feature command
- Fixed routes generation and implemented detail view
- Fixed entity command issues
- Fixed datasource plugin stability
- Fixed default timeout configuration
- Stabilized revert method and config defaults
- Fixed pull request finding logic (multiple iterations)
- Fixed 173+ analysis errors in generated code
- Resolved stability issues across multiple components

### Chore
- Added gitignore entries for Junie IDE
- Formatted codebase

## [3.19.0] - 2026-03-13

### Change
- Implemented "Smart Revert" for append operations: `--revert` now removes specific methods/imports instead of deleting the entire file if other content remains.
- Enhanced `LocalDataSourceBuilder` to support non-Zorphy entities using `Partial<T>` and `applyPartial` pattern.
- Improved `MockPlugin` to skip mock generation in presentation-only workflows when data layers are missing.
- Updated `RouteBuilder` to automatically generate and maintain `routing/index.dart` for all entity routes.
- Standardized relative import paths in UseCases and Services to use project-consistent depth (e.g., `../../entities/` for UseCases).
- Refactored Mock Provider naming convention to `EntityMockProvider` and unified DI registration filenames.

### Fix
- Fixed `zfa feature` command to correctly generate entity-based CRUD UseCases when the `usecase` plugin is active.
- Fixed missing imports for return types and mock data when appending to existing Mock Providers or DataSources.
- Fixed DI generation to prevent accidental deletion of existing mock DI registrations.
- Fixed `UseCasePlugin` to correctly handle revert operations even when implicit generation flags are off.
- Resolved multiple regressions in integration and regression test suites, restoring 100% pass rate (386 tests).

## [3.18.0] - 2026-03-10

### Change
- Refactored all plugins to use unified `GeneratorOptions` pattern (removed deprecated `dryRun`, `force`, `verbose` parameters)
- Updated `CodeGenerator` to accept `GeneratorOptions` for consistent configuration
- Migrated test files to use new `GeneratorOptions` API

### Fix
- Fixed generate configs for orchestrate usecases
- Fixed `zfa make` command with orchestrate usecases
- Fixed mock provider builder
- Fixed dependency injection configuration
- Fixed provider implementation

## [3.17.0] - 2026-02-17

### Change
- Standardized all CLI commands to use `capability.execute()` pattern
- Updated MCP server `zuraffa_generate` tool with `remote` and `local` flags
- Refactored `CodeGenerator` to execute independent plugin generations in parallel

### Fix
- Fixed hardcoded `dryRun: false` in all capabilities
- Corrected `CreateDataSourceCapability` input schema (added `remote`, removed duplicate `cache`)
- Resolved timeout in `full_entity_workflow_test.dart` by parallelizing plugin execution

## [3.16.0] - 2026-02-17

### Fix
- Resolved conflict between `--domain` and entity-based generation in `zfa generate`
- Fixed `NoParams.toString()` format
- Added `// TODO` comments to generated usecase templates
- Added dead code check to `zfa doctor`

## [3.15.0] - 2026-02-15

### Change
- ZFA CLI binaries are published for faster mcp tool calls

## [3.14.0] - 2026-02-15

### Change
- Added build command, better error message if zuraffa is not installed

## [3.13.0] - 2026-02-15

### Change
- Added zuraffa_build to mcp server tools

## [3.12.0] - 2026-02-15

### Change
- Improved timeout on doctor command,added zuraff_ prefix to mcp commands

## [3.11.0] - 2026-02-15

### Chore
- Downgraded analyzer version to match flutter_test meta 1.17

## [3.10.0] - 2026-02-15

### Fix
- Added _asStringList helper to handle String or List<String>
- Fixed field, subtypes, and values parsing
- All tests passing
- MCP server entity_create and entity_enum working correctly

## [3.0.9] - 2026-02-15

### Change
- Updated zorphy dependency to 1.6.0
- Entity command now uses zorphy library directly (no subprocess)

## [3.0.8] - 2026-02-15

### Change
- Integrated zorphy entity generation directly into zuraffa (no subprocess)
- Entity command now works without zorphy installed
- Published zorphy 1.6.0 with clean SOLID architecture

## [3.0.7] - 2026-02-15

### Change
- Refactor CLI to clean plugin-based architecture with Command<void>

### Change
- Refactored CLI to use clean plugin-based architecture with `Command<void>` from args package
- Removed legacy `GenerateCommand` monolith, now uses `PluginOrchestrator`
- Added all missing CLI flags: `--data`, `--debug`, `--from-json`, `--vpcs`, `--pc`, `--pcs`, and more
- Fixed disabled plugin support from `.zfa.json` configuration
- Improved error messages with suggestions for `--id-field-type` validation

## [3.0.6] - 2026-02-15

### Change
- Embed zfa CLI directly in MCP server - no external activation required
- Fix suggestions for id-field-type errors

## [3.0.5] - 2026-02-15

### Change
- Updated Zed extension with prebuilt MCP binaries

## [3.0.4] - 2026-02-15

### Change
- Fix MCP server to properly locate zuraffa installation

## [3.0.3] - 2026-02-14

### Change
- Add Zed extension support with prebuilt MCP binaries

## [3.0.3] - 2026-02-14

### Feat
- ZED extension is added

## [3.0.2] - 2026-02-14

### Fix
- Removed warnings from generated code

## [3.0.1] - 2026-02-14

### Feat
- Added zfa doctor feature, detect dead code, updated zorphy dependency

## [3.0.0] - 2026-02-13

### Change
- Major refactoring: Clean Architecture with plugin-based CLI
- Plugin orchestrator for composable code generation
- MCP server for AI/IDE integration
- Zorphy entity support

## [2.0.0] - 2025-12-01

### Change
- Initial Clean Architecture implementation
- UseCase pattern with Result type
- VPC (View-Presenter-Controller) layer generation

## [1.0.0] - 2025-06-01

### Feat
- Initial release with basic code generation
