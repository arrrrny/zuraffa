import 'mission.dart';
import 'mission_event.dart';

/// SPI for `dart_agent_core`'s `StatefulAgent` (FR-005, FR-013).
///
/// The [AgentKernel] delegates the agent loop entirely to this interface;
/// it does NOT implement the loop itself (FR-013 — no duplication). A real
/// `dart_agent_core` installation provides the implementation; tests provide
/// a stub.
abstract class StatefulAgent {
  /// Streams typed events for [mission]. The kernel orchestrates the
  /// tool registry + hooks around this call.
  Stream<MissionEvent> runStream(Mission mission);
}

/// A stub [StatefulAgent] that emits a start + completed event pair.
/// Used in tests and as a fallback when `dart_agent_core` is not on the
/// path.
class StubStatefulAgent implements StatefulAgent {
  StubStatefulAgent({this.outcome});

  final Object? outcome;
  int callCount = 0;

  @override
  Stream<MissionEvent> runStream(Mission mission) async* {
    callCount++;
    yield MissionEventStarted(mission.missionId, DateTime.now());
    yield MissionEventCompleted(mission.missionId, outcome);
  }
}
