/// The world differential gate (spec 968; bug #915 composes): the same
/// behaviors must be green against the mock world AND against the
/// real-adapter harness.
///
/// The gate executes the scenario's behavior program TWICE:
///
/// - **world binding** — the full simulated reality: virtual clock,
///   latency bands, failure storms (the retry drivers survive them)
/// - **real binding** — the direct real-adapter harness: the same
///   touchpoint contracts and corpus served with NO world semantics (no
///   injected latency, no storms, no virtual clock) — the
///   production-shaped side of the #915 differential
///
/// Per behavior the gate classifies the pair of outcomes:
///
/// - `parity` — green in both lanes with identical result payloads:
///   the world's simulation layer (latency, storms, clock wrapping)
///   did not corrupt the functional outcome. This is the literal
///   "same behaviors green against mock world AND real adapter
///   harness" proof.
/// - `storm-proof` — the world lane landed exactly the declared
///   honest-red (an `expect: red` failure-storm behavior) while the
///   real lane is green: the storm did what the schedule declared.
///   Recorded as rehearsed — never silently passed.
/// - `drift` — everything else: red in both lanes, red in the real
///   lane only, green in both with DIFFERENT payloads, or a world red
///   the schedule does not explain. Drift fails the gate.
///
/// The report is written to `<featureDir>/tdd/world-differential-report.json`
/// (schema `world-diff.v1`) and every declared storm must have fired at
/// least once across the world run — a declared-but-never-fired storm
/// is reported (unrehearsed failure semantics are a finding, not a
/// pass).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'world_manifest.dart';
import 'world_runtime.dart';

/// The gate's verdict.
enum WorldDiffVerdict { pass, drift }

/// One behavior's differential classification.
enum DiffClass { parity, stormProof, drift }

/// One behavior's differential comparison row.
final class WorldDiffRow {
  const WorldDiffRow({
    required this.behavior,
    required this.clazz,
    required this.worldPassed,
    required this.realPassed,
    required this.payloadsEqual,
    required this.detail,
  });

  final String behavior;
  final DiffClass clazz;

  /// The behavior's verdict inside the world binding.
  final bool worldPassed;

  /// The behavior's verdict against the real-adapter harness.
  final bool realPassed;

  /// Whether both lanes' result payloads are canonically equal.
  final bool payloadsEqual;

  final String detail;

  Map<String, dynamic> toJson() => {
    'behavior': behavior,
    'class': switch (clazz) {
      DiffClass.parity => 'parity',
      DiffClass.stormProof => 'storm-proof',
      DiffClass.drift => 'drift',
    },
    'world_passed': worldPassed,
    'real_passed': realPassed,
    'payloads_equal': payloadsEqual,
    'detail': detail,
  };
}

/// The differential run's result.
final class WorldDifferentialResult {
  const WorldDifferentialResult({
    required this.verdict,
    required this.rows,
    required this.unrehearsedStorms,
    this.worldHash,
  });

  final WorldDiffVerdict verdict;
  final List<WorldDiffRow> rows;

  /// Declared storms that never fired across the world run.
  final List<String> unrehearsedStorms;

  final String? worldHash;

  Map<String, dynamic> toDocument() => {
    'schema': 'world-diff.v1',
    'spec': 968,
    if (worldHash != null) 'world_hash': worldHash,
    'verdict': verdict.name,
    'behaviors': rows.length,
    'parity': rows.where((r) => r.clazz == DiffClass.parity).length,
    'storm_proof': rows.where((r) => r.clazz == DiffClass.stormProof).length,
    'drift': rows.where((r) => r.clazz == DiffClass.drift).length,
    'unrehearsed_storms': unrehearsedStorms,
    'rows': [for (final row in rows) row.toJson()],
  };
}

/// The differential gate: world binding vs real-adapter harness over
/// the same behavior program.
final class WorldDifferentialGate {
  const WorldDifferentialGate();

