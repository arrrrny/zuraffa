/// SliceFile model (spec 043 data model).
library;

/// Classification of a file's relationship to the slice (FR-010).
enum FileOwnership {
  /// Unique to this feature's page directory.
  owned,

  /// Used by multiple features.
  shared,

  /// External package (SDK, pub dependency). Never a sliced file.
  framework,
}

/// A file included in a slice, with metadata for merge tracking.
class SliceFile {
  /// Creates a slice file record.
  const SliceFile({
    required this.relativePath,
    required this.ownership,
    required this.hashAtCut,
    required this.layer,
  });

  /// Path relative to the project root.
  final String relativePath;

  /// Ownership classification.
  final FileOwnership ownership;

  /// SHA-256 hash of the file contents at extraction time.
  final String hashAtCut;

  /// Architecture layer: presentation, domain, data, di, routing, other.
  final String layer;
}
