/// Human checkpoints as policy (issue #810) — the approval-gate registry.
library;

enum PolicyGateRisk { safe, confirm, admin }

class PolicyGate {
  const PolicyGate({
    required this.id,
    required this.description,
    this.risk = PolicyGateRisk.confirm,
  });

  final String id;
  final String description;
  final PolicyGateRisk risk;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'description': description,
    'risk': risk.name,
  };
}

class PolicyGateRegistry {
  const PolicyGateRegistry._();

  static const List<PolicyGate> gates = <PolicyGate>[
    PolicyGate(
      id: 'entity.remove',
      description:
          'Removing an entity scaffold + writing its tombstone receipt. '
          'Destructive: deletes generated files and provenance.',
    ),
    PolicyGate(
      id: 'pubspec.mutate',
      description:
          'Mutating pubspec.yaml dependencies (auto-add or manual). '
          'Affects the dependency graph of the whole project.',
    ),
  ];

  static PolicyGate? byId(String id) {
    for (final g in gates) {
      if (g.id == id) return g;
    }
    return null;
  }

  static List<Map<String, dynamic>> toJsonList() =>
      gates.map((g) => g.toJson()).toList(growable: false);
}
