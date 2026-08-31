/// Provenance record model (spec 051-corpus-harness, FR-005/FR-006).
library;

/// Source of provenance for a lib/ file.
enum ProvenanceSource {
  cycleLog,
  setup,
  importCarveOut,
}

/// File-to-invocation mapping.
class ProvenanceRecord {
  const ProvenanceRecord({
    required this.filePath,
    required this.source,
    required this.invocation,
    this.feature,
    this.timestamp,
  });

  factory ProvenanceRecord.fromJson(Map<String, dynamic> json) =>
      ProvenanceRecord(
        filePath: json['file_path'] as String,
        source: ProvenanceSource.values.byName(json['source'] as String),
        invocation: json['invocation'] as String,
        feature: json['feature'] as String?,
        timestamp: json['timestamp'] as String?,
      );

  final String filePath;
  final ProvenanceSource source;
  final String invocation;
  final String? feature;
  final String? timestamp;

  Map<String, dynamic> toJson() => {
    'file_path': filePath,
    'source': source.name,
    'invocation': invocation,
    if (feature != null) 'feature': feature,
    if (timestamp != null) 'timestamp': timestamp,
  };
}
