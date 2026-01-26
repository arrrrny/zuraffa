## [Unreleased]

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
