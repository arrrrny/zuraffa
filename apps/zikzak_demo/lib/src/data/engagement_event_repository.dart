/// Hive-backed persistence for engagement events (mock app — bug 501).
///
/// Mirrors the production ZikZak repository contract: every event is written
/// to a local Hive box immediately and stored with `synced: false` (marked
/// for background sync). The EngagementHook delegates here directly — the
/// repository-direct pattern, never through a UseCase, to avoid the
/// hook-calls-UseCase infinite recursion documented in spec 011.
library;

import 'package:hive/hive.dart';

import '../domain/engagement_event.dart';

/// Local Hive-backed engagement event store.
class EngagementEventRepository {
  EngagementEventRepository({String? boxName})
    : _boxName = boxName ?? defaultBoxName;

  /// Name of the local Hive box holding engagement events.
  static const defaultBoxName = 'engagement_events';

  final String _boxName;
  Box<Map>? _box;

  /// Prepares Hive (optionally rooted at [path] — used by tests with a temp
  /// directory) and opens the event box. Must be called before any other
  /// method.
  Future<void> init({String? path}) async {
    if (path != null) Hive.init(path);
    _box = await Hive.openBox<Map>(_boxName);
  }

  Box<Map> get _store =>
      _box ??
      (throw StateError(
        'EngagementEventRepository.init() must be called before use',
      ));

  /// Persists [event] locally, flagged for background sync.
  Future<void> create(EngagementEvent event) async {
    await _store.put(event.id, event.toJson());
  }

  /// All locally stored events, newest last.
  Future<List<EngagementEvent>> getAll() async => _store.values
      .map((raw) => EngagementEvent.fromJson(Map<String, dynamic>.from(raw)))
      .toList();

  /// Number of locally stored events.
  Future<int> count() async => _store.length;

  /// Events still waiting for the background sync flush.
  Future<List<EngagementEvent>> pendingSync() async =>
      (await getAll()).where((event) => !event.synced).toList();

  /// Flags [id] as flushed to the backend by the background sync.
  Future<void> markSynced(String id) async {
    final raw = _store.get(id);
    if (raw == null) return;
    final event = EngagementEvent.fromJson(Map<String, dynamic>.from(raw));
    await _store.put(id, <String, dynamic>{...event.toJson(), 'synced': true});
  }

  /// Closes the underlying Hive box (test teardown / app shutdown).
  Future<void> dispose() => Hive.close();
}
