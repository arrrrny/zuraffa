/// A self-counting cost ledger for the v8 chord runtime.
///
/// Every [ZfaContext] carries its own [ZfaCostLedger]. Work records what it
/// spent (input/output tokens and a monetary cost) as it goes; a parent context
/// rolls a child's spend up with [absorb], so the root ledger is the running
/// total of the whole subtree without any central coordinator.
///
/// The ledger is **self-counted**: nothing else observes or resets it. An
/// immutable [snapshot] can be taken at any point for reporting; later writes
/// never mutate a snapshot already handed out.
///
/// ## Chord invariant
///
/// The ledger meters cost only. It holds no repository, database or HTTP
/// handle — those never live in a context.
class ZfaCostLedger {
  int _inputTokens = 0;
  int _outputTokens = 0;
  double _cost = 0.0;

  /// Input tokens recorded so far.
  int get inputTokens => _inputTokens;

  /// Output tokens recorded so far.
  int get outputTokens => _outputTokens;

  /// Total tokens (input + output) recorded so far.
  int get totalTokens => _inputTokens + _outputTokens;

  /// Accumulated monetary cost.
  double get cost => _cost;

  /// Whether nothing has been recorded yet.
  bool get isEmpty => _inputTokens == 0 && _outputTokens == 0 && _cost == 0.0;

  /// Record one usage event. Omitted fields default to zero.
  void record({int inputTokens = 0, int outputTokens = 0, double cost = 0.0}) {
    _inputTokens += inputTokens;
    _outputTokens += outputTokens;
    _cost += cost;
  }

  /// Roll another ledger's recorded spend into this one.
  ///
  /// Used to aggregate a child context's cost into its parent. The source
  /// ledger is left unchanged — it remains a record of its own subtree.
  void absorb(ZfaCostLedger other) {
    _inputTokens += other._inputTokens;
    _outputTokens += other._outputTokens;
    _cost += other._cost;
  }

  /// An immutable, detached view of the current totals.
  ZfaCostSnapshot get snapshot => ZfaCostSnapshot(
    inputTokens: _inputTokens,
    outputTokens: _outputTokens,
    cost: _cost,
  );

  @override
  String toString() =>
      'ZfaCostLedger(input: $_inputTokens, output: $_outputTokens, '
      'cost: $_cost)';
}

/// Immutable point-in-time totals captured from a [ZfaCostLedger].
class ZfaCostSnapshot {
  const ZfaCostSnapshot({
    required this.inputTokens,
    required this.outputTokens,
    required this.cost,
  });

  final int inputTokens;
  final int outputTokens;
  final double cost;

  /// Total tokens (input + output) in this snapshot.
  int get totalTokens => inputTokens + outputTokens;
}
