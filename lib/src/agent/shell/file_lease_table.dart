/// Real-time, crash-safe file ownership for the agent shell (issue #808).
///
/// The static ownership classifier (spec 043) decides which files a slice
/// *may* touch; the lease table decides who may touch them *right now*.
///
/// Design goals, straight from the issue:
/// - **Real-time**: a lease is granted/denied at write time, not at plan
///   time.
/// - **Crash-safe**: a lease carries a TTL. An agent that dies (`kill -9`)
///   never sends `release` — its leases simply expire and are then
///   stealable ("steal-on-timeout"). No cleanup handshake is required.
/// - **Workspace-scoped**: a lease covers a *scope prefix* (a feature
///   directory), so one grant protects every file under it.
///
/// Pure-Dart, single-isolate, no I/O — the same kernel assumptions as
/// `src/agent/kernel/` (FR-009).
library;

import 'package:meta/meta.dart';

/// A granted or denied lease (value object).
final class LeaseGrant {
  const LeaseGrant.granted(this.lease, {this.stoleFrom}) : conflict = null;

  const LeaseGrant.denied(this.conflict) : lease = null, stoleFrom = null;

  /// The lease, when granted.
  final FileLease? lease;

  /// The conflicting lease, when denied.
  final FileLease? conflict;

  /// Holder id whose expired lease was stolen (when applicable).
  final String? stoleFrom;

  bool get granted => lease != null;
  bool get denied => !granted;
}

/// An outstanding lease over a scope prefix.
@immutable
class FileLease {
  FileLease({
    required this.holderId,
    required this.scope,
    required this.acquiredAt,
    required this.expiresAt,
  });

  final String holderId;

  /// Normalized scope prefix WITH trailing `/` (directory scopes).
  final String scope;
  final DateTime acquiredAt;
  final DateTime expiresAt;

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  /// Whether this lease covers [path] (prefix semantics).
  bool covers(String path) {
    final p = _normalize(path);
    return p.startsWith(scope);
  }

  FileLease renewed(DateTime until) => FileLease(
    holderId: holderId,
    scope: scope,
    acquiredAt: acquiredAt,
    expiresAt: until,
  );

  @override
  String toString() => 'FileLease($holderId, $scope, expires=$expiresAt)';
}

/// Thrown when an agent tries to release a lease it does not hold.
class LeaseNotHeld implements Exception {
  LeaseNotHeld(this.scope, this.agentId);
  final String scope;
  final String agentId;

  @override
  String toString() => 'LeaseNotHeld: agent `$agentId` does not hold `$scope`';
}

/// Normalize a path/scope into `/`-separated form.
String _normalize(String path) => path.replaceAll('\\', '/');

/// The lease table — acquire / release / renew / steal-on-timeout.
class FileLeaseTable {
  FileLeaseTable({
    this.defaultTtl = const Duration(minutes: 5),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration defaultTtl;
  final DateTime Function() _now;

  final Map<String, FileLease> _leases = <String, FileLease>{};

  /// All live (non-expired) leases.
  List<FileLease> get active {
    final now = _now();
    return _leases.values.where((l) => !l.isExpiredAt(now)).toList()
      ..sort((a, b) => a.scope.compareTo(b.scope));
  }

  /// The live lease on exactly [scope], or null.
  FileLease? lookup(String scope) {
    final key = _scopeKey(scope);
    final lease = _leases[key];
    if (lease == null) return null;
    if (lease.isExpiredAt(_now())) return null;
    return lease;
  }

  /// Whether [agentId] may write [path]: some live lease held by
  /// [agentId] must cover the path.
  bool allowsWrite({required String agentId, required String path}) {
    final p = _normalize(path);
    final now = _now();
    for (final lease in _leases.values) {
      if (lease.isExpiredAt(now)) continue;
      if (lease.covers(p) && lease.holderId == agentId) return true;
    }
    return false;
  }

  /// Acquire a lease on [scope] for [agentId].
  ///
  /// - Live lease held by someone else → denied (with the conflict).
  /// - Live lease held by the same agent → renewed (idempotent re-grant).
  /// - Expired lease (dead holder) → stolen and granted
  ///   ("steal-on-timeout").
  LeaseGrant acquire({
    required String agentId,
    required String scope,
    Duration? ttl,
  }) {
    final key = _scopeKey(scope);
    final now = _now();
    final until = now.add(ttl ?? defaultTtl);
    final existing = _leases[key];

    if (existing != null && !existing.isExpiredAt(now)) {
      if (existing.holderId == agentId) {
        final renewed = existing.renewed(until);
        _leases[key] = renewed;
        return LeaseGrant.granted(renewed);
      }
      return LeaseGrant.denied(existing);
    }

    final stoleFrom = existing != null && existing.holderId != agentId
        ? existing.holderId
        : null;
    final lease = FileLease(
      holderId: agentId,
      scope: key,
      acquiredAt: now,
      expiresAt: until,
    );
    _leases[key] = lease;
    return LeaseGrant.granted(lease, stoleFrom: stoleFrom);
  }

  /// Release a held lease. Only the holder may release.
  void release({required String agentId, required String scope}) {
    final key = _scopeKey(scope);
    final lease = _leases[key];
    if (lease == null || lease.holderId != agentId) {
      throw LeaseNotHeld(key, agentId);
    }
    _leases.remove(key);
  }

  /// Extend the expiry of a held lease (heartbeat).
  FileLease renew({required String agentId, required String scope}) {
    final key = _scopeKey(scope);
    final lease = _leases[key];
    if (lease == null || lease.holderId != agentId) {
      throw LeaseNotHeld(key, agentId);
    }
    final now = _now();
    if (lease.isExpiredAt(now)) {
      _leases.remove(key);
      throw LeaseNotHeld(key, agentId);
    }
    final renewed = lease.renewed(now.add(defaultTtl));
    _leases[key] = renewed;
    return renewed;
  }

  /// Drop every expired lease. Returns what was swept — the shell logs
  /// these as crash-recovery steals.
  List<FileLease> sweepExpired() {
    final now = _now();
    final swept = <FileLease>[];
    for (final lease in _leases.values.toList(growable: false)) {
      if (lease.isExpiredAt(now)) {
        _leases.remove(lease.scope);
        swept.add(lease);
      }
    }
    return swept;
  }

  /// Exact scope key: normalized + trailing `/` for directory scopes.
  String _scopeKey(String scope) {
    final s = _normalize(scope);
    return s.endsWith('/') ? s : '$s/';
  }
}
