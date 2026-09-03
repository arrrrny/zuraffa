/// The differential harness (bug #915): fixture parity between mock and
/// real adapters.
///
/// The landed #832 simulation infrastructure verifies fixture INTEGRITY
/// (SHA-256 manifests) but not schema COMPATIBILITY: nothing compares the
/// mock adapter's fixture shapes with the real adapter's actual response
/// shapes. When a behavior transitions MOCKED → REAL, the real adapter
/// may return data with different field names, types, or nesting — and
/// the contract test either fails silently (different shape) or passes
/// dishonestly (the mock was too shallow to catch the mismatch).
///
/// This library is the missing measuring stick, per the #915 remediation:
///
/// 1. **Fixture contract** — one committed fixture pair per adapter
///    contract, under `specs/<feature>/tdd/fixtures/<adapter-contract>/`
///    with `mock.json` (the mock adapter's source of responses) and
///    `real.json` (the recorded real-adapter responses), consumed by
///    BOTH the mock and the realize differential. Each side records its
///    operations (request key → response body) and the failure scenarios
///    it rehearses (`faults`: timeouts, 5xx, corrupted payloads).
/// 2. **Schema-parity checker** — compares the SHAPE of every recorded
///    response across both lanes (field names, leaf types, nesting,
///    list element shapes — never values: parity is shape, not bytes).
///    Drift is a NAMED verdict with the field-level path and both
///    sides' type names, exit class 2.
/// 3. **Fault-injection parity** — every fault scenario the mock
///    rehearses must have a real-lane counterpart (and vice versa), so
///    the failure scenarios are triggerable against both adapters in
///    the integration lane. Gated behind `--full` (the #915 hard
///    constraint: parity checks may be opt-in).
/// 4. **Corpus rollup** — per-adapter parity scores surfaced in corpus
///    reports (`corpus status` / `corpus audit`), reported never
///    invented: a feature with no committed contract fixtures has no
///    parity line and no score.
///
/// Zorphy type availability varies across adapters (a #915 hard
/// constraint), so the checker never REQUIRES type metadata: fixtures
/// MAY record a `zorphyType` provenance name, which is surfaced in
/// verdicts when present, but shape comparison is structural and works
/// for every adapter.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// The named parity verdicts.
enum ParityVerdict {
  /// Every recorded response has the same shape on both lanes.
  match,

  /// At least one named shape or fault drift exists.
  drift,

  /// The fixture pair is incomplete (a lane is missing or unreadable) —
  /// an infrastructure verdict, never a silent pass.
  incomplete,
}

/// One named drift: where the shapes diverge and what each side is.
final class ParityDrift {
  const ParityDrift(this.kind, this.path, this.mockSide, this.realSide);

  /// `field-drift` (present on one side only) or `type-drift`
  /// (present on both, different shape) or `fault-drift`.
  final String kind;

  /// The field-level path of the divergence, e.g.
  /// `operations.GET /v1/quote/USD-TRY.price`.
  final String path;

  /// The mock lane's shape (or `absent`).
  final String mockSide;

  /// The real lane's shape (or `absent`).
  final String realSide;

  @override
  String toString() => '$kind at $path: mock=$mockSide real=$realSide';
}

/// A committed fixture pair for one adapter contract.
final class AdapterContractFixtures {
  const AdapterContractFixtures({
    required this.contract,
    required this.mock,
    required this.real,
  });

  /// The adapter contract name (the fixtures directory name).
  final String contract;

  /// The mock lane's fixture (`mock.json`): operations + faults.
  final Map<String, dynamic> mock;

  /// The real lane's fixture (`real.json`): operations + faults.
  final Map<String, dynamic> real;

  /// Load the committed pair for [contract] from
  /// `<featureDir>/tdd/fixtures/<contract>/`. Throws
  /// [AdapterParityException] when a lane is missing or unreadable —
  /// the caller surfaces it as the `incomplete` verdict.
  static AdapterContractFixtures load(String featureDir, String contract) {
    Map<String, dynamic> read(String fileName) {
      final file = File(
        p.join(featureDir, 'tdd', 'fixtures', contract, fileName),
      );
      if (!file.existsSync()) {
        throw AdapterParityException(
          'missing $fileName for adapter contract "$contract" '
          '(expected ${file.path})',
        );
      }
      final Object? decoded;
      try {
        decoded = jsonDecode(file.readAsStringSync());
      } on FormatException catch (e) {
        throw AdapterParityException(
          '$fileName for adapter contract "$contract" is not valid JSON: '
          '${e.message}',
        );
      }
      if (decoded is! Map<String, dynamic>) {
        throw AdapterParityException(
          '$fileName for adapter contract "$contract" must be a JSON object',
        );
      }
      return decoded;
    }

    return AdapterContractFixtures(
      contract: contract,
      mock: read('mock.json'),
      real: read('real.json'),
    );
  }
}

