# Feature Specification: Spec-Kit Boundary Scripts

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `1444-spec-kit-boundary-scripts`

**Created**: 2026-09-10

**Status**: Draft

**Input**: User description: "Create .sh scripts for spec-kit ↔ zfa boundary operations"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Sync Behaviors to Tasks (Priority: P1)

The TDD extension needs to insert and update `[behavior: <id>]` markers in `tasks.md` based on the behaviors defined in `test-list.md`. Currently the LLM performs this synchronization by reading both files and rewriting tasks.md, which is fragile and non-deterministic.

**Why this priority**: This is the most critical boundary operation - synchronizing test behaviors into the task list is fundamental to the TDD workflow and happens on every `tdd.plan` invocation. Inconsistent writes break the entire feature delivery pipeline.

**Independent Test**: Can be fully tested by creating a sample `test-list.md` with 3 behaviors, running the sync script, and verifying that `tasks.md` contains exactly those 3 `[behavior: ]` markers in the correct positions, and delivers immediate value by eliminating LLM-based file rewrites.

**Acceptance Scenarios**:

1. **Given** `test-list.md` contains 5 behaviors with IDs `A1`, `A2`, `U1`, `U2`, `U3`, **When** the sync script runs, **Then** `tasks.md` contains exactly 5 `[behavior: ]` markers with those IDs in dependency order
   **Type**: acceptance

2. **Given** `tasks.md` already has 2 `[behavior: ]` markers and `test-list.md` adds 3 new behaviors, **When** the sync script runs, **Then** the 2 existing markers remain unchanged and 3 new markers are inserted
   **Type**: acceptance

3. **Given** `test-list.md` is empty, **When** the sync script runs, **Then** `tasks.md` is unchanged and the script exits with success
   **Type**: acceptance

---

### User Story 2 - Read TDD Profile (Priority: P1)

The TDD extension needs to read the test stack configuration from `tdd-profile.md` to determine which test engine (Dart test, Flutter test, etc.) and commands to use. Currently the LLM parses this markdown file, which introduces parsing fragility.

**Why this priority**: The TDD profile is consulted on every `tdd.plan`, `tdd.run`, and `tdd.verify` invocation. A deterministic parser ensures the test commands are always correctly extracted.

**Independent Test**: Can be fully tested by creating a sample `tdd-profile.md` with known engine type and commands, running the read script with `--json`, and verifying the JSON output matches expected structure with correct engine and command values.

**Acceptance Scenarios**:

1. **Given** `tdd-profile.md` specifies engine type `dart_test` and test command `dart test`, **When** the read script runs with `--json`, **Then** output contains `{"engine":"dart_test","test_command":"dart test"}`
   **Type**: acceptance

2. **Given** `tdd-profile.md` is missing or malformed, **When** the read script runs, **Then** it exits with non-zero status and error message to stderr
   **Type**: acceptance

---

### User Story 3 - Read Cycle Evidence (Priority: P2)

The TDD extension needs to extract red-green-refactor evidence from `cycle-log.md` to report what was proven during the loop. Currently the LLM parses this log file to extract evidence entries.

**Why this priority**: Evidence extraction is needed for reporting and verification, but it's not blocking - the loop can continue without perfect evidence parsing. Making it deterministic improves reliability but is less critical than sync and profile operations.

**Independent Test**: Can be fully tested by creating a sample `cycle-log.md` with 3 evidence entries (red, green, refactor), running the read script with `--json`, and verifying the JSON output contains exactly 3 structured evidence objects with correct phases and timestamps.

**Acceptance Scenarios**:

1. **Given** `cycle-log.md` contains 3 evidence entries with phases `RED`, `GREEN`, `REFACTOR`, **When** the read script runs with `--json`, **Then** output contains array of 3 objects each with `phase`, `behavior_id`, and `evidence` fields
   **Type**: acceptance

2. **Given** `cycle-log.md` is empty, **When** the read script runs with `--json`, **Then** output is `{"evidence":[]}`
   **Type**: acceptance

---

### User Story 4 - Tick Behavior Task (Priority: P2)

The TDD extension needs to mark specific `[behavior: <id>]` tasks as done in `tasks.md` when the red-green-refactor cycle completes for that behavior. Currently the LLM finds and ticks the task marker.

**Why this priority**: Task ticking is important for progress tracking but is not blocking - if a tick is missed, the user can manually check it or the next sync will catch it. Making it deterministic improves reliability but is less critical than the sync operation itself.

**Independent Test**: Can be fully tested by creating a `tasks.md` with 3 behavior tasks (2 incomplete, 1 complete), running the tick script for one incomplete behavior ID, and verifying that exactly that task is marked done while others remain unchanged.

