/// Pluggable persistence seam for the session container (spec FR-008).
///
/// The core ships an in-memory implementation; durable backends (file,
/// Hive, SQL) are the application's choice — the container only needs
/// [load] to return the last saved envelope (or `null`) and [save] to
/// accept the envelope produced by `SessionContainer.toJson`.
library;

import 'session_container.dart';

/// A persistence backend for serialized session envelopes.
abstract class SessionPersistence {
  /// Loads the last persisted envelope, or `null` when nothing was saved
  /// (or the backend is unavailable — persistence is best-effort and must
  /// never crash the container).
  Future<Map<String, dynamic>?> load();

  /// Persists [envelope] (the container's `toJson()` output).
  Future<void> save(Map<String, dynamic> envelope);
}

/// Volatile in-memory persistence — the default backend.
///
/// Sessions restored from it survive container recreation within the same
/// process, which is exactly enough to validate the persistence contract;
/// durable backends plug in behind the same interface.
class InMemorySessionPersistence implements SessionPersistence {
  Map<String, dynamic>? _envelope;

  /// The stored envelope, if any (exposed for tests).
  Map<String, dynamic>? get stored => _envelope;

  @override
  Future<Map<String, dynamic>?> load() async => _envelope;

  @override
  Future<void> save(Map<String, dynamic> envelope) async {
    _envelope = Map<String, dynamic>.from(envelope);
  }
}

extension SessionContainerPersistence on SessionContainer {
  /// Snapshots the container into [persistence].
  Future<void> persist(SessionPersistence persistence) async {
    await persistence.save(toJson());
  }

  /// Restores the container from [persistence]. A `null` load (nothing
  /// persisted yet) leaves the container untouched and returns `false`.
  Future<bool> restore(SessionPersistence persistence) async {
    final envelope = await persistence.load();
    if (envelope == null) return false;
    loadFromEnvelope(envelope);
    return true;
  }
}
