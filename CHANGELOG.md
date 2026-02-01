## [1.11.0] - 2026-02-01

### Added
- **Initialize Command**: New `zfa initialize` command to quickly create sample entities
  - `--entity` parameter to specify entity name (default: Product)
  - Creates realistic sample entity with common fields (id, name, description, price, category, isActive, createdAt, updatedAt)
  - Includes complete implementation with copyWith, equals, hashCode, toString, JSON serialization
  - Added to MCP server as `initialize` tool for AI agent integration
  - Updated CLI help and README documentation

- **Singleton Entity Support**: New `--id-field=null` flag for parameterless operations
  - Generates `get()` and `watch()` methods without ID parameters using `NoParams`
  - Perfect for singleton entities like app config, user sessions, global settings
  - Uses fixed `'singleton'` key for Hive storage instead of entity ID
  - Validation prevents usage with list methods (`getList`, `watchList`)

### Changed
- **Optimized Repository Imports**: Repository interfaces now conditionally import zuraffa
  - Only imports `package:zuraffa/zuraffa.dart` when using zuraffa types (ListQueryParams, UpdateParams, DeleteParams)
  - Simple repositories with only `get()` methods have no zuraffa import
  - Keeps repository interfaces clean and minimal

- **Improved Local DataSource Generation**: 
  - No `saveAll()` method generated for singleton entities (`--id-field=null`)
  - Uses `'singleton'` key for Hive operations instead of entity field access

### Fixed
- **Test Generation for Singleton Entities**: Fixed mock repository calls in generated tests
  - Parameterless methods now use `mockRepository.get()` instead of `mockRepository.get(any())`
  - Fixed both success and failure test scenarios for Future and Stream UseCases
  - Eliminates "too many arguments" compilation errors

## [1.10.0] - 2026-02-01

### Added
- **Caching Support**: New dual datasource pattern for intelligent caching
  - `--cache` flag to enable caching with remote and local datasources
  - `--cache-policy` option: `daily`, `restart`, or `ttl` (default: daily)
  - `--cache-storage` option: `hive` for Hive implementation (more coming soon)
  - `CachePolicy` abstraction with `DailyCachePolicy`, `AppRestartCachePolicy`, and `TtlCachePolicy`
  - Automatic cache-aware repository generation with validity checks
  - Complete Hive implementation when `--cache-storage=hive` is specified
  - Local datasource with `save()`, `saveAll()`, `get()`, `getList()` methods
  - Remote datasource for API/external service calls
  - Cache invalidation support via `CachePolicy.invalidate()`

### Changed
- Remote and local datasources are now standalone implementations (no abstract interface)
- Updated to use `hive_ce_flutter` package for Hive support

### Fixed
- Import paths in generated datasources and repositories
- Repository imports now correctly use `../../domain/` paths

## [1.9.0] - 2026-01-31

### Added
- **Test Generation (`--test`)**: New flag to generate unit tests for generated UseCases with comprehensive mock setup and test scenarios.

## [1.8.0] - 2026-01-31

### Added
- **New Failure Types**: Added `StateFailure`, `TypeFailure`, `UnimplementedFailure`, `UnsupportedFailure`, and `PlatformFailure` to `AppFailure` for granular error handling.

### Changed
- **FailureHandler**:
  - Now uses a `switch` statement for improved performance and readability.
  - Correctly maps `PlatformException` (Flutter) to `PlatformFailure`.
  - Maps `MissingPluginException` to `UnsupportedFailure`.
  - Maps `ArgumentError`, `RangeError`, `FormatException` to `ValidationFailure`.
  - Maps `ConcurrentModificationError`, `StateError`, `StackOverflowError` to `StateFailure`.
- **Generated Repositories**: Fixed missing `zuraffa` import in generated repository files.


### Fixed
- **TodoDataSource**: Updated `InMemoryTodoDataSource` to fully implement the interface.

