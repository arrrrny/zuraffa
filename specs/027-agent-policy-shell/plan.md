# Implementation Plan: Agent Policy Shell

**Branch**: `027-agent-policy-shell` | **Date**: 2026-08-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/027-agent-policy-shell/spec.md`

## Summary

Ships the framework-default agent policy shell: `ToolGatingHook` (a tool permission registry with `safe` / `confirm` / `admin` risk tiers and per-mission allowlists), `MissionBudgetHook` (four-dimension budgets — calls, wall-clock, tokens, per-tool-class seconds — with typed budget-exceeded events and cancellation), and `MissionTraceRecorder` (hashed-argument Mission Trace JSON with concurrent-streaming integrity and an oversized-result guard that swaps in artifact references before model context). All three hooks are composable and individually disableable.

## Technical Context

**Language/Version**: Dart 3.13+ (SDK 3.11+ compatible) — pure-Dart package.

**Primary Dependencies**: `zuraffa core`; standard `dart:async`, `dart:convert`, `dart:collection`. Argument hashing uses `package:crypto` (already in the transitive resolution graph via `uuid` / `minio` / `opentelemetry`).

**Storage**: In-process — registry, budget trackers, and trace buffers live on the `PolicyShell` instance per mission. Trace JSON is materialized on mission end via `TraceRecorder.toJson()`.

**Testing**: `dart test`. Tests under `test/agent/policy/...`. Pure Dart — no `flutter_test`.

**Project Type**: library subsystem.

**Performance Goals**:
- SC-001: permission registry lookup <5ms per call (in-process map lookup → microseconds).
- SC-002: budget breach → mission cancel <100ms (synchronous check on every tool call → microseconds).
- SC-003: 20+ tool calls produce schema-valid JSON (deterministic, replayable).
- SC-004: oversized results never enter model context (interceptor replaces result with artifact reference before model reads it).

**Constraints**:
- Pure Dart — no Flutter imports.
- No new dependencies in `pubspec.yaml`.
- Hooks MUST be composable (each individually disableable).
- Single-isolate assumption (matches #388).

## Constitution Check

Pass — no constitution violations. Pure-Dart subsystem; no Flutter dependency; reuses transitive `crypto`.

## Project Structure

```text
specs/027-agent-policy-shell/
├── plan.md
├── tasks.md
└── tdd/
    ├── test-list.md
    ├── red-evidence.md
    └── verification.md

lib/src/agent/policy/
├── policy_shell.dart       # Barrel
├── policy_hook.dart        # PolicyHook interface + composition
├── permission_registry.dart # FR-001 (safe/confirm/admin)
├── tool_gating_hook.dart   # FR-001..004, FR-011, FR-012
├── mission_budget.dart     # FR-005, FR-013
├── mission_budget_hook.dart # FR-006
├── mission_trace.dart      # FR-007, FR-008, FR-009
├── mission_trace_recorder.dart # FR-007, FR-009
├── oversized_result_guard.dart # FR-010
└── artifact_reference.dart # FR-010

test/agent/policy/
├── permission_registry_test.dart
├── tool_gating_hook_test.dart
├── mission_budget_hook_test.dart
├── mission_trace_recorder_test.dart
├── oversized_result_guard_test.dart
└── policy_shell_test.dart
```

## Phases

### Phase 0 — Research
No external research required. The semantics follow the spec directly; hash-by-default with allowlist is a standard pattern; the oversized-result guard is a simple size check + swap.

### Phase 1 — Design
- **PolicyHook**: `abstract class PolicyHook { String id; bool enabled; Future<HookDecision> beforeToolCall(ToolCallContext ctx); Future<void> afterToolCall(ToolCallContext ctx, ToolResult result); }`. Composed via `PolicyShell` which runs each enabled hook in registration order.
- **PermissionRegistry**: `Map<String, RiskLevel>` with `lookup(toolName)` returning the most-restrictive match (glob supported). Falls back to tool's own risk metadata when not in registry (FR-012).
- **MissionBudget**: `class { int maxCalls; Duration maxWallClock; int maxTokens; Map<String, Duration> perToolClassMax; }`. Tracker records current usage; `check()` returns the first breached dimension or null.
- **MissionTraceRecorder**: maintains a list of `ToolCallRecord`s; each record carries `name`, `argumentsHash`, optional cleartext fields per allowlist, `duration`, `status`, `tokenUsage`. Concurrent streaming via a single-write lock (Dart's single-isolate model means we don't need real locks — just append-only).
- **OversizedResultGuard**: interceptor wraps the tool's return; if `result.size > threshold`, replaces with `ArtifactReference(uri, size, sha256)`.

### Phase 2 — Tasks
See `tasks.md`.
