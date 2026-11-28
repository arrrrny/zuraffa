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
        // Preserved regions are always kept as-is.
        buffer.write(region.content);
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

    // If the generated content has GENERATED markers, use the full
    // block (including markers) as the replacement.
    final genStartIdx = generatedLines.indexWhere(
      (l) => l.trim().startsWith('// GENERATED'),
    );
    final genEndIdx = generatedLines.lastIndexWhere(
      (l) => l.trim().startsWith('// END GENERATED'),
    );

    if (genStartIdx >= 0 && genEndIdx > genStartIdx) {
      return generatedLines.sublist(genStartIdx, genEndIdx + 1).join('\n');
    }

    // Fallback: match declarations by name.
    final regionContent = existingRegion.content;
    final declNames = <String>[];

    final classMatch = RegExp(
      r'(?:abstract\s+|sealed\s+)?class\s+(\$?[A-Za-z_][A-Za-z0-9_\$]*)',
    ).firstMatch(regionContent);
    if (classMatch != null) {
      declNames.add(classMatch.group(1)!);
    }

    final extMatch = RegExp(r'extension\s+(\w+)').firstMatch(regionContent);
    if (extMatch != null && !declNames.contains(extMatch.group(1))) {
      declNames.add(extMatch.group(1)!);
    }

    final enumMatch = RegExp(
      r'enum\s+([A-Za-z_][A-Za-z0-9_]*)',
    ).firstMatch(regionContent);
    if (enumMatch != null && !declNames.contains(enumMatch.group(1))) {
      declNames.add(enumMatch.group(1)!);
    }

    if (declNames.isEmpty) return null;

    final generatedDecls = extractDeclarationsFromSource(generatedContent);
    final matchingDecls = <Declaration>[];

    for (final decl in generatedDecls) {
      if (declNames.contains(decl.name)) {
        matchingDecls.add(decl);
      }
    }

    if (matchingDecls.isEmpty) return null;

    // Return concatenated declarations in source order.
    final buffer = StringBuffer();
    for (int i = 0; i < matchingDecls.length; i++) {
      final decl = matchingDecls[i];
      if (i > 0) buffer.writeln();
      buffer.write(
        generatedLines.sublist(decl.startLine, decl.endLine).join('\n'),
      );
    }

    return buffer.toString();
  }

  /// Splice preserved blocks into the replacement content.
  static String _splicePreservedBlocks(
    String replacement,
    List<PreservedBlock> preservedBlocks,
  ) {
    if (preservedBlocks.isEmpty) return replacement;

    final lines = replacement.split('\n');

    // Find the last closing brace at column 0 (end of class).
    int lastBrace = -1;
    for (int i = lines.length - 1; i >= 0; i--) {
      if (lines[i].trim() == '}') {
        lastBrace = i;
        break;
      }
    }

    if (lastBrace < 0) {
      // No class brace found — append at end.
      for (final block in preservedBlocks) {
        lines.add('');
        lines.addAll(block.content.split('\n'));
      }
      return lines.join('\n');
    }

    // Insert preserved blocks before the last closing brace.
    final insertLines = <String>[];
    for (final block in preservedBlocks) {
      insertLines.add('');
      insertLines.addAll(block.content.split('\n'));
    }

    lines.insertAll(lastBrace, insertLines);
    return lines.join('\n');
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
