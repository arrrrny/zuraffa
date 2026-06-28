import 'package:logging/logging.dart';

import 'hook.dart';

/// Global singleton registry for all hooks.
///
/// Manages hook registration, dispatch, and lifecycle.
/// All UseCases automatically dispatch to registered hooks —
/// no per-UseCase configuration needed.
///
/// ## Usage
/// ```dart
/// // Register hooks (typically in main())
/// HookRegistry.instance.register(EngagementTrackingHook());
/// HookRegistry.instance.register(TelemetryHook());
///
/// // Hooks now fire automatically on every UseCase execution.
/// ```
///
/// ## Disabling
///
/// Set [isEnabled] to `false` to instantly disable all hooks (e.g., GDPR
/// opt-out, debug mode):
///
/// ```dart
/// HookRegistry.instance.isEnabled = false;
/// ```
class HookRegistry {
  static final HookRegistry instance = HookRegistry._();

  static final _logger = Logger('HookRegistry');

  HookRegistry._();

  final Map<String, Hook> _hooks = {};
  bool _isEnabled = true;

  /// Whether hooks are globally enabled.
  ///
  /// When `false`, [dispatch] returns immediately without iterating hooks.
  /// Defaults to `true`.
  bool get isEnabled => _isEnabled;
  set isEnabled(bool value) => _isEnabled = value;

  /// All registered hooks, sorted by priority (ascending — lower first).
  List<Hook> get hooks {
    final list = _hooks.values.toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    return List.unmodifiable(list);
  }

  /// Whether any hooks are registered.
  bool get isEmpty => _hooks.isEmpty;

  /// Register a hook.
  ///
  /// Throws [StateError] if a hook with the same [id] is already registered.
  void register(Hook hook) {
    if (_hooks.containsKey(hook.id)) {
      throw StateError(
        'Hook already registered: ${hook.id}. Unregister it first.',
      );
    }
    _hooks[hook.id] = hook;
    _logger.info('Registered hook: ${hook.id} (phases: ${hook.phases})');
  }

  /// Unregister a hook by ID.
  void unregister(String id) {
    final removed = _hooks.remove(id);
    if (removed != null) {
      _logger.info('Unregistered hook: $id');
    }
  }

  /// Unregister all hooks.
  void clear() {
    _hooks.clear();
    _logger.info('All hooks unregistered');
  }

  /// Dispatch a context + phase to all matching hooks.
  ///
  /// **Fire-and-forget**: never throws, never blocks the calling UseCase.
  /// Hooks are executed in priority order (ascending). Errors in individual
  /// hooks are caught and logged — they do not prevent other hooks from
  /// running or affect the UseCase result.
  ///
  /// When [isEnabled] is `false` or no hooks are registered, returns
  /// immediately with negligible overhead.
  void dispatch(HookContext context, HookPhase phase) {
    if (!_isEnabled || _hooks.isEmpty) return;

    // Snapshot the hooks list to avoid concurrent modification issues
    final matching = hooks.where((h) {
      if (!h.phases.contains(phase)) return false;
      return h.shouldTrigger(context, phase);
    });

    for (final hook in matching) {
      // Fire and forget — never let a hook failure propagate
      hook.execute(context, phase).catchError((e, stackTrace) {
        _logger.warning(
          'Hook "${hook.id}" failed during $phase: $e',
          e,
          stackTrace,
        );
      });
    }
  }
}
