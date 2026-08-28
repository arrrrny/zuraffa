/// Per-mission session state (FR-009).
class AgentState {
  AgentState({required this.missionId, this.steps = const <String>[]});

  final String missionId;
  final List<String> steps;

  AgentState copyWith({List<String>? steps}) => AgentState(
        missionId: missionId,
        steps: steps ?? this.steps,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'missionId': missionId,
        'steps': steps,
      };

  static AgentState fromJson(Map<String, Object?> json) => AgentState(
        missionId: json['missionId'] as String,
        steps: (json['steps'] as List).cast<String>(),
      );
}

/// Persistence interface for [AgentState] (FR-009).
abstract class FileStateStorage {
  Future<void> save(AgentState state);
  Future<AgentState?> load(String missionId);
}

/// In-memory [FileStateStorage] used for tests and as a no-op fallback
/// when no real storage is configured.
class InMemoryFileStateStorage implements FileStateStorage {
  InMemoryFileStateStorage();

  final Map<String, AgentState> _states = <String, AgentState>{};

  @override
  Future<void> save(AgentState state) async {
    _states[state.missionId] = state;
  }

  @override
  Future<AgentState?> load(String missionId) async => _states[missionId];

  /// Whether [missionId] has persisted state.
  bool hasStateFor(String missionId) => _states.containsKey(missionId);
}
