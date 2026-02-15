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
