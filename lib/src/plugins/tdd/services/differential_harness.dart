/// `DifferentialHarness` — the MOCK-FIRST differential harness (spec
/// 1195, parent #908 P1: the REAL tier's honesty gate, companion to
/// `zfa tdd realize` #1193).
///
/// At realization time, the SAME committed inputs replay through (a) the
/// certified mock — the fixture's recorded `mockOutput`, the mock-era
/// oracle (driver fallback when unrecorded) — and (b) the real adapter
/// (the [RealizeFixtureDriver] protocol), and the outputs diff on the
/// CONTRACT-RELEVANT projection:
///
/// - **entity shapes** (the default dimension): field-name sets and type
///   signatures — parity is shape, not bytes (the #915 convention; list
///   length and map key sets are shape). Value drift inside a
///   same-shape entity field is NOT a divergence: server-assigned ids
///   and timestamps legitimately differ between the mock era and the
///   real one.
/// - **state transitions** (`state`, `status`, `nextState`, `fromState`,
///   `toState`, `transition`, `transitioned`): value equality — state
///   outcomes are contract.
/// - **error kinds** (`error`, `errorKind`, `errorCode`, `failure`,
///   `failureKind`): value equality + presence parity — the error
///   taxonomy is contract, and an error on one side only is the classic
///   contract break.
///
/// Every divergence is a NAMED row — `{fixture, field, dimension,
/// clause, input, mockOutput, realOutput, detail}` — the four fields
/// issue #1195 names plus the classification, so a blocked promotion
/// says exactly which contract behavior diverged. A fixture's
/// `contract` map pins per-field comparison (`{"<field>": "value"}`),
/// and its `clauses` map attributes rows to spec scenarios
/// (`{"<field>": "SC-3: …"}`); the default clause is the dimension's
/// parity statement.
///
/// The verdict defaults to strict: any row is `divergence` (blocks the
/// MOCKED→REAL promotion). The threshold from `.zfa.json`
/// (`tdd.realizeDifferentialThreshold`, default 0.0 — same key and
/// inclusive boundary as spec 913) is the conscious escape hatch: rows
/// within it still land in the receipt (never silenced), only the
/// blocking is lifted.
///
/// The receipt — `specs/<feature>/tdd/differential-receipt.json`,
/// schema `realize-diff-receipt.v1` — is DETERMINISTIC: fixed key
/// order, rows sorted by (fixture, field), no timestamps, no absolute
/// paths, and a `fixtures.digest` (sha256 over the sorted fixture
/// files' sha256s) binding the fixture set into the bytes. Same
/// fixtures, same report bytes — replayable, like the spec-fuzz
/// reports.
///
/// Journal-consumable (#1113): the `journal` block lifts into the
/// unified journal entry's fields without parsing prose —
/// `gate_state` (green|red|not_assessed: pass→green,
/// divergence/runner-error→red — the gate fails closed —,
/// skipped→not_assessed), `violations` (the row ids), `refs` (the
/// fixtures dir + this receipt, project-relative POSIX).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

/// Executes one fixture through one binding (MOCK or REAL). Injectable
/// for fast-tier tests; the production driver spawns the project's
/// `tool/realize_driver.dart` (the driver protocol documented in the
/// realize command docs). Supersedes the differential_gate.dart
/// declaration (same shape, new home).
typedef RealizeFixtureDriver =
    Future<Map<String, dynamic>> Function(
      String binding,
      String entity,
      Map<String, dynamic> input,
    );

/// The harness's verdict.
enum DifferentialVerdict { pass, divergence, skipped, runnerError }

/// The contract-relevant dimension one output field is compared in.
enum DiffDimension {
  /// Field-name sets and type signatures (shape, not bytes).
  entityShape('entity shape'),

  /// State outcome fields — value parity.
  stateTransition('state transition'),

  /// Error taxonomy fields — kind parity + presence parity.
  errorKind('error kind');

  const DiffDimension(this.label);
  final String label;
}

