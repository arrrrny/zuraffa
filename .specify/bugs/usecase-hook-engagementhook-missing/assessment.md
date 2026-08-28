# Bug Assessment: ZikZak EngagementHook missing (ZikZak app not in workspace)

- **Slug**: usecase-hook-engagementhook-missing
- **Created**: 2026-08-28
- **Source**: https://github.com/arrrrny/zuraffa/issues/501
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

The issue reports that User Story 3 of the UseCase Hook System spec cannot be validated because the ZikZak application codebase is not present in the workspace. The spec requires creating an `EngagementHook` in `zik_zak/lib/src/presentation/hooks/engagement_hook.dart`, mapping 8 UseCase names to `EngagementEventType` enum values, registering the hook in ZikZak's `main()`, removing manual tracking calls from controllers, and verifying zero manual tracking calls remain. The ZikZak app directory (`zik_zak/` or `apps/zikzak_demo`) does not exist, so the implementation cannot be done. The Zuraffa framework's hook system (US1 & US2) is complete and tested.

## Symptom

ZikZak application directory missing from workspace, preventing EngagementHook implementation and validation.

## Reproduction

1. Clone Zuraffa repo
2. Run `dart test test/core/hook_registry_test.dart test/core/telemetry_hook_test.dart test/domain/usecase_hook_test.dart test/domain/stream_usecase_hook_test.dart` — all pass
3. Look for `zik_zak/` directory — not found
4. Attempt to implement `EngagementHook` — no target codebase

## Suspected Code Paths

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to locate the code, or fill in manually.]

## Root Cause Hypothesis

[NEEDS CLARIFICATION — not yet analyzed.]

## Proposed Remediation

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to propose a fix, or apply a fix directly with /skill:speckit-bug-fix.]

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.

## Open Questions

- [NEEDS CLARIFICATION: Is the ZikZak app supposed to be a submodule or separate repo? Should it be cloned into `apps/zikzak_demo`?]
- [NEEDS CLARIFICATION: Is this a blocker for the UseCase Hook System feature, or can US3 be deferred?]