# Bug Issue: ZikZak EngagementHook missing (ZikZak app not in workspace)

- **Slug**: usecase-hook-engagementhook-missing
- **Fetched**: 2026-08-28T19:30:00Z
- **Issue**: 501
- **URL**: https://github.com/arrrrny/zuraffa/issues/501
- **State**: open
- **Severity**: unknown (no severity label)
- **Author**: arrrrny
- **Labels**: bug

## Body

The Zuraffa framework's UseCase Hook System (User Stories 1 & 2) is fully implemented and tested. However, **User Story 3 — ZikZak EngagementHook Validation** cannot be completed because the ZikZak application codebase is not available in the current workspace.

The spec requires:
1. Creating `EngagementHook` in `zik_zak/lib/src/presentation/hooks/engagement_hook.dart`
2. Mapping 8 UseCase names to `EngagementEventType` enum values
3. Registering the hook in ZikZak's `main()`
4. Removing 8 manual tracking calls from 5 controllers
5. Verifying zero manual tracking calls remain

### Expected vs Actual

**Expected (from spec.md)**
- C1: Barcode scan → `EngagementEvent(type=BARCODE_SCAN, payload=barcode_number)` stored in Hive
- C2: Search query → `EngagementEvent(type=SEARCH_TERM, payload=query_string)` stored
- C3: Tracked UseCase fails → NO engagement event created (hook fires on success only)
- C4: `TelemetryHook` + `EngagementHook` coexist without interference
- C5: Zero `CreateTelemetryEventUseCase` or `trackXxx()` calls in any controller

**Actual**
- ZikZak app directory (`zik_zak/` or `apps/zikzak_demo`) does not exist in workspace
- No `EngagementHook` implementation exists
- No integration tests for EngagementHook exist
- Cannot verify grep for manual tracking calls

### Root Cause
The ZikZak application is a **separate codebase** (likely at `~/Developer/zik_zak` or similar) that was not cloned into the current workspace. The tasks.md assumed it would be available at `zik_zak/` relative to the Zuraffa root.

The Zuraffa framework itself is **not at fault** — the hook system (US1 + US2) is complete and working. This is an environmental/dependency issue, not a code bug.

### Impact
- Zuraffa Framework: **None** (hook system fully functional)
- Spec Compliance: **Partial** (US1 & US2 ✅, US3 ❌)
- Success Criteria: **3/7 met** (SC-001, SC-002, SC-003, SC-007 ✅; SC-004, SC-005, SC-006 ❌)
- CI/CD: **None** (no tests added for missing functionality)
- Other Features: **None** (isolated to US3 validation)

### Reproduction Steps
1. Clone Zuraffa repo
2. Run `dart test test/core/hook_registry_test.dart test/core/telemetry_hook_test.dart test/domain/usecase_hook_test.dart test/domain/stream_usecase_hook_test.dart` — all pass
3. Look for `zik_zak/` directory — not found
4. Attempt to implement `EngagementHook` — no target codebase

### Suggested Fix
Option A: Add ZikZak as Submodule/Dependency (Recommended)
Option B: Mock ZikZak for Testing
Option C: Defer US3

### Files to Create (When ZikZak Available)
```
apps/zikzak_demo/
├── lib/
│   ├── src/
│   │   ├── presentation/
│   │   │   └── hooks/
│   │   │       └── engagement_hook.dart
│   │   ├── pages/
│   │   │   ├── barcode_listing/
│   │   │   │   └── barcode_listing_controller.dart
│   │   │   ├── ask_zikzak/
│   │   │   │   └── ask_zikzak_controller.dart
│   │   │   ├── url_listing/
│   │   │   │   └── url_listing_controller.dart
│   │   │   └── deal/
│   │   │       └── deal_controller.dart
│   │   └── widgets/
│   │       └── share/
│   │           └── share_button.dart
│   └── main.dart
└── test/
    └── presentation/
        └── hooks/
            └── engagement_hook_test.dart
```

### Verification Plan (When Fixed)
1. Run `dart test apps/zikzak_demo/test/presentation/hooks/engagement_hook_test.dart`
2. Run `grep -r "CreateTelemetryEventUseCase\|track" apps/zikzak_demo/lib/src/presentation/` → should return 0 matches
3. Run ZikZak app, trigger barcode scan → verify Hive stores `EngagementEvent(BARCODE_SCAN)`
4. Run with both `TelemetryHook` and `EngagementHook` → verify both fire

### Related Issues
- Blocking: None (Zuraffa framework complete)
- Depends on: ZikZak app availability
- Related: Spec `011-usecase-hook-system` User Story 3

### Assessment Metadata
- Assessed by: TDD Verification (automated)
- Profile: `tdd-profile.md` (Dart stack)
- Baseline commit: `614e648`
- Test evidence: 46/46 framework tests passing
- Gap location: `specs/011-usecase-hook-system/tdd/verification.md` (Gap 1)

## Comments

None.