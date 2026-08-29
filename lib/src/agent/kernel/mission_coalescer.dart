import 'dart:async';

import 'cancellation.dart';
import 'mission.dart';
import 'mission_event.dart';
import 'resource_handle.dart';

/// A coalescing group: one executing [Mission] + its subscribers (FR-002).
///
/// Exactly one mission in the group executes; all other subscribers receive
/// the same event stream via [events]. The group is removed from the
/// coalescer once the mission reaches a terminal state.
class CoalescingGroup {
  CoalescingGroup(this.mission);

  /// The executing mission.
  final Mission mission;

  /// Broadcast event stream — subscribers may join late and still receive
  /// subsequent events. (Late subscribers do NOT replay buffered partials
  /// by default; the host can replay by re-emitting from the [partials] list
  /// when it observes a new subscriber.)
  final StreamController<MissionEvent> _controller =
      StreamController<MissionEvent>.broadcast();

  Stream<MissionEvent> get events => _controller.stream;

  /// Subscribers attached to this group. Includes the original caller.
  final Set<String> subscribers = <String>{};

  /// Partials accumulated so far (for late-subscriber replay + salvage).
  final List<Object> partials = <Object>[];

  /// Resource handles registered by the executing mission for
  /// cancellation-time disposal (FR-004).
  final List<ResourceHandle> handles = <ResourceHandle>[];

  /// Cancel token shared between the executor and external cancel() calls.
  /// Created by [AgentKernel.submit] and stored here so [AgentKernel.cancel]
  /// can trigger the same instance.
  CancelToken? cancelToken;

  final Completer<MissionOutcome> _done = Completer<MissionOutcome>();

  Future<MissionOutcome> get done => _done.future;

  /// True if [complete] has been called (the group has reached a terminal
  /// state). Used by [AgentKernel.submit] to detect cancellation-during-
  /// execution and return the salvaged outcome instead of the executor's
  /// return value.
  bool get isCompleted => _done.isCompleted;

  void addSubscriber(String callerId) {
    subscribers.add(callerId);
    mission.subscriberIds.add(callerId);
  }

  void registerHandle(ResourceHandle handle) {
    handles.add(handle);
  }

  void emit(MissionEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
      if (event is MissionEventPartial) {
        partials.add(event.payload);
        mission.partials.add(event.payload);
      }
    }
  }

  void complete(MissionOutcome outcome) {
    if (_done.isCompleted) return; // already completed — no-op (e.g. cancel() ran first)
    mission.outcome = outcome;
    switch (outcome) {
      case OutcomeCompleted():
        mission.status = MissionStatus.completed;
        emit(MissionEventCompleted(mission.id, outcome.result));
      case OutcomeCancelledPartial():
        mission.status = MissionStatus.cancelled;
        emit(MissionEventCancelled(mission.id, outcome.partials));
      case OutcomeFailed():
        mission.status = MissionStatus.failed;
        emit(MissionEventFailed(mission.id, outcome.error, outcome.stackTrace));
      case OutcomeCachedServed():
        // Unreachable: the cache is only read in submit(); a group is never
        // completed with a cached outcome. Emit nothing misleading here.
        break;
    }
    _done.complete(outcome);
    _controller.close();
  }

  Future<void> close() async {
    if (!_controller.isClosed) await _controller.close();
  }
}

/// Per-subscriber outcome — used when original cancels but subscribers
/// continue under a new mission (FR-003 escalation policy).
enum CancelPolicy {
  /// Continue executing the existing mission for remaining subscribers.
  continue_,

  /// Escalate: start a new mission, reattach subscribers.
  escalate,

  /// Serve accumulated partials to remaining subscribers and end.
  servePartials,
}
