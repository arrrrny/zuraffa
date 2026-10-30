import 'dart:async';

import 'package:logging/logging.dart';

import 'failure.dart';
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

  /// Whether hooks are globally enabled.
  ///
  /// When `false`, [dispatch] returns immediately without iterating hooks.
  /// Defaults to `true`.
  bool isEnabled = true;

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
    if (!isEnabled || _hooks.isEmpty) return;

    // Snapshot the hooks list to avoid concurrent modification issues
    final matching = hooks.where((h) {
      if (!h.phases.contains(phase)) return false;
      return h.shouldTrigger(context, phase);
    });

    for (final hook in matching) {
      _fireAndForget(hook, context, phase);
    }
  }

  /// Dispatch a context + phase to all matching hooks, awaiting every
  /// **blocking** hook ([Hook.blocking]) to completion before returning.
  ///
  /// This is the ordering-critical counterpart to [dispatch] (issue #2032):
  /// the classic `UseCase.call` uses it for the `pre` phase so that a
  /// blocking hook provably finishes BEFORE the UseCase's `execute` begins.
  ///
  /// - Blocking hooks run **sequentially** in priority order (lower first),
  ///   each awaited to completion (or abandoned at its [Hook.blockingTimeout]).
  /// - A [Hook.blockingTimeout] is **abandonment, not cancellation**: the
  ///   registry stops waiting and proceeds; the hook's own future keeps
  ///   running and cleaning up after itself is the hook's responsibility.
  /// - A blocking hook's error is handled per its [Hook.onError] policy:
  ///   [HookErrorPolicy.continue_] logs and proceeds; [HookErrorPolicy.veto]
  ///   stops immediately by throwing [HookVetoException] (the UseCase turns
  ///   that into `Failure(hookFailure)` without running `execute`).
  /// - Non-blocking hooks keep [dispatch]'s exact fire-and-forget semantics.
  /// - When [isEnabled] is `false`, no hooks are registered, or no matching
  ///   hook is blocking, this degenerates to [dispatch] (one completed-future
  ///   await of overhead — effectively zero cost when the feature is unused).
  ///
  /// Only [HookVetoException] ever propagates out of this method.
  Future<void> dispatchAwaited(HookContext context, HookPhase phase) async {
    if (!isEnabled || _hooks.isEmpty) return;

    // Snapshot the hooks list to avoid concurrent modification issues
    final matching = hooks.where((h) {
      if (!h.phases.contains(phase)) return false;
      return h.shouldTrigger(context, phase);
    }).toList();

    for (final hook in matching) {
      if (!hook.blocking) {
        _fireAndForget(hook, context, phase);
        continue;
      }
      try {
        final timeout = hook.blockingTimeout;
        if (timeout == null) {
          await hook.execute(context, phase);
        } else {
          // .timeout keeps the hook's own future running — abandonment,
          // not cancellation. Cleanup remains the hook's responsibility.
          await hook.execute(context, phase).timeout(timeout);
        }
      } on TimeoutException catch (e, stackTrace) {
        _logger.warning(
          'Blocking hook "${hook.id}" timed out after '
          '${hook.blockingTimeout} during $phase — abandoned (the hook '
          'owns its own cleanup); policy: ${hook.onError}',
          e,
          stackTrace,
        );
        if (hook.onError == HookErrorPolicy.veto) {
          throw HookVetoException(
            hookId: hook.id,
            failure: AppFailure.from(e, stackTrace),
            originalError: e,
            originalStack: stackTrace,
          );
        }
      } catch (e, stackTrace) {
        _logger.warning(
          'Hook "${hook.id}" failed during $phase: $e',
          e,
          stackTrace,
        );
        if (hook.onError == HookErrorPolicy.veto) {
          throw HookVetoException(
            hookId: hook.id,
            failure: AppFailure.from(e, stackTrace),
            originalError: e,
            originalStack: stackTrace,
          );
        }
      }
    }
  }

  /// Fire-and-forget launch — never lets a hook failure propagate.
  void _fireAndForget(Hook hook, HookContext context, HookPhase phase) {
    hook.execute(context, phase).catchError((e, stackTrace) {
      _logger.warning(
        'Hook "${hook.id}" failed during $phase: $e',
        e,
        stackTrace,
      );
    });
  }
}
