/// Behavior entity for the `zfa tdd` plugin.
library;

enum BehaviorKind { acceptance, unit }

enum BehaviorState { pending, red, green, done }

class Behavior {
  final String id;
  final String feature;
  final BehaviorKind kind;
  final String description;
  final String sourceCriterion;
  final String target;
  BehaviorState state;

  Behavior({
    required this.id,
    required this.feature,
    required this.kind,
    required this.description,
    required this.sourceCriterion,
    required this.target,
    this.state = BehaviorState.pending,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Behavior && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Behavior(id: $id, kind: $kind, state: $state, traces: $sourceCriterion)';
}
