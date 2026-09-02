import 'file_lease_table.dart';

/// Enforces leases at write time (issue #808).
///
/// Every write an agent performs inside the shell MUST go through the
/// guard. The guard consults the [FileLeaseTable] and rejects any write
/// whose author does not hold a covering lease — this is the mechanism the
/// "two concurrent agents on one feature never interleave writes" proof
/// runs against.
class LeaseGuard {
  LeaseGuard(this.leases);

  final FileLeaseTable leases;

  /// Append-only record of every successful write. Each entry proves the
  /// writer held the lease at write time.
  final List<GuardedWrite> writeLog = <GuardedWrite>[];

  /// Guarded write. Throws [LeaseViolation] when [agentId] does not hold a
  /// lease covering [path].
  GuardedWrite write({
    required String agentId,
    required String path,
    required String contents,
  }) {
    final holder = _coveringHolder(path);
    if (holder != agentId) {
      throw LeaseViolation(path: path, agentId: agentId, holderId: holder);
    }
    final entry = GuardedWrite(
      agentId: agentId,
      path: path,
      contents: contents,
      holderAtWrite: agentId,
      at: DateTime.now(),
    );
    writeLog.add(entry);
    return entry;
  }

  /// The current lease holder covering [path], or null.
  String? _coveringHolder(String path) {
    for (final lease in leases.active) {
      if (lease.covers(path)) return lease.holderId;
    }
    return null;
  }

  /// Number of successful writes recorded.
  int get writeCount => writeLog.length;
}

/// A successful guarded write.
class GuardedWrite {
  GuardedWrite({
    required this.agentId,
    required this.path,
    required this.contents,
    required this.holderAtWrite,
    required this.at,
  });

  final String agentId;
  final String path;
  final String contents;

  /// The lease holder the table reported at write time. Invariant: this is
  /// always equal to [agentId] — otherwise the write would have thrown.
  final String holderAtWrite;
  final DateTime at;

  @override
  String toString() => 'GuardedWrite($agentId → $path)';
}

/// Thrown when an un-leased agent attempts a write.
class LeaseViolation implements Exception {
  LeaseViolation({
    required this.path,
    required this.agentId,
    required this.holderId,
  });

  final String path;
  final String agentId;

  /// The actual holder, or null when nobody holds the path.
  final String? holderId;

  @override
  String toString() {
    final holder = holderId ?? 'nobody';
    return 'LeaseViolation: agent `$agentId` may not write `$path` '
        '(held by: $holder)';
  }
}
