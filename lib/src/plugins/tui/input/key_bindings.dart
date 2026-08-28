/// Canonical keyboard defaults + plugin/app override precedence (FR-006).
///
/// [KeyBindings] maps each [KeyAction] to the set of keys that trigger it.
/// Defaults are the same across every Zuraffa TUI:
///   * [KeyAction.quit] — `q` and `Ctrl+C`
///   * [KeyAction.confirm] — `Enter`
///   * [KeyAction.navigateUp] / [navigateDown] / [navigateLeft] / [navigateRight]
///     — arrow keys
///   * [KeyAction.focusNext] / [focusPrevious] — `Tab` / `Shift+Tab`
///
/// Plugins and apps MAY override individual actions via [KeyBindings.merge]:
///   * A plugin override **replaces** the default for the overridden action.
///   * An app override **wins** any conflict with a plugin override.
///   * Unoverridden actions retain their defaults.
library;

import 'package:meta/meta.dart';

/// The set of canonical TUI key actions (FR-006).
///
/// Sealed family — every action a Zuraffa TUI ships by default is enumerated
/// here. Apps that need additional domain-specific actions dispatch them via
/// `BuildContext.dispatch(action)` where `action` is a custom enum, but the
/// canonical set stays fixed so cross-app consistency holds (SC-003).
enum KeyAction {
  /// Quit the TUI (default: `q` or `Ctrl+C`).
  quit,

  /// Confirm / activate (default: `Enter`).
  confirm,

  /// Cancel an in-flight async action (default: `Escape`).
  cancel,

  /// Directional navigation — up (default: `ArrowUp`).
  navigateUp,

  /// Directional navigation — down (default: `ArrowDown`).
  navigateDown,

  /// Directional navigation — left (default: `ArrowLeft`).
  navigateLeft,

  /// Directional navigation — right (default: `ArrowRight`).
  navigateRight,

  /// Move focus to the next focusable (default: `Tab`).
  focusNext,

  /// Move focus to the previous focusable (default: `Shift+Tab`).
  focusPrevious,
}

/// A single key binding: a set of [PhysicalKey]s that trigger one [KeyAction].
@immutable
class KeyBinding {
  const KeyBinding(this.action, this.keys);

  /// The action triggered by any of [keys].
  final KeyAction action;

  /// The keys (logical key identifiers) that trigger [action].
  ///
  /// Identifiers follow the nocterm `LogicalKey` naming convention:
  /// `'q'`, `'Q'`, `'Ctrl+C'`, `'Enter'`, `'Escape'`, `'Tab'`, `'Shift+Tab'`,
  /// `'ArrowUp'`, `'ArrowDown'`, `'ArrowLeft'`, `'ArrowRight'`.
  final Set<String> keys;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeyBinding &&
          action == other.action &&
          _setEquals(keys, other.keys);

  @override
  int get hashCode => Object.hash(action, Object.hashAllUnordered(keys));

  @override
  String toString() => 'KeyBinding($action ← $keys)';
}

/// The canonical key bindings table for a Zuraffa TUI.
///
/// Construct via [KeyBindings.defaults], [KeyBindings.merge], or build
/// manually from a list of [KeyBinding]s.
@immutable
class KeyBindings {
  const KeyBindings(this._table);

  /// Internal per-action → key set table.
  final Map<KeyAction, Set<String>> _table;

  /// The default canonical key bindings shipped with every Zuraffa TUI.
  ///
  /// Returns the full set defined by FR-006: `q`/`Ctrl+C` quit, `Enter`
  /// confirm, arrow keys navigate, `Tab`/`Shift+Tab` focus, `Escape` cancel.
  factory KeyBindings.defaults() => const KeyBindings({
    KeyAction.quit: {'q', 'Ctrl+C'},
    KeyAction.confirm: {'Enter'},
    KeyAction.cancel: {'Escape'},
    KeyAction.navigateUp: {'ArrowUp'},
    KeyAction.navigateDown: {'ArrowDown'},
    KeyAction.navigateLeft: {'ArrowLeft'},
    KeyAction.navigateRight: {'ArrowRight'},
    KeyAction.focusNext: {'Tab'},
    KeyAction.focusPrevious: {'Shift+Tab'},
  });

  /// Returns the set of keys that trigger [action], or the empty set if no
  /// binding is registered for [action].
  Set<String> keysFor(KeyAction action) => _table[action] ?? const {};

  /// Returns the [KeyAction] triggered by [key], or `null` if no binding
  /// matches.
  KeyAction? actionFor(String key) {
    for (final entry in _table.entries) {
      if (entry.value.contains(key)) return entry.key;
    }
    return null;
  }

  /// Whether [key] triggers [action].
  bool matches(String key, KeyAction action) =>
      _table[action]?.contains(key) ?? false;

  /// Merge defaults, plugin overrides, and app overrides (FR-006 precedence).
  ///
  /// Precedence:
  ///   1. [appOverrides] wins any conflict (highest precedence).
  ///   2. [pluginOverrides] replaces the default for the overridden action
  ///      (if no app override exists for the same action).
  ///   3. [defaults] for every unoverridden action (lowest precedence).
  ///
  /// Pass [defaults] explicitly when chaining merges; defaults to
  /// [KeyBindings.defaults] when omitted.
  factory KeyBindings.merge({
    KeyBindings? defaults,
    Map<KeyAction, Set<String>> pluginOverrides = const {},
    Map<KeyAction, Set<String>> appOverrides = const {},
  }) {
    final base = (defaults ?? KeyBindings.defaults())._table;
    final merged = Map<KeyAction, Set<String>>.of(base);

    // Plugin overrides replace defaults for the same action.
    for (final entry in pluginOverrides.entries) {
      merged[entry.key] = Set<String>.of(entry.value);
    }

    // App overrides win any conflict with plugin overrides.
    for (final entry in appOverrides.entries) {
      merged[entry.key] = Set<String>.of(entry.value);
    }

    return KeyBindings(Map.unmodifiable(merged));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeyBindings && _mapEquals(_table, other._table);

  @override
  int get hashCode => Object.hashAllUnordered(
    _table.entries.map(
      (e) => Object.hash(e.key, Object.hashAllUnordered(e.value)),
    ),
  );

  @override
  String toString() => 'KeyBindings($_table)';

  static bool _mapEquals<K>(Map<K, Set<String>> a, Map<K, Set<String>> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      final av = a[key]!;
      final bv = b[key];
      if (bv == null || !_setEquals(av, bv)) return false;
    }
    return true;
  }
}

bool _setEquals<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);
