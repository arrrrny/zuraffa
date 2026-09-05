/// The world manifest model (spec 968, VISION §9 simulation worlds).
///
/// A **world** is a versioned, committed scenario manifest composing
/// certified mocks into a coherent simulated reality with time, latency,
/// and failure semantics. The manifest lives at
/// `specs/<feature>/tdd/worlds/<scenario>.world.json` — committed,
/// diffable, and CI-verifiable (`zfa simulate verify-world`).
///
/// The manifest declares:
/// - **touchpoints** — which certified mocks participate, scaffolded from
///   the spec's declared External Dependencies & Contracts table (issue
///   #960's output, consumed by `zfa simulate init`)
/// - **time model** — virtual clock seed (deterministic)
/// - **latency model** — banded distributions per touchpoint
///   (fast/slow/timeout, never wall time)
/// - **failure schedule** — failure storms: auth expiry mid-flow, network
///   flaps, partial writes
/// - **corpus** — the golden fixture table the world serves per declared
///   contract method
/// - **behaviors** — the scenario's executable program (the temporal
///   behaviors `zfa simulate run` drives through the world)
///
/// The **world hash** is the SHA-256 of the canonical JSON encoding
/// (recursively sorted keys) of the manifest document: deterministic,
/// byte-sensitive, and stable across re-serializations — every green run
/// receipt names it, so every green is attributable to a world version.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import 'world_utils.dart';

/// Raised when a world manifest is structurally invalid. The message
/// carries the machine-actionable `--> fix:` line (errors-are-an-API).
final class WorldManifestError implements Exception {
  const WorldManifestError(this.message);

  final String message;

  @override
  String toString() => 'WorldManifestError: $message';
}

/// One parsed contract method: `signIn(email, password) -> User`.
final class ContractMethod {
  const ContractMethod({
    required this.name,
    required this.params,
    required this.returns,
  });

  final String name;
  final List<String> params;

  /// The declared return type name (`User`, `void`, `SyncResult`, ...).
  final String returns;

  Map<String, dynamic> toJson() => {
    'name': name,
    'params': params,
    'returns': returns,
  };

  factory ContractMethod.fromJson(Map<String, dynamic> json) => ContractMethod(
    name: json['name'] as String,
    params: (json['params'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(growable: false),
    returns: json['returns'] as String,
  );

  @override
  bool operator ==(Object other) =>
      other is ContractMethod &&
      other.name == name &&
      other.params.join(',') == params.join(',') &&
      other.returns == returns;

  @override
  int get hashCode => Object.hash(name, params.join(','), returns);

  @override
  String toString() => '$name(${params.join(', ')}) -> $returns';
}

/// Parses declared dependency contract strings into [ContractMethod] pins.
///
/// The declared table's contract cell (issue #960) is a comma-separated
/// method list: `signIn(email, password) -> User, signOut() -> void`.
abstract final class ContractParser {
  static final RegExp _method = RegExp(
    r'([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*)\)\s*(?:->|→)\s*([A-Za-z_][A-Za-z0-9_]*)',
  );

  /// Parse [contract] into ordered method pins. Throws
  /// [WorldManifestError] (with the fix hint) when nothing parses — a
  /// declared row without at least one parsable method cannot become a
  /// touchpoint.
  static List<ContractMethod> parse(String contract) {
    final methods = <ContractMethod>[];
    for (final match in _method.allMatches(contract)) {
      final params = match
          .group(2)!
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .map((p) => p.split(':').first.trim())
          .toList(growable: false);
      methods.add(
        ContractMethod(
          name: match.group(1)!,
          params: params,
          returns: match.group(3)!,
        ),
      );
    }
    if (methods.isEmpty) {
      throw WorldManifestError(
        'contract "$contract" has no parsable methods — expected '
        '"name(params) -> Return, name2() -> void" '
        '--> fix: declare the contract row as method signatures.',
      );
    }
    return methods;
  }
}

/// One touchpoint: a declared external dependency participating in the
/// world, with its contract methods and simulation semantics.
final class WorldTouchpoint {
  const WorldTouchpoint({
    required this.name,
    required this.type,
    required this.family,
    required this.priority,
    required this.contract,
    required this.methods,
  });

  /// The declared dependency name (`FirebaseAuth`, `RestSync`).
  final String name;

  /// The declared type (`service`, `storage`, `channel`, ...).
  final String type;

  /// The simulation family: `firebase-auth` composes the #832 certified
  /// `FirebaseAuthAdapter`; everything else is `generic`
  /// (corpus-served).
  final String family;

  /// The declared mock priority (`P1`/`P2`/`P3`).
  final String priority;

  /// The raw declared contract string (provenance for certification).
  final String contract;

  /// The parsed contract method pins.
  final List<ContractMethod> methods;

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'family': family,
    'priority': priority,
    'contract': contract,
    'methods': [for (final m in methods) m.toJson()],
  };

  factory WorldTouchpoint.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String?;
    if (name == null || name.isEmpty) {
      throw const WorldManifestError(
        'touchpoint without a name --> fix: every touchpoints[] entry '
        'needs a non-empty "name".',
      );
    }
    final contract = json['contract'] as String? ?? '';
    final methods = (json['methods'] as List? ?? const [])
        .map(
          (m) => ContractMethod.fromJson(Map<String, dynamic>.from(m as Map)),
        )
        .toList(growable: false);
    if (methods.isEmpty) {
      throw WorldManifestError(
        'touchpoint "$name" declares no contract methods '
        '--> fix: parse the contract first or declare methods[] — a '
        'world touchpoint without methods has no contract to satisfy.',
      );
    }
    return WorldTouchpoint(
      name: name,
      type: json['type'] as String? ?? 'service',
      family: json['family'] as String? ?? 'generic',
      priority: json['priority'] as String? ?? 'P2',
      contract: contract,
      methods: methods,
    );
  }
}

