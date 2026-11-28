import 'declaration_scanner.dart';
import 'merge_types.dart';

/// AST-based diff between an existing file and newly generated content.
///
/// Uses lightweight pattern matching to extract top-level declarations
/// from both files and compare them. Forzorphy's generated files,
/// the structure is predictable (single generated class + extensions),
/// so a full analyzer parse is unnecessary for diff purposes.
class AstDiff {
  /// Compare [existingSource] with [generatedSource] and return a list
  /// of [DiffEntry] items describing the differences.
  static List<DiffEntry> diff({
    required String existingSource,
    required String generatedSource,
    String? filePath,
  }) {
    final existingLines = existingSource.split('\n');
    final generatedLines = generatedSource.split('\n');

    // Quick path: identical content.
    if (existingSource == generatedSource) return [];

    final entries = <DiffEntry>[];

    final existingDecls = extractDeclarationsFromSource(existingSource);
    final generatedDecls = extractDeclarationsFromSource(generatedSource);

    final existingByName = {
      for (final d in existingDecls) '${d.kind}:${d.name}': d,
    };
    final generatedByName = {
      for (final d in generatedDecls) '${d.kind}:${d.name}': d,
    };

    // Find modifications and removals.
    for (final existing in existingDecls) {
      final generated = generatedByName['${existing.kind}:${existing.name}'];
      if (generated == null) {
        entries.add(
          DiffEntry(
            description: 'Removed: ${existing.kind} ${existing.name}',
            type: DiffType.removed,
            oldLine: existing.startLine,
            newLine: -1,
          ),
        );
      } else {
        final oldContent = existingLines
            .sublist(existing.startLine, existing.endLine)
            .join('\n');
        final newContent = generatedLines
            .sublist(generated.startLine, generated.endLine)
            .join('\n');
        if (oldContent != newContent) {
          entries.add(
            DiffEntry(
              description: 'Modified: ${existing.kind} ${existing.name}',
              type: DiffType.modified,
              oldLine: existing.startLine,
              newLine: generated.startLine,
            ),
          );
        }
      }
    }

    // Find additions.
    for (final generated in generatedDecls) {
      if (!existingByName.containsKey('${generated.kind}:${generated.name}')) {
        entries.add(
          DiffEntry(
            description: 'Added: ${generated.kind} ${generated.name}',
            type: DiffType.added,
            oldLine: -1,
            newLine: generated.startLine,
          ),
        );
      }
    }

    // Check for header changes.
    final existingHeaderEnd = existingDecls.isEmpty
        ? existingLines.length
        : existingDecls.first.startLine;
    final generatedHeaderEnd = generatedDecls.isEmpty
        ? generatedLines.length
        : generatedDecls.first.startLine;

    if (existingLines.sublist(0, existingHeaderEnd).join('\n') !=
        generatedLines.sublist(0, generatedHeaderEnd).join('\n')) {
      entries.add(
        DiffEntry(
          description: 'Modified: file header (imports/comments)',
          type: DiffType.modified,
          oldLine: 0,
          newLine: 0,
        ),
      );
    }

    return entries;
  }

  /// Build a human-readable diff summary.
  static String buildSummary(List<DiffEntry> entries) {
    if (entries.isEmpty) return '';
    return entries.map((e) => e.toString()).join('\n');
  }
}