## [1.7.0] - 2026-01-31
### Added
- **Typed Updates (`--morphy`)**: New flag to generate update operations using typed Patch objects (e.g., `CustomerPatch`) instead of Map-based partials.
- **Partial Updates**: Default update mechanism now uses `Partial<T>` (Map<String, dynamic>) with automatic field extraction for validation.
- **Validation**:
  - `UpdateParams.validate()` automatically checks fields against your entity definition.
  - `FailureHandler` now catches `ArgumentError` (common in validation) and converts it to `ValidationFailure`.
- **New Parameter Wrappers**:
  - `ListQueryParams`: Standardized params for list queries (filtering, sorting, pagination).
  - `DeleteParams`: Standardized params for delete operations.
  - `UpdateParams<T>`: Now generic over data type to support both Maps and Patch objects.
- **CLI Global Flags**:
  - `--morphy`: Enable Morphy-style patch objects.
  - `--id-field` & `--id-field-type`: Customize the identifier field name and type (default: 'id', 'String').
  - `--query-field` & `--query-field-type`: Customize the lookup field definition for `get`/`watch` methods.

### Changed
- **Scripts**: Updated `publish.sh` to support "promote unreleased" workflow.

## [1.6.2] - 2026-01-31

### Fix
- Subdirectory path issue on generated data repository

## [1.6.1] - 2026-01-31

### Fix
- Subdirectory path issue on generated presenters

## [1.6.1] - 2026-01-31

### Fix
- Subdirectory path issue on generated presenters

## [1.6.0] - 2026-01-31

### Change
- fixed not overriding onInitState from CleanView, updated state generation to generate entity

## [1.5.0] - 2026-01-30

### Fix
- mcp server connection fix

## [1.4.2] - 2026-01-27

### Change
- Release 1.4.2

## [1.4.1] - 2026-01-26

### Feat
- Added InitializationParams and --init flag to cli

## [1.5.0] - 2026-01-30

### Fix
- mcp server connection fix

## [1.4.2] - 2026-01-27

### Change
- Release 1.4.2

## [1.4.1] - 2026-01-26

### Feat
- Added InitializationParams and --init flag to cli

## [1.4.0] - 2026-01-24

### Feat
- Added --subdirectory flag to zfa cli

## [1.3.3] - 2026-01-24

### Chore
- testing CI

## [1.3.1] - 2026-01-24

### Chore
- CI chores

## [1.3.0] - 2026-01-24

### Chore
- CI chores

## [1.2.0] - 2026-01-24

### Changed
- Exposed Loggable mixin and added to generated DataRepos

## [1.1.0] - 2026-01-24

### Changed
- Updated MCP server method names and documentation.

## [1.0.1] - 2026-01-23

### Chore
- Updated description in pubspec.yaml to better reflect package purpose and fit the required 180 character limit.

## [1.0.0] - 2026-01-23

### Added

#### Core Framework
- **Result Type**: Type-safe error handling with `Result<S, F>` sealed class
- **AppFailure Hierarchy**: Comprehensive sealed class hierarchy for error classification
  - `ServerFailure` - HTTP 5xx errors
  - `NetworkFailure` - Connection issues
  - `ValidationFailure` - Input validation errors
  - `NotFoundFailure` - HTTP 404 / resource not found
  - `UnauthorizedFailure` - HTTP 401 / authentication required
  - `ForbiddenFailure` - HTTP 403 / access denied
  - `TimeoutFailure` - Request timeout
  - `CacheFailure` - Local storage errors
  - `ConflictFailure` - HTTP 409 / version conflicts
  - `CancellationFailure` - Operation cancelled
  - `UnknownFailure` - Catch-all for unclassified errors