  /// Run the gate for [manifest]; [featureDir] receives the report
  /// (`tdd/world-differential-report.json`).
  Future<WorldDifferentialResult> run(
    WorldManifest manifest,
    String featureDir,
  ) async {
    // World binding: full semantics, seeded from the manifest.
    final worldRuntime = WorldRuntime(manifest, binding: WorldBinding.world);
    final worldResults = await worldRuntime.executeScenario();

    // Real binding: the direct real-adapter harness (no world
    // semantics).
    final realRuntime = WorldRuntime(manifest, binding: WorldBinding.real);
    final realResults = await realRuntime.executeScenario();

    final byBehavior = {for (final r in realResults) r.behavior: r};

    final rows = <WorldDiffRow>[];
    for (final world in worldResults) {
      final real = byBehavior[world.behavior];
      if (real == null) {
        rows.add(
          WorldDiffRow(
            behavior: world.behavior,
            clazz: DiffClass.drift,
            worldPassed: world.passed,
            realPassed: false,
            payloadsEqual: false,
            detail: 'behavior missing from the real-lane program',
          ),
        );
        continue;
      }
      final payloadsEqual =
          world.succeeded &&
          real.succeeded &&
          _payloadEquals(world.result, real.result);

      final row = _classify(world, real, payloadsEqual);
      rows.add(row);
    }

    // Every declared storm must have fired at least once in the world
    // run — scan the play ledger for each storm's fingerprint (failed
    // and partial plays both name their storm).
    final unrehearsed = <String>[];
    for (final storm in manifest.storms) {
      final fired = worldRuntime.plays.any(
        (play) =>
            play.outcome != 'ok' && play.detail.contains('storm ${storm.name}'),
      );
      if (!fired) {
        unrehearsed.add(storm.name);
      }
    }

    final verdict = rows.any((r) => r.clazz == DiffClass.drift)
        ? WorldDiffVerdict.drift
        : WorldDiffVerdict.pass;
    final result = WorldDifferentialResult(
      verdict: verdict,
      rows: rows,
      unrehearsedStorms: unrehearsed,
      worldHash: manifest.worldHash,
    );

    // The committed report artifact.
    final reportPath = p.join(
      featureDir,
      'tdd',
      'world-differential-report.json',
    );
    final reportFile = File(reportPath);
    await reportFile.parent.create(recursive: true);
    await reportFile.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(result.toDocument())}\n',
    );
    return result;
  }

  /// Classification semantics (the honest table):
  ///
  /// | world lane (`passed` = matched its declared expectation) | real
  /// lane (`succeeded` — the harness has no storm semantics) | class |
  /// |---|---|---|
  /// | green as expected | green | payloads equal → **parity**;
  /// payloads differ → **drift** (the world corrupted the outcome) |
  /// | red (unexpected) | any | **drift** — the world's failure
  /// semantics broke a green-expected behavior (budget exhausted, ...) |
  /// | red as declared (`expect: red`) | green | **storm-proof** — the
  /// storm rehearsed the honest red without leaking into the real lane |
  /// | red as declared | red | **drift** — the real harness is red |
  /// | green but `expect: red` | green | **drift** — a blindly-retrying
  /// engine turned the declared honest red green; the world refuses
  /// free greens in both directions |
  static WorldDiffRow _classify(
    BehaviorResult world,
    BehaviorResult real,
    bool payloadsEqual,
  ) {
    if (!world.expectedRed) {
      if (world.passed && real.succeeded) {
        return WorldDiffRow(
          behavior: world.behavior,
          clazz: payloadsEqual ? DiffClass.parity : DiffClass.drift,
          worldPassed: true,
          realPassed: true,
          payloadsEqual: payloadsEqual,
          detail: payloadsEqual
              ? 'green in both lanes, payloads identical '
                    '(world attempts=${world.attempts}, '
                    'real attempts=${real.attempts})'
              : 'green in both lanes but payloads differ — the world '
                    'corrupted the functional outcome',
        );
      }
      return WorldDiffRow(
        behavior: world.behavior,
        clazz: DiffClass.drift,
        worldPassed: world.passed,
        realPassed: real.succeeded,
        payloadsEqual: payloadsEqual,
        detail:
            'unexpected divergence: world=${world.detail}; '
            'real=${real.detail}',
      );
    }

    // The expect-red (failure-storm) class.
    if (!world.succeeded && real.succeeded) {
      return WorldDiffRow(
        behavior: world.behavior,
        clazz: DiffClass.stormProof,
        worldPassed: true,
        realPassed: true,
        payloadsEqual: false,
        detail:
            'storm rehearsed: world lane surfaced the declared '
            'honest red (${world.failureLedger.join(', ')}), real lane '
            'green',
      );
    }
    return WorldDiffRow(
      behavior: world.behavior,
      clazz: DiffClass.drift,
      worldPassed: world.passed,
      realPassed: real.succeeded,
      payloadsEqual: false,
      detail: world.succeeded
          ? 'the declared honest-red behavior landed GREEN in the world '
                '(blindly retried?) — the world refuses free greens in '
                'both directions'
          : 'the real-adapter harness is red for a storm behavior: '
                'real=${real.detail}',
    );
  }

  /// Structural payload equality: canonicalize then encode to a
  /// string — Dart's `==` on maps is identity-based, and deep-copied
  /// fixtures are distinct objects with equal content.
  static bool _payloadEquals(dynamic a, dynamic b) =>
      jsonEncode(_canonical(a)) == jsonEncode(_canonical(b));

  static dynamic _canonical(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: _canonical(value[k])};
    }
    if (value is List) return [for (final e in value) _canonical(e)];
    return value;
  }
}
