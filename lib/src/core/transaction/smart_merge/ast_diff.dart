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

    // Check the source spans that fall OUTSIDE every classified
    // declaration (intervening gaps and the trailing span). A change to
    // top-level code the scanner skips — e.g. a `const schemaVersion`
    // value — produces no declaration diff, so without this the merge
    // would treat the file as unchanged and return the old source.
    if (!_unclassifiedSpansEqual(
      existingLines: existingLines,
      generatedLines: generatedLines,
      existingDecls: existingDecls,
      generatedDecls: generatedDecls,
    )) {
      entries.add(
        DiffEntry(
          description: 'Modified: top-level source outside declarations',
          type: DiffType.modified,
          oldLine: -1,
          newLine: -1,
        ),
      );
    }

    return entries;
  }

  /// Collect the line ranges NOT covered by any declaration (or the
  /// header, which is handled separately) and compare them between the
  /// two sources. Returns `true` when every such span is identical.
  static bool _unclassifiedSpansEqual({
    required List<String> existingLines,
    required List<String> generatedLines,
    required List<Declaration> existingDecls,
    required List<Declaration> generatedDecls,
  }) {
    final existingGaps = _unclassifiedContent(existingLines, existingDecls);
    final generatedGaps = _unclassifiedContent(generatedLines, generatedDecls);
    return existingGaps == generatedGaps;
  }

  /// Concatenate the lines outside [decls]' ranges (excluding the header
  /// before the first declaration). Each line is normalized by stripping
  /// only its TRAILING whitespace, so a formatting-only trailing-space
  /// difference does not register as a change — while LEADING whitespace is
  /// preserved, so a change to the indentation inside a triple-quoted
  /// string payload (which `trim()` would have erased) still produces a
  /// diff entry (CodeRabbit finding on ast_diff.dart:157).
  static String _unclassifiedContent(
    List<String> lines,
    List<Declaration> decls,
  ) {
    final covered = <bool>[for (var _ in lines) false];
    for (final d in decls) {
      for (int i = d.startLine; i < d.endLine && i < covered.length; i++) {
        covered[i] = true;
      }
    }
    final firstDeclLine = decls.isEmpty ? lines.length : decls.first.startLine;
    final buffer = StringBuffer();
    for (int i = firstDeclLine; i < lines.length; i++) {
      if (covered[i]) continue;
      buffer.writeln(lines[i].trimRight());
    }
    return buffer.toString();
  }

  /// Build a human-readable diff summary.
  static String buildSummary(List<DiffEntry> entries) {
    if (entries.isEmpty) return '';
    return entries.map((e) => e.toString()).join('\n');
  }
}
