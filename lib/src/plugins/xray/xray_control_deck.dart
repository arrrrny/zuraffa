// X-Ray Control Deck — runtime registry of mock entries + broadcast stream
// for the Flutter UI + release-mode strip.
//
// The Flutter Control Deck panel subscribes to [changes] and re-renders
// the button list whenever a new batch is registered. Tapping a button
// calls [inject] which returns the payload string (the Flutter side then
// routes it into the UseCase via DI).
//
// Pure-Dart, no Flutter dependency. The release-mode guard is the
// compile-time constant `bool.fromEnvironment('dart.vm.product')`
// (defined in `lib/src/core/xray_config.dart`).
//
// Track 4.3 — Spec 034 (issue #185, FR-005, FR-006, FR-007, FR-008).
library;

import 'dart:async';

import '../../core/xray_config.dart';
import 'xray_mock_entry.dart';

/// Mutable registry of X-Ray mock entries + broadcast stream of snapshots.
///
/// In release mode, EVERY public method is a no-op:
///   - [registerEntries] does not modify the registry.
///   - [clear] is a no-op.
///   - [inject] always returns `null`.
///   - [find] always returns `null`.
///   - [changes] never emits.
///
/// This is the runtime mirror of the codegen's `kDebugMode` wrap — even
/// if a stray reference escapes the codegen's `if (kDebugMode)` block,
/// the runtime guard ensures no observable behavior.
class XRayControlDeck {
  /// Singleton — the Flutter app references this via
  /// `XRayControlDeck.instance.registerEntries([...])` from the
  /// generated `register<Entity>XRayDeck()` calls.
  static final XRayControlDeck instance = XRayControlDeck();

  /// Release-mode flag (overridable in tests via constructor param).
  final bool _isReleaseMode;

  /// The current registry keyed by `"$name\0$payload"` for O(1) dedup
  /// and O(1) lookup by [find].
  final Map<String, XRayMockEntry> _entries = {};

  /// Broadcast controller for the [changes] stream.
  final StreamController<List<XRayMockEntry>> _controller =
      StreamController<List<XRayMockEntry>>.broadcast();

  XRayControlDeck({bool? isReleaseMode})
    : _isReleaseMode = isReleaseMode ?? kXrayReleaseMode;

  /// Whether the deck is currently active (i.e. not in release mode and
  /// at least one entry is registered).
  bool get active => !_isReleaseMode && _entries.isNotEmpty;

  /// Snapshot of the current registered entries (immutable list view).
  List<XRayMockEntry> get entries =>
      _isReleaseMode ? const [] : List.unmodifiable(_entries.values);

  /// Broadcast stream of entry snapshots. Emits after every
  /// [registerEntries] / [clear]. Emits nothing in release mode.
  Stream<List<XRayMockEntry>> get changes => _isReleaseMode
      ? const Stream<List<XRayMockEntry>>.empty()
      : _controller.stream;

  /// Register a batch of entries. Dedups by name+payload pair
  /// (per spec edge case). Existing entries are retained — call [clear]
  /// first if you want a clean replace. No-op in release mode.
  void registerEntries(List<XRayMockEntry> newEntries) {
    if (_isReleaseMode) return;
    final prevLength = _entries.length;
    for (final e in newEntries) {
      final key = _key(e.name, e.payload);
      _entries[key] ??= e;
    }
    if (_entries.length != prevLength) _emit();
  }

  /// Clear all registered entries. No-op in release mode.
  void clear() {
    if (_isReleaseMode) return;
    _entries.clear();
    _emit();
  }

  /// Find an entry by name + payload. Returns `null` if not registered
  /// or in release mode.
  XRayMockEntry? find(String name, String payload) {
    if (_isReleaseMode) return null;
    return _entries[_key(name, payload)];
  }

  /// Inject a payload by entry name. Returns the payload string, or
  /// `null` if no entry with that name is registered (or in release mode).
  ///
  /// When multiple entries share the same name (different payloads),
  /// returns the payload of the first one encountered (per spec edge
  /// case — same name different payloads are NOT deduped).
  String? inject(String name) {
    if (_isReleaseMode) return null;
    for (final e in _entries.values) {
      if (e.name == name) return e.payload;
    }
    return null;
  }

  /// Serialize the registry for the MCP bridge.
  /// In release mode, returns `{"active": false, "release_mode": true, "entries": []}`.
  Map<String, dynamic> toJson() => {
    'active': active,
    'release_mode': _isReleaseMode,
    'entries': _isReleaseMode
        ? <Map<String, dynamic>>[]
        : _entries.values.map((e) => e.toJson()).toList(),
  };

  /// Registry key for [XRayMockEntry] — uses a NUL separator to avoid
  /// collisions between `("a", "b\0c")` and `("a\0b", "c")`.
  static String _key(String name, String payload) => '$name\x00$payload';

  void _emit() {
    if (_isReleaseMode) return;
    _controller.add(List.unmodifiable(_entries.values));
  }
}
