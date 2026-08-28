# Implementation Plan: Agent Kernel — Mission Coalescing, Cancellation & Partial-Salvage

**Branch**: `026-agent-kernel-mission` | **Date**: 2026-08-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/026-agent-kernel-mission/spec.md`

## Summary

Implements the agent kernel's efficiency + safety core: identical missions coalesce into one execution via a composite key (spark type + normalized value + country + strategy variant) and fan out events to all subscribers; mid-execution cancellation triggers a grace period that disposes webviews / aborts requests / closes streams before teardown, salvages partials as `cancelled_partial`, and asserts zero resource leaks; an idempotency cache serves repeated submissions within TTL. Introspection endpoints (`activeMissions`, `waitingSubscribers`, coalescing window) and a configurable coalescing window are exposed. Single-isolate assumption is documented; multi-isolate extension is a future hook.

## Technical Context

**Language/Version**: Dart 3.13+ (SDK 3.11+ compatible) — pure-Dart package (`sdk: ^3.11.0`).

**Primary Dependencies**: `zuraffa core` (this package); standard `dart:async` primitives (`StreamController`, `Completer`, `Future`). No new external dependencies.

**Storage**: In-process — coalescing table and idempotency cache live in memory on the `AgentKernel` instance. Persistence of mission records is delegated to the existing mission record store (out of scope).

**Testing**: `dart test` (package:test ^1.25.0). Tests live under `test/agent/kernel/...` mirroring source layout. No `flutter_test` — pure Dart. Concurrency tests use `Future.wait` to schedule overlapping submissions.

**Target Platform**: In-process agent runtime; single isolate (documented assumption).

**Project Type**: library (subsystem under `zuraffa` core).

**Performance Goals**: 50 concurrent identical missions → exactly 1 executes (SC-001); cancellation completes within bounded grace period; 200 mixed missions (80% dup) — no deadlock, bounded memory (SC-003).

**Constraints**:
- Pure Dart — NO `package:flutter` import anywhere in `lib/src/agent/kernel/**` or its tests.
- No new dependencies added to `pubspec.yaml`.
- Existing pubspec `dependency_overrides:` block must remain removed.
- Must NOT duplicate agent-loop logic from `dart_agent_core` (out of scope for this kernel-efficiency feature).

## Constitution Check

Pass — no constitution violations identified. Pure-Dart subsystem; no Flutter dependency introduced; no new external dependencies.

## Project Structure

```text
specs/026-agent-kernel-mission/
├── plan.md              # This file
├── tasks.md             # Task breakdown
└── tdd/
    ├── test-list.md     # FR → test mapping
    ├── red-evidence.md  # RED run output
    └── verification.md   # GREEN + acceptance-criteria coverage

lib/src/agent/kernel/
├── agent_kernel.dart        # Barrel + public AgentKernel class
├── mission.dart             # Mission, MissionKey, MissionStatus, MissionOutcome
├── mission_coalescer.dart   # CoalescingGroup + composite-key derivation + fan-out
├── cancellation.dart        # CancelToken, grace period, resource disposal protocol
├── partial_salvage.dart    # Salvage protocol (cancelled_partial outcome)
├── idempotency_cache.dart   # TTL-bounded outcome cache
├── introspection.dart       # activeMissions / waitingSubscribers / coalescing window
└── resource_handle.dart     # Disposable resource handle protocol (webview / stream / request)

test/agent/kernel/
├── mission_coalescer_test.dart
├── cancellation_test.dart
├── partial_salvage_test.dart
├── idempotency_cache_test.dart
├── introspection_test.dart
└── agent_kernel_test.dart
```

## Phases

### Phase 0 — Research
No external research required. The semantics are entirely defined by the spec; the cancellation grace-period pattern is a standard `Completer` + `Future.any` race.

### Phase 1 — Design
- **Mission composite key**: `Object.hash(sparkType, normalizedValue, country, strategyVariant)` rendered as a stable string `"$sparkType|$normalizedValue|$country|$strategyVariant"`. Deterministic and collision-resistant for the four-tuple.
- **CoalescingGroup**: holds the executing `Mission`, a `StreamController<MissionEvent>` (broadcast), a `Set<SubscriberId>` of attached subscribers, and a `Completer<MissionOutcome>` for completion.
- **Cancellation**: a `CancelToken` carries a `Completer<void>`; on cancel, the kernel calls `tool.dispose()` for each registered resource handle inside a `Future.any([allDisposes, timeout])` race. Salvage runs after disposal.
- **Idempotency cache**: `Map<MissionKey, _Cached>` with `expiresAt` per entry; on lookup, expired entries are evicted; bounded size with simple LRU eviction.
- **Single-isolate extension point**: `AgentKernel` accepts an injectable `MissionExecutor` and `ResourceRegistry`; a future multi-isolate pool would override these to send work over `SendPort`.

### Phase 2 — Tasks
See `tasks.md`.
