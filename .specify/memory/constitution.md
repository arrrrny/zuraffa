<!--
Sync Impact Report:
Version change: [NEW] → 1.0.0
Added sections:
- I. AI-First Architecture
- II. Clean Architecture by Design
- III. Type-Safe Result Handling (NON-NEGOTIABLE)
- IV. Test-Driven Development (NON-NEGOTIABLE)
- V. Zero-Boilerplate CLI Usage
- Technical Standards
- AI Agent Development Workflow
Templates requiring updates:
- ✅ .specify/templates/plan-template.md (verified alignment)
- ✅ .specify/templates/spec-template.md (verified scope alignment)
- ✅ .specify/templates/tasks-template.md (verified task categorization)
Follow-up TODOs: None
-->

# Zuraffa Constitution

## Core Principles

### I. AI-First Architecture
AI agents MUST use the Zuraffa CLI exclusively for ALL code generation except UI widgets. 
The Zuraffa framework is a COMPLETE Clean Architecture builder designed specifically for AI agents 
via MCP server. Manual code creation violates this principle - agents MUST leverage the CLI's 
comprehensive generation capabilities. Every feature, entity, usecase, repository, datasource, 
presenter, controller, state, and test MUST be generated through `zfa` commands.

**Rationale**: Zuraffa is purpose-built for AI agents to generate bulletproof, architecturally 
compliant code. Manual coding undermines consistency, type safety, and architectural integrity.

### II. Clean Architecture by Design
MUST enforce strict layer separation: Domain (entities, usecases, repository interfaces) → 
Data (repository implementations, datasources, models) → Presentation (views, presenters, 
controllers, state). Dependencies flow inward only. No layer may depend on outer layers.
Cross-cutting concerns (DI, logging, caching) are handled through framework patterns.

**Rationale**: Prevents coupling, ensures testability, maintains scalability, and enables 
clean separation of business logic from implementation details.

### III. Type-Safe Result Handling (NON-NEGOTIABLE)
ALL operations that can fail MUST return `Result<T, AppFailure>` types. No exceptions thrown 
for business logic failures. Error handling is explicit and exhaustive pattern matching is 
enforced. Success and failure paths are clearly defined at compile time.

**Rationale**: Eliminates runtime crashes, makes error handling visible in type signatures, 
and ensures all failure cases are handled explicitly.

### IV. Test-Driven Development (NON-NEGOTIABLE)
TDD is mandatory: Tests written → User approved → Tests fail → Implementation generated via CLI.
Red-Green-Refactor cycle strictly enforced. All generated code MUST include comprehensive 
unit tests. Integration tests required for inter-layer communication and external dependencies.

**Rationale**: Ensures code quality, prevents regressions, validates architectural boundaries, 
and provides living documentation of expected behavior.

### V. Zero-Boilerplate CLI Usage
AI agents MUST use CLI commands for ALL code generation: `zfa feature scaffold` for complete 
features, `zfa make` for granular components, `zfa entity create` for Zorphy entities. 
Manual file creation or build_runner usage violates this principle. The CLI ensures 
architectural compliance and generates all necessary boilerplate.

**Rationale**: Maintains consistency, prevents architectural violations, reduces errors, 
and leverages the framework's full capabilities for type-safe code generation.

## Technical Standards

### Code Quality Requirements
- All generated code MUST pass static analysis without warnings
- Null safety MUST be enforced throughout the codebase
- Immutable entities via Zorphy annotations are mandatory
- Dependency injection through GetIt is required for all services
- GraphQL integration through generated queries/mutations when specified

### Testing Standards
- Unit test coverage MUST be >95% for generated business logic
- Integration tests required for repository-datasource contracts
- Mock data generation through CLI for rapid prototyping
- Test doubles MUST be generated via `zfa mock create` commands

### Performance Standards
- Caching strategies MUST be implemented through CLI-generated cache layers
- Offline-first patterns required for data persistence
- State management through generated state classes with loading flags
- Memory management through proper disposal patterns in generated code

## AI Agent Development Workflow

### Phase 1: Architecture Planning
1. Define entities using `zfa entity create` with Zorphy annotations
2. Plan feature boundaries and identify required CRUD operations
3. Determine caching and sync requirements
4. Validate architectural decisions against Clean Architecture principles

### Phase 2: Code Generation
1. Generate complete features: `zfa feature scaffold [Entity] --methods --mock --vpcs --state --test`
2. Generate granular components: `zfa make [Component] [type] --domain --params --returns`
3. Generate DI registrations: `zfa di create` for automatic dependency wiring
4. Generate GraphQL operations: `zfa graphql` for API schema introspection

### Phase 3: Testing & Validation
1. Run generated tests to ensure Red phase of TDD
2. Implement business logic in generated UseCase classes
3. Verify Green phase through test execution
4. Run `zfa doctor` for architectural compliance validation

## Governance

This constitution supersedes all other development practices. AI agents MUST verify compliance 
with these principles before any code generation. Complexity that violates Clean Architecture 
MUST be justified with explicit rationale. All generated code MUST follow the established 
patterns and maintain architectural integrity.

**Amendment Process**: Constitution changes require major version bump with migration plan. 
All existing generated code must remain compatible unless breaking changes are explicitly 
documented and migration paths provided.

**Compliance Review**: Every feature generation MUST validate against these principles. 
Use `zfa doctor` for automated architectural compliance checking. Manual code review 
focuses on business logic correctness, not architectural compliance (handled by CLI).

**Version**: 1.0.0 | **Ratified**: 2026-04-03 | **Last Amended**: 2026-04-03