/// The latency model for one touchpoint: banded distributions
/// (fast/slow/timeout) with deterministic band selection. Latency is
/// VIRTUAL time — the world advances its clock, never wall time.
final class WorldLatencyBands {
  const WorldLatencyBands({
    required this.fastMinMs,
    required this.fastMaxMs,
    required this.slowMinMs,
    required this.slowMaxMs,
    required this.timeoutMinMs,
    required this.timeoutMaxMs,
    required this.slowEvery,
    required this.timeoutEvery,
  });

  /// The fast band bounds (milliseconds, inclusive).
  final int fastMinMs;
  final int fastMaxMs;

  /// The slow band bounds.
  final int slowMinMs;
  final int slowMaxMs;

  /// The timeout band bounds.
  final int timeoutMinMs;
  final int timeoutMaxMs;

  /// Every Nth call (1-based modulo) samples the slow band; 0 disables.
  final int slowEvery;

  /// Every Nth call samples the timeout band; 0 disables.
  final int timeoutEvery;

  /// The certified default: fast 5–15 ms, slow 120–400 ms every 4th
  /// call, timeout 800–1500 ms every 25th call.
  static const WorldLatencyBands certified = WorldLatencyBands(
    fastMinMs: 5,
    fastMaxMs: 15,
    slowMinMs: 120,
    slowMaxMs: 400,
    timeoutMinMs: 800,
    timeoutMaxMs: 1500,
    slowEvery: 4,
    timeoutEvery: 25,
  );

  Map<String, dynamic> toJson() => {
    'fast': [fastMinMs, fastMaxMs],
    'slow': [slowMinMs, slowMaxMs],
    'timeout': [timeoutMinMs, timeoutMaxMs],
    'slowEvery': slowEvery,
    'timeoutEvery': timeoutEvery,
  };

  factory WorldLatencyBands.fromJson(Map<String, dynamic> json) {
    List<int> pair(String key, List<int> fallback) {
      final raw = json[key];
      if (raw is List && raw.length == 2) {
        return [(raw[0] as num).toInt(), (raw[1] as num).toInt()];
      }
      return fallback;
    }

    final fast = pair('fast', const [5, 15]);
    final slow = pair('slow', const [120, 400]);
    final timeout = pair('timeout', const [800, 1500]);
    final slowEvery = (json['slowEvery'] as num?)?.toInt() ?? 4;
    final timeoutEvery = (json['timeoutEvery'] as num?)?.toInt() ?? 25;
    return WorldLatencyBands(
      fastMinMs: fast[0],
      fastMaxMs: fast[1],
      slowMinMs: slow[0],
      slowMaxMs: slow[1],
      timeoutMinMs: timeout[0],
      timeoutMaxMs: timeout[1],
      slowEvery: slowEvery < 0 ? 0 : slowEvery,
      timeoutEvery: timeoutEvery < 0 ? 0 : timeoutEvery,
    );
  }
}