/// Raised when a fixture pair cannot be loaded; [message] names the
/// contract and the missing/corrupt file.
class AdapterParityException implements Exception {
  const AdapterParityException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The parity report for one adapter contract.
final class ContractParityReport {
  const ContractParityReport({
    required this.contract,
    required this.verdict,
    this.detail,
    this.drifts = const [],
    this.faultDrifts = const [],
  });

  /// The adapter contract name.
  final String contract;

  /// The named verdict.
  final ParityVerdict verdict;

  /// The infrastructure reason for an `incomplete` verdict (names the
  /// missing/corrupt file), or the match confirmation.
  final String? detail;

  /// The named shape drifts (empty unless the verdict is drift).
  final List<ParityDrift> drifts;

  /// The named fault drifts (empty unless `--full` ran the fault gate).
  final List<ParityDrift> faultDrifts;

  /// The machine exit class: 0 match, 2 drift, 1 incomplete.
  int get exitCode => switch (verdict) {
    ParityVerdict.match => 0,
    ParityVerdict.drift => 2,
    ParityVerdict.incomplete => 1,
  };

  @override
  String toString() =>
      '$contract -> ${verdict.name}'
      '${detail == null ? '' : ' ($detail)'}';
}

/// The per-feature parity rollup (corpus rollup, remediation item 4).
final class ParityRollup {
  const ParityRollup({required this.reports});

  /// One report per committed adapter contract, sorted by name.
  final List<ContractParityReport> reports;

  /// The sorted contract names.
  List<String> get contracts => reports.map((r) => r.contract).toList();

  int get matched =>
      reports.where((r) => r.verdict == ParityVerdict.match).length;

  int get drifted =>
      reports.where((r) => r.verdict == ParityVerdict.drift).length;

  int get incomplete =>
      reports.where((r) => r.verdict == ParityVerdict.incomplete).length;

  /// The parity score: matched / committed contracts, `null` when the
  /// feature has no contract fixtures (never invented).
  double? get score => reports.isEmpty ? null : matched / reports.length;

  /// The machine summary line (no prefix — the surfacing command adds
  /// its own `parity:` label):
  /// `contracts=<n> matched=<n> drifted=<n> incomplete=<n> score=<s|->
  /// result=<match|drift|incomplete|no-contracts>`.
  String get summaryLine {
    if (reports.isEmpty) {
      return 'contracts=0 matched=0 drifted=0 incomplete=0 score=- '
          'result=no-contracts';
    }
    final result = drifted > 0
        ? 'drift'
        : incomplete > 0
        ? 'incomplete'
        : 'match';
    return 'contracts=${reports.length} matched=$matched drifted=$drifted '
        'incomplete=$incomplete score=${score!.toStringAsFixed(2)} '
        'result=$result';
  }
}

/// The schema-parity checker + fault-injection parity + corpus rollup
/// (bug #915 remediation items 2-4).
abstract final class AdapterParityChecker {
  /// Check one adapter contract's committed fixture pair. When [full]
  /// is set, ALSO runs the fault-injection parity gate (the opt-in hard
  /// constraint: the expensive/burdensome parts of the parity harness
  /// stay behind `--full`).
  static ContractParityReport checkContract(
    String featureDir,
    String contract, {
    bool full = false,
  }) {
    final AdapterContractFixtures fixtures;
    try {
      fixtures = AdapterContractFixtures.load(featureDir, contract);
    } on AdapterParityException catch (e) {
      return ContractParityReport(
        contract: contract,
        verdict: ParityVerdict.incomplete,
        detail: e.message,
      );
    }

    final drifts = <ParityDrift>[];
    _compareOperations(fixtures, drifts);
    final faultDrifts = <ParityDrift>[];
    if (full) _compareFaults(fixtures, faultDrifts);

    if (drifts.isEmpty && faultDrifts.isEmpty) {
      final zorphy = fixtures.mock['zorphyType'] ?? fixtures.real['zorphyType'];
      return ContractParityReport(
        contract: contract,
        verdict: ParityVerdict.match,
        detail: zorphy == null
            ? 'shapes match across mock and real lanes'
            : 'shapes match across mock and real lanes '
                  '(zorphyType: $zorphy)',
      );
    }
    return ContractParityReport(
      contract: contract,
      verdict: ParityVerdict.drift,
      detail:
          '${drifts.length} shape drift(s), '
          '${faultDrifts.length} fault drift(s)',
      drifts: drifts,
      faultDrifts: faultDrifts,
    );
  }

