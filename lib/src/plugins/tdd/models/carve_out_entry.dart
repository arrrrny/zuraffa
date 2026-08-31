/// Carve-out entry model (spec 051-corpus-harness).
library;

/// Manual-UI exemption entry in the carve-out manifest.
class CarveOutEntry {
  const CarveOutEntry({
    required this.path,
    required this.reason,
    required this.addedBy,
    required this.addedAt,
  });

  factory CarveOutEntry.fromJson(Map<String, dynamic> json) =>
      CarveOutEntry(
        path: json['path'] as String,
        reason: json['reason'] as String,
        addedBy: json['added_by'] as String,
        addedAt: json['added_at'] as String,
      );

  final String path;
  final String reason;
  final String addedBy;
  final String addedAt;

  Map<String, dynamic> toJson() => {
    'path': path,
    'reason': reason,
    'added_by': addedBy,
    'added_at': addedAt,
  };
}
