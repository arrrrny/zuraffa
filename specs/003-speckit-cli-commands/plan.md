# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]
**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

Implement a Speckit extension that exposes all 24+ ZFA CLI commands through the Speckit command interface, organized by category with full flag support and help documentation mirroring the CLI.

## Technical Context

**Language/Version**: YAML (extension definition), Dart/ZFA CLI  
**Primary Dependencies**: ZFA CLI (v4.0.0+), Speckit extension framework  
**Storage**: N/A (no persistent data)  
**Testing**: N/A (integration with external CLI)  
**Target Platform**: Developer tool / CLI extension  
**Project Type**: Speckit extension  
**Performance Goals**: Command execution latency < 500ms (inherited from ZFA CLI)  
**Constraints**: Must pass through all CLI flags accurately, support dry-run mode  
**Scale/Scope**: 24+ commands, organized into 4-5 categories

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Status | Notes |
|------|--------|-------|
| Clean Architecture Separation | ✅ PASS | Extension only wraps CLI, no new layers created |
| Type-Safe Result Handling | ✅ PASS | Wrapper passes through Result types from CLI |
| TDD (tests first) | ⚠️ PARTIAL | Extension tests will be created, CLI behavior tested via integration |
| Zero-Boilerplate CLI Usage | ✅ PASS | This extension IS the CLI wrapper - using zfa for its own generation |

**Constitution Compliance**: All gates pass. This extension wraps the existing ZFA CLI commands and does not create new layers or violate any architectural principles.

## Project Structure

### Documentation (this feature)

```text
specs/003-speckit-cli-commands/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
.specify/extensions/zuraffa/     # Zuraffa Speckit Extension (submodule)
├── extension.yml                # Extension manifest
├── commands/                    # Command definitions
│   ├── init.md                  # Existing init command
│   └── [new command files]       # Additional ZFA commands
├── config/                      # Configuration templates
└── hooks/                       # Extension hooks

zuraffa/                         # Main zuraffa package (provides zfa CLI)
├── lib/src/
│   └── ...                      # ZFA CLI implementation
└── ...
```

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
