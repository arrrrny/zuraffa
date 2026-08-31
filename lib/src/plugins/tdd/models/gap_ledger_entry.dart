/// Gap ledger entry model (spec 051-corpus-harness, FR-007/FR-008).
library;

/// Append-only stop record in the gap ledger.
class GapLedgerEntry {
  const GapLedgerEntry({
    required this.feature,
    this.behavior,
    this.step,
    required this.outcome,
    required this.command,
    this.issueLink,
    required this.timestamp,
    this.resolution,
  });

  factory GapLedgerEntry.fromJson(Map<String, dynamic> json) =>
      GapLedgerEntry(
        feature: json['feature'] as String,
        behavior: json['behavior'] as String?,
        step: json['step'] as String?,
        outcome: json['outcome'] as String,
        command: json['command'] as String,
        issueLink: json['issue_link'] as String?,
        timestamp: json['timestamp'] as String,
        resolution: json['resolution'] as String?,
      );

  final String feature;
  final String? behavior;
  final String? step;
  final String outcome;
  final String command;
  final String? issueLink;
  final String timestamp;
  final String? resolution;

  Map<String, dynamic> toJson() => {
    'feature': feature,
    if (behavior != null) 'behavior': behavior,
    if (step != null) 'step': step,
    'outcome': outcome,
    'command': command,
    if (issueLink != null) 'issue_link': issueLink,
    'timestamp': timestamp,
    if (resolution != null) 'resolution': resolution,
  };
}
