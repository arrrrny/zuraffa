/// UI Event Channel — streaming event channel for rendered trees and routed
/// interactions (spec FR-003, FR-004).
library;

import 'dart:async';

import 'rendered_view.dart';
import 'semantic_action.dart';
import 'ui_render_event.dart';

/// A broadcast stream of [UiRenderEvent]s.
///
/// The host UI subscribes to [events] to paint rendered trees; the agent (or
/// its test harness) subscribes to observe interaction routing and policy
/// decisions.
class UiEventChannel {
  final StreamController<UiRenderEvent> _controller =
      StreamController<UiRenderEvent>.broadcast();

  /// Stream of all UI render events. Broadcast so multiple subscribers (host
  /// UI, agent trace recorder, tests) can listen simultaneously.
  Stream<UiRenderEvent> get events => _controller.stream;

  /// Whether the channel is still open (not closed).
  bool get isClosed => _controller.isClosed;

  /// Emit a single event to all subscribers (FR-003, FR-004, FR-006).
  void emit(UiRenderEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  /// Emit a render event for the given [view] (FR-001). Set [isPartial] to
  /// `true` for intermediate progressive-rendering events (FR-003).
  void emitRender(RenderedView view, {bool isPartial = false}) =>
      emit(UiRenderEventRender(view, isPartial: isPartial));

  /// Emit a replace event (FR-001 acceptance 2).
  void emitReplace(String replacedViewId, RenderedView view) =>
      emit(UiRenderEventReplace(replacedViewId, view));

  /// Emit an interaction event (FR-004).
  void emitInteraction(SemanticAction action) =>
      emit(UiRenderEventInteraction(action));

  /// Emit a policy-decision event (FR-006).
  void emitPolicy(SemanticAction action, {required bool approved}) =>
      emit(UiRenderEventPolicy(action, approved: approved));

  /// Emit a done event signalling no more partials are coming for a view.
  void emitDone(String viewId) => emit(UiRenderEventDone(viewId));

  /// Emit an error event (FR-002 — typed errors propagated through the
  /// channel).
  void emitError(Object error) => emit(UiRenderEventError(error));

  /// Close the channel. Idempotent.
  Future<void> close() => _controller.close();
}