/// One failure storm: a named window of scripted failures on one
/// touchpoint. Kinds (the issue's storm classes):
/// - `network-flap` — HTTP failures (default status 503) over a call
///   range: calls [fromCall, toCall] fail.
/// - `auth-expiry` — an auth failure mid-flow (single call by default,
///   code `user-token-expired`).
/// - `partial-write` — a half-written marker (the write "succeeds" but
///   the response carries `partial: true`, which honest syncs must
///   detect and repair).
final class WorldStorm {
  const WorldStorm({
    required this.name,
    required this.kind,
    required this.touchpoint,
    required this.fromCall,
    required this.toCall,
    required this.failure,
    required this.description,
    this.method,
  });

  final String name;
  final String kind;
  final String touchpoint;

  /// Optional method scoping: the storm fires only on [touchpoint]'s
  /// [method] (null = every method of the touchpoint shares the call
  /// window). Scoping is how mid-flow storms stay surgical — an auth
  /// expiry at `signIn` call 1 must not also fail `signOut`.
  final String? method;

  /// First call index (1-based) the storm fires on.
  final int fromCall;

  /// Last call index the storm fires on (defaults to [fromCall]).
  final int toCall;

  /// The scripted failure payload: `{type: http, status: 503}` /
  /// `{type: auth, code: user-token-expired}` / `{type: partial}`.
  final Map<String, dynamic> failure;

  final String description;

  /// The storm's failure classification label.
  String get failureKind => failure['type'] as String? ?? kind;

  Map<String, dynamic> toJson() => {
    'name': name,
    'kind': kind,
    'touchpoint': touchpoint,
    if (method != null) 'method': method,
    'fromCall': fromCall,
    'toCall': toCall,
    'failure': failure,
    'description': description,
  };

  factory WorldStorm.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';
    final kind = json['kind'] as String? ?? '';
    final touchpoint = json['touchpoint'] as String? ?? '';
    if (name.isEmpty || touchpoint.isEmpty) {
      throw const WorldManifestError(
        'storm without a name/touchpoint --> fix: every storms[] entry '
        'needs "name", "kind", and "touchpoint".',
      );
    }
    final fromCall = (json['fromCall'] as num?)?.toInt() ?? 1;
    var toCall = (json['toCall'] as num?)?.toInt() ?? fromCall;
    if (toCall < fromCall) toCall = fromCall;
    return WorldStorm(
      name: name,
      kind: kind,
      touchpoint: touchpoint,
      method: json['method'] as String?,
      fromCall: fromCall,
      toCall: toCall,
      failure: Map<String, dynamic>.from(
        json['failure'] as Map? ?? const <String, dynamic>{},
      ),
      description: json['description'] as String? ?? '',
    );
  }

  /// Whether the storm fires on [callIndex] (1-based).
  bool firesOn(int callIndex) => callIndex >= fromCall && callIndex <= toCall;
}

/// One executable behavior in the scenario program. Drivers:
/// - `retry-sync` — the temporal retry-with-backoff driver (the shipped
///   `RetrySyncEngine` semantics): attempts the touchpoint method with
///   the declared retry policy; backoff waits advance VIRTUAL time.
/// - `invoke` — a single contract invocation (failures surface
///   honestly).
///
/// [WorldBehavior.expect] makes failure-storm scenarios first-class
/// red→green behaviors: `green` (default) requires the behavior to
/// succeed; `red` requires the honest failure surface (e.g. auth expiry
/// mid-flow must surface red — a blindly-retrying engine would turn
/// green there and the run goes red: the world refuses free greens in
/// BOTH directions).
final class WorldBehavior {
  const WorldBehavior({
    required this.id,
    required this.driver,
    required this.touchpoint,
    required this.method,
    required this.args,
    required this.maxAttempts,
    this.backoffBaseMs = 50,
    this.backoffFactor = 2.0,
    this.expect = 'green',
  });

  final String id;
  final String driver;
  final String touchpoint;
  final String method;
  final Map<String, dynamic> args;

  /// Retry budget for the `retry-sync` driver.
  final int maxAttempts;

  /// First backoff wait (virtual ms) for the `retry-sync` driver.
  final int backoffBaseMs;

  /// Exponential factor: wait_n = base * factor^(n-1).
  final double backoffFactor;

  /// The expected verdict: `green` (default) or `red` (the honest
  /// failure surface — the failure-storm behaviors).
  final String expect;

