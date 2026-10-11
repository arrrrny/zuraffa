# zuraffa Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-08-05

## Active Technologies

- Dart 3.11+ (pure Dart) / Flutter 3.41+ / Zuraffa framework, Zorphy entity generation, GetIt DI, GoRouter navigation, Hive local storage for mock data persistence (001-hotel-booking-system)
- **Two-package architecture**: `zuraffa` (pure Dart core) + `zuraffa_flutter` (Flutter UI layer). Pure Dart apps depend on zuraffa only.

## Code Search

- **PREFER semantic search** (`mcp__claude-context__search_code`) over `grep`, `find`, or other shell-based searches for all code discovery tasks. Semantic search is faster and more accurate for understanding code relationships, finding implementations, and exploring the codebase.
- **Use `search_code`**: When looking for implementations, understanding how features work, finding related code, or exploring the codebase.
- **Use `grep`/`find` only**: When you need exact string matches, file name patterns, or the semantic search index is unavailable/broken.

## Commands

# Add commands for Dart 3.11+ / Flutter 3.41+

## Code Style

Dart 3.11+ / Flutter 3.41+: Follow standard conventions

## Recent Changes

- 014-pure-dart-core-split: Split zuraffa into pure-Dart core (no Flutter SDK dependency) + zuraffa_flutter UI package with ZuraffaFlutterPlugin. CLI, MCP server, and code generators remain pure Dart. See specs/014-pure-dart-core-split/spec.md.

- 013-plugin-usecase-abstraction: Added DI override support (`override: true` on ZuraffaDIContainer), UseCase interceptor pipeline (InterceptorRegistry, InterceptableUseCase), UseCase contract codegen (UseCaseContractFactory), and `zfa plugin add` CLI action.

<!-- MANUAL ADDITIONS START -->

<!-- MANUAL ADDITIONS END -->
