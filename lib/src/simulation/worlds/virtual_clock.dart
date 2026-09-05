/// The virtual clock (spec 968, VISION §9): deterministic simulated
/// time.
///
/// The world's time model runs on a virtual clock seeded from the
/// manifest: the epoch is seed-derived, [advance] moves time forward,
/// and NOTHING ever reads the wall clock — latency bands and backoff
/// waits advance virtual time, so temporal behaviors (retry-with-backoff
/// sync over a failure storm) complete in ~0 wall milliseconds while
/// recording hundreds or thousands of virtual milliseconds. Same seed →
/// same epoch → same time sequence: world runs are deterministically
/// replayable (#806 composes).
library;

/// A deterministic virtual clock. Never touches `DateTime.now()`.
final class VirtualClock {
  /// Construct a clock whose epoch is deterministically derived from
  /// [seed] (stable across platforms: pure integer arithmetic, no
  /// wall-clock anchoring).
  VirtualClock(int seed) : _nowMs = _epochOf(seed), epochMs = _epochOf(seed);

  /// Construct a clock pinned to an explicit epoch (tests).
  VirtualClock.atEpoch(this.epochMs) : _nowMs = epochMs;

  static int _epochOf(int seed) {
    // 2026-01-01T00:00:00Z plus a seed-derived offset within a year —
    // deterministic, human-plausible timestamps for play ledgers.
    const base = 1767225600000; // 2026-01-01T00:00:00Z (ms)
    final normalized = seed & 0x7fffffff;
    return base + normalized * 1000;
  }

  final int epochMs;

  int _nowMs;

  /// The current virtual time (milliseconds since the Unix epoch).
  int get nowMs => _nowMs;

  /// Virtual milliseconds elapsed since the clock's epoch.
  int get elapsedMs => _nowMs - epochMs;

  /// Advance virtual time by [ms] (negative values are clamped to 0 —
  /// time only moves forward). Returns the new [nowMs].
  int advance(int ms) {
    if (ms > 0) _nowMs += ms;
    return _nowMs;
  }

  /// The current virtual time as an ISO-8601 UTC instant.
  String get nowIso => DateTime.fromMillisecondsSinceEpoch(
    _nowMs,
    isUtc: true,
  ).toIso8601String();
}
