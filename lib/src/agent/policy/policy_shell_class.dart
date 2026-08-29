import 'policy_hook.dart';

/// Composes policy hooks in registration order (FR-011).
///
/// Each hook can be individually disabled via [PolicyHook.enabled].
/// The shell runs all enabled hooks' `beforeToolCall` in order; the
/// first non-allow decision wins. `afterToolCall` runs in reverse order
/// (like middleware), so the first-registered hook wraps the others.
class PolicyShell {
  PolicyShell({List<PolicyHook>? hooks}) {
    if (hooks != null) _hooks.addAll(hooks);
  }

  final List<PolicyHook> _hooks = <PolicyHook>[];

  /// Registered hooks in registration order.
  List<PolicyHook> get hooks => List<PolicyHook>.unmodifiable(_hooks);

  /// Registers a hook.
  void register(PolicyHook hook) => _hooks.add(hook);

  /// Disables a hook by id (FR-011 — individually disableable).
  ///
  /// Throws an [ArgumentError] when no hook with [id] is registered.
  void disable(String id) => _byId(id).enabled = false;

  /// Enables a hook by id.
  ///
  /// Throws an [ArgumentError] when no hook with [id] is registered.
  void enable(String id) => _byId(id).enabled = true;

  PolicyHook _byId(String id) {
    for (final hook in _hooks) {
      if (hook.id == id) return hook;
    }
    throw ArgumentError.value(
      id,
      'id',
      'no policy hook registered with this id',
    );
  }

  /// Notifies all hooks of mission start.
  Future<void> onMissionStart(String missionId) async {
    for (final hook in _hooks) {
      if (!hook.enabled) continue;
      await hook.onMissionStart(missionId);
    }
  }

  /// Notifies all hooks of mission end.
  Future<void> onMissionEnd(String missionId) async {
    for (final hook in _hooks) {
      if (!hook.enabled) continue;
      await hook.onMissionEnd(missionId);
    }
  }

  /// Runs `beforeToolCall` on each enabled hook in order. Returns the
  /// first non-allow decision; if all allow, returns [HookDecisionAllow].
  Future<HookDecision> beforeToolCall(ToolCallContext ctx) async {
    for (final hook in _hooks) {
      if (!hook.enabled) continue;
      final decision = await hook.beforeToolCall(ctx);
      if (decision is! HookDecisionAllow) {
        return decision;
      }
    }
    return const HookDecisionAllow();
  }

  /// Runs `afterToolCall` on each enabled hook in REVERSE registration
  /// order (so the first-registered hook wraps the others). Each hook
  /// may modify the result.
  Future<ToolResult> afterToolCall(
    ToolCallContext ctx,
    ToolResult result,
  ) async {
    var current = result;
    for (final hook in _hooks.reversed) {
      if (!hook.enabled) continue;
      current = await hook.afterToolCall(ctx, current);
    }
    return current;
  }
}
