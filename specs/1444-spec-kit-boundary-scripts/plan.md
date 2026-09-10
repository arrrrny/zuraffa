# Implementation Plan: Spec-Kit Boundary Scripts

**Branch**: `1444-spec-kit-boundary-scripts` | **Date**: 2026-09-10 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/1444-spec-kit-boundary-scripts/spec.md`

## Summary

This feature creates deterministic bash scripts for spec-kit ↔ zuraffa boundary operations, replacing fragile LLM-based file operations with reliable three-tier parser cascade (jq → python3 → grep/sed) scripts. Four core scripts handle: syncing behaviors to tasks, reading TDD profiles, reading cycle evidence, and ticking behavior tasks. These scripts eliminate non-determinism in the TDD workflow, ensure atomic file operations, and follow the reference implementation pattern from `scripts/bash/setup-tasks.sh`.

## Technical Context

**Language/Version**: Bash 3.2+ (macOS default), jq 1.6+, Python 3.x

**Primary Dependencies**: jq (JSON processor), python3 (fallback parser), standard POSIX utilities (grep, sed, awk)

**Storage**: Markdown files in `.specify/specs/*/tdd/` (test-list.md, tdd-profile.md, cycle-log.md, tasks.md)

**Testing**: Dart test for integration validation, manual bash script testing with sample inputs

**Target Platform**: macOS/Linux shell environments (spec-kit runtime)

**Project Type**: Bash scripting library for spec-kit TDD extension

**Performance Goals**: <100ms per script execution for typical file sizes (<1000 lines)

**Constraints**: Must work without jq/python3 (fallback to grep/sed), atomic file writes (temp + mv), POSIX-compatible where possible

**Scale/Scope**: 4 scripts, ~200-300 lines each, targeting 10-20 behaviors per feature, files <1000 lines

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

**Constitution Status**: This project does not have a populated constitution file (`.specify/memory/constitution.md` contains only a template). No constitution gates apply.

**Verification**: The spec-kit project is infrastructure/tooling focused. The bash scripts follow the existing pattern in `scripts/bash/setup-tasks.sh` and maintain consistency with the established spec-kit architecture.

**Complexity Assessment**: No complexity violations detected. Scripts are self-contained utilities following established patterns.

## Project Structure

### Documentation (this feature)

```text
specs/1444-spec-kit-boundary-scripts/
├── plan.md              # This file
├── research.md          # Phase 0: bash best practices, parser cascades, atomic operations
├── data-model.md        # Phase 1: entity definitions (BehaviorMarker, TDDProfile, etc.)
├── quickstart.md        # Phase 1: quick start guide for script usage
├── contracts/           # Phase 1: script interface contracts
│   ├── sync-behaviors-to-tasks.md
│   ├── read-tdd-profile.md
│   ├── read-cycle-evidence.md
│   └── tick-behavior-task.md
└── tasks.md             # Phase 2: NOT created by this plan
```

### Source Code (repository root)

```text
.specify/
├── scripts/
│   └── bash/
│       ├── common.sh                      # Existing shared helpers
│       ├── sync-behaviors-to-tasks.sh     # NEW: P1 - Sync behaviors to tasks
│       ├── read-tdd-profile.sh            # NEW: P1 - Read TDD profile
│       ├── read-cycle-evidence.sh         # NEW: P2 - Read cycle evidence
│       ├── tick-behavior-task.sh          # NEW: P2 - Tick behavior task
│       └── setup-tasks.sh                 # REFERENCE: existing three-tier parser example

test/
└── integration/
    └── bash_scripts_test.dart             # NEW: Integration tests for all scripts
```

**Structure Decision**: Scripts live in `.specify/scripts/bash/` following the existing spec-kit convention. All scripts share `common.sh` for utility functions. Integration tests in `test/integration/` validate script behavior end-to-end using Dart's process spawning capabilities.

## Complexity Tracking

> **No violations detected** - Constitution file is not populated, no complexity gates apply.

---

## Phase 0: Research

**Objective**: Generate `research.md` covering bash scripting best practices, three-tier parser cascades, and atomic file operations.

**Research Topics**:

1. Bash scripting best practices (`set -euo pipefail`, error handling, argument parsing)
2. Three-tier parser cascade pattern (jq → python3 → grep/sed) from `setup-tasks.sh`
3. Atomic file operations (write to temp, mv to final location)
4. JSON construction with `jq --arg` to prevent injection
5. Markdown parsing strategies (behavior markers, YAML frontmatter, evidence blocks)
6. Safe file modification patterns (preserving content during partial updates)

**Deliverable**: `specs/1444-spec-kit-boundary-scripts/research.md`

## Phase 1: Design Artifacts

**Objective**: Generate data model, contracts, and quickstart documentation.

### 1.1 Data Model (`data-model.md`)

Define the core entities manipulated by the scripts:

- **BehaviorMarker**: Represents `[behavior: <id>]` markers in tasks.md
  - Fields: `id`, `status` (pending/done), `line_number`, `task_text`
- **TDDProfile**: Parsed TDD stack configuration from tdd-profile.md
  - Fields: `engine`, `test_command`, `verify_command`, `plan_command`
- **EvidenceEntry**: One red-green-refactor evidence record from cycle-log.md
  - Fields: `phase` (RED/GREEN/REFACTOR), `behavior_id`, `timestamp`, `evidence_text`
- **TaskEntry**: One task line from tasks.md
  - Fields: `checkbox`, `text`, `behavior_id`, `line_number`

### 1.2 Script Contracts (`contracts/*.md`)

Four contract documents, one per script:

1. **`contracts/sync-behaviors-to-tasks.md`**
   - Purpose: Insert/update `[behavior: <id>]` markers in tasks.md based on test-list.md
   - Inputs: `test-list.md` path, `tasks.md` path
   - Outputs: Updated `tasks.md` (atomic write), exit status
   - Error handling: Malformed test-list.md, missing files, duplicate behavior IDs

2. **`contracts/read-tdd-profile.md`**
   - Purpose: Parse tdd-profile.md and emit JSON with engine/commands
   - Inputs: `tdd-profile.md` path, `--json` flag
   - Outputs: JSON object or text format, exit status
   - Error handling: Missing profile, malformed YAML, multiple engine declarations

3. **`contracts/read-cycle-evidence.md`**
   - Purpose: Extract evidence entries from cycle-log.md as JSON array
   - Inputs: `cycle-log.md` path, `--json` flag
   - Outputs: JSON array of evidence objects, exit status
   - Error handling: Empty log, malformed evidence blocks

4. **`contracts/tick-behavior-task.md`**
   - Purpose: Mark a specific behavior task as done in tasks.md
   - Inputs: `tasks.md` path, `--behavior <id>`
   - Outputs: Updated `tasks.md` (atomic write), exit status
   - Error handling: Behavior not found, task already ticked, malformed markers

### 1.3 Quickstart Guide (`quickstart.md`)

Usage examples for each script:

```bash
# Sync behaviors to tasks
.specify/scripts/bash/sync-behaviors-to-tasks.sh \
  specs/042-feature/tdd/test-list.md \
  specs/042-feature/tasks.md

# Read TDD profile as JSON
.specify/scripts/bash/read-tdd-profile.sh \
  .specify/memory/tdd-profile.md \
  --json

# Read cycle evidence
.specify/scripts/bash/read-cycle-evidence.sh \
  specs/042-feature/tdd/cycle-log.md \
  --json

# Tick a behavior task
.specify/scripts/bash/tick-behavior-task.sh \
  specs/042-feature/tasks.md \
  --behavior A1
```

**Deliverables**:

- `specs/1444-spec-kit-boundary-scripts/data-model.md`
- `specs/1444-spec-kit-boundary-scripts/contracts/sync-behaviors-to-tasks.md`
- `specs/1444-spec-kit-boundary-scripts/contracts/read-tdd-profile.md`
- `specs/1444-spec-kit-boundary-scripts/contracts/read-cycle-evidence.md`
- `specs/1444-spec-kit-boundary-scripts/contracts/tick-behavior-task.md`
- `specs/1444-spec-kit-boundary-scripts/quickstart.md`

---

## Success Metrics

- **SM-001**: All four scripts pass acceptance tests from spec.md (18 total acceptance scenarios)
- **SM-002**: Scripts execute in <100ms for typical file sizes (measured via `time` command)
- **SM-003**: Three-tier parser cascade degrades gracefully (jq fails → python3 → grep/sed)
- **SM-004**: JSON output from all scripts is valid (pipe through `jq .` succeeds)
- **SM-005**: Atomic writes prevent data loss on script interruption (manual SIGINT test)
- **SM-006**: Integration tests in `test/integration/bash_scripts_test.dart` achieve 100% pass rate

## Next Steps

1. **Phase 0**: Generate `research.md` (bash best practices, parser cascades, atomic operations)
2. **Phase 1**: Generate `data-model.md`, `contracts/*.md`, and `quickstart.md`
3. **Phase 2**: Run `/speckit-tasks` to generate actionable task breakdown
4. **Phase 3**: Run `/speckit-implement` to build the scripts and tests
