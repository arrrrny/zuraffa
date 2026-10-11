/// The latency model (spec 968, VISION §9): deterministic banded
/// distributions per touchpoint.
///
/// Every touchpoint invocation draws a latency from its declared bands:
/// **fast** (the common case), **slow** (every Nth call), **timeout**
/// (every Mth call). The draw is deterministic: a seeded xorshift PRNG
/// supplies in-band jitter, and the SAME seed + same call index always
/// yields the SAME latency — a world run's play ledger is replayable
/// byte-for-byte (#806 composes).
///
/// Latency is VIRTUAL: the runtime advances the virtual clock by the
/// drawn value and never sleeps wall time.
library;

import 'world_manifest.dart';

/// Which band a latency sample came from.
enum LatencyBand { fast, slow, timeout }

/// One drawn latency: the milliseconds and the band they came from.
final class LatencySample {
  const LatencySample(this.ms, this.band);

  final int ms;
  final LatencyBand band;

  @override
  String toString() => '$band:${ms}ms';
}

/// Deterministic seeded xorshift32 — small, stable, and dependency-free.
class _Xorshift32 {
  int _state;

  _Xorshift32(int seed) : _state = (seed & 0xffffffff) | 1;

  int nextUInt32() {
    var x = _state;
    x ^= x << 13;
    x &= 0xffffffff;
    x ^= x >>> 17;
    x ^= x << 5;
    x &= 0xffffffff;
    _state = x;
    return x;
  }

  /// Uniform integer in [min, max] (inclusive).
  int nextInt(int min, int max) {
    if (max <= min) return min;
    return min + (nextUInt32() % (max - min + 1));
  }
}

/// The per-world latency model: one PRNG stream seeded from the world
/// seed, band selection by call index, jitter within the band.
final class LatencyModel {
  LatencyModel({required int seed}) : _rng = _Xorshift32(seed == 0 ? 1 : seed);

  final _Xorshift32 _rng;

  /// Sample the latency for [touchpoint]'s [callIndex] (1-based) under
  /// the declared [bands].
  LatencySample sample(
    String touchpoint,
    int callIndex,
    WorldLatencyBands bands,
  ) {
    final band = _bandFor(callIndex, bands);
    final (min, max) = switch (band) {
      LatencyBand.fast => (bands.fastMinMs, bands.fastMaxMs),
      LatencyBand.slow => (bands.slowMinMs, bands.slowMaxMs),
      LatencyBand.timeout => (bands.timeoutMinMs, bands.timeoutMaxMs),
    };
    return LatencySample(_rng.nextInt(min, max), band);
  }

  /// Deterministic band selection: the timeout band wins when its
  /// modulus hits, then the slow band, else fast. Disabled moduli (0)
  /// never fire.
  static LatencyBand _bandFor(int callIndex, WorldLatencyBands bands) {
    if (bands.timeoutEvery > 0 && callIndex % bands.timeoutEvery == 0) {
      return LatencyBand.timeout;
    }
    if (bands.slowEvery > 0 && callIndex % bands.slowEvery == 0) {
      return LatencyBand.slow;
    }
    return LatencyBand.fast;
  }
}
