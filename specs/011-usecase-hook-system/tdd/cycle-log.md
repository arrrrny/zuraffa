# TDD Cycle Log: UseCase Hook System

**Feature**: `011-usecase-hook-system` | **Branch**: `011-usecase-hook-system` | **Spec**: [spec.md](spec.md)

---

## Baseline Entry

**Date**: 2026-08-26
**Commit SHA**: `614e648`
**Test Command**: `dart test test/core/hook_registry_test.dart test/core/telemetry_hook_test.dart test/domain/usecase_hook_test.dart test/domain/stream_usecase_hook_test.dart`

### Suite Results

| Test File | Tests | Passed | Failed | Skipped | Duration |
|-----------|-------|--------|--------|---------|----------|
| `test/core/hook_registry_test.dart` | 18 | 18 | 0 | 0 | ~2s |
| `test/core/telemetry_hook_test.dart` | 10 | 10 | 0 | 0 | ~1s |
| `test/domain/usecase_hook_test.dart` | 7 | 7 | 0 | 0 | ~1s |
| `test/domain/stream_usecase_hook_test.dart` | 11 | 11 | 0 | 0 | ~1s |
| **Total** | **46** | **46** | **0** | **0** | **~5s** |

### Known Pre-existing Issues

- **Full suite (`dart test test --preset=all`)**: 1 flaky failure in `test/plugins/mcp/mcp_sse_server_test.dart` — "McpSseServer remote requests get 401 when Authorization is missing or invalid" (30s timeout). This is unrelated to the hook system and was present before this feature.

---

## Cycle 1: User Story 3 (EngagementHook in ZikZak) — EXECUTED (bug 501, 2026-09-01)

**Target**: Implement `EngagementHook` in ZikZak app and verify 5 acceptance behaviors (C1–C5).

**Prerequisites**:
- ZikZak app codebase available at `../zik_zak` or `apps/zikzak_demo`
- `EngagementEventRepository` already exists in ZikZak
- 8 engagement event types defined: BARCODE_SCAN, LINK_SHARE, DEAL_LIKE, DEAL_SHARE, LISTING_SHARE, ASK_ZIKZAK, VISIT_LINK, SEARCH_TERM

**Plan**:
1. Create `EngagementHook` class in `zik_zak/lib/src/presentation/hooks/engagement_hook.dart`
2. Map 8 UseCase names to `EngagementEventType` enum values
3. Implement `execute()` calling repository with extracted payload
4. Register hook in ZikZak's `main()`
5. Remove manual `CreateTelemetryEventUseCase` calls from 5 controllers
6. Write integration tests in `zik_zak/test/presentation/hooks/engagement_hook_test.dart`
7. Verify zero tracking calls remain via grep

### Execution Record (bug 501 remediation — mock app `apps/zikzak_demo/`)

**Date**: 2026-09-01 | **Branch**: `fix/501-usecase-hook-engagementhook-missing` | **Base**: `11de4bf`

ZikZak remained unavailable as a separate codebase, so the recorded remediation
(assessment: "create a minimal mock ZikZak app") was executed against
`apps/zikzak_demo/` — a pure-Dart mock with the real framework as a path dep.

#### RED (commit `1b9bb88` — tests + mock app with manual calls, no hook)

- Command: `dart test test/presentation/hooks/engagement_hook_test.dart`
  → exit 1. Evidence (compile-level red, hook absent):
  `Error: Method not found: 'EngagementHook'` (3 occurrences); `Some tests failed.`
- Command: `dart test test/presentation/hooks/manual_calls_absence_test.dart`
  → exit 1. Evidence (assertion-level red, 21 manual call sites):
  `manual engagement calls must be removed (bug 501, criterion C5); found 21 offending line(s)`.

#### GREEN (commit `3264f56` — hook implemented, manual calls removed)

- Command: `dart test` (in `apps/zikzak_demo/`) → **6/6 passed**, exit 0
  (C1, C2, C3, C4, SC-005 map, C5 source scan).
- C5 grep: `grep -rn "CreateTelemetryEventUseCase\|track" lib/src/presentation/`
  → 0 matches, exit 1 (no match).
- Framework regression: root `tools/run_tests_chunked.sh` → 1307 tests passing
  across 33 runnable chunks, 0 new failures (3 chunks — `test/benchmark`,
  `test/core/dependencies`, `test/integration` — contain only tag-excluded tests
  and exit 79 "No tests ran"; reproduced identical at base `11de4bf`, pre-existing).

#### Deliberate mutants (test-strength sample, both restored + re-verified green)

| Mutant | Behavior | Caught |
|--------|----------|--------|
| `engagement_hook.dart` `payloadFor` → return `''` always | C1/C2 payload | Yes (C1+C2 failed) |
| `engagement_hook.dart` `phases` → all three phases | C3 success-only | Yes (C3 failed, exit 1) |

---

## Future Cycles

### Cycle 2: Edge Case Hardening (if needed)
- Test synchronous hook completion
- Test metadata sharing with multiple hooks
- Test StreamUseCase with error emission mid-stream

### Cycle 3: Performance Validation
- Benchmark dispatch overhead with 0, 1, 10 hooks registered
- Verify <1μs when no hooks registered (single `isEmpty` check)

---

## Rollback/Revert Points

- **Baseline (614e648)**: All Zuraffa framework hook tests pass. Safe to return here.
- If ZikZak integration fails, the framework (US1+US2) remains fully functional.

---

## Notes

- The Zuraffa framework hook system (US1 + US2) is **complete and tested**.
- US3 requires the ZikZak app which is a separate codebase. This cycle log tracks progress there separately.
- No bugs found in the Zuraffa hook implementation during baseline testing.

## 2026-09-02T19:11:27.681033Z: certified simulation fixtures (bug #832)
- behavior: 011-usecase-hook-system-fixtures
- kind: fixtures
- at: 2026-09-02T19:11:27.681033Z
- exit: 0
- criterion: certified fixture world committed under tdd/fixtures/ and hashed into the manifest digest
- command: `zfa simulate --scaffold specs/011-usecase-hook-system --family otel`
- schema: 1
- prev-hash: genesis
- hash: ab948447a85f60b9b62947f6181b48b696ea1aa76f16e53e44883085c0b66ef4
- families: otel
- fixtures: otel-world.json=e372cb31ae5acf3ad3ccf734f74af303cb5739b9c158e0830b541b3b80a11da2
