import 'dart:math';

import 'package:dart_style/dart_style.dart';

import 'declaration_scanner.dart';
import 'merge_types.dart';
import 'region_parser.dart';

/// Applies merge rules to produce the final file content.
///
/// The merge strategy operates on the **line level**, guided by
/// [RegionParser]'s classification of the existing file:
///
/// 1. **Generated regions** → replaced with the corresponding
///    generated content (after splicing in preserved blocks).
///
/// 2. **Preserved regions** → carried over verbatim.
///
/// 3. **User regions** (gaps) → carried over verbatim.
///
/// When the existing file has no region markers, the strategy
/// falls back to a **full replacement** with the generated content.
class MergeStrategy {
  static final DartFormatter _formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );

  /// Merge [existingContent] with [generatedContent].
  static MergeResult merge({
    required String existingContent,
    required String generatedContent,
    required List<SourceRegion> regions,
  }) {
    // Quick path: no existing file or no regions.
    if (existingContent.isEmpty || regions.isEmpty) {
      final formatted = _safeFormat(generatedContent);
      if (formatted == existingContent) {
        return MergeResult.unchanged(existingContent);
      }
      return MergeResult(
        content: formatted,
        hasChanges: true,
        diffSummary: _simpleDiff(existingContent, formatted),
        conflicts: const [],
      );
    }

    // Sort regions by start line.
    final sorted = List<SourceRegion>.from(regions)
      ..sort((a, b) => a.startLine.compareTo(b.startLine));

    final existingLines = existingContent.split('\n');
    final buffer = StringBuffer();
    final diffs = <String>[];
    final conflicts = <MergeConflict>[];
    int cursor = 0;

    for (final region in sorted) {
      // Skip regions that are already covered by previously emitted content.
      if (region.startLine < cursor) {
        continue;
      }

      // Emit user code before this region.
      if (cursor < region.startLine) {
        final userCode = existingLines
            .sublist(cursor, region.startLine)
            .join('\n');
        buffer.write(userCode);
        if (cursor < region.startLine) buffer.writeln();
      }

      if (region.type == RegionType.preserved) {
        // Preserved regions are always kept as-is, followed by a line
        // separator so the following source is not joined onto the
        // end-marker comment (`// @end-preserveclass A {}`).
        buffer.write(region.content);
        buffer.writeln();
      } else if (region.type == RegionType.generated) {
        // Extract any @preserve blocks from the existing generated region
        // before replacing it.
        final preservedBlocks = RegionParser.extractPreservedBlocks(
          region.content,
        );

        // Replace the generated region with the new generated content.
        final replacement = _findGeneratedReplacement(
          existingRegion: region,
          generatedContent: generatedContent,
        );

        if (replacement != null) {
          // Splice preserved blocks into the replacement.
          final merged = _splicePreservedBlocks(replacement, preservedBlocks);
          final formatted = _safeFormat(merged);
          buffer.write(formatted);
          buffer.writeln();

          if (formatted.trim() != region.content.trim()) {
            diffs.add(
              'Replaced generated block at line '
              '${region.startLine + 1}',
            );
          }
        } else {
          // Could not find matching generated content — conflict.
          conflicts.add(
            MergeConflict(
              message:
                  'Generated block at line ${region.startLine + 1} '
                  'has no matching generated content',
              line: region.startLine,
              existingContent: region.content,
              generatedContent: '<no match>',
              suggestion:
                  'The generated block may reference a declaration '
                  'that was removed. Review and delete manually.',
            ),
          );
          buffer.write(region.content);
          buffer.writeln();
        }
      }

      cursor = region.endLine > cursor ? region.endLine : cursor;
    }

    // Emit remaining user code after the last region.
    if (cursor < existingLines.length) {
      buffer.write(existingLines.sublist(cursor).join('\n'));
    }

    final result = buffer.toString();
    final formatted = _safeFormat(result);
    final hasChanges =
        formatted.trimRight() != _safeFormat(existingContent).trimRight();

    return MergeResult(
      content: formatted,
      hasChanges: hasChanges,
      diffSummary: diffs.join('\n'),
      conflicts: conflicts,
    );
  }

  /// Try to find the replacement content in the generated source
  /// for a given existing generated region.
  ///
  /// When the generated content contains `// GENERATED` / `// END GENERATED`
  /// markers, returns the full generated block (markers included) so the
  /// output preserves the marker structure.
  /// Otherwise falls back to declaration-level matching.
  static String? _findGeneratedReplacement({
    required SourceRegion existingRegion,
    required String generatedContent,
  }) {
    final generatedLines = generatedContent.split('\n');

    // Parse the generated content into its generated regions so each
    // existing region is matched to its OWN corresponding block — never
    // a span across every generated block (which would emit A, B, A, B).
    final generatedRegions = RegionParser.parse(
      generatedContent,
    ).where((r) => r.type == RegionType.generated).toList();

    if (generatedRegions.isNotEmpty) {
      final names = _declarationNames(existingRegion.content);
      if (generatedRegions.length == 1) {
        return generatedRegions.first.content;
      }
      // Match by declaration name; fall back to the first block when the
      // names do not identify a unique region.
      for (final r in generatedRegions) {
        final rNames = _declarationNames(r.content);
        if (rNames.any(names.contains)) return r.content;
      }
      return generatedRegions.first.content;
    }

    // Fallback: the generated content has no markers. Collect EVERY
    // declaration in the existing region (not just the first match) and
    // match all corresponding generated declarations in source order.
    final declNames = _declarationNames(existingRegion.content);
    if (declNames.isEmpty) return null;

    final generatedDecls = extractDeclarationsFromSource(generatedContent);
    final matchingDecls = <Declaration>[];
    for (final decl in generatedDecls) {
      if (declNames.contains(decl.name)) {
        matchingDecls.add(decl);
      }
    }

    if (matchingDecls.isEmpty) return null;

    final buffer = StringBuffer();
    for (int i = 0; i < matchingDecls.length; i++) {
      final decl = matchingDecls[i];
      if (i > 0) buffer.writeln();
      buffer.write(
        generatedLines.sublist(decl.startLine, decl.endLine).join('\n'),
      );
    }

    // Wrap the fallback replacement in the generated boundary markers so
    // a preserved method inside the existing class keeps its generated
    // markers on the next regeneration pass.
    return '${RegionParser.generatedStart}\n'
        '${buffer.toString()}\n'
        '${RegionParser.generatedEnd}';
  }

  /// The top-level declaration names present in [content], in source
  /// order.
  static List<String> _declarationNames(String content) => [
    for (final d in extractDeclarationsFromSource(content)) d.name,
  ];

  /// Splice preserved blocks into the replacement content.
  static String _splicePreservedBlocks(
    String replacement,
    List<PreservedBlock> preservedBlocks,
  ) {
    if (preservedBlocks.isEmpty) return replacement;

    var lines = replacement.split('\n');

    for (final block in preservedBlocks) {
      // If the replacement already carries this preserved block (e.g. it
      // was threaded through unchanged), do not insert a duplicate.
      if (replacement.contains(block.content.trim())) continue;

      final blockLines = block.content.split('\n');

      // Restore the block to its original enclosing declaration so a
      // preserved method of A does not land inside B; fall back to the
      // last closing brace when the declaration is unknown.
      final insertAt = _closingBraceFor(lines, block.enclosingDeclaration);

      if (insertAt < 0) {
        // No class brace found — append at end.
        lines.add('');
        lines.addAll(blockLines);
        continue;
      }

      lines.insertAll(insertAt, ['', ...blockLines]);
    }

    return lines.join('\n');
  }

  /// Index of the line holding the closing brace of [declName] in [lines]
  /// (preserved members are inserted BEFORE it), or the last top-level
  /// closing brace when [declName] is `null` or not found. Returns `-1`
  /// when no closing brace exists.
  static int _closingBraceFor(List<String> lines, String? declName) {
    if (declName != null) {
      final decls = extractDeclarationsFromSource(lines.join('\n'));
      for (final d in decls) {
        if (d.name == declName && d.endLine > d.startLine) {
          // d.endLine is exclusive (the line after the closing brace).
          for (int i = d.endLine - 1; i >= d.startLine; i--) {
            if (lines[i].trim() == '}') return i;
          }
        }
      }
    }
    for (int i = lines.length - 1; i >= 0; i--) {
      if (lines[i].trim() == '}') return i;
    }
    return -1;
  }

  /// Format Dart source, returning raw on failure.
  static String _safeFormat(String source) {
    try {
      return _formatter.format(source);
    } catch (_) {
      return source;
    }
  }

  /// Generate a simple diff summary between two strings.
  static String _simpleDiff(String old, String nu) {
    final oldLines = old.split('\n');
    final newLines = nu.split('\n');
    final buffer = StringBuffer();

    final maxLen = max(oldLines.length, newLines.length);
    for (int i = 0; i < maxLen; i++) {
      final oldLine = i < oldLines.length ? oldLines[i] : null;
      final newLine = i < newLines.length ? newLines[i] : null;

      if (oldLine == newLine) continue;

      if (oldLine == null) {
        buffer.writeln('+ $newLine');
      } else if (newLine == null) {
        buffer.writeln('- $oldLine');
      } else {
        buffer.writeln('- $oldLine');
        buffer.writeln('+ $newLine');
      }
    }

    return buffer.toString().trimRight();
  }
}
