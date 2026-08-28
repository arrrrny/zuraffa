# Bug Triage Handoff

**Slug**: usecase-hook-engagementhook-missing-501  
**Assessment path**: `.specify/bugs/usecase-hook-engagementhook-missing-501/assessment.md`  
**Verdict**: likely valid, needs reproduction  
**Severity**: medium

## Top Suspected Code Paths

- `lib/src/core/hook.dart:145` — Hook abstract base class definition
- `lib/src/core/hook_registry.dart:28` — HookRegistry singleton
- `specs/011-usecase-hook-system/spec.md:49` — User Story 3 acceptance scenarios
- Missing ZikZak app directory (`zik_zak/` or `apps/zikzak_demo`)

## Summary

The issue reports that User Story 3 of the UseCase Hook System spec cannot be validated because the ZikZak application codebase is not present in the workspace. The spec requires creating an `EngagementHook` in `zik_zak/lib/src/presentation/hooks/engagement_hook.dart`, mapping 8 UseCase names to `EngagementEventType` enum values, registering the hook in ZikZak's `main()`, removing manual tracking calls from controllers, and verifying zero manual tracking calls remain.

**Root cause**: ZikZak application not in workspace, blocking EngagementHook implementation. The Zuraffa framework hook system (US1 & US2) is complete and tested (46/46 tests passing). This is an environmental/dependency issue, not a code bug.

## Next Steps

1. Add ZikZak as submodule or create mock app for testing
2. Implement EngagementHook per spec
3. Verify zero manual tracking calls remain in controllers
4. Run integration tests for multi-hook coexistence