/// One divergence, named: the four fields issue #1195 requires (input,
/// mock output, real output, contract clause) plus the classification.
class DifferentialRow {
  const DifferentialRow({
    required this.fixture,
    required this.field,
    required this.dimension,
    required this.clause,
    required this.input,
    required this.mockOutput,
    required this.realOutput,
    required this.detail,
  });

  /// The fixture's id.
  final String fixture;

  /// The output field that diverged.
  final String field;

  final DiffDimension dimension;

  /// The contract clause the row violates — the fixture's `clauses`
  /// entry, or the dimension's default parity statement.
  final String clause;

  /// The fixture's committed input (the replayed input).
  final Map<String, dynamic> input;

  /// The mock side's full output.
  final Map<String, dynamic> mockOutput;

  /// The real side's full output.
  final Map<String, dynamic> realOutput;

  /// Human-readable divergence rendering (names both sides).
  final String detail;

  /// The row's stable identity: `<fixture>/<field>`.
  String get id => '$fixture/$field';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'fixture': fixture,
    'field': field,
    'dimension': dimension.name,
    'clause': clause,
    'input': input,
    'mockOutput': mockOutput,
    'realOutput': realOutput,
    'detail': detail,
  };
}

/// The differential run's result.
class DifferentialHarnessResult {
  const DifferentialHarnessResult({
    required this.verdict,
    required this.threshold,
    required this.replayed,
    required this.compared,
    required this.rows,
    required this.fixturesDigest,
    this.error,
  });

  final DifferentialVerdict verdict;

  /// The threshold the gate enforced (from `.zfa.json`
  /// `tdd.realizeDifferentialThreshold`; default 0.0 — strict).
  final double threshold;

  /// Number of fixtures replayed through both sides (0 when skipped).
  final int replayed;

  /// Number of output fields compared across all fixtures.
  final int compared;

  /// The named divergence rows (sorted by (fixture, field)).
  final List<DifferentialRow> rows;

  /// sha256 over the sorted fixture files' sha256s — binds the fixture
  /// set into the receipt (`sha256:<hex>`).
  final String fixturesDigest;

  /// The runner-error detail, when the verdict is runner-error.
  final String? error;

  /// The overall divergence ratio: rows / compared fields.
  double get divergence => compared == 0 ? 0.0 : rows.length / compared;

  /// Compact rendering for the machine summary (0.5, 0.2, 0.0).
  String get divergenceLabel => _compact(divergence);

  static String _compact(double value) =>
      double.parse(value.toStringAsFixed(4)).toString();
}

/// The harness. One run replays every committed fixture under
/// `specs/<feature>/tdd/fixtures/` (the #832 commitment, the
/// `realize-diff.v1` shape: `{schema, id, input, mockOutput}`) through
/// both sides, diffs the contract projection, and writes the receipt.
class DifferentialHarness {
  const DifferentialHarness({
    required this.featureDir,
    required this.projectRoot,
    required RealizeFixtureDriver driver,
    required this.mode,
  }) : _driver = driver;

  /// The feature directory (`specs/<feature>`).
  final String featureDir;

  /// The target project root (`.zfa.json`, receipt-relative refs).
  final String projectRoot;

  /// The run's mode stamp: `embedded` (inside `zfa tdd realize`) or
  /// `diff-only` (the standalone replay) — recorded in the receipt.
  final String mode;

  final RealizeFixtureDriver _driver;

  /// Load the divergence threshold from `.zfa.json`
  /// (`tdd.realizeDifferentialThreshold`). Absent file or absent key →
  /// 0.0 (strict: any row blocks until consciously allowed).
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

  /// The state-transition field names (compared by value). Matched
  /// case-insensitively with `_`/camel spacing normalized away.
  static const _stateFields = <String>{
    'state',
    'status',
    'newstate',
    'currentstate',
    'nextstate',
    'prevstate',
    'previousstate',
    'fromstate',
    'tostate',
    'transition',
    'transitioned',
    'resultstate',
  };

  /// The error-kind field names (compared by value + presence parity).
  static const _errorFields = <String>{
    'error',
    'errorkind',
    'errorcode',
    'errortype',
    'failure',
    'failurekind',
    'failurecode',
    'failuretype',
  };

