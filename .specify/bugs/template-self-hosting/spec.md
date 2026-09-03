# Feature Specification: Template self-hosting defects (issue #912)

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `fix/template-self-hosting`

**Created**: 2026-09-03

**Status**: Approved

**Input**: Bug issue #912 (Part of #908): Generator template self-hosting and defect hardening.
1. Persistence template: behavior description with apostrophe (e.g. `persist the user's theme preference`) breaks single-quoted Dart strings.
2. `zfa tdd migrate-paths`: rewrites relative imports and package-URI imports in test files when moving to namespaced layout.

## User Scenarios & Testing

### User Story 1 - Escape description in persistence tests (Priority: P1)

A behavior description containing apostrophes, quotes, or special characters must be properly escaped in all generated test templates so the generated test is valid Dart code and compiles cleanly.

**Acceptance Scenarios**:

1. **Given** a persistence behavior with description `persist the user's theme preference`, **When** `BehaviorTestWriter` generates the test, **Then** the test contains escaped descriptions and compiles without syntax errors.

### User Story 2 - migrate-paths package-URI rewriting (Priority: P1)

When migrating tests from flat to namespaced layout, `migrate-paths` rewrites both relative subject imports and package-URI imports so tests remain runnable.

**Acceptance Scenarios**:

1. **Given** a moved test with package-URI or relative imports, **When** `migrate-paths` runs, **Then** all imports are rewritten to the new namespaced subject location.
