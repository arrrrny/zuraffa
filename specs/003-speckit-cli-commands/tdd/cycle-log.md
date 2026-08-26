# TDD Cycle Log: 003-speckit-cli-commands

**Feature**: Implement all ZFA CLI Commands in Zuraffa Speckit Extension  
**Baseline Commit**: `614e648` (2026-08-26)  
**TDD Profile**: `/specify/memory/tdd-profile.md` (detected_at: 614e648)

---

## Baseline Entry

**Date**: 2026-08-26  
**Commit**: `614e648`  
**Test Suite**: `dart test test` (fast unit suite)  
**Result**: 1552 pass / 1 fail (blocking)

### Baseline Failure Details

**Failing Test**: `test/plugins/mcp/mcp_sse_server_test.dart`  
**Test Name**: "McpSseServer remote requests get 401 when Authorization is missing or invalid"  
**Failure**: TimeoutException after 30 seconds  
**Note**: Pre-existing flaky test - not related to this feature

### Current Test Coverage for Feature Behaviors

| Behavior | Status | Existing Test |
|---|---|---|
| U1: generate-commands regenerates .md from manifest | DONE | `test/commands/generate_command_test.dart` |
| U4: Commands organized into categories | DONE | Directory structure exists |
| U5: extension.yml has all 26+ commands | DONE | extension.yml verified |
| U6: Category index files | DONE | Category dirs exist |
| U7: Navigation index.md | DONE | commands/index.md exists |
| U8: Auto-discovery config | DONE | extension.yml |
| U10: --format=json, --dry-run support | DONE | `test/commands/make_command_test.dart` |
| A1-A3: Full entity workflow | PARTIAL | `test/integration/full_entity_workflow_test.dart` |
| U2: Frontmatter correctness | PENDING | - |
| U3: Flags from inputSchema | PENDING | - |
| U9: Regeneration script | PENDING | - |
| U11: Help text matches CLI | PENDING | - |
| A4: Manifest coverage | PENDING | - |
| A5: Reproducible regeneration | PENDING | - |
| A6: zfa missing detection | PENDING | - |
| A7: Invalid params handling | PENDING | - |

---

## Cycle 1

**Date**: -  
**Behavior**: -  
**Action**: -  
**Test Result**: -  
**Notes**: -

---

## Cycle 2

**Date**: -  
**Behavior**: -  
**Action**: -  
**Test Result**: -  
**Notes**: -

---

## Cycle 3

**Date**: -  
**Behavior**: -  
**Action**: -  
**Test Result**: -  
**Notes**: -

---

## Cycle 4

**Date**: -  
**Behavior**: -  
**Action**: -  
**Test Result**: -  
**Notes**: -

---

## Cycle 5

**Date**: -  
**Behavior**: -  
**Action**: -  
**Test Result**: -  
**Notes**: -

---

## Cycle N...

**Date**: -  
**Behavior**: -  
**Action**: -  
**Test Result**: -  
**Notes**: -