  static String _normalizeKey(String key) =>
      key.toLowerCase().replaceAll('_', '').replaceAll(' ', '');

  static DiffDimension _dimensionOf(String field) {
    final norm = _normalizeKey(field);
    if (_stateFields.contains(norm)) return DiffDimension.stateTransition;
    if (_errorFields.contains(norm)) return DiffDimension.errorKind;
    return DiffDimension.entityShape;
  }

  /// Run every committed fixture through both sides and diff the
  /// contract projection. Writes `tdd/differential-receipt.json`
  /// (always — skipped and runner-error are recorded, never silent).
  Future<DifferentialHarnessResult> run({
    required String entity,
    String adapter = '-',
  }) async {
    final fixturesDir = Directory(p.join(featureDir, 'tdd', 'fixtures'));
    final files = await _fixtureFiles(fixturesDir);
    final digest = await _fixturesDigest(files);
    final threshold = thresholdOf(projectRoot);

    if (files.isEmpty) {
      final skipped = DifferentialHarnessResult(
        verdict: DifferentialVerdict.skipped,
        threshold: threshold,
        replayed: 0,
        compared: 0,
        rows: const <DifferentialRow>[],
        fixturesDigest: digest,
      );
      await _writeReceipt(entity: entity, adapter: adapter, result: skipped);
      return skipped;
    }

    final rows = <DifferentialRow>[];
    var compared = 0;
    var completedFixtures = 0;
    for (final file in files) {
      final parsed = _parseFixture(file);
      if (parsed == null) {
        final failed = DifferentialHarnessResult(
          verdict: DifferentialVerdict.runnerError,
          threshold: threshold,
          replayed: completedFixtures,
          compared: compared,
          rows: rows,
          fixturesDigest: digest,
          error:
              'fixture ${p.basename(file.path)} could not execute '
              'through both sides — see the driver protocol in the '
              'realize command docs.',
        );
        await _writeReceipt(entity: entity, adapter: adapter, result: failed);
        return failed;
      }
      final run = await _runFixture(parsed, entity);
      compared += run.compared;
      if (run.error != null) {
        final failed = DifferentialHarnessResult(
          verdict: DifferentialVerdict.runnerError,
          threshold: threshold,
          replayed: completedFixtures,
          compared: compared,
          rows: rows,
          fixturesDigest: digest,
          error: run.error,
        );
        await _writeReceipt(entity: entity, adapter: adapter, result: failed);
        return failed;
      }
      completedFixtures++;
      rows.addAll(run.rows);
    }
    rows.sort((a, b) {
      final byFixture = a.fixture.compareTo(b.fixture);
      return byFixture != 0 ? byFixture : a.field.compareTo(b.field);
    });

    final divergence = compared == 0 ? 0.0 : rows.length / compared;
    final result = DifferentialHarnessResult(
      verdict: divergence <= threshold
          ? DifferentialVerdict.pass
          : DifferentialVerdict.divergence,
      threshold: threshold,
      replayed: completedFixtures,
      compared: compared,
      rows: rows,
      fixturesDigest: digest,
    );
    await _writeReceipt(entity: entity, adapter: adapter, result: result);
    return result;
  }

