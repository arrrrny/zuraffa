/// `RealizeState` — the per-feature mock/real era record at
/// `tdd/realize-state.json` (spec 913 — zfa tdd realize, phase 1).
///
/// STUB (red phase): every member throws until the green phase implements
/// the state transition contract.
library;

/// The realization era a feature's datasource binding is in.
///
/// MOCKED is the default era: mocks are 100% generatable and real impls are
/// not, so every feature starts mocked and only crosses to REAL through
/// `zfa tdd realize` with its contract + differential gates.
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

  Map<String, dynamic> toJson() => throw UnimplementedError();

  factory RealizeTransition.fromJson(Map<String, dynamic> json) =>
      throw UnimplementedError();
}

/// The persisted realization state for one feature + entity.
class RealizeState {
  const RealizeState({
    required this.feature,
    required this.entity,
    required this.era,
    required this.transitions,
  });

  final String feature;
  final String entity;
  final RealizeEra era;
  final List<RealizeTransition> transitions;

  static RealizeState initial({required String feature, required String entity}) =>
      throw UnimplementedError();

  Map<String, dynamic> toJson() => throw UnimplementedError();

  factory RealizeState.fromJson(Map<String, dynamic> json) =>
      throw UnimplementedError();
}

/// Atomic persistence for `specs/<feature>/tdd/realize-state.json`.
class RealizeStateStore {
  RealizeStateStore(this.featureDir);

  final String featureDir;

  String get path => throw UnimplementedError();

  /// The persisted state, or the MOCKED initial state when no file exists
  /// (mock-first is the default path — the absence of a state file is the
  /// normal starting condition, never an error).
  Future<RealizeState> loadOrDefault({
    required String feature,
    required String entity,
  }) => throw UnimplementedError();

  /// The MOCKED → REAL transition: era flips, a transition record with the
  /// gate evidence appends. Idempotent for the same adapter — re-realizing
  /// what is already bound appends nothing.
  Future<RealizeState> transitionToReal({
    required RealizeState state,
    required String adapter,
    Map<String, dynamic> evidence = const <String, dynamic>{},
  }) => throw UnimplementedError();

  /// Persist [state] atomically (temp file + rename, like RunStateStore).
  Future<void> save(RealizeState state) => throw UnimplementedError();
}
