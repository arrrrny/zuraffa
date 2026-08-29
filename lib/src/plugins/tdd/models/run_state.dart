/// `RunState` entity — per-feature resumable state file at
/// `tdd/run-state.json`.
library;

import 'dart:convert';

import 'behavior.dart';

class RunState {
  final String feature;
  final Map<String, BehaviorState> behaviorStates;
  final String? inFlightBehaviorId;
  final String? inFlightStep;

  RunState({
    required this.feature,
    required this.behaviorStates,
    this.inFlightBehaviorId,
    this.inFlightStep,
  });

  factory RunState.empty(String feature) =>
      RunState(feature: feature, behaviorStates: const {});

  RunState advance(String behaviorId, BehaviorState newState) {
    final next = Map<String, BehaviorState>.from(behaviorStates);
    next[behaviorId] = newState;
    return RunState(
      feature: feature,
      behaviorStates: Map.unmodifiable(next),
      inFlightBehaviorId: null,
      inFlightStep: null,
    );
  }

  RunState markInFlight(String behaviorId, String step) {
    return RunState(
      feature: feature,
      behaviorStates: behaviorStates,
      inFlightBehaviorId: behaviorId,
      inFlightStep: step,
    );
  }

  String toJson() {
    final states = <String, String>{};
    behaviorStates.forEach((k, v) => states[k] = v.name);
    return jsonEncode({
      'feature': feature,
      'behavior_states': states,
      if (inFlightBehaviorId != null)
        'in_flight_behavior_id': inFlightBehaviorId,
      if (inFlightStep != null) 'in_flight_step': inFlightStep,
    });
  }

  static RunState fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    final statesRaw = (map['behavior_states'] as Map<String, dynamic>?) ?? {};
    final states = statesRaw.map(
      (k, v) => MapEntry(k, BehaviorState.values.byName(v as String)),
    );
    return RunState(
      feature: map['feature'] as String,
      behaviorStates: Map.unmodifiable(states),
      inFlightBehaviorId: map['in_flight_behavior_id'] as String?,
      inFlightStep: map['in_flight_step'] as String?,
    );
  }

  @override
  String toString() =>
      'RunState(feature: $feature, states: $behaviorStates, '
      'inFlight: $inFlightBehaviorId/$inFlightStep)';
}
