/// Top-level entry point for the AST-based smart regeneration.
///
/// Orchestrates the full pipeline:
/// 1. Parse existing file regions (GENERATED / @preserve markers).
/// 2. Run AST diff to detect changes.
/// 3. Apply merge strategy to produce final content.
/// 4. Return [MergeResult] with content, diff, and conflicts.
library;

import 'package:dart_style/dart_style.dart';

import 'ast_diff.dart';
import 'declaration_scanner.dart';
import 'merge_strategy.dart';
import 'merge_types.dart';
import 'region_parser.dart';

class MergeOrchestrator {
  static final DartFormatter _formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );

  /// Merge [existingContent] with [generatedContent] using [mode].
  static MergeResult merge({
    required String existingContent,
    required String generatedContent,
    MergeMode mode = MergeMode.smart,
    String? filePath,
  }) {
    // Force mode: just return the generated content directly.
    if (mode == MergeMode.force) {
      final formatted = safeFormat(generatedContent);
      return MergeResult(
        content: formatted,
        hasChanges: formatted != existingContent,
        diffSummary: existingContent.isEmpty
            ? ''
            : simpleDiff(existingContent, formatted),
        conflicts: const [],
      );
    }

    // No existing file.
    if (existingContent.isEmpty) {
      return MergeResult(
        content: safeFormat(generatedContent),
        hasChanges: true,
        diffSummary: '(new file)',
        conflicts: const [],
      );
    }

    // Smart merge: parse regions from existing file.
    final regions = RegionParser.parse(existingContent);
    final diffEntries = AstDiff.diff(
      existingSource: existingContent,
      generatedSource: generatedContent,
      filePath: filePath,
    );

    if (regions.isEmpty && diffEntries.isEmpty) {
      return MergeResult.unchanged(existingContent);
    }

    if (regions.isNotEmpty) {
      return MergeStrategy.merge(
        existingContent: existingContent,
        generatedContent: generatedContent,
        regions: regions,
      );
    }

    // No markers: structural merge.
    return structuralMerge(
      existingContent: existingContent,
      generatedContent: generatedContent,
      diffEntries: diffEntries,
    );
  }

  /// Structural merge for files without region markers.
  ///
  /// Walks the EXISTING file and replaces each generated declaration
  /// in place, preserving every other line — imports, top-level
  /// variables and user declarations — so user-owned source is never
  /// dropped when a generated declaration changes. Generated
  /// declarations absent from the existing file are appended.
  static MergeResult structuralMerge({
    required String existingContent,
    required String generatedContent,
    required List<DiffEntry> diffEntries,
  }) {
    if (existingContent.trimRight() == generatedContent.trimRight()) {
      return MergeResult.unchanged(existingContent);
    }

    final existingLines = existingContent.split('\n');
    final generatedLines = generatedContent.split('\n');

    final existingDecls = extractDeclarationsFromSource(existingContent);
    final generatedDecls = extractDeclarationsFromSource(generatedContent);
    final generatedByName = {
      for (final d in generatedDecls) '${d.kind}:${d.name}': d,
    };

    final buffer = StringBuffer();
    int cursor = 0;
    for (final decl in existingDecls) {
      // Preserve the existing lines before this declaration (imports,
      // top-level variables, comments).
      if (cursor < decl.startLine) {
        buffer.write(existingLines.sublist(cursor, decl.startLine).join('\n'));
        buffer.writeln();
      }
      final gen = generatedByName['${decl.kind}:${decl.name}'];
      if (gen != null) {
        buffer.write(
          generatedLines.sublist(gen.startLine, gen.endLine).join('\n'),
        );
      } else {
        // User declaration — keep it verbatim.
        buffer.write(
          existingLines.sublist(decl.startLine, decl.endLine).join('\n'),
        );
      }
      buffer.writeln();
      cursor = decl.endLine;
    }
    // Preserve any trailing existing lines after the last declaration.
    if (cursor < existingLines.length) {
      buffer.write(existingLines.sublist(cursor).join('\n'));
    }

    // Append generated declarations that have no existing counterpart.
    final existingNames = {
      for (final d in existingDecls) '${d.kind}:${d.name}',
    };
    for (final d in generatedDecls) {
      if (existingNames.contains('${d.kind}:${d.name}')) continue;
      buffer.writeln();
      buffer.write(generatedLines.sublist(d.startLine, d.endLine).join('\n'));
    }

    return MergeResult(
      content: safeFormat(buffer.toString()),
      hasChanges: true,
      diffSummary: AstDiff.buildSummary(diffEntries),
      conflicts: const [],
    );
  }

  /// Format Dart source, returning raw on failure.
  static String safeFormat(String source) {
    try {
      return _formatter.format(source);
    } catch (_) {
      return source;
    }
  }

  /// Generate a simple line-level diff between two strings.
  static String simpleDiff(String old, String nu) {
    final oldLines = old.split('\n');
    final newLines = nu.split('\n');
    final buffer = StringBuffer();
    final maxLen = oldLines.length > newLines.length
        ? oldLines.length
        : newLines.length;
    for (int i = 0; i < maxLen; i++) {
      final o = i < oldLines.length ? oldLines[i] : null;
      final n = i < newLines.length ? newLines[i] : null;
      if (o == n) continue;
      if (o == null) {
        buffer.writeln('+ $n');
      } else if (n == null) {
        buffer.writeln('- $o');
      } else {
        buffer.writeln('- $o');
        buffer.writeln('+ $n');
      }
    }
    return buffer.toString().trimRight();
  }
}
