/// `DifferentialGate` — real vs mock run the same committed fixtures and
/// the output diff becomes a drift report (spec 913, phase 3).
///
/// Extends the #832 fixture commitment (fixtures live at
/// `specs/<feature>/tdd/fixtures/`) with the realization differential:
/// every fixture executes through BOTH bindings via the driver protocol
/// and the outputs compare per field. Findings reuse the #805
/// differential machinery's [VectorFinding] model; the verdict applies
/// the threshold from `.zfa.json` (`tdd.realizeDifferentialThreshold`,
/// default 0.0 — strict: any drift fails until consciously allowed).
///
/// The driver protocol (production): the project's
/// `tool/realize_driver.dart` is spawned as
/// `dart run tool/realize_driver.dart --binding <mock|real> --entity <E>`
/// with the fixture input JSON on stdin and the output JSON expected on
/// stdout — a thin, project-owned adapter the command documents (it is
/// the only place the generated interface's method names are known).
/// Fast-tier tests inject the driver directly.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

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

  Map<String, dynamic> toJson() => {
    'fixture': fixture,
    'compared': compared,
    'drifted': drifted,
    'findings': [
      for (final finding in findings)
        {'kind': finding.kind, 'detail': finding.detail},
    ],
  };
}

/// The differential run's result.
class DifferentialGateResult {
  const DifferentialGateResult({
    required this.verdict,
    required this.threshold,
    required this.diffs,
    required this.fixturesRun,
    this.error,
  });

  final DifferentialVerdict verdict;

  /// The threshold the gate enforced (from `.zfa.json`
  /// `tdd.realizeDifferentialThreshold`; default 0.0 — strict).
  final double threshold;

  final List<FixtureDiff> diffs;

  /// Number of fixtures executed (0 when skipped).
  final int fixturesRun;

  /// The runner-error detail, when the verdict is runner-error.
  final String? error;

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

  /// Compact drift rendering for the machine summary (0.5, 0.2, 0.0).
  String get driftLabel => _compact(drift);

  static String _compact(double value) =>
      double.parse(value.toStringAsFixed(4)).toString();
}

class DifferentialGate {
  const DifferentialGate({
    required this.featureDir,
    required this.projectRoot,
    required RealizeFixtureDriver driver,
  }) : _driver = driver;

  /// The feature directory (`specs/<feature>`).
  final String featureDir;

  /// The target project root (for `.zfa.json` and the driver spawn cwd).
  final String projectRoot;

  final RealizeFixtureDriver _driver;

  /// Load the differential threshold from `.zfa.json`
  /// (`tdd.realizeDifferentialThreshold`). Absent file or absent key →
  /// 0.0 (strict: any drift fails until consciously allowed).
  static double thresholdOf(String projectRoot) {
    final file = File(p.join(projectRoot, '.zfa.json'));
    if (!file.existsSync()) return 0.0;
    try {
      final json = jsonDecode(file.readAsStringSync());
      if (json is! Map<String, dynamic>) return 0.0;
      final tdd = json['tdd'];
      if (tdd is! Map<String, dynamic>) return 0.0;
      final raw = tdd['realizeDifferentialThreshold'];
      if (raw is num) {
        final value = raw.toDouble();
        // Clamp into [0, 1]: the threshold is a ratio.
        if (value < 0) return 0.0;
        if (value > 1) return 1.0;
        return value;
      }
      return 0.0;
    } on FormatException {
      return 0.0;
    }
  }

