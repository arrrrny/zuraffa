/// Identifies and classifies line ranges in a Dart source file.
///
/// The merge engine treats the file as a sequence of **regions**:
///
/// - **Generated region**: bracketed by
///   `// GENERATED - DO NOT EDIT` (start) and
///   `// END GENERATED` (end). The content inside is safe to replace.
///
/// - **Preserved region**: bracketed by
///   `// @preserve` (start) and
///   `// @end-preserve` (end). The content inside must survive
///   regeneration even if it falls inside a generated region.
///
/// - **User region**: everything else. Never touched by the merge
///   engine.
///
/// Regions may nest. A `@preserve` inside a `GENERATED` block takes
/// priority — the preserved lines are extracted before the generated
/// block is replaced, then spliced back in.
class RegionParser {
  /// Marker that begins a generated (replaceable) region.
  static const String generatedStart = '// GENERATED - DO NOT EDIT';

  /// Marker that ends a generated region.
  static const String generatedEnd = '// END GENERATED';

  /// Marker that begins a preserved (immutable) region.
  static const String preserveStart = '// @preserve';

  /// Marker that ends a preserved region.
  static const String preserveEnd = '// @end-preserve';

  /// Parse [source] into a list of [SourceRegion]s.
  ///
  /// Lines are 0-based. Each region covers [startLine, endLine).
  static List<SourceRegion> parse(String source) {
    final lines = source.split('\n');
    final regions = <SourceRegion>[];

    // Stack for nested generated regions.
    final genStack = <_Marker>[];
    // Stack for nested preserved regions (within a generated block).
    final preserveStack = <_Marker>[];

    for (int i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();

      // Check for preserve start (only meaningful inside generated).
      if (trimmed.startsWith(preserveStart) &&
          !trimmed.startsWith(preserveEnd)) {
        preserveStack.add(_Marker(i, _MarkerType.preserveStart));
        continue;
      }
      if (trimmed.startsWith(preserveEnd)) {
        if (preserveStack.isNotEmpty) {
          final start = preserveStack.removeLast();
          regions.add(
            SourceRegion(
              startLine: start.line,
              endLine: i + 1,
              type: RegionType.preserved,
              content: lines.sublist(start.line, i + 1).join('\n'),
            ),
          );
        }
        continue;
      }

      // Check for generated block markers.
      if (trimmed.startsWith(generatedStart) &&
          !trimmed.startsWith(generatedEnd)) {
        genStack.add(_Marker(i, _MarkerType.generatedStart));
        continue;
      }
      if (trimmed.startsWith(generatedEnd)) {
        if (genStack.isNotEmpty) {
          final start = genStack.removeLast();
          regions.add(
            SourceRegion(
              startLine: start.line,
              endLine: i + 1,
              type: RegionType.generated,
              content: lines.sublist(start.line, i + 1).join('\n'),
            ),
          );
        }
        continue;
      }
    }

    // Anything not covered by a region is implicitly user code.
    // We don't create explicit user regions — the merge engine treats
    // gaps between regions as user code.

    regions.sort((a, b) => a.startLine.compareTo(b.startLine));
    return regions;
  }

  /// Extract preserved regions from a generated block's content.
  ///
  /// When a generated block is about to be replaced, this extracts
  /// any `@preserve`...`@end-preserve` regions so they can be
  /// spliced into the replacement.
  static List<PreservedBlock> extractPreservedBlocks(String blockContent) {
    final lines = blockContent.split('\n');
    final blocks = <PreservedBlock>[];
    final stack = <int>[];

    for (int i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      if (trimmed.startsWith(preserveStart) &&
          !trimmed.startsWith(preserveEnd)) {
        stack.add(i);
      } else if (trimmed.startsWith(preserveEnd) && stack.isNotEmpty) {
        final start = stack.removeLast();
        blocks.add(
          PreservedBlock(content: lines.sublist(start, i + 1).join('\n')),
        );
      }
    }

    return blocks;
  }
}

/// A contiguous region of source lines classified by its role.
class SourceRegion {
  final int startLine;
  final int endLine;
  final RegionType type;
  final String content;

  const SourceRegion({
    required this.startLine,
    required this.endLine,
    required this.type,
    required this.content,
  });
}

/// Type of a [SourceRegion].
enum RegionType {
  /// Code inside `// GENERATED - DO NOT EDIT` ... `// END GENERATED`.
  generated,

  /// Code inside `// @preserve` ... `// @end-preserve`.
  preserved,
}

/// A preserved block extracted from a generated region.
///
/// These are spliced back into the replacement generated content.
class PreservedBlock {
  final String content;

  const PreservedBlock({required this.content});
}

enum _MarkerType { generatedStart, preserveStart }

class _Marker {
  final int line;
  final _MarkerType type;
  const _Marker(this.line, this.type);
}
