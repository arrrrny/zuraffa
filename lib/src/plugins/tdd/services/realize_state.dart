/// `RealizeState` — the per-feature mock/real era record at
/// `tdd/realize-state.json` (spec 913 — zfa tdd realize, phase 1).
///
/// Contract:
/// - The era starts MOCKED: mocks are 100% generatable, real impls are
///   not, so an absent state file IS the mock-first default (never an
///   error). `RealizeStateStore.loadOrDefault` returns the initial
///   MOCKED state in that case.
/// - `transitionToReal` flips the era and appends a transition record
///   carrying the gate evidence that authorized the swap (contract
///   verdict, differential drift, hand-delta count). Idempotent for the
///   same adapter: re-realizing what is already bound appends nothing.
/// - `save` writes atomically (temp file + rename), the same crash
///   contract `RunStateStore` established for run-state.json.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// The realization era a feature's datasource binding is in.
enum RealizeEra { mocked, real }

/// One MOCKED → REAL (or back) transition, with the gate evidence that
/// authorized it.
class RealizeTransition {
  const RealizeTransition({
    required this.from,
    required this.to,
    required this.adapter,
    required this.at,
    this.evidence = const <String, dynamic>{},
  });

  final RealizeEra from;
  final RealizeEra to;
  final String adapter;
  final String at;

  /// Gate verdicts carried into the transition record (contract verdict,
  /// differential drift/threshold, hand-delta count).
  final Map<String, dynamic> evidence;

  Map<String, dynamic> toJson() => {
    'from': from.name.toUpperCase(),
    'to': to.name.toUpperCase(),
    'adapter': adapter,
    'at': at,
    'evidence': evidence,
  };

  factory RealizeTransition.fromJson(Map<String, dynamic> json) =>
      RealizeTransition(
        from: _eraFrom(json['from']),
        to: _eraFrom(json['to']),
        adapter: json['adapter'] as String,
        at: json['at'] as String,
        evidence: json['evidence'] is Map
            ? Map<String, dynamic>.from(json['evidence'] as Map)
            : const <String, dynamic>{},
      );

  static RealizeEra _eraFrom(dynamic raw) =>
      (raw as String).toLowerCase() == 'real'
      ? RealizeEra.real
      : RealizeEra.mocked;
}

/// The persisted realization state for one feature + entity.
class RealizeState {
  const RealizeState({
    required this.feature,
    required this.entity,
    required this.era,
    required this.adapter,
    required this.transitions,
  });

  final String feature;
  final String entity;
  final RealizeEra era;

  /// The adapter the real era is bound to ('' while mocked).
  final String adapter;

  final List<RealizeTransition> transitions;

  static RealizeState initial({
    required String feature,
    required String entity,
  }) => RealizeState(
    feature: feature,
    entity: entity,
    era: RealizeEra.mocked,
    adapter: '',
    transitions: const [],
  );

  Map<String, dynamic> toJson() => {
    'schema': 'realize.v1',
    'feature': feature,
    'entity': entity,
    'era': era.name.toUpperCase(),
    'adapter': adapter,
    'transitions': transitions.map((t) => t.toJson()).toList(),
  };

  factory RealizeState.fromJson(Map<String, dynamic> json) => RealizeState(
    feature: json['feature'] as String,
    entity: json['entity'] as String,
    era: _era(json['era']),
    adapter: json['adapter'] as String? ?? '',
    transitions: (json['transitions'] as List? ?? const [])
        .map(
          (t) =>
              RealizeTransition.fromJson(Map<String, dynamic>.from(t as Map)),
        )
        .toList(growable: false),
  );

  static RealizeEra _era(dynamic raw) =>
      raw is String && raw.toLowerCase() == 'real'
      ? RealizeEra.real
      : RealizeEra.mocked;
}

/// Atomic persistence for `specs/<feature>/tdd/realize-state.json`.
class RealizeStateStore {
  RealizeStateStore(this.featureDir);

  /// The feature directory (`specs/<feature>`).
  final String featureDir;

  String get path => p.join(featureDir, 'tdd', 'realize-state.json');

  String get _expectedFeature => p.basename(featureDir);

  /// The persisted state, or the MOCKED initial state when no file exists
  /// (mock-first is the default path — the absence of a state file is the
  /// normal starting condition, never an error).
  Future<RealizeState> loadOrDefault({
    required String feature,
    required String entity,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      return RealizeState.initial(feature: feature, entity: entity);
    }
    final map = jsonDecode(await file.readAsString());
    if (map is! Map<String, dynamic>) {
      throw StateError(
        'corrupted realize-state.json at $path (top-level value is not an '
        'object). Recovery: delete the file to restart from MOCKED, or '
        'repair it to valid realize-state JSON.',
      );
    }
    if (map['feature'] is! String || map['feature'] != _expectedFeature) {
      throw StateError(
        'corrupted realize-state.json at $path (feature mismatch: '
        '"${map['feature']}" vs directory "$_expectedFeature"). Recovery: '
        'delete the file to restart from MOCKED, or repair it.',
      );
    }
    return RealizeState.fromJson(map);
  }

  /// The MOCKED → REAL transition: era flips, a transition record with the
  /// gate evidence appends. Idempotent for the same adapter — re-realizing
  /// what is already bound appends nothing.
  Future<RealizeState> transitionToReal({
    required RealizeState state,
    required String adapter,
    Map<String, dynamic> evidence = const <String, dynamic>{},
  }) async {
    if (state.era == RealizeEra.real && state.adapter == adapter) {
      return state;
    }
    final transition = RealizeTransition(
      from: state.era,
      to: RealizeEra.real,
      adapter: adapter,
      at: DateTime.now().toUtc().toIso8601String(),
      evidence: Map<String, dynamic>.of(evidence),
    );
    return RealizeState(
      feature: state.feature,
      entity: state.entity,
      era: RealizeEra.real,
      adapter: adapter,
      transitions: [...state.transitions, transition],
    );
  }

  /// Persist [state] atomically (temp file + rename, like RunStateStore).
  Future<void> save(RealizeState state) async {
    final dir = Directory(p.dirname(path));
    await dir.create(recursive: true);
    final tmp = File('$path.tmp');
    await tmp.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(state.toJson())}\n',
    );
    await tmp.rename(path);
  }
}