  /// Run every committed fixture under `tdd/fixtures/` through both
  /// bindings and compare outputs per field. Writes
  /// `tdd/differential-report.json`.
  Future<DifferentialGateResult> run({required String entity}) async {
    final fixturesDir = Directory(p.join(featureDir, 'tdd', 'fixtures'));
    if (!await fixturesDir.exists()) {
      return const DifferentialGateResult(
        verdict: DifferentialVerdict.skipped,
        threshold: 0.0,
        diffs: [],
        fixturesRun: 0,
      );
    }
    final files =
        fixturesDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    final threshold = thresholdOf(projectRoot);
    final diffs = <FixtureDiff>[];
    for (final file in files) {
      final diff = await _runFixture(file, entity);
      if (diff == null) {
        return DifferentialGateResult(
          verdict: DifferentialVerdict.runnerError,
          threshold: threshold,
          diffs: diffs,
          fixturesRun: diffs.length,
          error:
              'fixture ${p.basename(file.path)} could not execute '
              'through both bindings — see the driver protocol in the '
              'realize command docs.',
        );
      }
      diffs.add(diff);
    }

    final result = DifferentialGateResult(
      verdict: _verdictFor(diffs, threshold),
      threshold: threshold,
      diffs: diffs,
      fixturesRun: diffs.length,
    );
    await _writeReport(result);
    return result;
  }

  static DifferentialVerdict _verdictFor(
    List<FixtureDiff> diffs,
    double threshold,
  ) {
    var compared = 0;
    var drifted = 0;
    for (final diff in diffs) {
      compared += diff.compared;
      drifted += diff.drifted;
    }
    final drift = compared == 0 ? 0.0 : drifted / compared;
    return drift <= threshold
        ? DifferentialVerdict.pass
        : DifferentialVerdict.drift;
  }

  /// Execute one fixture through both bindings; null on a driver/parse
  /// failure (the runner-error class — the gate fails closed).
  Future<FixtureDiff?> _runFixture(File file, String entity) async {
    Map<String, dynamic> fixture;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      fixture = decoded;
    } on FormatException {
      return null;
    }
    final input = fixture['input'];
    if (input is! Map<String, dynamic>) return null;
    final id =
        (fixture['id'] as String?) ?? p.basenameWithoutExtension(file.path);

    Map<String, dynamic> mockOut;
    final recorded = fixture['mockOutput'];
    if (recorded is Map<String, dynamic>) {
      mockOut = recorded;
    } else {
      try {
        mockOut = await _driver('mock', entity, input);
      } on Object {
        return null;
      }
    }
    Map<String, dynamic> realOut;
    try {
      realOut = await _driver('real', entity, input);
    } on Object {
      return null;
    }

    return _compare(id, mockOut, realOut);
  }

  /// Per-field comparison: every top-level field on either side, value
  /// equality by JSON encoding (nested values compare whole).
  static FixtureDiff _compare(
    String id,
    Map<String, dynamic> mockOut,
    Map<String, dynamic> realOut,
  ) {
    final findings = <VectorFinding>[];
    final keys = <String>{...mockOut.keys, ...realOut.keys}.toList()..sort();
    var drifted = 0;
    for (final key in keys) {
      final inMock = mockOut.containsKey(key);
      final inReal = realOut.containsKey(key);
      if (!inMock || !inReal) {
        drifted++;
        findings.add(
          VectorFinding(
            kind: 'missing-field',
            detail:
                '$id: field "$key" only on the '
                '${inMock ? 'mock' : 'real'} side',
          ),
        );
        continue;
      }
      if (jsonEncode(mockOut[key]) != jsonEncode(realOut[key])) {
        drifted++;
        findings.add(
          VectorFinding(
            kind: 'field',
            detail:
                '$id: field "$key" drifts — mock ${jsonEncode(mockOut[key])} '
                'vs real ${jsonEncode(realOut[key])}',
          ),
        );
      }
    }
    return FixtureDiff(
      fixture: id,
      compared: keys.length,
      drifted: drifted,
      findings: findings,
    );
  }

  Future<void> _writeReport(DifferentialGateResult result) async {
    final path = p.join(featureDir, 'tdd', 'differential-report.json');
    final report = {
      'schema': 'realize-diff.v1',
      'verdict': result.verdict.name,
      'threshold': result.threshold,
      'drift': double.parse(result.drift.toStringAsFixed(6)),
      'fixtures': result.fixturesRun,
      'diffs': result.diffs.map((d) => d.toJson()).toList(),
      'findings': [
        for (final diff in result.diffs)
          for (final finding in diff.findings)
            {'kind': finding.kind, 'detail': finding.detail},
      ],
    };
    await File(
      path,
    ).writeAsString('${const JsonEncoder.withIndent('  ').convert(report)}\n');
  }
}
