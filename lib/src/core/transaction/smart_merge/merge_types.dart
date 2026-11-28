/// AST-Based Smart Regeneration — shared types.
///
/// Defines the data structures used by the merge engine.
library;

// Re-export canonical MergeMode from zorphy_annotation to ensure
// type identity between annotation consumers and the merge engine.
export 'package:zorphy_annotation/zorphy_annotation.dart' show MergeMode;

/// The kind of change a [DiffEntry] represents.
enum DiffType { added, removed, modified, unchanged }

/// A single unit of change detected by the diff engine.
class DiffEntry {
  final String description;
  final DiffType type;
  final int oldLine;
  final int newLine;

  const DiffEntry({
    required this.description,
    required this.type,
    required this.oldLine,
    required this.newLine,
  });

  @override
  String toString() {
    final symbol = switch (type) {
      DiffType.added => '+',
      DiffType.removed => '-',
      DiffType.modified => '~',
      DiffType.unchanged => ' ',
    };
    return '$symbol $description (line $oldLine -> $newLine)';
  }
}

/// A conflict that the merge engine could not automatically resolve.
class MergeConflict {
  final String message;
  final int line;
  final String existingContent;
  final String generatedContent;
  final String suggestion;

  const MergeConflict({
    required this.message,
    required this.line,
    required this.existingContent,
    required this.generatedContent,
    required this.suggestion,
  });

  @override
  String toString() =>
      'Conflict at line ${line + 1}: $message\n'
      '  Suggestion: $suggestion';
}

/// The result of merging an existing file with newly generated content.
class MergeResult {
  /// The final merged source code.
  final String content;

  /// Whether any changes were detected.
  final bool hasChanges;

  /// Human-readable summary of what changed.
  final String diffSummary;

  /// Unresolvable conflicts.
  final List<MergeConflict> conflicts;

  const MergeResult({
    required this.content,
    required this.hasChanges,
    required this.diffSummary,
    required this.conflicts,
  });

  /// A no-op merge result.
  factory MergeResult.unchanged(String content) => MergeResult(
    content: content,
    hasChanges: false,
    diffSummary: '',
    conflicts: const [],
  );

  /// Whether the merge is fully clean (no conflicts).
  bool get isClean => conflicts.isEmpty;
}
