/// UI Render Event — sealed type emitted on the [UiEventChannel]
/// (spec FR-003, FR-004, FR-006).
library;

import 'rendered_view.dart';
import 'semantic_action.dart';

/// A single event on the UI render stream.
///
/// The host UI subscribes to the [UiEventChannel] and renders each event.
/// The agent receives the same channel when it needs to observe UI lifecycle
/// (e.g. for trace recording).
sealed class UiRenderEvent {
  const UiRenderEvent();
}

/// A tree (or partial tree) has been rendered and is ready for the host UI to
/// paint (FR-001, FR-003).
final class UiRenderEventRender extends UiRenderEvent {
  /// The rendered view, or a partial view during progressive streaming.
  final RenderedView view;

  /// `true` when this is an intermediate partial render (FR-003 acceptance 3).
  final bool isPartial;

  const UiRenderEventRender(this.view, {this.isPartial = false});

  @override
  String toString() =>
      'UiRenderEventRender(view=$view, isPartial=$isPartial)';
}

/// A previous view has been replaced by a new tree (FR-001 acceptance 2).
final class UiRenderEventReplace extends UiRenderEvent {
  final String replacedViewId;
  final RenderedView view;

  const UiRenderEventReplace(this.replacedViewId, this.view);

  @override
  String toString() =>
      'UiRenderEventReplace(replaced=$replacedViewId, view=$view)';
}

/// A user interaction has been captured on a rendered tree (FR-004).
final class UiRenderEventInteraction extends UiRenderEvent {
  final SemanticAction action;

  const UiRenderEventInteraction(this.action);

  @override
  String toString() => 'UiRenderEventInteraction(action=$action)';
}

/// A policy decision has been made for a confirm-tier action (FR-006).
final class UiRenderEventPolicy extends UiRenderEvent {
  final SemanticAction action;
  final bool approved;

  const UiRenderEventPolicy(this.action, {required this.approved});

  @override
  String toString() =>
      'UiRenderEventPolicy(action=$action, approved=$approved)';
}

/// The render stream is complete (no more partials coming).
final class UiRenderEventDone extends UiRenderEvent {
  final String viewId;

  const UiRenderEventDone(this.viewId);

  @override
  String toString() => 'UiRenderEventDone(viewId=$viewId)';
}

/// An error during render / validation. Carries the typed exception so the
/// host UI / agent can branch on the error kind (FR-002).
final class UiRenderEventError extends UiRenderEvent {
  final Object error;

  const UiRenderEventError(this.error);

  @override
  String toString() => 'UiRenderEventError(error=$error)';
}
