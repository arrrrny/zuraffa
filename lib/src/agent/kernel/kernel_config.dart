/// Configuration for the [AgentKernel] (FR-010 — configurable coalescing
/// window; FR-009 — single-isolate documentation).
class KernelConfig {
  const KernelConfig({
    this.coalescingWindow = const Duration(milliseconds: 50),
    this.idempotencyTtl = const Duration(minutes: 5),
    this.idempotencyEnabled = true,
    this.cancellationGracePeriod = const Duration(milliseconds: 250),
  });

  /// Window during which identical mission keys coalesce into one
  /// execution (FR-010).
  final Duration coalescingWindow;

  /// TTL for the idempotency cache (FR-007).
  final Duration idempotencyTtl;

  /// Whether idempotency is enabled (false → every submission runs fresh).
  final bool idempotencyEnabled;

  /// Grace period for resource disposal on cancellation (FR-004).
  final Duration cancellationGracePeriod;
}
