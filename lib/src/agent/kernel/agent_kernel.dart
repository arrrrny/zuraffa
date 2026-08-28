/// Agent Kernel — Mission Coalescing, Cancellation & Partial-Salvage.
///
/// Provides the efficiency + safety core of the agent kernel. Identical
/// missions coalesce via a composite key (spark type + normalized value +
/// country + strategy variant) and execute exactly once, with events fanned
/// out to all subscribers. Mid-execution cancellation triggers a grace
/// period that disposes all registered resource handles (webviews, network
/// streams, open requests) before teardown, salvages partial results as
/// `cancelled_partial`, and asserts zero resource leaks. An idempotency
/// cache serves repeated submissions within a configurable TTL.
///
/// ## Single-Isolate Assumption (FR-009)
///
/// This kernel operates within a single Dart isolate. All missions,
/// coalescing groups, and resource handles live in the same isolate's
/// memory. Concurrency is cooperative (async/await on the event loop),
/// not parallel. For multi-isolate pool support, override
/// [MissionExecutor] and [ResourceRegistry] with implementations that
/// proxy work over `SendPort`/`ReceivePort` — the kernel's coordination
/// logic is unchanged.
///
/// Pure-Dart — no `package:flutter` imports. See
/// `specs/026-agent-kernel-mission/` for the full spec.
library;

export 'kernel_config.dart';
export 'mission.dart';
export 'mission_event.dart';
export 'resource_handle.dart';
export 'mission_coalescer.dart';
export 'cancellation.dart';
export 'partial_salvage.dart';
export 'idempotency_cache.dart';
export 'introspection.dart';
export 'kernel.dart';