  /// Every committed adapter contract under [featureDir] (a fixtures
  /// subdirectory carrying at least one fixture lane), sorted.
  static List<String> discoverContracts(String featureDir) {
    final root = Directory(p.join(featureDir, 'tdd', 'fixtures'));
    if (!root.existsSync()) return const [];
    final names = <String>[];
    for (final entity in root.listSync()) {
      if (entity is! Directory) continue;
      final hasLane =
          File(p.join(entity.path, 'mock.json')).existsSync() ||
          File(p.join(entity.path, 'real.json')).existsSync();
      if (hasLane) names.add(p.basename(entity.path));
    }
    return names..sort();
  }

  /// The corpus rollup for [featureDir]: one report per committed
  /// adapter contract, sorted by name.
  static ParityRollup rollupForFeature(String featureDir) => ParityRollup(
    reports: [
      for (final contract in discoverContracts(featureDir))
        checkContract(featureDir, contract),
    ],
  );

  /// The feature directories under `<projectRoot>/specs/` that carry at
  /// least one committed adapter contract, sorted by feature name.
  static List<String> discoverFeaturesWithContracts(String projectRoot) {
    final specs = Directory(p.join(projectRoot, 'specs'));
    if (!specs.existsSync()) return const [];
    final names = <String>[];
    for (final entity in specs.listSync()) {
      if (entity is! Directory) continue;
      if (discoverContracts(entity.path).isNotEmpty) {
        names.add(p.basename(entity.path));
      }
    }
    return names..sort();
  }

  // -----------------------------------------------------------------
  // Shape comparison (structural, value-blind).
  // -----------------------------------------------------------------

  static void _compareOperations(
    AdapterContractFixtures fixtures,
    List<ParityDrift> drifts,
  ) {
    final mockOps =
        (fixtures.mock['operations'] as Map<String, dynamic>? ?? const {})
            .cast<String, dynamic>();
    final realOps =
        (fixtures.real['operations'] as Map<String, dynamic>? ?? const {})
            .cast<String, dynamic>();
    final keys = {...mockOps.keys, ...realOps.keys}.toList()..sort();
    for (final key in keys) {
      final mockBody = mockOps[key];
      final realBody = realOps[key];
      if (!mockOps.containsKey(key) || !realOps.containsKey(key)) {
        drifts.add(
          ParityDrift(
            'field-drift',
            'operations.$key',
            mockOps.containsKey(key) ? encodeShape(mockBody) : 'absent',
            realOps.containsKey(key) ? encodeShape(realBody) : 'absent',
          ),
        );
        continue;
      }
      _compareShape('operations.$key', mockBody, realBody, drifts);
    }
  }

  static void _compareShape(
    String path,
    Object? mockValue,
    Object? realValue,
    List<ParityDrift> drifts,
  ) {
    final mockShape = encodeShape(mockValue);
    final realShape = encodeShape(realValue);
    if (mockShape == realShape) return;
    // Objects: name the per-field divergence instead of the whole object.
    if (mockValue is Map && realValue is Map) {
      _compareObject(path, mockValue, realValue, drifts);
      return;
    }
    // Lists: compare the merged element shape.
    if (mockValue is List && realValue is List) {
      final mockElement = _mergedElementShape(mockValue);
      final realElement = _mergedElementShape(realValue);
      if (mockElement == realElement) return;
      drifts.add(
        ParityDrift(
          'type-drift',
          '$path[]',
          'list<$mockElement>',
          'list<$realElement>',
        ),
      );
      return;
    }
    drifts.add(ParityDrift('type-drift', path, mockShape, realShape));
  }

  static void _compareObject(
    String path,
    Map mock,
    Map real,
    List<ParityDrift> drifts,
  ) {
    final fields = {...mock.keys, ...real.keys}.toList()..sort();
    for (final field in fields) {
      final mockHas = mock.containsKey(field);
      final realHas = real.containsKey(field);
      if (!mockHas && !realHas) continue;
      final fieldPath = '$path.$field';
      if (!mockHas || !realHas) {
        drifts.add(
          ParityDrift(
            'field-drift',
            fieldPath,
            mockHas ? encodeShape(mock[field]) : 'absent',
            realHas ? encodeShape(real[field]) : 'absent',
          ),
        );
        continue;
      }
      _compareShape(fieldPath, mock[field], real[field], drifts);
    }
  }

