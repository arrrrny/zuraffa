# TDD Test List for Feature 005-speckit-extension-enhancements

## Overview
- **Feature**: Speckit Extension Enhancement - Init, Generate, and Manifest
- **Spec**: `/Users/ahmettok/Developer/zuraffa/specs/005-speckit-extension-enhancements/spec.md`
- **Plan**: `/Users/ahmettok/Developer/zuraffa/specs/005-speckit-extension-enhancements/plan.md` (not yet created - outer-only mode)
- **Git Commit**: 614e648
- **Mode**: outer-only (acceptance behaviors only)

---

## Acceptance Behaviors (from spec.md)

### User Story 1: One-Click Project Setup (P1)

| ID | Behavior | Description | Status | Test File / Name |
|----|----------|-------------|--------|------------------|
| A1 | Fresh Flutter project init | Given a fresh Flutter project, when agent runs `speckit.zuraffa.init`, then pubspec.yaml is updated with all required dependencies, overrides, and build.yaml is created | PENDING | test/commands/initialize_dart_inplace_test.dart (existing) |
| A2 | Idempotent init on partial setup | Given an existing project with partial setup, when the init command runs, then missing pieces are added without duplicating existing entries | PENDING | test/commands/initialize_dart_inplace_test.dart (existing) |
| A3 | init adds zuraffa, zorphy_annotation to deps | FR-001: `speckit.zuraffa.init` MUST add `zuraffa`, `zorphy_annotation` to dependencies and `build_runner` to dev_dependencies | PENDING | test/commands/initialize_dart_inplace_test.dart (existing) |
| A4 | init adds dependency overrides | FR-002: `speckit.zuraffa.init` MUST add `meta`, `analyzer`, `dart_style` dependency overrides for Flutter SDK compatibility | PENDING | test/commands/initialize_dart_inplace_test.dart (existing) |
| A5 | init creates build.yaml | FR-003: `speckit.zuraffa.init` MUST create `build.yaml` with zorphy and json_serializable builder configuration | PENDING | test/commands/initialize_dart_inplace_test.dart (existing) |
| A6 | init is idempotent | FR-004: `speckit.zuraffa.init` MUST be idempotent - running twice should not duplicate entries | PENDING | test/commands/initialize_dart_inplace_test.dart (existing) |

### User Story 2: Auto-Regenerate Commands from Manifest (P1)

| ID | Behavior | Description | Status | Test File / Name |
|----|----------|-------------|--------|------------------|
| A7 | generate-commands parses zfa manifest | FR-005: `speckit.zuraffa.generate-commands` MUST parse `zfa manifest` JSON output | PENDING | N/A (no test exists) |
| A8 | generate-commands creates .md files per plugin | FR-006: `speckit.zuraffa.generate-commands` MUST create one .md file per plugin command with frontmatter, usage, flags table, and examples | PENDING | N/A (no test exists) |
| A9 | generate-commands organizes by category | FR-007: `speckit.zuraffa.generate-commands` MUST organize files into category subdirectories (data, domain, presentation, scaffolding, testing, utilities) | PENDING | N/A (no test exists) |
| A10 | generate-commands supports --dry-run | FR-010: All commands MUST support `--dry-run` to preview changes without writing files | PENDING | N/A (no test exists) |
| A11 | generate-commands creates registry | FR-006: `speckit.zuraffa.generate-commands` MUST create `command_registry.json` with machine-readable mapping | PENDING | N/A (no test exists) |

### User Story 3: Extension Manifest with Aliases (P2)

| ID | Behavior | Description | Status | Test File / Name |
|----|----------|-------------|--------|------------------|
| A12 | extension.yml lists all commands | FR-008: `extension.yml` MUST list all commands with name, file path, description, category, and aliases | PENDING | test/utils/manifest_writer_test.dart (different purpose) |
| A13 | extension.yml enables IDE integration | SC-003: `extension.yml` contains all commands with valid file paths and unique aliases | PENDING | N/A (no test exists) |
| A14 | Extension lives at correct path | FR-009: The extension MUST live at `.specify/extensions/zuraffa/` with commands in `commands/` subdirectory | PENDING | N/A (no test exists) |
| A15 | Generated files follow consistent format | SC-005: All generated command files follow the same format with consistent frontmatter structure | PENDING | N/A (no test exists) |

---

## Existing Tests Analysis

### Existing: test/commands/initialize_dart_inplace_test.dart
- Tests: InitializeCommand parser flags (--dart, --flutter)
- Tests: --dart --deps-only --dry-run on repo without pubspec
- Tests: --dart --dry-run without --deps-only previews entity scaffolding
- Tests: --dart non-dry-run on repo without pubspec creates minimal pubspec
- Tests: synthesizeMinimalPubspec derives snake_case package names
- **Coverage**: A1, A2, A3, A4, A5, A6 (partially)

### Missing Tests (PENDING - require new test files):
- A7, A8, A9, A10, A11 - generate-commands functionality (NO IMPLEMENTATION YET)
- A12, A13, A14, A15 - extension.yml and structure validation

---

## Unit Behaviors (if plan.md existed - NOT APPLICABLE IN OUTER-ONLY MODE)
_Note: No plan.md exists, so we only track acceptance behaviors in outer-only mode._

---

## Baseline Entry
- **Date**: 2026-08-26
- **Commit**: 614e648
- **Suite**: dart test test (fast unit suite)
- **Result**: Baseline RED (1 failing test in mcp_sse_server_test.dart - pre-existing timeout)
- **Test Count**: 1552 passed, 1 failed (timeout)