- **UseCase**: Single-shot operations returning `Future<Result<T, AppFailure>>`
- **CompletableUseCase**: Operations returning `Result<void, AppFailure>`
- **StreamUseCase**: Reactive operations returning `Stream<Result<T, AppFailure>>`
- **BackgroundUseCase**: CPU-intensive operations on isolates with `BackgroundTask`
- **Controller**: State management with automatic cleanup and lifecycle hooks
- **Presenter**: Optional orchestration layer for complex business flows
- **CleanView & CleanViewState**: Base classes for views with automatic lifecycle management
- **ResponsiveViewState**: Responsive layouts with device-specific builders
- **ControlledWidgetBuilder**: Rebuild widgets when Controller calls `refreshUI()`
- **ControlledWidgetSelector**: Fine-grained rebuilds based on selected values
- **CancelToken**: Cooperative cancellation for long-running operations
- **NoParams**: Sentinel for parameterless UseCases
- **Observer**: Optional callback-based stream listener

#### CLI Tool
- **zfa CLI**: Powerful code generator for Clean Architecture boilerplate
  - Entity-based UseCase generation with `--methods`
  - Custom UseCase generation with `--params` and `--returns`
  - Repository interface generation with `--repository`
  - Presentation layer generation with `--vpc`
  - Data layer generation with `--data`
  - Data source generation with `--datasource`
  - State object generation with `--state`
  - JSON output format with `--format=json`
  - Stdin input support with `--from-stdin`
  - Dry run mode with `--dry-run`
  - Verbose logging with `--verbose`
  - Force overwrite with `--force`
- **zfa validate**: Validate JSON generation configs
- **zfa schema**: Get JSON schema for config validation
- **Dual executable support**: Both `zuraffa` and `zfa` commands available

#### MCP Server
- **zuraffa_mcp_server**: Model Context Protocol server for AI/IDE integration
  - `zuraffa_generate` tool for code generation
  - `zuraffa_schema` tool for schema retrieval
  - `zuraffa_validate` tool for config validation
  - Resource change notifications for generated files
  - Precompiled binary support for faster startup

#### Extensions & Utilities
- **Future Extensions**: Convert futures to `Result` type
- **Test Utilities**: Matchers and test helpers
- **Logging**: Global logging configuration via `Zuraffa.enableLogging()`
- **Controller Access**: `Zuraffa.getController<T>()` for accessing controllers from widget tree

#### Documentation
- Comprehensive README with quick start guide
- CLI Guide with all command options
- MCP Server documentation
- AI Agents guide for AI-assisted development
- Example application demonstrating all features

### Features

- **Type-safe error handling**: All operations return `Result<T, AppFailure>` for exhaustive error handling
- **Sealed class hierarchies**: Pattern matching with compile-time exhaustiveness checks
- **Automatic cleanup**: Controllers automatically cancel operations and subscriptions on dispose
- **Fine-grained rebuilds**: Optimized performance with selective widget updates
- **Cooperative cancellation**: CancelToken for cancelling long-running operations
- **Background processing**: Run CPU-intensive work on isolates without blocking UI
- **Reactive streams**: StreamUseCase for real-time data updates
- **CLI code generation**: Generate boilerplate with a single command
- **AI/IDE integration**: MCP server for seamless AI agent integration
- **Testable**: Pure domain layer with easy mocking and testing

### Dependencies

- `flutter`: ^3.10.0
- `args`: ^2.7.0
- `logging`: ^1.3.0
- `meta`: ^1.12.0
- `path`: ^1.9.0
- `provider`: ^6.1.5+1
- `responsive_builder`: ^0.7.1
- `flutter_lints`: ^6.0.0 (dev)
- `mocktail`: ^1.0.4 (dev)

### Documentation

- Added comprehensive README with examples
- Added CLI Guide with all options
- Added MCP Server documentation
- Added AI Agents guide
- Added contributing guidelines
- Added code of conduct

### Example Application

- Complete Todo app demonstrating all framework features
- UseCase examples (single-shot, stream, background)
- Controller and View examples
- Error handling examples
- Cancellation examples
- State management examples

### Planned Features

- Web support for BackgroundUseCase
- Additional code generation templates
- More validation failure types
- Performance monitoring utilities
- Extended documentation and tutorials

---

## Version Summary

- **1.0.0** - Initial release with complete Clean Architecture framework, CLI tool, and MCP server
