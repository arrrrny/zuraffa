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

    // Parse the generated content's generated regions ONCE, and track which
    // ones have already been assigned to an existing region so a single
    // generated block is never emitted into two existing regions and no
    // generated region is silently dropped (CodeRabbit findings on
    // merge_strategy.dart:169 and :175).
    final generatedRegions = RegionParser.parse(
      generatedContent,
    ).where((r) => r.type == RegionType.generated).toList();
    final usedGenerated = <int>{};

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

        // Replace the generated region with the new generated content,
        // consuming the matching generated region so it cannot be reused.
        final replacement = _findGeneratedReplacement(
          existingRegion: region,
          generatedContent: generatedContent,
          generatedRegions: generatedRegions,
          usedGenerated: usedGenerated,
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

    // Emit any generated region that was never assigned to an existing
    // region, so generated content is never silently dropped
    // (CodeRabbit finding on merge_strategy.dart:175).
    for (int g = 0; g < generatedRegions.length; g++) {
      if (usedGenerated.contains(g)) continue;
      final content = generatedRegions[g].content;
      final formatted = _safeFormat(content);
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.write(formatted);
      buffer.writeln();
      diffs.add('Appended unmatched generated block ${g + 1}');
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
  /// [generatedRegions] is the generated content's parsed generated regions
  /// and [usedGenerated] tracks which of them (by index) have already been
  /// assigned to an earlier existing region, so each generated region is
  /// emitted at most once (CodeRabbit findings on merge_strategy.dart:169
  /// and :175). The chosen region's index is added to [usedGenerated].
  ///
  /// When the generated content contains `// GENERATED` / `// END GENERATED`
  /// markers, returns the matching generated block (markers included) so the
  /// output preserves the marker structure. Otherwise falls back to
  /// declaration-level matching.
  static String? _findGeneratedReplacement({
    required SourceRegion existingRegion,
    required String generatedContent,
    required List<SourceRegion> generatedRegions,
    required Set<int> usedGenerated,
  }) {
    final generatedLines = generatedContent.split('\n');

    if (generatedRegions.isNotEmpty) {
      final names = _declarationNames(existingRegion.content);
      // Match by declaration name among the regions not yet consumed. A
      // sole generated block is NOT blindly assigned to every existing
      // region: it is used only when it corresponds to this region (its
      // declarations intersect, or this region names none).
      for (int g = 0; g < generatedRegions.length; g++) {
        if (usedGenerated.contains(g)) continue;
        final rNames = _declarationNames(generatedRegions[g].content);
        final corresponds =
            names.isEmpty || rNames.isEmpty || rNames.any(names.contains);
        if (corresponds) {
          usedGenerated.add(g);
          return generatedRegions[g].content;
        }
      }
      return null;
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

      // A null enclosing declaration is a TOP-LEVEL preserved block: it
      // must be inserted at a top-level boundary (before the generated end
      // marker), never inside the last class's body — otherwise a top-level
      // caller can no longer resolve it (CodeRabbit finding on
      // merge_strategy.dart:238).
      if (block.enclosingDeclaration == null) {
        final topLevelAt = _topLevelInsertIndex(lines);
        lines.insertAll(topLevelAt, ['', ...blockLines]);
        continue;
      }

      // Restore the block to its original enclosing declaration so a
      // preserved method of A does not land inside B. When the matched
      // declaration's closing brace cannot be located, do NOT fall back to
      // another class's brace (which would misplace the member) — append
      // the block at the end as a last resort
      // (CodeRabbit finding on merge_strategy.dart:264).
      final insertAt = _closingBraceFor(lines, block.enclosingDeclaration);

      if (insertAt < 0) {
        // No brace found for the named declaration — append at end.
        lines.add('');
        lines.addAll(blockLines);
        continue;
      }

      lines.insertAll(insertAt, ['', ...blockLines]);
    }

    return lines.join('\n');
  }

  /// Index at which a top-level preserved block should be inserted: just
  /// before the generated end marker when present, otherwise at the end of
  /// the content.
  static int _topLevelInsertIndex(List<String> lines) {
    for (int i = lines.length - 1; i >= 0; i--) {
      if (lines[i].trim() == RegionParser.generatedEnd) return i;
    }
    return lines.length;
  }

  /// Index of the line holding the closing brace of [declName] in [lines]
  /// (preserved members are inserted BEFORE it). The closing brace is found
  /// even when it shares its line with the declaration or other tokens
  /// (CodeRabbit finding on merge_strategy.dart:264). Returns `-1` when
  /// [declName] is `null` or its closing brace cannot be located — the
  /// caller must NOT fall back to an unrelated declaration's brace.
  static int _closingBraceFor(List<String> lines, String? declName) {
    if (declName == null) return -1;
    final decls = extractDeclarationsFromSource(lines.join('\n'));
    for (final d in decls) {
      if (d.name == declName && d.endLine > d.startLine) {
        // d.endLine is exclusive (the line after the closing brace). Search
        // the declaration's own span for a line carrying a `}` — including
        // a `}` that shares its line with other tokens (`class A {}`).
        for (int i = d.endLine - 1; i >= d.startLine; i--) {
          if (lines[i].contains('}')) return i;
        }
      }
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
