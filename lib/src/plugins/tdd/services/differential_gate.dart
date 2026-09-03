/// `DifferentialGate` — real vs mock run the same committed fixtures and
/// the output diff becomes a drift report (spec 913, phase 3).
///
/// STUB (red phase): every member throws until the green phase implements
/// the drift contract.
library;

import 'dart:io';

import '../models/differential_vector.dart';

/// Executes one fixture through one binding (MOCK or REAL). Injectable
/// for fast-tier tests; the production driver spawns the project's
/// `tool/realize_driver.dart` (the driver protocol documented in the
/// realize command docs).
typedef RealizeFixtureDriver =
    Future<Map<String, dynamic>> Function(
      String binding,
      String entity,
      Map<String, dynamic> input,
    );

/// The gate's verdict.
enum DifferentialVerdict { pass, drift, skipped, runnerError }

/// One fixture's comparison outcome.
class FixtureDiff {
  const FixtureDiff({
    required this.fixture,
    required this.compared,
    required this.drifted,
    required this.findings,
  });

  /// The fixture's id (or file name when it carries none).
  final String fixture;

  /// Number of top-level fields compared.
  final int compared;

  /// Number of fields that drifted (value mismatch or one-sided).
  final int drifted;

  /// Per-field findings (the #805 machinery's finding model).
  final List<VectorFinding> findings;
}

/// The differential run's result.
class DifferentialGateResult {
  const DifferentialGateResult({
    required this.verdict,
    required this.threshold,
    required this.diffs,
    required this.fixturesRun,
  });

  final DifferentialVerdict verdict;

  /// The threshold the gate enforced (from `.zfa.json`
  /// `tdd.realizeDifferentialThreshold`; default 0.0 — strict).
  final double threshold;

  final List<FixtureDiff> diffs;

  /// Number of fixtures executed (0 when skipped).
  final int fixturesRun;

  /// The overall drift ratio: drifted fields / compared fields.
  double get drift {
    var compared = 0;
    var drifted = 0;
    for (final diff in diffs) {
      compared += diff.compared;
      drifted += diff.drifted;
    }
    return compared == 0 ? 0.0 : drifted / compared;
  }
}

class DifferentialGate {
  const DifferentialGate({
    required this.featureDir,
    required this.projectRoot,
    required RealizeFixtureDriver driver,
  });

  /// The feature directory (`specs/<feature>`).
  final String featureDir;

  /// The target project root (for `.zfa.json`).
  final String projectRoot;

  /// Load the differential threshold from `.zfa.json`
  /// (`tdd.realizeDifferentialThreshold`). Absent file or absent key →
  /// 0.0 (strict: any drift fails until consciously allowed).
  static double thresholdOf(String projectRoot) => throw UnimplementedError();

  /// Run every committed fixture under `tdd/fixtures/` through both
  /// bindings and compare outputs per field. Writes
  /// `tdd/differential-report.json`.
  Future<DifferentialGateResult> run({required String entity}) =>
      throw UnimplementedError();
}
