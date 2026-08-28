# Feature Specification: Migrate ZikZak pub.dev Packages to Zuraffa

**Feature Branch**: `032-migrate-pubdev-packages`

**Created**: 2026-08-28

**Status**: Draft

**Input**: GitHub issue #214 (https://github.com/arrrrny/zuraffa/issues/214)

## Overview

Migrate all ZikZak packages currently published on pub.dev (https://pub.dev/publishers/zuzu.dev/packages) so their codebase is completely rewritten on top of Zuraffa v6. This migration also establishes a private package repository for PRO subscribers and showcases Zuraffa's capabilities through a public-facing ecommerce application.

## User Scenarios & Testing

### User Story 1 - Migrate Existing ZikZak Packages to Zuraffa (Priority: P1)

As a ZikZak package consumer, I want all published packages to be rebuilt on Zuraffa v6 so that I can use a modern, well-architected toolkit with consistent APIs, shared infrastructure, and long-term maintainability.

**Why this priority**: The current packages may be inconsistently maintained, use outdated patterns, or lack a unified foundation. Migrating them to Zuraffa v6 is the foundational step that all other goals depend on. Without it, there is no foundation for the private repository, no showcase, and no way to fork orphaned packages.

**Independent Test**: Can be validated by verifying that each migrated package compiles, passes its test suite, publishes successfully to pub.dev under the zuzu.dev publisher, and that existing consumers can upgrade without breaking changes. Each package can be migrated and validated independently.

**Acceptance Scenarios**:

1. **Given** the list of all ZikZak packages on pub.dev, **When** the migration plan is produced, **Then** every package is accounted for with a migration status (migrate, fork, deprecate) and priority order.
2. **Given** a package has been migrated to Zuraffa v6, **When** a developer runs the package's tests, **Then** all existing tests pass and the package is API-compatible with its published version.
3. **Given** a migrated package is published to pub.dev, **When** an existing consumer upgrades their dependency, **Then** the upgrade is non-breaking or provides a clear migration path documented in a CHANGELOG.
4. **Given** the migration plan covers all packages, **When** the plan is reviewed, **Then** each package's dependencies on other ZikZak packages are mapped and migration order resolves circular dependencies.

---

### User Story 2 - Launch Private Unpub Repository for PRO Subscribers (Priority: P2)

As a PRO subscriber, I want access to a private package repository hosted at zikzak.zuzu.dev so that I can use high-value proprietary packages (e.g., network interceptor) that are not available on public pub.dev.

**Why this priority**: The private repository is the monetization mechanism for the PRO subscription. It depends on the migration being complete (packages must be on Zuraffa first), but it is the primary value proposition that differentiates the PRO tier.

**Independent Test**: Can be validated by verifying that an authenticated PRO subscriber can add the private repository as a Dart package source, resolve dependencies from it, and download packages. Non-subscribers must be rejected.

**Acceptance Scenarios**:

1. **Given** a PRO subscriber has valid credentials, **When** they configure zikzak.zuzu.dev as a package source, **Then** they can resolve and download all PRO-only packages.
2. **Given** a non-subscriber or expired subscription, **When** they attempt to resolve packages from the private repository, **Then** authentication fails with a clear error message indicating subscription requirement.
3. **Given** a new PRO-only package is published, **When** a PRO subscriber runs `dart pub get`, **Then** the package is resolved and downloaded successfully.
4. **Given** the private repository is live, **When** the repository serves package metadata, **Then** response times are comparable to public pub.dev (sub-second for resolution).

---

### User Story 3 - Fork Orphaned/Unmaintained Packages into Zuraffa Ecosystem (Priority: P2)

As a ZikZak ecosystem developer, I want unmaintained or orphaned third-party packages that ZikZak depends on to be forked and maintained within the Zuraffa ecosystem so that the dependency supply chain remains secure and actively supported.

**Why this priority**: This ensures long-term dependency health. It is secondary to the core migration but critical before the private repository launch, since PRO packages may depend on these forks.

**Independent Test**: Can be validated by verifying that each forked package compiles, passes tests, and is published under the zuzu.dev publisher with its own version history.

**Acceptance Scenarios**:

1. **Given** the dependency audit identifies orphaned packages, **When** the fork plan is produced, **Then** each orphaned package has a clear fork strategy (fork and maintain, replace with Zuraffa native, or drop).
2. **Given** a package has been forked, **When** the fork is published to pub.dev, **Then** it is API-compatible with the original and available under the zuzu.dev publisher.
3. **Given** existing consumers depend on the original orphaned package, **When** they upgrade to the forked version, **Then** the upgrade path is documented and non-breaking.

---

### User Story 4 - Launch Zuraffa Showcase App on macOS, iOS, and Android (Priority: P3)

As a prospective Zuraffa adopter, I want to see a fully functional ecommerce application (similar to Magento) running on macOS, iOS, and Android so that I can evaluate Zuraffa's capabilities as an app builder platform before committing to building on it.

**Why this priority**: The showcase app demonstrates the end-to-end value of Zuraffa and the migrated packages working together. It is a marketing and evaluation asset, not a dependency for the package migration itself.

**Independent Test**: Can be validated by building and running the showcase app on each target platform, verifying that core ecommerce flows (browse, search, cart, checkout) work end-to-end.

**Acceptance Scenarios**:

1. **Given** the showcase app is built, **When** it runs on macOS, **Then** a user can browse products, add items to cart, and complete checkout.
2. **Given** the showcase app is built, **When** it runs on iOS or Android, **Then** the same core ecommerce flows work with native-feeling UX.
3. **Given** the showcase app uses migrated packages, **When** its dependencies are listed, **Then** it exclusively uses packages built on Zuraffa v6.
4. **Given** the showcase app is live, **When** a developer inspects its source, **Then** it serves as a reference implementation demonstrating how to build on Zuraffa with open-source and private resources.

---

### Edge Cases

- What happens when a ZikZak package has a dependency on another ZikZak package that is itself being migrated? The migration must resolve inter-package dependency ordering to avoid circular build failures.
- What happens when a migrated package introduces a breaking change that existing consumers depend on? The package versioning must follow semantic versioning, and a major version bump with migration guide is required.
- What happens when a package to be forked has licensing restrictions that prevent forking? A legal review step must precede any fork action.
- What happens when the private repository becomes unavailable? PRO subscribers must receive an SLA-backed availability guarantee and graceful degradation (cached resolution).
- What happens when a consumer has pinned a specific version of a ZikZak package on the old architecture? The CHANGELOG and migration guide must provide a clear upgrade path, and old versions remain published for backward compatibility.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST produce a complete inventory of all ZikZak packages published on pub.dev under the zuzu.dev publisher, including package name, current version, dependencies, and maintenance status.
- **FR-002**: The system MUST classify each package into one of three categories: migrate (rewrite on Zuraffa v6), fork (take over an orphaned dependency), or deprecate (sunset with clear consumer guidance).
- **FR-003**: The system MUST define a migration execution order that resolves inter-package dependencies, ensuring no package is migrated before its dependencies are ready.
- **FR-004**: Each migrated package MUST maintain API compatibility with its published version, or provide a documented semver-major breaking change path with migration guide.
- **FR-005**: The system MUST establish a private package repository at zikzak.zuzu.dev that requires PRO subscriber authentication for access.
- **FR-006**: The system MUST provide a mechanism for PRO subscribers to authenticate and resolve packages from the private repository using standard Dart/Flutter package tooling.
- **FR-007**: The system MUST produce a showcase ecommerce application that demonstrates all migrated packages working together, buildable for macOS, iOS, and Android.
- **FR-008**: The system MUST provide a migration playbook that documents the process, decisions, and lessons learned so that future package migrations (from other ecosystems) can follow the same pattern.

### Key Entities

- **ZikZak Package**: A Dart/Flutter package currently published on pub.dev under the zuzu.dev publisher. Key attributes: package name, current version, dependencies, migration status, target category (migrate/fork/deprecate).
- **Private Repository**: The zikzak.zuzu.dev Unpub instance serving PRO-only packages. Key attributes: repository URL, authentication mechanism, package inventory, subscriber access tier.
- **Showcase Application**: A full-featured ecommerce app built on Zuraffa v6 using migrated packages. Key attributes: target platforms (macOS, iOS, Android), feature set, dependency manifest.
- **Migration Plan**: A document specifying the order, strategy, and status of each package migration. Key attributes: package list, execution phases, dependency graph, completion status.

## Success Criteria

### Measurable Outcomes

- **SC-001**: 100% of active ZikZak packages on pub.dev have been migrated to Zuraffa v6 or explicitly deprecated with consumer guidance, within the planned timeline.
- **SC-002**: All migrated packages pass their full test suites and publish successfully to pub.dev under the zuzu.dev publisher with zero regressions in API surface area (or documented breaking changes at major version bumps).
- **SC-003**: The private repository at zikzak.zuzu.dev is operational and PRO subscribers can authenticate, resolve, and download packages within 2 seconds of resolution time.
- **SC-004**: The showcase ecommerce application builds and runs on all three target platforms (macOS, iOS, Android) with core ecommerce flows (browse, search, cart, checkout) fully functional.

## Assumptions

- All ZikZak packages currently on pub.dev are public knowledge and their source code is accessible to the migration team.
- Zuraffa v6 is stable enough to serve as the foundation for rewriting all packages without requiring simultaneous changes to Zuraffa core.
- The zikzak.zuzu.dev Unpub infrastructure can be provisioned and configured independently of the package migration work.
- Existing consumers of ZikZak packages will accept a semver-major version bump if the API surface changes during migration.
- The migration team has sufficient bandwidth to migrate all packages in a phased approach, starting with foundational packages and working outward.
- Legal review of licensing for packages to be forked will be completed before any fork action is taken.
- The PRO subscription tier and pricing model are defined separately from this feature and will be ready before the private repository launch.
