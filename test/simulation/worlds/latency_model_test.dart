/// Spec 968 — the latency model (U3, A4): deterministic banded
/// distributions per touchpoint.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/simulation/worlds/latency_model.dart';
import 'package:zuraffa/src/simulation/worlds/world_manifest.dart';

void main() {
  const bands = WorldLatencyBands.certified;

  group('band selection (deterministic by call index)', () {
    final model = LatencyModel(seed: 968);

    test('the timeout band wins when its modulus hits (25, 50, ...)', () {
      // certified defaults: slowEvery 4, timeoutEvery 25.
      expect(model.sample('T', 25, bands).band, LatencyBand.timeout);
      expect(model.sample('T', 50, bands).band, LatencyBand.timeout);
    });

    test('the slow band hits on its modulus (4, 8, 28, ...)', () {
      expect(model.sample('T', 4, bands).band, LatencyBand.slow);
      expect(model.sample('T', 8, bands).band, LatencyBand.slow);
      expect(model.sample('T', 28, bands).band, LatencyBand.slow);
    });

    test('everything else is the fast band', () {
      expect(model.sample('T', 1, bands).band, LatencyBand.fast);
      expect(model.sample('T', 26, bands).band, LatencyBand.fast);
    });

    test('disabled moduli (0) never fire', () {
      const disabled = WorldLatencyBands(
        fastMinMs: 5,
        fastMaxMs: 15,
        slowMinMs: 120,
        slowMaxMs: 400,
        timeoutMinMs: 800,
        timeoutMaxMs: 1500,
        slowEvery: 0,
        timeoutEvery: 0,
      );
      for (var i = 1; i <= 30; i++) {
        expect(model.sample('T', i, disabled).band, LatencyBand.fast);
      }
    });
  });

  group('sampling (seeded, in-band)', () {
    test('samples stay within the selected band bounds', () {
      final model = LatencyModel(seed: 968);
      for (var call = 1; call <= 60; call++) {
        final s = model.sample('RestSync', call, bands);
        final (min, max) = switch (s.band) {
          LatencyBand.fast => (bands.fastMinMs, bands.fastMaxMs),
          LatencyBand.slow => (bands.slowMinMs, bands.slowMaxMs),
          LatencyBand.timeout => (bands.timeoutMinMs, bands.timeoutMaxMs),
        };
        expect(s.ms, greaterThanOrEqualTo(min));
        expect(s.ms, lessThanOrEqualTo(max));
      }
    });

    test('same seed → identical draw sequence (replayable)', () {
      final a = LatencyModel(seed: 42);
      final b = LatencyModel(seed: 42);
      for (var call = 1; call <= 20; call++) {
        expect(a.sample('T', call, bands).ms, b.sample('T', call, bands).ms);
      }
    });

    test('different seeds produce different draws somewhere', () {
      final a = LatencyModel(seed: 1);
      final b = LatencyModel(seed: 2);
      final drawsA = [for (var i = 1; i <= 10; i++) a.sample('T', i, bands).ms];
      final drawsB = [for (var i = 1; i <= 10; i++) b.sample('T', i, bands).ms];
      expect(drawsA, isNot(drawsB));
    });
  });
}
