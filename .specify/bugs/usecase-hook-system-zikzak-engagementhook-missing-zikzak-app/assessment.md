# Bug Assessment: UseCase Hook System: ZikZak EngagementHook missing (ZikZak app not in workspace)

- **Slug**: usecase-hook-system-zikzak-engagementhook-missing-zikzak-app
- **Created**: 2026-08-27T14:26:40.253967+00:00
- **Source**: https://github.com/arrrrny/zuraffa/issues/501
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

# Bug Assessment: ZikZak EngagementHook Not Implemented

**Feature**: `011-usecase-hook-system` (User Story 3)
**Bug ID**: `011-usecase-hook-system-zikzak-engagementhook-missing`
**Date**: 2026-08-26
**Severity**: Medium (P2 validation story)
**Status**: Open

---

## Summary

The Zuraffa framework's UseCase Hook System (User Stories 1 & 2) is fully implemented and tested. However, **User Story 3 — ZikZak EngagementHook Validation** cannot be completed because the ZikZak application codebase is not available in the current workspace.

The spec requires:
1. Creating `EngagementHook` in `zik_zak/lib/src/presentation/hooks/engagement_hook.dart`
2. Mapping 8 UseCase names to `EngagementEventType` enum values
3. Registering the hook in ZikZak's `main()`
4. Removing 8 manual tracking calls from 5 controllers
5. Verifying zero manual tracking calls remain

---

## Expected vs Actual

### Expected (from spec.md)

**User Story 3 Acceptance Scenarios** (all 5 PENDING):
1. **C1**: Barcode scan → `EngagementEvent(type=BARCODE_SCAN, payload=barcode_number)` stored in Hive
2. **C2**: Search query → `EngagementEvent(type=SEARCH_TERM, payload=query_string)` stored
3. **C3**: Tracked UseCase fails → NO engagement event created (hook fires on success only)
4. **C4**: `TelemetryHook` + `EngagementHook` coexist without interference
5. **C5**: Zero `CreateTelemetryEventUseCase` or `trackXxx()` calls in any controller

**Success Criteria**:
- SC-004: ZikZak's engagement tracking fully automated via single `EngagementHook` registration
- SC-005: All 8 engagement event types tracked correctly
- SC-006: Multi-hook coexistence without interference

### Actual

- ZikZak app directory (`zik_zak/` or `apps/zikzak_demo`) does not exist in workspace
- No `EngagementHook` implementation exists
- No integration tests for EngagementHook exist
- Cannot verify grep for manual tracking calls

---

## Root Cause

The ZikZak application is a **separate codebase** (likely at `~/Developer/zik_zak` or similar) that was not cloned into the current workspace. The tasks.md assumed it would be available at `zik_zak/` relative to the Zuraffa root.

The Zuraffa framework itself is **not at fault** — the hook system (US1 + US2) is complete and working. This is an environmental/dependency issue, not a code bug.

---

## Impact Assessment

| Impact Area | Level | Notes |
|-------------|-------|-------|
| Zuraffa Framework | **None** | Hook system fully functional |
| Spec Compliance | **Partial** | US1 & US2 ✅, US3 ❌ |
| Success Criteria | **3/7 met** | SC-001, SC-002, SC-003, SC-007 ✅; SC-004, SC-005, SC-006 ❌ |
| CI/CD | **None** | No tests added for missing functionality |
| Other Features | **None** | Isolated to US3 validation |

---

## Reproduction Steps

1. Clone Zuraffa repo
2. Run `dart test test/core/hook_registry_test.dart test/core/telemetry_hook_test.dart test/domain/usecase_hook_test.dart test/domain/stream_usecase_hook_test.dart` — all pass
3. Look for `zik_zak/` directory — not found
4. Attempt to implement `EngagementHook` — no target codebase

---

## Suggested Fix

### Option A: Add ZikZak as Submodule/Dependency (Recommended)
```bash
# In Zuraffa root
git submodule add https://github.com/arrrrny/zik_zak.git apps/zikzak_demo
# Or clone separately and symlink
```

### Option B: Mock ZikZak for Testing
Create a minimal ZikZak-like test app in `apps/zikzak_demo` that:
- Has `EngagementEventRepository` (Hive-based)
- Has 8 UseCases matching the engagement event types
- Has controllers that currently call `CreateTelemetryEventUseCase`
- Allows verifying the hook system end-to-end

### Option C: Defer US3
Mark US3 as "requires external dependency" and complete when ZikZak is available. The framework is production-ready without US3.

---

## Files to Create (When ZikZak Available)

```
apps/zikzak_demo/
├── lib/
│   ├── src/
│   │   ├── presentation/
│   │   │   └── hooks/
│   │   │       └── engagement_hook.dart      # NEW: EngagementHook implementation
│   │   ├── pages/
│   │   │   ├── barcode_listing/
│   │   │   │   └── barcode_listing_controller.dart  # MODIFIED: Remove tracking calls
│   │   │   ├── ask_zikzak/
│   │   │   │   └── ask_zikzak_controller.dart       # MODIFIED: Remove tracking calls
│   │   │   ├── url_listing/
│   │   │   │   └── url_listing_controller.dart      # MODIFIED: Remove tracking calls
│   │   │   └── deal/
│   │   │       └── deal_controller.dart             # MODIFIED: Remove tracking calls
│   │   └── widgets/
│   │       └── share/
│   │           └── share_button.dart                # MODIFIED: Remove tracking calls
│   └── main.dart                                     # MODIFIED: Register EngagementHook
└── test/
    └── presentation/
        └── hooks/
            └── engagement_hook_test.dart    # NEW: Integration tests for C1-C4
```

---

## Verification Plan (When Fixed)

1. Run `dart test apps/zikzak_demo/test/presentation/hooks/engagement_hook_test.dart`
2. Run `grep -r "CreateTelemetryEventUseCase\|track" apps/zikzak_demo/lib/src/presentation/` → should return 0 matches
3. Run ZikZak app, trigger barcode scan → verify Hive stores `EngagementEvent(BARCODE_SCAN)`
4. Run with both `TelemetryHook` and `EngagementHook` → verify both fire

---

## Related Issues

- **Blocking**: None (Zuraffa framework complete)
- **Depends on**: ZikZak app availability
- **Related**: Spec `011-usecase-hook-system` User Story 3

---

## Assessment Metadata

- **Assessed by**: TDD Verification (automated)
- **Profile**: `tdd-profile.md` (Dart stack)
- **Baseline commit**: `614e648`
- **Test evidence**: 46/46 framework tests passing
- **Gap location**: `specs/011-usecase-hook-system/tdd/verification.md` (Gap 1)

See https://github.com/arrrrny/zuraffa/issues/501.

## Symptom

[NEEDS CLARIFICATION]

## Reproduction

[NEEDS CLARIFICATION]

## Suspected Code Paths

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to locate the code, or fill in manually.]

## Root Cause Hypothesis

[NEEDS CLARIFICATION — not yet analyzed.]

## Proposed Remediation

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to propose a fix, or apply a fix directly with /skill:speckit-bug-fix.]

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.

## Open Questions

- [NEEDS CLARIFICATION: confirm the exact code path and a safe remediation.]
