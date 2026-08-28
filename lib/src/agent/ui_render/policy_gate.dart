/// Policy Gate — intercepts `confirm`-tier actions and requires explicit user
/// approval before delivery to the agent (spec FR-006, US5).
library;

import 'dart:async';

import 'semantic_action.dart';
import 'ui_vocabulary_schema.dart';

/// A pending policy decision for one [SemanticAction].
///
/// The host UI receives a [PolicyDecision] for each intercepted confirm-tier
/// action, prompts the user, and calls either [approve] or [deny]. The
/// original action is then delivered to the agent only if approved.
class PolicyDecision {
  /// The action awaiting approval.
  final SemanticAction action;

  /// Completes with the approved action (with `tier` preserved) once the user
  /// approves, or with `null` once the user denies (or the gate is dropped).
  final Future<SemanticAction?> future;

  final Completer<SemanticAction?> _completer;

  PolicyDecision._(this.action, this.future, this._completer);

  factory PolicyDecision.forAction(SemanticAction action) {
    final c = Completer<SemanticAction?>();
    return PolicyDecision._(action, c.future, c);
  }

  /// Mark the action as approved — the gate releases it for agent delivery.
  void approve() {
    if (!_completer.isCompleted) _completer.complete(action);
  }

  /// Mark the action as denied — the gate drops it; nothing reaches the agent.
  void deny() {
    if (!_completer.isCompleted) _completer.complete(null);
  }

  /// Whether the user has already decided.
  bool get isDecided => _completer.isCompleted;
}

/// Intercepts `confirm`-tier actions and gates them behind user approval
/// (spec FR-006).
///
/// Safe-tier actions bypass the gate entirely. The host UI is responsible for
/// surfacing the prompt; the gate itself is just the blocking primitive.
class PolicyGate {
  final List<PolicyDecision> _pending = <PolicyDecision>[];

  /// Read-only view of currently-pending decisions (host UI uses this to know
  /// what to prompt the user about).
  List<PolicyDecision> get pending =>
      List<PolicyDecision>.unmodifiable(_pending.where((d) => !d.isDecided));

  /// Intercept an action. If it's [ActionTier.safe], the returned future
  /// completes immediately with the action unchanged. If it's
  /// [ActionTier.confirm], the future completes when [PolicyDecision.approve]
  /// or [PolicyDecision.deny] is called.
  ///
  /// Returns `null` when denied — the caller (typically the
  /// `UiRenderTool`/`UiEventChannel`) drops the action and emits a
  /// `policyDenied` event (FR-006 acceptance 2).
  Future<SemanticAction?> intercept(SemanticAction action) {
    if (action.tier != ActionTier.confirm) {
      return Future.value(action);
    }
    final decision = PolicyDecision.forAction(action);
    _pending.add(decision);
    return decision.future.whenComplete(() => _pending.remove(decision));
  }

  /// Convenience: approve the most-recently-pending decision.
  void approveLatest() {
    for (var i = _pending.length - 1; i >= 0; i--) {
      if (!_pending[i].isDecided) {
        _pending[i].approve();
        return;
      }
    }
  }

  /// Convenience: deny the most-recently-pending decision.
  void denyLatest() {
    for (var i = _pending.length - 1; i >= 0; i--) {
      if (!_pending[i].isDecided) {
        _pending[i].deny();
        return;
      }
    }
  }
}
