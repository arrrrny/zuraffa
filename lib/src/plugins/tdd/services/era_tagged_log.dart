/// `EraTaggedLog` — era-tagged, hash-chained evidence entries appended to
/// the feature's `tdd/cycle-log.md` (spec 913, phase 5).
///
/// STUB (red phase): every member throws until the green phase implements
/// the era-tagged chain contract.
library;

import 'realize_state.dart';

/// One era-tagged cycle-log entry: the realization evidence a transition
/// leaves behind.
class EraTaggedLogEntry {
  const EraTaggedLogEntry({
    required this.behaviorId,
    required this.kind,
    required this.era,
    required this.criterion,
    required this.test,
    required this.command,
    required this.exitCode,
    required this.output,
  });

  /// The chain behavior id (e.g. `user-realize`).
  final String behaviorId;

  /// Entry kind: `realize` (the transition), `realize-contract`,
  /// `realize-differential` (gate evidence).
  final String kind;

  /// The era this entry certifies (MOCKED before, REAL after a swap).
  final RealizeEra era;

  final String criterion;

  /// Suite scope the evidence covers (or `-`).
  final String test;

  final String command;

  final int exitCode;

  final String output;
}

class EraTaggedLog {
  const EraTaggedLog(this.featureDir);

  /// The feature directory (`specs/<feature>`).
  final String featureDir;

  /// Append one era-tagged entry in the schema-1 hash-chain format: the
  /// payload covers the era, and the entry chains onto the behavior's
  /// last hashed link.
  Future<void> append(EraTaggedLogEntry entry) => throw UnimplementedError();

  /// The chain hash for [entry] given [prevHash] (shared with the
  /// verification side).
  static String chainHashFor(EraTaggedLogEntry entry, String prevHash) =>
      throw UnimplementedError();

  /// The last era tag recorded in the cycle log, or null when the log
  /// carries no era-tagged entries yet. The era survives across appended
  /// entries — evidence per era, readable back.
  Future<RealizeEra?> lastEra() => throw UnimplementedError();
}
