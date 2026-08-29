/// Semantic Action — a user interaction captured from a rendered view (spec
/// Key Entities).
///
/// Routed back to the agent through [ActionRouter] / [UiEventChannel]
/// (FR-004).
library;

import 'ui_vocabulary_schema.dart';

/// A user interaction captured from a rendered view (spec Key Entities).
class SemanticAction {
  /// Identifier declared by the agent on the node (e.g. `select_offer_42`).
  final String actionId;

  /// Arbitrary arguments the host UI captured (e.g. the selected option's
  /// value). Free-form so different component types can carry different
  /// payloads.
  final Map<String, Object?> args;

  /// Risk tier — gates whether this action must pass through the [PolicyGate]
  /// (FR-006).
  final ActionTier tier;

  /// View id of the rendered tree that emitted this action. Set by the
  /// `UiRenderTool` when delivering the action so the agent knows which view
  /// to update.
  final String? viewId;

  const SemanticAction({
    required this.actionId,
    this.args = const <String, Object?>{},
    this.tier = ActionTier.safe,
    this.viewId,
  });

  SemanticAction copyWith({
    String? actionId,
    Map<String, Object?>? args,
    ActionTier? tier,
    String? viewId,
  }) => SemanticAction(
    actionId: actionId ?? this.actionId,
    args: args ?? this.args,
    tier: tier ?? this.tier,
    viewId: viewId ?? this.viewId,
  );

  @override
  String toString() =>
      'SemanticAction($actionId tier=$tier viewId=$viewId args=$args)';
}

/// Interface the [UiRenderTool] uses to deliver routed [SemanticAction]s
/// back to the agent (FR-004). Implementations translate to whatever the
/// agent runtime supports (tool result, steering message, etc.).
abstract class ActionRouter {
  void deliver(SemanticAction action);
}

/// In-memory [ActionRouter] capturing delivered actions for test inspection.
class CapturingActionRouter implements ActionRouter {
  final List<SemanticAction> delivered = <SemanticAction>[];

  @override
  void deliver(SemanticAction action) {
    delivered.add(action);
  }
}
