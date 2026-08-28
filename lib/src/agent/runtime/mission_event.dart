/// Typed events streamed by [AgentKernel.runMission] (FR-008).
sealed class MissionEvent {
  MissionEvent(this.missionId);
  final String missionId;
}

final class MissionEventStarted extends MissionEvent {
  MissionEventStarted(super.missionId, this.startedAt);
  final DateTime startedAt;
}

final class MissionEventToolCallStart extends MissionEvent {
  MissionEventToolCallStart(super.missionId, this.toolName, this.args);
  final String toolName;
  final Map<String, Object?> args;
}

final class MissionEventToolCallResult extends MissionEvent {
  MissionEventToolCallResult(super.missionId, this.toolName, this.result);
  final String toolName;
  final Object? result;
}

final class MissionEventAssistantMessage extends MissionEvent {
  MissionEventAssistantMessage(super.missionId, this.content);
  final String content;
}

final class MissionEventCompleted extends MissionEvent {
  MissionEventCompleted(super.missionId, this.outcome);
  final Object? outcome;
}

final class MissionEventFailed extends MissionEvent {
  MissionEventFailed(super.missionId, this.error, [this.stackTrace]);
  final Object error;
  final StackTrace? stackTrace;
}