**Acceptance Scenarios**:

1. **Given** `tasks.md` contains `- [ ] Implement login [behavior: A1]`, **When** the tick script runs with `--behavior A1`, **Then** `tasks.md` is updated to `- [x] Implement login [behavior: A1]`
   **Type**: acceptance

2. **Given** `tasks.md` contains a behavior task already ticked, **When** the tick script runs for that behavior, **Then** the task remains ticked and script exits with success
   **Type**: acceptance

3. **Given** the behavior ID does not exist in `tasks.md`, **When** the tick script runs, **Then** it exits with non-zero status and error message to stderr
   **Type**: acceptance

---

### Edge Cases

- What happens when `test-list.md` contains duplicate behavior IDs? (sync script should deduplicate or error)
- What happens when `tdd-profile.md` contains multiple engine declarations? (read script should take the first or error)
- What happens when `cycle-log.md` contains malformed evidence entries? (read script should skip malformed entries and report valid ones)
- What happens when `tasks.md` contains behavior markers without IDs? (sync/tick scripts should ignore malformed markers)
- What happens when concurrent processes modify the same file? (scripts should use atomic writes or advisory locks)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a `sync-behaviors-to-tasks.sh` script that reads `test-list.md` and inserts/updates `[behavior: <id>]` markers in `tasks.md`
- **FR-002**: System MUST provide a `read-tdd-profile.sh` script that parses `tdd-profile.md` and emits JSON with engine type and commands
- **FR-003**: System MUST provide a `read-cycle-evidence.sh` script that parses `cycle-log.md` and emits structured JSON with evidence entries
- **FR-004**: System MUST provide a `tick-behavior-task.sh` script that marks a specific `[behavior: <id>]` task as done in `tasks.md`
- **FR-005**: All scripts MUST use the three-tier parser cascade (jq → python3 → grep/sed) as documented in `scripts/bash/setup-tasks.sh`
- **FR-006**: All scripts MUST emit JSON output when invoked with `--json` flag, text output otherwise
- **FR-007**: All scripts MUST use `jq --arg` for safe JSON construction to prevent injection vulnerabilities
- **FR-008**: All scripts MUST follow `set -euo pipefail` fail-fast pattern to ensure errors are not silently ignored
- **FR-009**: Scripts MUST be located at `.specify/scripts/bash/` following the existing convention
- **FR-010**: Scripts MUST share common helpers via `scripts/bash/common.sh` (or create it if it doesn't exist)

## Layer Contracts

**Function**:
- `sync_behaviors_to_tasks`: `sync_behaviors_to_tasks(test_list_path, tasks_path) -> Result`
- `read_tdd_profile`: `read_tdd_profile(profile_path, format) -> ProfileData`
- `read_cycle_evidence`: `read_cycle_evidence(log_path, format) -> EvidenceList`
- `tick_behavior_task`: `tick_behavior_task(tasks_path, behavior_id) -> Result`

### Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| BehaviorMarker | `id: String`, `status: String` (pending/done), `line_number: int` | Represents a behavior task marker in tasks.md |
| TDDProfile | `engine: String`, `test_command: String`, `verify_command: String` | Parsed TDD stack configuration |
| EvidenceEntry | `phase: String`, `behavior_id: String`, `timestamp: String`, `evidence: String` | One red/green/refactor evidence record |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The TDD extension can synchronize behaviors to tasks without any LLM file operations - measurable by running `tdd.plan` and verifying tasks.md is updated via script execution logs only
- **SC-002**: All four scripts execute successfully on the reference implementation `scripts/bash/setup-tasks.sh` test cases - measurable by running a test suite that covers happy path and error cases for each script
- **SC-003**: Scripts handle malformed input gracefully without data loss - measurable by running each script against 5 malformed input files and verifying non-zero exit status with error messages to stderr, and original files unchanged
- **SC-004**: JSON output from all scripts is valid and parseable by downstream consumers - measurable by piping `--json` output through `jq .` and verifying zero exit status for 10 representative test cases per script

## Assumptions

- The existing `scripts/bash/setup-tasks.sh` pattern is the correct reference implementation and contains the three-tier parser cascade we should follow
- `jq` and `python3` are already available in the Spec Kit runtime environment (they are required dependencies)
- The spec-kit skills (`speckit-tdd-plan`, `speckit-tdd-run`, `speckit-tdd-verify`) will be updated separately to call these scripts instead of doing LLM-based file operations
- Scripts will be invoked synchronously (no concurrent access to the same file) in the initial implementation - concurrent access handling can be added later if needed
- The markdown file formats (`test-list.md`, `tdd-profile.md`, `cycle-log.md`, `tasks.md`) follow the documented Spec Kit conventions and will not change without migration support
