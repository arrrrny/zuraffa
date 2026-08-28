/// The kernel's structured input (FR-008).
class Mission {
  Mission({
    required this.missionId,
    required this.spark,
    required this.country,
    this.locale,
    this.budgets = const <String, int>{},
    this.toolAllowlist,
    this.riskTier = RiskTier.standard,
    this.playbook,
  });

  final String missionId;
  final String spark;
  final String country;
  final String? locale;
  final Map<String, int> budgets;
  final Set<String>? toolAllowlist;
  final RiskTier riskTier;
  final String? playbook;
}

/// Risk tier declared on the mission (intercepts with the policy shell,
/// see spec 027).
enum RiskTier {
  standard,
  elevated,
  admin,
}
