# Test List: Spec-Kit Boundary Scripts

**Feature**: 1444-spec-kit-boundary-scripts  
**Template**: zuraffa-1.0  
**Generated**: 2026-09-10

This test list traces every testable behavior to its source criterion (acceptance criteria from user stories or functional requirements).

---

## Acceptance Behaviors (Outer Loop)

These behaviors trace to the Given/When/Then scenarios in the user stories.

### User Story 1 - Sync Behaviors to Tasks

**A1**: Sync script inserts all behavior markers in dependency order  
**Criterion**: US1-AC1 - Given test-list.md contains 5 behaviors with IDs A1, A2, U1, U2, U3, When the sync script runs, Then tasks.md contains exactly 5 [behavior: ] markers with those IDs in dependency order  
**Status**: DONE  
**Evidence**: GREEN @ Cycle 5 - A1 acceptance test: markers A1 A2 U1 U2 U3 written in dependency order, exactly 5 markers asserted

**A2**: Sync script preserves existing markers and adds new ones  
**Criterion**: US1-AC2 - Given tasks.md already has 2 [behavior: ] markers and test-list.md adds 3 new behaviors, When the sync script runs, Then the 2 existing markers remain unchanged and 3 new markers are inserted  
**Status**: DONE  
**Evidence**: GREEN @ Cycle 5 - A2 acceptance test: 3 markers added, existing A1/U1 lines byte-identical, second run idempotent (behaviors_added=0)

**A3**: Sync script exits successfully when test-list is empty  
**Criterion**: US1-AC3 - Given test-list.md is empty, When the sync script runs, Then tasks.md is unchanged and the script exits with success  
**Status**: DONE  
**Evidence**: GREEN @ Cycle 5 - A3 acceptance test: empty test-list exits 0 and leaves tasks.md unchanged

### User Story 2 - Read TDD Profile

**A4**: Read script emits JSON with correct engine and command  
**Criterion**: US2-AC1 - Given tdd-profile.md specifies engine type dart_test and test command dart test, When the read script runs with --json, Then output contains {"engine":"dart_test","test_command":"dart test"}  
**Status**: DONE  
**Evidence**: GREEN @ Cycle 5 - A4 acceptance test: engine=dart_test and test_command="dart test" read from YAML frontmatter

**A5**: Read script errors on missing or malformed profile  
**Criterion**: US2-AC2 - Given tdd-profile.md is missing or malformed, When the read script runs, Then it exits with non-zero status and error message to stderr  
**Status**: DONE  
**Evidence**: GREEN @ Cycle 5 - A5 acceptance test: missing and malformed profiles both exit non-zero with a stderr message

### User Story 3 - Read Cycle Evidence

**A6**: Read script emits array of evidence entries with correct structure  
**Criterion**: US3-AC1 - Given cycle-log.md contains 3 evidence entries with phases RED, GREEN, REFACTOR, When the read script runs with --json, Then output contains array of 3 objects each with phase, behavior_id, and evidence fields  
**Status**: DONE  
**Evidence**: GREEN @ Cycle 5 - A6 acceptance test: 3 entries with phases RED,GREEN,REFACTOR, all four fields present, timestamp normalised to ISO 8601

**A7**: Read script returns empty array when cycle-log is empty  
**Criterion**: US3-AC2 - Given cycle-log.md is empty, When the read script runs with --json, Then output is {"evidence":[]}  
**Status**: DONE  
**Evidence**: GREEN @ Cycle 5 - A7 acceptance test: empty cycle-log exits 0 and emits {"evidence":[]}

### User Story 4 - Tick Behavior Task

**A8**: Tick script marks specific behavior task as done  
**Criterion**: US4-AC1 - Given tasks.md contains "- [ ] Implement login [behavior: A1]", When the tick script runs with --behavior A1, Then tasks.md is updated to "- [x] Implement login [behavior: A1]"  
**Status**: DONE  
**Evidence**: GREEN @ Cycle 5 - A8 acceptance test: A1 ticked to [x] while the U1 and U2 lines stay byte-identical

**A9**: Tick script exits successfully when task already ticked  
**Criterion**: US4-AC2 - Given tasks.md contains a behavior task already ticked, When the tick script runs for that behavior, Then the task remains ticked and script exits with success  
**Status**: DONE  
**Evidence**: GREEN @ Cycle 5 - A9 acceptance test: already-ticked task exits 0 and leaves tasks.md unchanged

