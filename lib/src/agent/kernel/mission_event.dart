/// Events emitted on a mission's event stream (FR-002, FR-005).
sealed class MissionEvent {
  const MissionEvent(this.missionId);
  final String missionId;
}

/// Progress tick — non-result status update.
final class MissionEventProgress extends MissionEvent {
  const MissionEventProgress(super.missionId, this.message);
  final String message;
}

/// Partial result emitted mid-execution.
final class MissionEventPartial extends MissionEvent {
  const MissionEventPartial(super.missionId, this.payload);
  final Object payload;
}

/// Mission completed normally.
final class MissionEventCompleted extends MissionEvent {
  const MissionEventCompleted(super.missionId, this.result);
  final Object? result;
}

/// Mission failed.
final class MissionEventFailed extends MissionEvent {
  const MissionEventFailed(super.missionId, this.error, [this.stackTrace]);
  final Object error;
  final StackTrace? stackTrace;
}

/// Mission was cancelled; partials salvaged as `cancelled_partial`.
final class MissionEventCancelled extends MissionEvent {
  const MissionEventCancelled(super.missionId, this.partials);
  final List<Object> partials;
}