  /// The structural shape encoding of a JSON value — the parity
  /// contract's type language. Leaf types render as their names
  /// (`string`, `number`, `bool`, `null`); int and double are the SAME
  /// type (`number`), so 41 vs 41.2 is never false drift. Objects
  /// render as `object{field:shape,...}` with sorted fields; lists as
  /// `list<element>` where the element shape is merged across the
  /// recorded elements (an empty list records `list<empty>` — the lane
  /// recorded no elements to prove parity with).
  static String encodeShape(Object? value) => switch (value) {
    null => 'null',
    bool() => 'bool',
    num() => 'number',
    String() => 'string',
    List() => 'list<${_mergedElementShape(value)}>',
    Map() => 'object{${_objectFields(value)}}',
    _ => value.toString(),
  };

  static String _objectFields(Map value) {
    final fields = value.keys.toList()..sort();
    return [
      for (final field in fields) '$field:${encodeShape(value[field])}',
    ].join(',');
  }

  /// The merged element shape of a list's recorded elements: identical
  /// element shapes collapse; a heterogeneous list merges its object
  /// fields (union, conflicting types become `mixed`).
  static String _mergedElementShape(List elements) {
    if (elements.isEmpty) return 'empty';
    var merged = encodeShape(elements.first);
    for (final element in elements.skip(1)) {
      merged = _mergeShapes(merged, encodeShape(element));
    }
    return merged;
  }

  static String _mergeShapes(String a, String b) {
    if (a == b) return a;
    if (a == 'empty' || a == 'list<empty>') return b;
    if (b == 'empty' || b == 'list<empty>') return a;
    if (a.startsWith('list<') &&
        a.endsWith('>') &&
        b.startsWith('list<') &&
        b.endsWith('>')) {
      return 'list<${_mergeShapes(a.substring(5, a.length - 1), b.substring(5, b.length - 1))}>';
    }
    if (a.startsWith('object{') && b.startsWith('object{')) {
      final aFields = _splitFields(a.substring(7, a.length - 1));
      final bFields = _splitFields(b.substring(7, b.length - 1));
      final merged = <String, String>{...aFields};
      for (final entry in bFields.entries) {
        merged[entry.key] = merged.containsKey(entry.key)
            ? _mergeShapes(merged[entry.key]!, entry.value)
            : entry.value;
      }
      final fields = merged.keys.toList()..sort();
      return 'object{${[for (final f in fields) '$f:${merged[f]}'].join(',')}}';
    }
    return 'mixed';
  }

  /// Split a comma-separated `field:shape` list back into pairs,
  /// respecting nested braces (shapes themselves contain commas).
  static Map<String, String> _splitFields(String body) {
    final out = <String, String>{};
    if (body.isEmpty) return out;
    var depth = 0;
    final parts = <String>[];
    var current = StringBuffer();
    for (final char in body.split('')) {
      if (char == '{') depth++;
      if (char == '}') depth--;
      if (char == ',' && depth == 0) {
        parts.add(current.toString());
        current = StringBuffer();
        continue;
      }
      current.write(char);
    }
    parts.add(current.toString());
    for (final part in parts) {
      final colon = part.indexOf(':');
      if (colon <= 0) continue;
      out[part.substring(0, colon)] = part.substring(colon + 1);
    }
    return out;
  }

  // -----------------------------------------------------------------
  // Fault-injection parity.
  // -----------------------------------------------------------------

  static void _compareFaults(
    AdapterContractFixtures fixtures,
    List<ParityDrift> drifts,
  ) {
    final mockFaults =
        (fixtures.mock['faults'] as Map<String, dynamic>? ?? const {})
            .cast<String, dynamic>();
    final realFaults =
        (fixtures.real['faults'] as Map<String, dynamic>? ?? const {})
            .cast<String, dynamic>();
    final kinds = {...mockFaults.keys, ...realFaults.keys}.toList()..sort();
    for (final kind in kinds) {
      final inMock = mockFaults.containsKey(kind);
      final inReal = realFaults.containsKey(kind);
      if (inMock && inReal) continue;
      drifts.add(
        ParityDrift(
          'fault-drift',
          'faults.$kind',
          inMock ? _faultSurface(mockFaults[kind]) : 'absent',
          inReal ? _faultSurface(realFaults[kind]) : 'absent',
        ),
      );
    }
  }

  /// How a fault scenario is surfaced on a lane (its kind, plus the
  /// status for HTTP faults) — the scenario the lane can trigger.
  static String _faultSurface(Object? fault) {
    if (fault is Map<String, dynamic>) {
      final kind = fault['kind'] ?? 'unknown';
      final status = fault['status'];
      return status == null ? '$kind' : '$kind($status)';
    }
    return fault?.toString() ?? 'unknown';
  }
}