**A10**: Tick script errors when behavior ID not found  
**Criterion**: US4-AC3 - Given the behavior ID does not exist in tasks.md, When the tick script runs, Then it exits with non-zero status and error message to stderr  
**Status**: DONE  
**Evidence**: GREEN @ Cycle 5 - A10 acceptance test: unknown behavior ID exits non-zero with a stderr message

---

## Unit Behaviors (Inner Loop)

These behaviors trace to the functional requirements section.

**U1**: System provides sync-behaviors-to-tasks.sh script  
**Criterion**: FR-001 - System MUST provide a sync-behaviors-to-tasks.sh script that reads test-list.md and inserts/updates [behavior: <id>] markers in tasks.md  
**Status**: DONE  
**Evidence**: GREEN @ Cycle 5 - U1 unit test: script present and executable

**U2**: System provides read-tdd-profile.sh script  
**Criterion**: FR-002 - System MUST provide a read-tdd-profile.sh script that parses tdd-profile.md and emits JSON with engine type and commands  
**Status**: DONE  
**Evidence**: GREEN @ Cycle 5 - U2 unit test: script present and executable

**U3**: System provides read-cycle-evidence.sh script  
**Criterion**: FR-003 - System MUST provide a read-cycle-evidence.sh script that parses cycle-log.md and emits structured JSON with evidence entries  
**Status**: DONE  
**Evidence**: GREEN @ Cycle 5 - U3 unit test: script present and executable

**U4**: System provides tick-behavior-task.sh script  
**Criterion**: FR-004 - System MUST provide a tick-behavior-task.sh script that marks a specific [behavior: <id>] task as done in tasks.md  
**Status**: DONE  
**Evidence**: GREEN @ Cycle 5 - U4 unit test: script present and executable

**U5**: All scripts use three-tier parser cascade  
**Criterion**: FR-005 - All scripts MUST use the three-tier parser cascade (jq → python3 → grep/sed) as documented in scripts/bash/setup-tasks.sh  
**Status**: DONE  
**Evidence**: GREEN @ Cycle 5 - U5 unit test: python3 plus grep/sed cascade present in all four scripts

**U6**: All scripts emit JSON with --json flag  
**Criterion**: FR-006 - All scripts MUST emit JSON output when invoked with --json flag, text output otherwise  
**Status**: DONE  
**Evidence**: GREEN @ Cycle 5 - U6 unit test: --json flag handled by all four scripts

**U7**: All scripts use jq --arg for safe JSON construction  
**Criterion**: FR-007 - All scripts MUST use jq --arg for safe JSON construction to prevent injection vulnerabilities  
**Status**: DONE  
**Evidence**: GREEN @ Cycle 5 - U7 unit test: jq --arg used for JSON construction in all four scripts

**U8**: All scripts follow set -euo pipefail pattern  
**Criterion**: FR-008 - All scripts MUST follow set -euo pipefail fail-fast pattern to ensure errors are not silently ignored  
**Status**: DONE  
**Evidence**: GREEN @ Cycle 5 - U8 unit test: set -euo pipefail present in all four scripts

**U9**: Scripts located at .specify/scripts/bash/  
**Criterion**: FR-009 - Scripts MUST be located at .specify/scripts/bash/ following the existing convention  
**Status**: DONE  
**Evidence**: GREEN @ Cycle 5 - U9 unit test: all four scripts present under .specify/scripts/bash/

**U10**: Scripts share common helpers via common.sh  
**Criterion**: FR-010 - Scripts MUST share common helpers via scripts/bash/common.sh (or create it if it doesn't exist)  
**Status**: DONE  
**Evidence**: GREEN @ Cycle 5 - U10 unit test: common.sh sourced by all four scripts

---

## Summary

- **Acceptance behaviors**: 10 (A1-A10)
- **Unit behaviors**: 10 (U1-U10)
- **Total behaviors**: 20
- **Status**: All DONE ✓ (20/20 tests passing)

---

## Notes

This test list was derived using the LLM-guided fallback workflow (zfa unavailable).
Each behavior ID references its source criterion for traceability.

The A1-A10 evidence notes were corrected during the review-fix cycle (Cycle 5, see
`tdd/cycle-log.md`): earlier revisions carried cross-wired notes that attributed
several behaviors to a script they do not exercise.

Parser-cascade coverage: besides the static check in `unit_tests.sh` (U5), every
script was run with both `python3` and `yq` removed from `PATH`. All four produced
output identical to the python3 tier, including malformed-entry warnings on stderr
for `read-cycle-evidence.sh` and an inert injection payload for
`tick-behavior-task.sh`, so the cascade is verified behaviourally too.
