/// The failure schedule (spec 968, VISION §9): failure storms.
///
/// A storm is a named window of scripted failures on one touchpoint —
/// the issue's storm classes:
/// - **auth expiry mid-flow** — the auth touchpoint starts failing at a
///   declared call (the token expired while the flow was running)
/// - **network flaps** — HTTP failures over a call range (503s, then
///   recovery)
/// - **partial writes** — a write "succeeds" but returns the half-written
///   marker (`partial: true`), which honest syncs must detect and repair
///
/// The schedule is deterministic: whether a storm fires depends only on
/// the (touchpoint, call index) pair and the manifest's declared window —
/// never on wall time, randomness, or execution order. Storm semantics
/// are first-class red→green behaviors: the failure-storm window is what
/// the temporal feature's retry logic is developed against.
library;

import 'world_manifest.dart';

/// The partial-write marker the runtime injects into a response when a
/// `partial-write` storm fires: the write half-landed, honest consumers
/// must detect and repair it.
const String kPartialWriteMarker = '__partial';

/// The storm that fires for [touchpoint]'s [method] on call
/// [callIndex] (1-based), or `null` when the schedule is silent there.
/// A storm with a null `method` matches every method of the
/// touchpoint; a method-scoped storm fires only on its method (how
/// mid-flow storms stay surgical). When several storms overlap, the
/// LAST declared wins (later entries refine earlier ones — the
/// manifest reads as an ordered schedule).
WorldStorm? stormAt(
  List<WorldStorm> storms,
  String touchpoint,
  String method,
  int callIndex,
) {
  WorldStorm? firing;
  for (final storm in storms) {
    final methodMatch = storm.method == null || storm.method == method;
    if (storm.touchpoint == touchpoint &&
        methodMatch &&
        storm.firesOn(callIndex)) {
      firing = storm;
    }
  }
  return firing;
}

/// The failure a fired storm throws/wraps, classified.
enum StormFailureKind { http, auth, partial, unknown }

/// One fired storm's resolved failure.
final class StormFailure {
  const StormFailure({required this.storm, required this.kind});

  final WorldStorm storm;
  final StormFailureKind kind;

  /// The HTTP status when [kind] is [StormFailureKind.http].
  int get httpStatus => (storm.failure['status'] as num?)?.toInt() ?? 503;

  /// The auth error code when [kind] is [StormFailureKind.auth].
  String get authCode =>
      storm.failure['code'] as String? ?? 'user-token-expired';

  /// Human-readable classification for ledgers and receipts.
  String get label => switch (kind) {
    StormFailureKind.http => 'http-${httpStatus}',
    StormFailureKind.auth => 'auth-${authCode}',
    StormFailureKind.partial => 'partial-write',
    StormFailureKind.unknown => storm.kind,
  };

  static StormFailureKind kindOf(Map<String, dynamic> failure) {
    switch (failure['type'] as String? ?? '') {
      case 'http':
        return StormFailureKind.http;
      case 'auth':
        return StormFailureKind.auth;
      case 'partial':
      case 'partial-write':
        return StormFailureKind.partial;
    }
    return StormFailureKind.unknown;
  }
}