  /// Whether this behavior is expected to land RED (the honest failure
  /// surface class).
  bool get expectRed => expect == 'red';

  Map<String, dynamic> toJson() => {
    'id': id,
    'driver': driver,
    'touchpoint': touchpoint,
    'method': method,
    'args': args,
    'maxAttempts': maxAttempts,
    'backoffBaseMs': backoffBaseMs,
    'backoffFactor': backoffFactor,
    'expect': expect,
  };

  factory WorldBehavior.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final touchpoint = json['touchpoint'] as String? ?? '';
    final method = json['method'] as String? ?? '';
    if (id.isEmpty || touchpoint.isEmpty || method.isEmpty) {
      throw const WorldManifestError(
        'behavior without id/touchpoint/method --> fix: every behaviors[] '
        'entry needs "id", "driver", "touchpoint", and "method".',
      );
    }
    return WorldBehavior(
      id: id,
      driver: json['driver'] as String? ?? 'invoke',
      touchpoint: touchpoint,
      method: method,
      args: Map<String, dynamic>.from(
        json['args'] as Map? ?? const <String, dynamic>{},
      ),
      maxAttempts: (json['maxAttempts'] as num?)?.toInt() ?? 3,
      backoffBaseMs: (json['backoffBaseMs'] as num?)?.toInt() ?? 50,
      backoffFactor: (json['backoffFactor'] as num?)?.toDouble() ?? 2.0,
      expect: json['expect'] as String? ?? 'green',
    );
  }
}

/// The world manifest (schema 1).
final class WorldManifest {
  const WorldManifest({
    required this.schema,
    required this.spec,
    required this.scenario,
    required this.feature,
    required this.version,
    required this.seed,
    required this.touchpoints,
    required this.latency,
    required this.storms,
    required this.corpus,
    required this.behaviors,
    required this.description,
  });

  static const int schemaVersion = 1;
  static const int specNumber = 968;

  final int schema;
  final int spec;

  /// The scenario name (`checkout-flow`) — the `--scenario` key.
  final String scenario;

  /// The owning feature slug (`968-simulation-worlds`).
  final String feature;

  /// The world's version (bump when the world's reality changes).
  final int version;

  /// The deterministic time-model seed: same seed + same manifest →
  /// identical virtual time, identical latency draws, identical runs.
  final int seed;

  final List<WorldTouchpoint> touchpoints;

  /// Latency bands per touchpoint name.
  final Map<String, WorldLatencyBands> latency;

  /// The failure schedule (storms).
  final List<WorldStorm> storms;

  /// The golden corpus: fixture responses per touchpoint per method.
  final Map<String, Map<String, dynamic>> corpus;

  /// The scenario's executable behavior program.
  final List<WorldBehavior> behaviors;

  final String description;

  /// The touchpoint with [name], or `null`.
  WorldTouchpoint? touchpointNamed(String name) {
    for (final t in touchpoints) {
      if (t.name == name) return t;
    }
    return null;
  }

  /// The corpus fixture [touchpoint]'s [method] serves, when declared.
  dynamic corpusFixture(String touchpoint, String method) =>
      corpus[touchpoint]?[method]?['fixture'];

  /// The corpus failure entry for [touchpoint]'s [method], when the
  /// corpus itself scripts the failure (fixture-table-level faults,
  /// distinct from the storm schedule).
  Map<String, dynamic>? corpusFailure(String touchpoint, String method) {
    final entry = corpus[touchpoint]?[method];
    if (entry == null) return null;
    final failure = entry['failure'];
    if (failure is Map<String, dynamic>) return failure;
    if (failure is Map) return Map<String, dynamic>.from(failure);
    return null;
  }

  Map<String, dynamic> toDocument() => {
    'schema': schema,
    'spec': spec,
    'scenario': scenario,
    'feature': feature,
    'version': version,
    'description': description,
    'time': {'seed': seed},
    'touchpoints': [for (final t in touchpoints) t.toJson()],
    'latency': {for (final e in latency.entries) e.key: e.value.toJson()},
    'failureSchedule': {
      'storms': [for (final s in storms) s.toJson()],
    },
    'corpus': corpus,
    'behaviors': [for (final b in behaviors) b.toJson()],
  };