  /// The committed `.json` fixture files in document (sorted-path)
  /// order — the replay order that makes the receipt byte-stable.
  Future<List<File>> _fixtureFiles(Directory fixturesDir) async {
    if (!await fixturesDir.exists()) return const <File>[];
    final files =
        fixturesDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  /// sha256 over the sorted fixture files' sha256s — the fixture-set
  /// binding that makes replayability provable, not asserted.
  Future<String> _fixturesDigest(List<File> files) async {
    final hashes = <String>[];
    for (final file in files) {
      hashes.add(crypto.sha256.convert(await file.readAsBytes()).toString());
    }
    return 'sha256:'
        '${crypto.sha256.convert(utf8.encode(hashes.join('\n')))}';
  }

  _ParsedFixture? _parseFixture(File file) {
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) return null;
      final input = decoded['input'];
      if (input is! Map<String, dynamic>) return null;
      final id = decoded['id'];
      if (id != null && id is! String) return null;
      final clauses = decoded['clauses'];
      if (clauses != null && clauses is! Map<String, dynamic>) return null;
      final contract = decoded['contract'];
      if (contract != null && contract is! Map<String, dynamic>) return null;
      return _ParsedFixture(
        id: (id as String?) ?? p.basenameWithoutExtension(file.path),
        input: input,
        mockOutput: decoded['mockOutput'],
        clauses: clauses as Map<String, dynamic>?,
        contract: contract as Map<String, dynamic>?,
      );
    } on FormatException {
      return null;
    }
  }

  /// Replay one fixture: mock side first (the recorded certified
  /// output, driver fallback), then the real side; diff the contract
  /// projection. [error] carries the driver failure detail (the
  /// runner-error class — the gate fails closed); rows are null-safe
  /// empty alongside it.
  Future<({List<DifferentialRow> rows, int compared, String? error})>
  _runFixture(_ParsedFixture fixture, String entity) async {
    Map<String, dynamic> mockOut;
    final recorded = fixture.mockOutput;
    if (recorded is Map<String, dynamic>) {
      mockOut = recorded;
    } else {
      try {
        mockOut = await _driver('mock', entity, fixture.input);
      } on Object catch (e) {
        return (
          rows: const <DifferentialRow>[],
          compared: 0,
          error:
              'fixture "${fixture.id}" mock side failed at the '
              'driver level: $e',
        );
      }
    }
    Map<String, dynamic> realOut;
    try {
      realOut = await _driver('real', entity, fixture.input);
    } on Object catch (e) {
      return (
        rows: const <DifferentialRow>[],
        compared: 0,
        error:
            'fixture "${fixture.id}" real side failed at the '
            'driver level: $e',
      );
    }

    final keys = <String>{...mockOut.keys, ...realOut.keys}.toList()..sort();

    final rows = <DifferentialRow>[];
    for (final key in keys) {
      final row = _compareField(fixture, key, mockOut, realOut);
      if (row != null) rows.add(row);
    }
    return (rows: rows, compared: keys.length, error: null);
  }

  /// Compare one output field in its dimension (or the fixture's pinned
  /// mode); null when the field agrees.
  DifferentialRow? _compareField(
    _ParsedFixture fixture,
    String field,
    Map<String, dynamic> mockOut,
    Map<String, dynamic> realOut,
  ) {
    final dimension = _dimensionOf(field);
    final pinned = _pinnedMode(fixture.contract, field);
    final valueParity = pinned ?? dimension != DiffDimension.entityShape;

    final inMock = mockOut.containsKey(field);
    final inReal = realOut.containsKey(field);
    final clause = _clauseFor(fixture, field, dimension);

    String? detail;
    if (!inMock || !inReal) {
      detail =
          'field "$field" only on the '
          '${inMock ? 'mock' : 'real'} side (one side is silent — '
          'presence parity is contract)';
    } else if (valueParity) {
      final mockJson = jsonEncode(mockOut[field]);
      final realJson = jsonEncode(realOut[field]);
      if (mockJson == realJson) return null;
      detail =
          'field "$field" ${dimension == DiffDimension.entityShape ? 'value drifts (pinned to exact parity by the fixture '
                    'contract)' : '${dimension.label} drifts'} — '
          'mock $mockJson vs real $realJson';
    } else {
      final mockSig = _shapeSignature(mockOut[field]);
      final realSig = _shapeSignature(realOut[field]);
      if (mockSig == realSig) return null;
      detail =
          'field "$field" entity shape drifts — mock $mockSig vs real '
          '$realSig';
    }

    return DifferentialRow(
      fixture: fixture.id,
      field: field,
      dimension: dimension,
      clause: clause,
      input: fixture.input,
      mockOutput: mockOut,
      realOutput: realOut,
      detail: detail,
    );
  }

  /// The fixture's pinned comparison mode for one field:
  /// `{"<field>": "value"}` → true (exact parity), `"shape"` → false;
  /// null when the fixture pins nothing.
  static bool? _pinnedMode(Map<String, dynamic>? contract, String field) {
    if (contract == null) return null;
    final raw = contract[field];
    if (raw is String) {
      switch (raw.toLowerCase()) {
        case 'value':
          return true;
        case 'shape':
          return false;
      }
    }
    return null;
  }

  /// The row's contract clause: the fixture's `clauses` entry for the
  /// field, else the dimension's default parity statement.
  static String _clauseFor(
    _ParsedFixture fixture,
    String field,
    DiffDimension dimension,
  ) {
    final declared = fixture.clauses?[field];
    if (declared is String && declared.isNotEmpty) return declared;
    return '${dimension.label} parity on field "$field"';
  }

  /// The type-signature of one JSON value — the entity-shape lens
  /// (shape, not bytes: `42` and `43` are both `num`; `42` and `'42'`
  /// are not). List length and map key sets are shape.
  static String _shapeSignature(Object? value) {
    if (value == null) return 'null';
    if (value is bool) return 'bool';
    if (value is num) return 'num';
    if (value is String) return 'string';
    if (value is List) {
      if (value.isEmpty) return 'list[0]';
      final sigs = value.map(_shapeSignature).toSet().toList()..sort();
      return 'list[${value.length}]{${sigs.join('|')}}';
    }
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      final parts = [for (final k in keys) '$k:${_shapeSignature(value[k])}'];
      return 'map{${parts.join(',')}}';
    }
    return 'other';
  }

  /// The journal's gate_state lift (#1113): pass → green,
  /// divergence/runner-error → red (the gate fails closed), skipped →
  /// not_assessed.
  static String _gateState(DifferentialVerdict verdict) => switch (verdict) {
    DifferentialVerdict.pass => 'green',
    DifferentialVerdict.divergence => 'red',
    DifferentialVerdict.runnerError => 'red',
    DifferentialVerdict.skipped => 'not_assessed',
  };

  /// The receipt's project-relative fixture ref (POSIX, stable across
  /// machines — never an absolute path).
  String get _fixturesRef {
    final rel = p.relative(featureDir, from: projectRoot);
    return p.posix
        .joinAll(p.posix.split(p.posix.normalize(rel)))
        .replaceAll('\\', '/');
  }

  Future<void> _writeReceipt({
    required String entity,
    required String adapter,
    required DifferentialHarnessResult result,
  }) async {
    final fixturesRef = _fixturesRef;
    final report = <String, dynamic>{
      'schema': 'realize-diff-receipt.v1',
      'feature': p.basename(featureDir),
      'entity': entity,
      'adapter': adapter,
      'mode': mode,
      'verdict': result.verdict.name,
      'threshold': result.threshold,
      'divergence': double.parse(result.divergence.toStringAsFixed(6)),
      'fixtures': {'count': result.replayed, 'digest': result.fixturesDigest},
      'replayed': result.replayed,
      'compared': result.compared,
      'rows': [for (final row in result.rows) row.toJson()],
      if (result.error != null) 'error': result.error,
      'journal': {
        'gate_state': _gateState(result.verdict),
        'violations': [for (final row in result.rows) row.id],
        'refs': {
          'fixtures': '$fixturesRef/tdd/fixtures',
          'receipt': '$fixturesRef/tdd/differential-receipt.json',
        },
      },
    };
    final dir = Directory(p.join(featureDir, 'tdd'));
    await dir.create(recursive: true);
    await File(
      p.join(dir.path, 'differential-receipt.json'),
    ).writeAsString('${const JsonEncoder.withIndent('  ').convert(report)}\n');
  }
}

class _ParsedFixture {
  const _ParsedFixture({
    required this.id,
    required this.input,
    required this.mockOutput,
    this.clauses,
    this.contract,
  });

  final String id;
  final Map<String, dynamic> input;
  final Object? mockOutput;
  final Map<String, dynamic>? clauses;
  final Map<String, dynamic>? contract;
}
