# Changelog

All notable changes to the Zuraffa project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.5] - 2025-11-14

### Improved
- **Better error handling for Flutter SDK issues**: Zuraffa now detects when build_runner fails due to Flutter SDK corruption (e.g., `'Offset' isn't a type`, `Method not found: 'clampDouble'`) and provides clear instructions to fix the SDK rather than showing confusing error messages.

## [Unreleased]

### Phase 1 - Core Package Setup
- [ ] Project structure
- [ ] JSON parser (primitives only)
- [ ] Morphy entity generator
- [ ] Build runner integration

### Phase 2 - TDD Engine
- [ ] AI test generator
- [ ] Red-Green-Refactor workflow
- [ ] Test file generation

### Phase 3 - DataSource + Repository
- [ ] DataSource interface generator
- [ ] Remote/Local/Mock DataSource generators
- [ ] Repository generator with cache-first logic

### Phase 4 - UseCase Generation
- [ ] UseCase base classes
- [ ] UseCase generator
- [ ] Exception handling

### Phase 5 - Dependency Injection
- [ ] ZuraffaDI service locator
- [ ] DI setup generator
- [ ] Test DI setup

### Phase 6 - CLI Implementation
- [ ] Command structure
- [ ] Configuration loading
- [ ] AI integration (Anthropic Claude)
- [ ] Interactive mode

### Phase 7 - Flutter Integration
- [ ] Example Flutter app
- [ ] State management with Result<T>
- [ ] End-to-end flow

### Phase 8 - Polish & Documentation
- [ ] Error handling
- [ ] Logging
- [ ] Documentation
- [ ] Examples

### Phase 9 - Testing & Validation
- [ ] Unit tests (100% coverage)
- [ ] Integration tests
- [ ] Real-world test (ZikZak)

### Phase 10 - Publishing
- [ ] Package preparation
- [ ] Pub.dev publishing
- [ ] GitHub release
- [ ] Documentation site

## [0.1.0] - 2025-11-14

### Added
- Initial project setup
- README with project vision
- TODO with comprehensive checklist
- Basic package structure

[Unreleased]: https://github.com/arrrrny/zuraffa/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/arrrrny/zuraffa/releases/tag/v0.1.0