  /// The canonical JSON encoding: every map's keys sorted recursively,
  /// stable 2-space indent, so git diffs are minimal and the encoding is
  /// a pure function of the manifest's VALUE (not its construction
  /// order).
  String toCanonicalJson() =>
      const JsonEncoder.withIndent('  ').convert(canonical(toDocument()));

  /// The world hash: SHA-256 of the canonical encoding (compact form —
  /// hashing ignores indentation so hand-formatting never lies).
  String get worldHash => crypto.sha256
      .convert(utf8.encode(jsonEncode(canonical(toDocument()))))
      .toString();

  /// Serialize to the committed, diffable document bytes.
  String toFileContents() => '${toCanonicalJson()}\n';

  /// Parse a manifest document. Throws [WorldManifestError] (with fix
  /// hints) on structural violations.
  factory WorldManifest.fromDocument(Map<String, dynamic> doc) {
    final schema = (doc['schema'] as num?)?.toInt() ?? 0;
    if (schema != schemaVersion) {
      throw WorldManifestError(
        'world manifest schema $schema is not $schemaVersion '
        '--> fix: regenerate the world with `zfa simulate init`.',
      );
    }
    final scenario = doc['scenario'] as String? ?? '';
    if (scenario.isEmpty) {
      throw const WorldManifestError(
        'world manifest without a scenario name --> fix: set "scenario" '
        '(the `zfa simulate --scenario` key).',
      );
    }
    final touchpoints = (doc['touchpoints'] as List? ?? const [])
        .map(
          (t) => WorldTouchpoint.fromJson(Map<String, dynamic>.from(t as Map)),
        )
        .toList(growable: false);
    if (touchpoints.isEmpty) {
      throw WorldManifestError(
        'world "$scenario" declares no touchpoints --> fix: declare the '
        'dependency rows (External Dependencies table) and re-run '
        '`zfa simulate init $scenario`.',
      );
    }
    final storms =
        (((doc['failureSchedule'] as Map<String, dynamic>? ??
                        const <String, dynamic>{})['storms']
                    as List? ??
                const [])
            .map(
              (s) => WorldStorm.fromJson(Map<String, dynamic>.from(s as Map)),
            )
            .toList(growable: false));
    final behaviors = (doc['behaviors'] as List? ?? const [])
        .map((b) => WorldBehavior.fromJson(Map<String, dynamic>.from(b as Map)))
        .toList(growable: false);
    final latency = <String, WorldLatencyBands>{};
    final latencyDoc = doc['latency'] as Map? ?? const {};
    for (final entry in latencyDoc.entries) {
      final value = entry.value;
      if (value is Map) {
        latency[entry.key.toString()] = WorldLatencyBands.fromJson(
          Map<String, dynamic>.from(value),
        );
      }
    }
    final corpus = <String, Map<String, dynamic>>{};
    final corpusDoc = doc['corpus'] as Map? ?? const {};
    for (final entry in corpusDoc.entries) {
      final value = entry.value;
      if (value is Map) {
        corpus[entry.key.toString()] = Map<String, dynamic>.from(value);
      }
    }
    return WorldManifest(
      schema: schema,
      spec: (doc['spec'] as num?)?.toInt() ?? specNumber,
      scenario: scenario,
      feature: doc['feature'] as String? ?? '',
      version: (doc['version'] as num?)?.toInt() ?? 1,
      seed: (doc['time'] is Map
          ? ((doc['time'] as Map)['seed'] as num?)?.toInt() ?? 0
          : 0),
      touchpoints: touchpoints,
      latency: latency,
      storms: storms,
      corpus: corpus,
      behaviors: behaviors,
      description: doc['description'] as String? ?? '',
    );
  }

  /// Parse manifest file [bytes] (UTF-8 JSON).
  factory WorldManifest.parse(List<int> bytes) {
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw const WorldManifestError(
        'world manifest is not valid UTF-8 --> fix: re-save the manifest '
        'as UTF-8 JSON.',
      );
    }
    final dynamic doc;
    try {
      doc = jsonDecode(text);
    } on FormatException catch (e) {
      throw WorldManifestError(
        'world manifest is not valid JSON (${e.message}) '
        '--> fix: repair the manifest JSON.',
      );
    }
    if (doc is! Map<String, dynamic>) {
      throw const WorldManifestError(
        'world manifest is not a JSON object --> fix: the manifest must '
        'be a JSON object at the top level.',
      );
    }
    return WorldManifest.fromDocument(doc);
  }
}
