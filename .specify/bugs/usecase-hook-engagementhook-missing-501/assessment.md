# Bug Assessment: ZikZak EngagementHook missing (ZikZak app not in workspace)

- **Slug**: usecase-hook-engagementhook-missing-501
- **Created**: 2026-08-28
- **Source**: https://github.com/arrrrny/zuraffa/issues/501
- **Verdict**: likely valid, needs reproduction
- **Severity**: medium

## Report (verbatim or summarized)

The issue reports that User Story 3 of the UseCase Hook System spec cannot be validated because the ZikZak application codebase is not present in the workspace. The spec requires creating an `EngagementHook` in `zik_zak/lib/src/presentation/hooks/engagement_hook.dart`, mapping 8 UseCase names to `EngagementEventType` enum values, registering the hook in ZikZak's `main()`, removing manual tracking calls from controllers, and verifying zero manual tracking calls remain. The ZikZak app directory (`zik_zak/` or `apps/zikzak_demo`) does not exist, so the implementation cannot be done. The Zuraffa framework's hook system (US1 & US2) is complete and tested.

**URL Trust Policy**: GitHub host is allowlisted; fetched without prompting.

## Symptom

ZikZak application directory missing from workspace, preventing EngagementHook implementation and validation.

## Reproduction

1. Clone Zuraffa repo
2. Run `dart test test/core/hook_registry_test.dart test/core/telemetry_hook_test.dart test/domain/usecase_hook_test.dart test/domain/stream_usecase_hook_test.dart` — all pass
3. Look for `zik_zak/` directory — not found
4. Attempt to implement `EngagementHook` — no target codebase

## Suspected Code Paths

- `lib/src/core/hook.dart` — Hook abstract base class and HookContext definition (lines 145-180)
- `lib/src/core/hook_registry.dart` — HookRegistry singleton (lines 28-109)
- `lib/src/core/telemetry_hook.dart` — TelemetryHook implementation (built-in example)
- `specs/011-usecase-hook-system/spec.md` — User Story 3 acceptance scenarios (lines 49-63)
- Missing: `zik_zak/lib/src/presentation/hooks/engagement_hook.dart` (non-existent)
- Missing: `apps/zikzak_demo/` directory (non-existent)

## Root Cause Hypothesis

The ZikZak application is a separate codebase (likely at `~/Developer/zik_zak` or similar) that was not cloned into the current workspace. The tasks.md assumed it would be available at `zik_zak/` relative to the Zuraffa root. The Zuraffa framework itself is not at fault — the hook system (US1 + US2) is complete and working. This is an environmental/dependency issue, not a code bug. Confidence: high.

## Proposed Remediation

**Preferred**: Add ZikZak as a submodule or dependency in the workspace. The spec expects the ZikZak app to be available at `zik_zak/` relative to Zuraffa root. Options:

1. `git submodule add https://github.com/arrrrny/zik_zak.git apps/zikzak_demo`
2. Clone ZikZak separately and symlink into the workspace
3. Create a minimal mock ZikZak app in `apps/zikzak_demo` for testing purposes

**Alternatives**:
- Defer US3 until ZikZak is available (framework is production-ready without US3)
- Mock ZikZak for testing (create minimal test app with EngagementEventRepository, 8 UseCases, controllers)

**Files likely to change**:
- `apps/zikzak_demo/lib/src/presentation/hooks/engagement_hook.dart` (new)
- `apps/zikzak_demo/lib/src/main.dart` (modified)
- `apps/zikzak_demo/lib/src/pages/barcode_listing/barcode_listing_controller.dart` (modified)
- `apps/zikzak_demo/lib/src/pages/ask_zikzak/ask_zikzak_controller.dart` (modified)
- `apps/zikzak_demo/lib/src/pages/url_listing/url_listing_controller.dart` (modified)
- `apps/zikzak_demo/lib/src/pages/deal/deal_controller.dart` (modified)
- `apps/zikzak_demo/lib/src/widgets/share/share_button.dart` (modified)
- `apps/zikzak_demo/test/presentation/hooks/engagement_hook_test.dart` (new)

**Tests to add or update**:
- `dart test apps/zikzak_demo/test/presentation/hooks/engagement_hook_test.dart`
- `grep -r "CreateTelemetryEventUseCase\|track" apps/zikzak_demo/lib/src/presentation/` → should return 0 matches

## Risks & Considerations

- This is a dependency/environmental issue, not a Zuraffa framework bug
- The hook system (US1 & US2) is complete and tested (46/46 tests passing)
- US3 validation story is blocked by missing ZikZak app
- Could be resolved by adding ZikZak as submodule or creating mock app
- No impact on Zuraffa framework functionality or other features

## Open Questions

- [NEEDS CLARIFICATION: Is the ZikZak app supposed to be a submodule or separate repo? Should it be cloned into `apps/zikzak_demo`?]
- [NEEDS CLARIFICATION: Is this a blocker for the UseCase Hook System feature, or can US3 be deferred?]
- [NEEDS CLARIFICATION: Should we create a mock ZikZak app for testing purposes?]